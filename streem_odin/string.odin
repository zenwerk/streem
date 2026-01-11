// ============================================================================
// string.odin - Streem言語の文字列型実装
// ============================================================================
//
// 概要:
//   このファイルはStreem言語における文字列型の実装を提供します。
//   NaN-boxing技術を使用して、64ビット値の中に文字列データを効率的に格納します。
//
// 文字列の種類:
//   Streemの文字列は、長さに応じて4つの異なる方法で格納されます：
//
//   1. STRING_I (インライン短文字列): 5バイト以下
//      - 64ビット値の中に直接格納（長さ1バイト + データ最大5バイト）
//      - ヒープ割り当て不要で最も高速
//      - メモリレイアウト: [tag:16bit][length:8bit][data:40bit]
//
//   2. STRING_6 (6バイトインライン): 正確に6バイト
//      - 長さバイト不要で6バイト全てをデータに使用
//      - メモリレイアウト: [tag:16bit][data:48bit]
//
//   3. STRING_O (所有文字列): 7バイト以上、ヒープ割り当て
//      - Streemが所有権を持ち、解放責任がある
//      - ポインタでStrm_String_Struct構造体を参照
//
//   4. STRING_F (外部/静的文字列): 7バイト以上、外部所有
//      - 静的文字列やインターン文字列用
//      - 個別解放不要（プログラム終了時に一括解放）
//
// 文字列インターン:
//   同じ内容の文字列を複数回作成する際、インターンテーブルを使用して
//   メモリを節約し、文字列比較を高速化します。
//   短い文字列（6バイト以下）は自動的にインライン化されるため、
//   インターンテーブルは長い文字列のみに使用されます。
//
// 参照: src/strm.h, src/string.c
// ============================================================================

package streem

import "core:hash"
import "core:mem"
import "core:strings"
import "core:sync"

// ============================================================================
// 文字列型の定義
// ============================================================================

// ----------------------------------------------------------------------------
// Strm_String - NaN-boxed文字列型
// ----------------------------------------------------------------------------
// 説明:
//   Strm_Valueの派生型として定義された文字列専用の型。
//   NaN-boxingにより、短い文字列は値の中に直接格納され、
//   長い文字列はヒープ上の構造体へのポインタとして格納されます。
//
// 使用例:
//   short_str := strm_str_new("hello")  // インライン格納（STRING_I）
//   long_str := strm_str_new("hello, world!") // ヒープ割り当て（STRING_O）
// ----------------------------------------------------------------------------
Strm_String :: distinct Strm_Value

// ----------------------------------------------------------------------------
// Strm_String_Struct - ヒープ割り当て文字列の構造体
// ----------------------------------------------------------------------------
// 説明:
//   7バイト以上の文字列用のヒープ構造体。
//   STRING_OとSTRING_Fタグを持つ文字列がこの構造体を参照します。
//
// フィールド:
//   ptr - Null終端されたC文字列へのポインタ
//   len - 文字列の長さ（Null終端を除く）
//
// メモリレイアウト:
//   +----------------+
//   | ptr (cstring)  | -> "hello, world!\0"
//   +----------------+
//   | len (i32)      | = 13
//   +----------------+
// ----------------------------------------------------------------------------
Strm_String_Struct :: struct {
	ptr: cstring, // 文字列データへのポインタ（Null終端）
	len: i32,     // 文字列の長さ
}

// ----------------------------------------------------------------------------
// STRM_STR_NULL - Null文字列定数
// ----------------------------------------------------------------------------
// 説明:
//   空または無効な文字列を表す定数値。
//   文字列が存在しない場合や初期化前の状態を示すのに使用。
// ----------------------------------------------------------------------------
STRM_STR_NULL :: Strm_String(0)

// ============================================================================
// 文字列インターンテーブル
// ============================================================================
//
// インターンとは:
//   同じ内容の文字列を一度だけメモリに格納し、
//   以降は同じ参照を再利用する最適化技術。
//
// 利点:
//   - メモリ使用量の削減（重複文字列を排除）
//   - 文字列比較の高速化（ポインタ比較で済む場合がある）
//   - シンボルや識別子に特に効果的
//
// 実装:
//   FNV-1aハッシュをキーとしたハッシュテーブルを使用。
//   マルチスレッド安全のためmutexで保護。
// ============================================================================

