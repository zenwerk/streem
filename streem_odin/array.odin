package streem

// ============================================================================
// 配列型 (Array Type)
// ============================================================================
// NaNボクシングを使用した64ビット値として配列を表現する。
// Streemの配列は動的型付けされた値の列を格納する。
//
// 参照: src/strm.h, src/array.c
//
// 配列の種類:
//   - ARRAY:  通常の配列（インデックスでアクセス）
//   - STRUCT: 名前付きフィールドを持つ配列（構造体的な使用）
//
// メモリレイアウト:
//   配列構造体とデータバッファは連続したメモリに配置される。
//   これによりキャッシュ効率が向上し、アロケーション回数が減少する。
//
//   +-------------------+
//   | Strm_Array_Struct |  ← ヘッダー
//   +-------------------+
//   | Strm_Value[0]     |  ← データバッファ（インライン）
//   | Strm_Value[1]     |
//   | ...               |
//   +-------------------+
//
// 使用例（Streemコード）:
//   [1, 2, 3]                    # 通常の配列
//   {name: "Alice", age: 30}     # 構造体（headers付き配列）

import "core:mem"

// ============================================================================
// 型定義 (Type Definitions)
// ============================================================================

// Strm_Array - 配列を表すNaNボクシング値
// Strm_Valueと同じビットレイアウトだが、配列専用の型として区別する。
// これにより型安全性が向上し、配列操作の意図が明確になる。
Strm_Array :: distinct Strm_Value

// Strm_Array_Struct - ヒープ上に確保される配列の内部構造
// 配列のメタデータと要素へのポインタを保持する。
//
// フィールド:
//   len     - 配列の要素数
//   ptr     - 要素バッファへのポインタ（構造体の直後に配置）
//   headers - フィールド名の配列（構造体的配列の場合）
//   ns      - 関連付けられた名前空間（型付きオブジェクトの場合）
Strm_Array_Struct :: struct {
	len:     i32,               // 要素数
	ptr:     [^]Strm_Value,     // 要素バッファへのポインタ
	headers: Strm_Array,        // フィールド名（オプション、構造体用）
	ns:      ^Strm_State,       // 名前空間（オプション、型付きオブジェクト用）
}

// STRM_ARY_NULL - null配列値
// 0はNaNボクシングで有効なポインタ値ではないため、nullを表現できる
STRM_ARY_NULL :: Strm_Array(0)

// ============================================================================
// 配列の作成 (Array Creation)
// ============================================================================

// ----------------------------------------------------------------------------
// strm_ary_new - 新しい配列を作成
// ----------------------------------------------------------------------------
// 指定された値で初期化された配列を作成する。
// valuesがnilの場合は、長さ0の空配列を作成する。
//
// 引数:
//   values    - 初期値の配列（nilで空配列）
//   allocator - 使用するアロケータ（デフォルトはcontext.allocator）
//
// 戻り値:
//   作成された配列
//
// 例:
//   ary := strm_ary_new({strm_int_value(1), strm_int_value(2)})
strm_ary_new :: proc(values: []Strm_Value = nil, allocator := context.allocator) -> Strm_Array {
	context.allocator = allocator
	length := i32(len(values)) if values != nil else 0
	return strm_ary_new_len(length, values, allocator)
}