// ----------------------------------------------------------------------------
// Intern_Entry - インターンテーブルのエントリ
// ----------------------------------------------------------------------------
// 説明:
//   インターンテーブルに格納される各エントリの構造体。
//   ハッシュ値をキャッシュして検索を高速化。
//
// フィールド:
//   str  - インターンされた文字列値
//   hash - FNV-1aで計算されたハッシュ値（衝突検出用）
// ----------------------------------------------------------------------------
@(private)
Intern_Entry :: struct {
	str:  Strm_String, // インターンされた文字列値
	hash: u64,         // キャッシュされたハッシュ値
}

// グローバルインターンテーブル
// 7バイト以上の文字列のみを格納（短い文字列はインライン化される）
@(private)
intern_table: map[u64]Intern_Entry

// インターンテーブル保護用のmutex
// 複数スレッドからの同時アクセスを防止
@(private)
intern_mutex: sync.Mutex

// ----------------------------------------------------------------------------
// strm_intern_init - インターンテーブルの初期化
// ----------------------------------------------------------------------------
// 説明:
//   インターンテーブルを初期化します。
//   プログラム開始時に一度だけ呼び出す必要があります。
//   既に初期化されている場合は何もしません。
//
// スレッド安全性:
//   mutex保護により、複数スレッドから同時に呼び出しても安全。
//
// 使用例:
//   strm_intern_init()  // main()の最初で呼び出し
// ----------------------------------------------------------------------------
strm_intern_init :: proc() {
	sync.mutex_lock(&intern_mutex)
	defer sync.mutex_unlock(&intern_mutex)

	if intern_table == nil {
		intern_table = make(map[u64]Intern_Entry)
	}
}

// ----------------------------------------------------------------------------
// strm_intern_cleanup - インターンテーブルのクリーンアップ
// ----------------------------------------------------------------------------
// 説明:
//   インターンテーブルを解放し、格納された全ての文字列を解放します。
//   プログラム終了時に呼び出してメモリリークを防止。
//
// 注意:
//   この関数呼び出し後、インターンされた文字列への参照は無効になります。
//
// 使用例:
//   defer strm_intern_cleanup()  // main()の最後で呼び出し
// ----------------------------------------------------------------------------
strm_intern_cleanup :: proc() {
	sync.mutex_lock(&intern_mutex)
	defer sync.mutex_unlock(&intern_mutex)

	// 全てのインターン文字列を解放
	for _, entry in intern_table {
		strm_str_free(entry.str)
	}
	delete(intern_table)
	intern_table = nil
}

// ----------------------------------------------------------------------------
// str_hash - 文字列のハッシュ計算
// ----------------------------------------------------------------------------
// 説明:
//   FNV-1aアルゴリズムを使用して文字列のハッシュ値を計算します。
//   インターンテーブルのキーとして使用。
//
// 引数:
//   s - ハッシュを計算する文字列
//
// 戻り値:
//   64ビットのFNV-1aハッシュ値
//
// アルゴリズム:
//   FNV-1a (Fowler-Noll-Vo) は高速で衝突の少ないハッシュ関数。
//   特に短い文字列に対して良好な分布を示す。
// ----------------------------------------------------------------------------
@(private)
str_hash :: proc(s: string) -> u64 {
	return hash.fnv64a(transmute([]u8)s)
}

// ============================================================================
// 文字列の作成
// ============================================================================

// ----------------------------------------------------------------------------
// strm_str_new - 所有文字列の作成
// ----------------------------------------------------------------------------
// 説明:
//   新しい所有文字列（STRING_O）を作成します。
//   Streemが所有権を持ち、不要になったら解放する責任があります。
//
// 引数:
//   s         - 作成元のOdin文字列
//   allocator - メモリアロケータ（省略時はcontext.allocator）
//
// 戻り値:
//   新しく作成されたStrm_String
//   - 5バイト以下: STRING_I（インライン）
//   - 6バイト: STRING_6（インライン）
//   - 7バイト以上: STRING_O（ヒープ割り当て）
//
// メモリ管理:
//   STRING_Oとして作成された文字列は、strm_str_free()で解放が必要。
//
// 使用例:
//   s1 := strm_str_new("hi")      // STRING_I（解放不要）
//   s2 := strm_str_new("hello!")  // STRING_6（解放不要）
//   s3 := strm_str_new("hello, world!")  // STRING_O（要解放）
//   defer strm_str_free(s3)
// ----------------------------------------------------------------------------
strm_str_new :: proc(s: string, allocator := context.allocator) -> Strm_String {
	return str_new_internal(s, false, allocator)
}

// ----------------------------------------------------------------------------
// strm_str_new_raw - 生ポインタからの所有文字列作成
// ----------------------------------------------------------------------------
// 説明:
//   バイトポインタと長さから所有文字列を作成します。
//   外部ライブラリやC言語インターフェースからの文字列作成に使用。
//
// 引数:
//   ptr       - 文字列データへのポインタ
//   len       - 文字列の長さ
//   allocator - メモリアロケータ（省略時はcontext.allocator）
//
// 戻り値:
//   新しく作成されたStrm_String
//   ptrがnilの場合は空文字列を返す
//
// 使用例:
//   buf: [100]u8 = ...
//   s := strm_str_new_raw(raw_data(buf[:]), 10)
// ----------------------------------------------------------------------------
strm_str_new_raw :: proc(ptr: [^]u8, len: i32, allocator := context.allocator) -> Strm_String {
	if ptr == nil {
		return str_new_internal("", false, allocator)
	}
	s := string(ptr[:len])
	return str_new_internal(s, false, allocator)
}

// ----------------------------------------------------------------------------
// strm_str_static - 静的文字列参照の作成
// ----------------------------------------------------------------------------
// 説明:
//   静的文字列への参照（STRING_F）を作成します。
//   元の文字列の所有権を取得せず、参照のみを保持します。
//
// 引数:
//   s - 参照する静的文字列
//
// 戻り値:
//   STRING_Fタグを持つStrm_String
//
// 注意:
//   呼び出し側は、参照される文字列がStrm_Stringより長く生存することを
//   保証する必要があります。主にリテラル文字列やグローバル文字列に使用。
//
// 使用例:
//   // グローバル定数の参照
//   VERSION :: "1.0.0"
//   version_str := strm_str_static(VERSION)
// ----------------------------------------------------------------------------
strm_str_static :: proc(s: string) -> Strm_String {
	return str_new_internal(s, true, context.allocator)
}

// ----------------------------------------------------------------------------
// str_new_internal - 文字列作成の内部実装
// ----------------------------------------------------------------------------
// 説明:
//   全ての文字列作成関数の内部実装。
//   文字列の長さに応じて最適な格納方法を選択します。
//
// 引数:
//   s         - 作成元の文字列
//   is_static - trueの場合STRING_F、falseの場合STRING_Oを作成
//   allocator - メモリアロケータ
//
// 戻り値:
//   適切なタグを持つStrm_String
//
// 内部処理フロー:
//   1. 長さが6未満 → STRING_I（インライン、長さ+データ）
//   2. 長さが6 → STRING_6（インライン、データのみ）
//   3. 長さが7以上 → STRING_O または STRING_F（ヒープ構造体）
//
// メモリレイアウト（STRING_I、5バイト以下）:
//   ビット: [63:48 タグ][47:40 長さ][39:0 文字データ]
//   例: "abc" → [STRING_I][3]['a']['b']['c'][0][0]
//
// メモリレイアウト（STRING_6、正確に6バイト）:
//   ビット: [63:48 タグ][47:0 文字データ]
//   例: "abcdef" → [STRING_6]['a']['b']['c']['d']['e']['f']
// ----------------------------------------------------------------------------
@(private)
str_new_internal :: proc(s: string, is_static: bool, allocator := context.allocator) -> Strm_String {
	slen := i32(len(s))

	if slen < 6 {
		// STRING_I: 短い文字列（長さバイト + 最大5バイトのデータ）をインライン格納
		val: u64 = 0
		val_bytes := transmute([8]u8)val

		// 最初のバイト（タグの後）に長さを格納
		val_bytes[0] = u8(slen)
		// 文字列データをコピー
		for i in 0 ..< slen {
			val_bytes[1 + i] = s[i]
		}
		val = transmute(u64)val_bytes
		return Strm_String((u64(Value_Tag.String_I) << 48) | (val & STRM_VAL_MASK))
	} else if slen == 6 {
		// STRING_6: 正確に6バイトをインライン格納
		val: u64 = 0
		val_bytes := transmute([8]u8)val
		for i in 0 ..< 6 {
			val_bytes[i] = s[i]
		}
		val = transmute(u64)val_bytes
		return Strm_String((u64(Value_Tag.String_6) << 48) | (val & STRM_VAL_MASK))
	} else {
		// ヒープ割り当て文字列
		context.allocator = allocator
		str_struct := new(Strm_String_Struct)

		if is_static {
			// STRING_F: 外部/静的 - ポインタを格納するだけ
			str_struct.ptr = strings.clone_to_cstring(s)
			str_struct.len = slen
			ptr_val := u64(uintptr(str_struct)) & STRM_VAL_MASK
			return Strm_String((u64(Value_Tag.String_F) << 48) | ptr_val)
		} else {
			// STRING_O: 所有 - Null終端文字列用のバッファを割り当て
			buf := make([]u8, slen + 1)
			copy(buf[:slen], s)
			buf[slen] = 0 // Null終端
			str_struct.ptr = cstring(raw_data(buf))
			str_struct.len = slen
			ptr_val := u64(uintptr(str_struct)) & STRM_VAL_MASK
			return Strm_String((u64(Value_Tag.String_O) << 48) | ptr_val)
		}
	}
}