// ----------------------------------------------------------------------------
// strm_ary_new_len - 指定長の配列を作成
// ----------------------------------------------------------------------------
// 指定された長さの配列を作成する。
// valuesが提供され、十分な長さがあればその値をコピーする。
// そうでなければnil値で初期化する。
//
// 引数:
//   length    - 配列の長さ
//   values    - 初期値（オプション）
//   allocator - 使用するアロケータ
//
// 戻り値:
//   作成された配列
strm_ary_new_len :: proc(length: i32, values: []Strm_Value = nil, allocator := context.allocator) -> Strm_Array {
	context.allocator = allocator

	// 構造体とバッファを連続したメモリに確保
	// これにより1回のアロケーションで済み、メモリ局所性も向上する
	total_size := size_of(Strm_Array_Struct) + size_of(Strm_Value) * int(length)
	raw_mem, _ := mem.alloc(total_size)

	// 構造体とバッファのポインタを設定
	ary := cast(^Strm_Array_Struct)raw_mem
	buf := cast([^]Strm_Value)(uintptr(raw_mem) + size_of(Strm_Array_Struct))

	if values != nil && len(values) >= int(length) {
		// 提供された値をコピー
		for i in 0 ..< length {
			buf[i] = values[i]
		}
	} else {
		// nil値で初期化
		for i in 0 ..< length {
			buf[i] = strm_nil_value()
		}
	}

	// 構造体のフィールドを初期化
	ary.ptr = buf
	ary.len = length
	ary.ns = nil
	ary.headers = STRM_ARY_NULL

	// NaNボクシングされたタグ付きポインタ値を作成
	// 上位ビットにArrayタグ、下位ビットにポインタを格納
	ptr_val := u64(uintptr(ary)) & STRM_VAL_MASK
	return Strm_Array((u64(Value_Tag.Array) << 48) | ptr_val)
}

// ----------------------------------------------------------------------------
// strm_ary_new_struct - 構造体配列を作成
// ----------------------------------------------------------------------------
// フィールド名（headers）を持つ構造体的な配列を作成する。
// Streemの構造体リテラル `{name: "Alice", age: 30}` で使用される。
//
// 引数:
//   values    - 要素の値
//   headers   - フィールド名の配列
//   ns        - 関連付ける名前空間（オプション）
//   allocator - 使用するアロケータ
//
// 戻り値:
//   作成された構造体配列（Structタグ付き）
//
// 例:
//   headers := strm_ary_new({strm_str_value("name"), strm_str_value("age")})
//   values := {strm_str_value("Alice"), strm_int_value(30)}
//   person := strm_ary_new_struct(values, headers)
strm_ary_new_struct :: proc(
	values: []Strm_Value,
	headers: Strm_Array,
	ns: ^Strm_State = nil,
	allocator := context.allocator,
) -> Strm_Array {
	// まず通常の配列として作成
	ary := strm_ary_new(values, allocator)
	// headersと名前空間を設定
	strm_ary_set_headers(ary, headers)
	strm_ary_set_ns(ary, ns)
	// タグをStructに変更（構造体であることを示す）
	ptr_val := u64(ary) & STRM_VAL_MASK
	return Strm_Array((u64(Value_Tag.Struct) << 48) | ptr_val)
}

// ============================================================================
// 配列アクセス (Array Access)
// ============================================================================

// ----------------------------------------------------------------------------
// strm_ary_struct - 配列の内部構造体を取得
// ----------------------------------------------------------------------------
// NaNボクシング値から内部のStrm_Array_Structへのポインタを取得する。
//
// 引数:
//   ary - 配列値
//
// 戻り値:
//   内部構造体へのポインタ
strm_ary_struct :: proc(ary: Strm_Array) -> ^Strm_Array_Struct {
	ptr := strm_value_rawptr(Strm_Value(ary))
	return cast(^Strm_Array_Struct)ptr
}

// ----------------------------------------------------------------------------
// strm_ary_len - 配列の長さを取得
// ----------------------------------------------------------------------------
// 配列の要素数を返す。
//
// 引数:
//   ary - 配列値
//
// 戻り値:
//   要素数（null配列の場合は0）
strm_ary_len :: proc(ary: Strm_Array) -> i32 {
	if u64(ary) == 0 {
		return 0
	}
	return strm_ary_struct(ary).len
}

// ----------------------------------------------------------------------------
// strm_ary_ptr - 要素バッファへのポインタを取得
// ----------------------------------------------------------------------------
// 配列要素の先頭へのポインタを返す。
// 直接アクセスが必要な場合に使用する。
//
// 引数:
//   ary - 配列値
//
// 戻り値:
//   要素バッファへのポインタ（null配列の場合はnil）
strm_ary_ptr :: proc(ary: Strm_Array) -> [^]Strm_Value {
	if u64(ary) == 0 {
		return nil
	}
	return strm_ary_struct(ary).ptr
}