// ----------------------------------------------------------------------------
// strm_str_intern - インターン文字列の作成/取得
// ----------------------------------------------------------------------------
// 説明:
//   文字列をインターンテーブルに登録し、同じ内容の文字列は
//   同じ参照を返すようにします。
//
// 引数:
//   s         - インターンする文字列
//   allocator - メモリアロケータ（省略時はcontext.allocator）
//
// 戻り値:
//   インターンされたStrm_String
//   - 6バイト以下: 常にインライン（テーブル不使用）
//   - 7バイト以上: インターンテーブルから取得または新規登録
//
// 動作:
//   1. 短い文字列（≤6バイト）はインラインなのでそのまま作成
//   2. 長い文字列はハッシュテーブルを検索
//   3. 既存の場合はその参照を返す
//   4. 新規の場合はSTRING_Fとして登録
//
// スレッド安全性:
//   mutex保護により、複数スレッドから同時に呼び出しても安全。
//
// 使用例:
//   // シンボルや識別子に推奨
//   sym1 := strm_str_intern("variable_name")
//   sym2 := strm_str_intern("variable_name")
//   // sym1とsym2は同じビットパターン（高速比較可能）
// ----------------------------------------------------------------------------
strm_str_intern :: proc(s: string, allocator := context.allocator) -> Strm_String {
	// 短い文字列は常にインライン - インターンテーブル不要
	if len(s) <= 6 {
		return str_new_internal(s, false, allocator)
	}

	// 長い文字列はインターンテーブルを使用
	h := str_hash(s)

	sync.mutex_lock(&intern_mutex)
	defer sync.mutex_unlock(&intern_mutex)

	// 必要に応じてテーブルを初期化
	if intern_table == nil {
		intern_table = make(map[u64]Intern_Entry)
	}

	// 既にインターンされているか確認
	if entry, ok := intern_table[h]; ok {
		// 同じ文字列か確認（ハッシュ衝突チェック）
		entry_copy := entry.str
		if strm_str_ptr(&entry_copy) == s {
			return entry.str
		}
		// ハッシュ衝突 - 対処が必要（現在は新規作成）
		// 実際にはFNV-1aの衝突は短い文字列では稀
	}

	// 新しいインターン文字列を作成（静的/外部として - 個別解放されない）
	new_str := str_new_internal(s, true, allocator)
	intern_table[h] = Intern_Entry{str = new_str, hash = h}

	return new_str
}