// ----------------------------------------------------------------------------
// strm_ary_headers - フィールド名（headers）を取得
// ----------------------------------------------------------------------------
// 構造体配列のフィールド名を格納した配列を返す。
// 通常の配列の場合はnull配列を返す。
//
// 引数:
//   ary - 配列値
//
// 戻り値:
//   フィールド名の配列、またはSTRM_ARY_NULL
strm_ary_headers :: proc(ary: Strm_Array) -> Strm_Array {
	if u64(ary) == 0 {
		return STRM_ARY_NULL
	}
	return strm_ary_struct(ary).headers
}

// ----------------------------------------------------------------------------
// strm_ary_ns - 関連付けられた名前空間を取得
// ----------------------------------------------------------------------------
// 配列に関連付けられた名前空間を返す。
// これによりユーザー定義型のインスタンスを表現できる。
//
// 引数:
//   ary - 配列値
//
// 戻り値:
//   名前空間へのポインタ、またはnil
strm_ary_ns :: proc(ary: Strm_Array) -> ^Strm_State {
	if u64(ary) == 0 {
		return nil
	}
	return strm_ary_struct(ary).ns
}

// ----------------------------------------------------------------------------
// strm_ary_set_headers - フィールド名を設定
// ----------------------------------------------------------------------------
// 配列にフィールド名（headers）を設定する。
// これにより通常の配列を構造体的に使用できるようになる。
//
// 引数:
//   ary     - 対象の配列
//   headers - フィールド名の配列
strm_ary_set_headers :: proc(ary: Strm_Array, headers: Strm_Array) {
	if u64(ary) == 0 {
		return
	}
	strm_ary_struct(ary).headers = headers
}

// ----------------------------------------------------------------------------
// strm_ary_set_ns - 名前空間を設定
// ----------------------------------------------------------------------------
// 配列に名前空間を関連付ける。
// これによりメソッドディスパッチで適切な名前空間が選択される。
//
// 引数:
//   ary - 対象の配列
//   ns  - 関連付ける名前空間
strm_ary_set_ns :: proc(ary: Strm_Array, ns: ^Strm_State) {
	if u64(ary) == 0 {
		return
	}
	strm_ary_struct(ary).ns = ns
}

// ----------------------------------------------------------------------------
// strm_ary_get - インデックスで要素を取得
// ----------------------------------------------------------------------------
// 指定されたインデックスの要素を取得する。
// 範囲外のインデックスの場合はnil値とfalseを返す。
//
// 引数:
//   ary   - 配列値
//   index - 要素のインデックス（0始まり）
//
// 戻り値:
//   (value, ok) - 要素の値と成功フラグ
strm_ary_get :: proc(ary: Strm_Array, index: i32) -> (Strm_Value, bool) {
	if u64(ary) == 0 {
		return strm_nil_value(), false
	}
	ary_struct := strm_ary_struct(ary)
	// 境界チェック
	if index < 0 || index >= ary_struct.len {
		return strm_nil_value(), false
	}
	return ary_struct.ptr[index], true
}

// ----------------------------------------------------------------------------
// strm_ary_set - インデックスで要素を設定
// ----------------------------------------------------------------------------
// 指定されたインデックスの要素を設定する。
// 範囲外のインデックスの場合は何もせずfalseを返す。
//
// 引数:
//   ary   - 配列値
//   index - 要素のインデックス（0始まり）
//   value - 設定する値
//
// 戻り値:
//   成功した場合true、失敗した場合false
strm_ary_set :: proc(ary: Strm_Array, index: i32, value: Strm_Value) -> bool {
	if u64(ary) == 0 {
		return false
	}
	ary_struct := strm_ary_struct(ary)
	// 境界チェック
	if index < 0 || index >= ary_struct.len {
		return false
	}
	ary_struct.ptr[index] = value
	return true
}

// ============================================================================
// 配列の比較 (Array Comparison)
// ============================================================================