// ----------------------------------------------------------------------------
// strm_str_intern_p - 文字列がインターンされているか判定
// ----------------------------------------------------------------------------
// 説明:
//   文字列がインターン済み（または短いインライン）かどうかを判定します。
//   インターン文字列は個別解放の必要がありません。
//
// 引数:
//   str - 判定する文字列
//
// 戻り値:
//   true  - インライン（STRING_I, STRING_6）または外部（STRING_F）
//   false - 所有文字列（STRING_O）で個別解放が必要
//
// 使用例:
//   s := strm_str_new("hello, world!")
//   if !strm_str_intern_p(s) {
//       defer strm_str_free(s)  // STRING_Oなので解放が必要
//   }
// ----------------------------------------------------------------------------
strm_str_intern_p :: proc(str: Strm_String) -> bool {
	tag := strm_value_tag(Strm_Value(str))
	#partial switch tag {
	case .String_I, .String_6, .String_F:
		return true  // インラインまたは外部 → 個別解放不要
	case .String_O:
		return false // 所有 → 解放が必要
	case:
		return false
	}
}

// ============================================================================
// 文字列の抽出
// ============================================================================

// ----------------------------------------------------------------------------
// strm_str_len - 文字列の長さを取得
// ----------------------------------------------------------------------------
// 説明:
//   文字列の長さ（バイト数）を返します。
//   Null終端は含みません。
//
// 引数:
//   str - 長さを取得する文字列
//
// 戻り値:
//   文字列の長さ（バイト数）
//   不正なタグの場合は0
//
// 実装詳細:
//   - STRING_I: ペイロードの最初のバイトから取得
//   - STRING_6: 固定で6を返す
//   - STRING_O/F: 構造体のlenフィールドから取得
//
// 使用例:
//   s := strm_str_new("hello")
//   length := strm_str_len(s)  // 5
// ----------------------------------------------------------------------------
strm_str_len :: proc(str: Strm_String) -> i32 {
	tag := strm_value_tag(Strm_Value(str))
	#partial switch tag {
	case .String_I:
		// 長さはペイロードの最初のバイトに格納
		val_bytes := transmute([8]u8)u64(str)
		return i32(val_bytes[0])
	case .String_6:
		return 6 // 固定長
	case .String_O, .String_F:
		ptr := strm_value_rawptr(Strm_Value(str))
		str_struct := cast(^Strm_String_Struct)ptr
		return str_struct.len
	case:
		return 0
	}
}

// ----------------------------------------------------------------------------
// strm_str_ptr - 文字列をOdin文字列として取得
// ----------------------------------------------------------------------------
// 説明:
//   Strm_StringをOdin文字列（スライス）として取得します。
//   インライン文字列の場合、値自体の中のデータへの参照を返します。
//
// 引数:
//   str - 取得元の文字列へのポインタ
//         （インライン文字列の場合、値自体を参照するためポインタが必要）
//
// 戻り値:
//   文字列データを指すOdin文字列
//
// 警告:
//   インライン文字列（STRING_I, STRING_6）の場合、返されるスライスは
//   strが有効な間のみ有効です。strが変更または破棄されると無効になります。
//
// 使用例:
//   s := strm_str_new("hello")
//   odin_str := strm_str_ptr(&s)  // "hello"
//   fmt.println(odin_str)
// ----------------------------------------------------------------------------
strm_str_ptr :: proc(str: ^Strm_String) -> string {
	tag := strm_value_tag(Strm_Value(str^))
	#partial switch tag {
	case .String_I:
		// 値自体の中のデータへのポインタを取得
		val_bytes := cast([^]u8)str
		length := val_bytes[0]
		return string(val_bytes[1:][:length])
	case .String_6:
		val_bytes := cast([^]u8)str
		return string(val_bytes[:6])
	case .String_O, .String_F:
		ptr := strm_value_rawptr(Strm_Value(str^))
		str_struct := cast(^Strm_String_Struct)ptr
		return string(str_struct.ptr)[:str_struct.len]
	case:
		return ""
	}
}