// ----------------------------------------------------------------------------
// strm_ary_eq - 配列の等価比較
// ----------------------------------------------------------------------------
// 2つの配列が等しいかどうかを判定する。
// 要素数と全要素の値が一致する場合にtrueを返す。
//
// 引数:
//   a - 比較する配列1
//   b - 比較する配列2
//
// 戻り値:
//   等しい場合true
strm_ary_eq :: proc(a: Strm_Array, b: Strm_Array) -> bool {
	// 高速パス: 同一のビットパターン（同じオブジェクト）
	if u64(a) == u64(b) {
		return true
	}

	// null配列の処理
	if u64(a) == 0 || u64(b) == 0 {
		return false
	}

	// 長さの比較
	len_a := strm_ary_len(a)
	len_b := strm_ary_len(b)
	if len_a != len_b {
		return false
	}

	// 要素ごとの比較
	ptr_a := strm_ary_ptr(a)
	ptr_b := strm_ary_ptr(b)
	for i in 0 ..< len_a {
		if !strm_value_eq(ptr_a[i], ptr_b[i]) {
			return false
		}
	}

	return true
}

// ============================================================================
// 配列ユーティリティ (Array Utilities)
// ============================================================================

// ----------------------------------------------------------------------------
// strm_ary_value - Strm_ArrayをStrm_Valueに変換
// ----------------------------------------------------------------------------
// 配列値を汎用値型に変換する。
// 型変換のみで、ビットパターンは変わらない。
//
// 引数:
//   ary - 配列値
//
// 戻り値:
//   汎用値型
strm_ary_value :: proc(ary: Strm_Array) -> Strm_Value {
	return Strm_Value(ary)
}

// ----------------------------------------------------------------------------
// strm_value_ary - Strm_ValueをStrm_Arrayに変換
// ----------------------------------------------------------------------------
// 汎用値型を配列値型に変換する。
// 値が実際に配列であることを前提とする（チェックなし）。
//
// 引数:
//   v - 汎用値
//
// 戻り値:
//   配列値
strm_value_ary :: proc(v: Strm_Value) -> Strm_Array {
	return Strm_Array(v)
}

// ----------------------------------------------------------------------------
// strm_ary_slice - 配列をスライスとして取得
// ----------------------------------------------------------------------------
// 配列の要素をOdinのスライスとして返す。
// ループ処理などで便利に使用できる。
//
// 引数:
//   ary - 配列値
//
// 戻り値:
//   要素のスライス（null配列の場合はnil）
//
// 例:
//   for elem in strm_ary_slice(ary) {
//       // 各要素を処理
//   }
strm_ary_slice :: proc(ary: Strm_Array) -> []Strm_Value {
	if u64(ary) == 0 {
		return nil
	}
	ary_struct := strm_ary_struct(ary)
	return ary_struct.ptr[:ary_struct.len]
}

// ----------------------------------------------------------------------------
// strm_ary_free - 配列のメモリを解放
// ----------------------------------------------------------------------------
// 配列が使用しているメモリを解放する。
// 構造体とバッファは連続して確保されているため、1回の解放で済む。
//
// 注意:
//   通常、Streemのガベージコレクションが管理するため、
//   手動で呼び出す必要はない。
//
// 引数:
//   ary       - 解放する配列
//   allocator - 使用するアロケータ
strm_ary_free :: proc(ary: Strm_Array, allocator := context.allocator) {
	if u64(ary) == 0 {
		return
	}
	context.allocator = allocator
	ptr := strm_value_rawptr(Strm_Value(ary))
	// 構造体とバッファは連続して確保されているため、まとめて解放
	free(ptr)
}

// ----------------------------------------------------------------------------
// strm_is_array_like - 配列的な値かどうかを判定
// ----------------------------------------------------------------------------
// 値がArray型またはStruct型かどうかを判定する。
// 両方とも配列操作（インデックスアクセスなど）が可能。
//
// 引数:
//   v - 判定する値
//
// 戻り値:
//   配列的な値の場合true
strm_is_array_like :: proc(v: Strm_Value) -> bool {
	tag := strm_value_tag(v)
	return tag == .Array || tag == .Struct
}