// ----------------------------------------------------------------------------
// strm_str_cstr - Null終端C文字列を取得
// ----------------------------------------------------------------------------
// 説明:
//   Strm_StringをNull終端のC文字列（cstring）として取得します。
//   インライン文字列の場合、提供されたバッファにコピーします。
//
// 引数:
//   str - 取得元の文字列
//   buf - インライン文字列用のバッファ（最低7バイト必要）
//         ヒープ文字列の場合は無視される
//
// 戻り値:
//   Null終端のC文字列へのポインタ
//   - インライン文字列: bufの先頭を指す（bufがnilまたは小さい場合nil）
//   - ヒープ文字列: 構造体のptrを直接返す
//
// 注意:
//   インライン文字列の場合、返される値はbufの生存期間に依存します。
//
// 使用例:
//   s := strm_str_new("hello")
//   buf: [16]u8
//   c_str := strm_str_cstr(s, buf[:])
//   if c_str != nil {
//       // C関数に渡す
//       some_c_function(c_str)
//   }
// ----------------------------------------------------------------------------
strm_str_cstr :: proc(str: Strm_String, buf: []u8 = nil) -> cstring {
	tag := strm_value_tag(Strm_Value(str))
	#partial switch tag {
	case .String_I:
		// バッファが提供されていない、または小さすぎる場合はnil
		if buf == nil || len(buf) < 7 {
			return nil
		}
		val_bytes := transmute([8]u8)u64(str)
		length := int(val_bytes[0])
		// バッファにコピー
		for i in 0 ..< length {
			buf[i] = val_bytes[1 + i]
		}
		buf[length] = 0 // Null終端
		return cstring(raw_data(buf))
	case .String_6:
		if buf == nil || len(buf) < 7 {
			return nil
		}
		val_bytes := transmute([8]u8)u64(str)
		for i in 0 ..< 6 {
			buf[i] = val_bytes[i]
		}
		buf[6] = 0 // Null終端
		return cstring(raw_data(buf))
	case .String_O, .String_F:
		// ヒープ文字列は既にNull終端されている
		ptr := strm_value_rawptr(Strm_Value(str))
		str_struct := cast(^Strm_String_Struct)ptr
		return str_struct.ptr
	case:
		return nil
	}
}

// ============================================================================
// 文字列の比較
// ============================================================================

// ----------------------------------------------------------------------------
// strm_str_eq - 文字列の等価比較
// ----------------------------------------------------------------------------
// 説明:
//   2つの文字列が等しいかどうかを比較します。
//   可能な限り高速なパスを使用します。
//
// 引数:
//   a - 比較する文字列1
//   b - 比較する文字列2
//
// 戻り値:
//   true  - 文字列の内容が等しい
//   false - 文字列の内容が異なる
//
// 最適化:
//   1. ビットパターンが同一 → 即座にtrue（最速）
//   2. 両方がSTRING_F（インターン）でビットが異なる → 即座にfalse
//   3. 長さが異なる → false
//   4. 内容を比較
//
// 使用例:
//   s1 := strm_str_new("hello")
//   s2 := strm_str_new("hello")
//   s3 := strm_str_new("world")
//   strm_str_eq(s1, s2)  // true
//   strm_str_eq(s1, s3)  // false
// ----------------------------------------------------------------------------
strm_str_eq :: proc(a: Strm_String, b: Strm_String) -> bool {
	// 高速パス: ビットパターンが同一
	if u64(a) == u64(b) {
		return true
	}

	// 両方が外部（インターン）の場合 - ポインタ比較で十分
	tag_a := strm_value_tag(Strm_Value(a))
	tag_b := strm_value_tag(Strm_Value(b))
	if tag_a == .String_F && tag_b == .String_F {
		// 両方が外部/インターンでビットが異なる → 異なる文字列
		return false
	}

	// 長さを比較
	len_a := strm_str_len(a)
	len_b := strm_str_len(b)
	if len_a != len_b {
		return false
	}

	// 内容を比較
	a_copy := a
	b_copy := b
	str_a := strm_str_ptr(&a_copy)
	str_b := strm_str_ptr(&b_copy)
	return str_a == str_b
}

// ============================================================================
// 文字列ユーティリティ
// ============================================================================

// ----------------------------------------------------------------------------
// strm_str_to_string - Odin文字列への変換（コピー作成）
// ----------------------------------------------------------------------------
// 説明:
//   Strm_Stringから新しいOdin文字列を作成します。
//   strm_str_ptr()と異なり、独立したコピーを作成するため、
//   元の文字列が破棄されても有効です。
//
// 引数:
//   str       - 変換元の文字列
//   allocator - メモリアロケータ（省略時はcontext.allocator）
//
// 戻り値:
//   新しく割り当てられたOdin文字列
//   呼び出し側で解放が必要
//
// 使用例:
//   s := strm_str_new("hello")
//   odin_str := strm_str_to_string(s)
//   defer delete(odin_str)
//   // odin_strはsとは独立して使用可能
// ----------------------------------------------------------------------------
strm_str_to_string :: proc(str: Strm_String, allocator := context.allocator) -> string {
	str_copy := str
	s := strm_str_ptr(&str_copy)
	return strings.clone(s, allocator)
}

// ----------------------------------------------------------------------------
// strm_str_value - Strm_StringをStrm_Valueに変換
// ----------------------------------------------------------------------------
// 説明:
//   文字列型を汎用値型に変換します。
//   型システムでの互換性のために使用。
//
// 引数:
//   str - 変換する文字列
//
// 戻り値:
//   同じビットパターンを持つStrm_Value
//
// 使用例:
//   s := strm_str_new("hello")
//   v := strm_str_value(s)  // Strm_Valueとして使用可能
// ----------------------------------------------------------------------------
strm_str_value :: proc(str: Strm_String) -> Strm_Value {
	return Strm_Value(str)
}

// ----------------------------------------------------------------------------
// strm_value_str - Strm_ValueをStrm_Stringに変換
// ----------------------------------------------------------------------------
// 説明:
//   汎用値型を文字列型に変換します。
//   値が文字列であることを前提とします。
//
// 引数:
//   v - 変換する値（文字列タグを持つこと）
//
// 戻り値:
//   同じビットパターンを持つStrm_String
//
// 注意:
//   値が文字列でない場合の動作は未定義です。
//   呼び出し前にstrm_value_tag()で確認することを推奨。
//
// 使用例:
//   v := some_strm_value()
//   if strm_string_p(v) {
//       s := strm_value_str(v)
//       // 文字列として操作
//   }
// ----------------------------------------------------------------------------
strm_value_str :: proc(v: Strm_Value) -> Strm_String {
	return Strm_String(v)
}

// ----------------------------------------------------------------------------
// strm_str_free - 文字列リソースの解放
// ----------------------------------------------------------------------------
// 説明:
//   所有文字列（STRING_O）のリソースを解放します。
//   インライン文字列やインターン文字列には何もしません。
//
// 引数:
//   str       - 解放する文字列
//   allocator - メモリアロケータ（作成時と同じものを使用）
//
// 動作:
//   - STRING_I, STRING_6: 何もしない（ヒープ割り当てなし）
//   - STRING_O: バッファと構造体を解放
//   - STRING_F: cstringコピーと構造体を解放
//
// 注意:
//   同じ文字列を複数回解放しないでください（二重解放）。
//   解放後の文字列へのアクセスは未定義動作です。
//
// 使用例:
//   s := strm_str_new("hello, world!")
//   // 使用...
//   strm_str_free(s)  // 使い終わったら解放
// ----------------------------------------------------------------------------
strm_str_free :: proc(str: Strm_String, allocator := context.allocator) {
	tag := strm_value_tag(Strm_Value(str))
	if tag == .String_O {
		// STRING_O: 所有文字列 - バッファと構造体を解放
		context.allocator = allocator
		ptr := strm_value_rawptr(Strm_Value(str))
		str_struct := cast(^Strm_String_Struct)ptr
		// 文字列バッファを解放
		if str_struct.ptr != nil {
			free(rawptr(str_struct.ptr))
		}
		// 構造体を解放
		free(str_struct)
	} else if tag == .String_F {
		// STRING_F: 外部/静的文字列 - cstringコピーと構造体を解放
		context.allocator = allocator
		ptr := strm_value_rawptr(Strm_Value(str))
		str_struct := cast(^Strm_String_Struct)ptr
		// cstringコピーを解放
		if str_struct.ptr != nil {
			free(rawptr(str_struct.ptr))
		}
		free(str_struct)
	}
	// STRING_I, STRING_6: ヒープ割り当てなし - 何もしない
}
