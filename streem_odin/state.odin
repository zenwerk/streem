package streem

// ============================================================================
// 名前空間とスコープ管理 (Namespace and Scope Management)
// ============================================================================
// 変数バインディングとスコープチェーンを管理する。
// Streemのレキシカルスコープと名前空間（モジュール）システムの基盤。
//
// 参照: src/strm.h, src/ns.c
//
// 概要:
//   - Strm_State: スコープを表す構造体。変数環境とスコープチェーンを保持
//   - レキシカルスコープ: prev ポインタで親スコープをリンク
//   - 名前空間: グローバル登録された名前付きスコープ
//
// スコープチェーンの例:
//   グローバル → 名前空間 → 関数ローカル → ブロックローカル
//
// 変数検索:
//   現在のスコープから始めて、親スコープを順に検索する。
//   最初に見つかった変数を使用（シャドウイング）。

// ============================================================================
// 状態フラグ (State Flags)
// ============================================================================

// State_Flag - スコープの属性フラグ
State_Flag :: enum {
	Udef, // ユーザー定義名前空間（インスタンス作成可能）
	      // 組み込み名前空間（Array, String等）はこのフラグを持たない
}

// State_Flags - フラグのビットセット
State_Flags :: bit_set[State_Flag]

// ============================================================================
// 状態構造体 (State Structure)
// ============================================================================

// Strm_State - スコープ/名前空間を表す構造体
// 変数バインディングとスコープチェーンを管理する。
//
// フィールド:
//   env   - 変数バインディングのハッシュテーブル（内部化文字列をキーとして使用）
//   prev  - 親スコープへのポインタ（レキシカルスコープの実現）
//   name  - 名前空間名（匿名スコープの場合は STRM_STR_NULL）
//   flags - 名前空間の属性フラグ
Strm_State :: struct {
	env:   map[Strm_String]Strm_Value, // 変数バインディング
	prev:  ^Strm_State,                // 親スコープ（スコープチェーン）
	name:  Strm_String,                // 名前空間名
	flags: State_Flags,                // 属性フラグ
}

// ============================================================================
// 状態の作成と破棄 (State Creation and Destruction)
// ============================================================================

// ----------------------------------------------------------------------------
// strm_state_new - 新しいスコープを作成
// ----------------------------------------------------------------------------
// オプションで親スコープを指定できる。
// 親スコープを指定すると、変数検索時にスコープチェーンを辿る。
//
// 引数:
//   prev - 親スコープ（nilでルートスコープ）
//
// 戻り値:
//   新しいスコープ
//
// 例:
//   global := strm_state_new()           // ルートスコープ
//   local := strm_state_new(global)      // globalを親とするスコープ
strm_state_new :: proc(prev: ^Strm_State = nil) -> ^Strm_State {
	s := new(Strm_State)
	s.env = make(map[Strm_String]Strm_Value)
	s.prev = prev
	s.name = STRM_STR_NULL  // 匿名スコープ
	s.flags = {}
	return s
}

// ----------------------------------------------------------------------------
// strm_ns_new - 名前付き名前空間を作成
// ----------------------------------------------------------------------------
// ユーザー定義の名前空間を作成する。
// このバージョンはグローバル登録を行わない（内部用）。
//
// 引数:
//   prev - 親スコープ
//   name - 名前空間名
//
// 戻り値:
//   新しい名前空間
strm_ns_new :: proc(prev: ^Strm_State, name: string) -> ^Strm_State {
	s := strm_state_new(prev)
	s.name = strm_str_intern(name)
	s.flags = {.Udef}  // ユーザー定義フラグを設定
	return s
}

// ----------------------------------------------------------------------------
// strm_state_destroy - スコープを破棄
// ----------------------------------------------------------------------------
// スコープとその変数環境を解放する。
// 親スコープは破棄しない（親は別途管理される）。
//
// 引数:
//   s - 破棄するスコープ
strm_state_destroy :: proc(s: ^Strm_State) {
	if s == nil {
		return
	}
	delete(s.env)
	free(s)
}

// ============================================================================
// 変数操作 (Variable Operations)
// ============================================================================
// 変数の定義、設定、取得を行う。
// 文字列キーと Strm_String キーの両方のバージョンを提供。

// ----------------------------------------------------------------------------
// strm_var_def_str - 変数を定義（文字列キー版）
// ----------------------------------------------------------------------------
// 現在のスコープに新しい変数を定義する。
// 既に同名の変数が存在する場合は失敗する。
//
// 引数:
//   state - 対象スコープ
//   name  - 変数名（文字列）
//   value - 初期値
//
// 戻り値:
//   true  - 成功
//   false - 失敗（変数が既に存在）
strm_var_def_str :: proc(state: ^Strm_State, name: string, value: Strm_Value) -> bool {
	if state == nil {
		return false
	}
	key := strm_str_intern(name)
	if key in state.env {
		return false // 既に定義済み
	}
	state.env[key] = value
	return true
}

// ----------------------------------------------------------------------------
// strm_var_def_sym - 変数を定義（Strm_Stringキー版）
// ----------------------------------------------------------------------------
// 現在のスコープに新しい変数を定義する。
// 内部化済み文字列をキーとして使用（高速）。
//
// 引数:
//   state - 対象スコープ
//   name  - 変数名（内部化文字列）
//   value - 初期値
//
// 戻り値:
//   true  - 成功
//   false - 失敗（変数が既に存在）
strm_var_def_sym :: proc(state: ^Strm_State, name: Strm_String, value: Strm_Value) -> bool {
	if state == nil {
		return false
	}
	if name in state.env {
		return false // 既に定義済み
	}
	state.env[name] = value
	return true
}

// strm_var_def - オーバーロード版（文字列 or Strm_String）
strm_var_def :: proc {
	strm_var_def_str,
	strm_var_def_sym,
}

// ----------------------------------------------------------------------------
// strm_var_set_str - 変数を設定（文字列キー版）
// ----------------------------------------------------------------------------
// 変数に値を設定する。スコープチェーンを検索し、
// 既存の変数があれば更新、なければ現在のスコープに新規作成。
//
// 引数:
//   state - 対象スコープ
//   name  - 変数名（文字列）
//   value - 設定する値
//
// 戻り値:
//   STRM_OK - 成功
//   STRM_NG - 失敗
strm_var_set_str :: proc(state: ^Strm_State, name: string, value: Strm_Value) -> int {
	if state == nil {
		return STRM_NG
	}
	key := strm_str_intern(name)
	return strm_var_set_sym(state, key, value)
}

// ----------------------------------------------------------------------------
// strm_var_set_sym - 変数を設定（Strm_Stringキー版）
// ----------------------------------------------------------------------------
// スコープチェーンを検索して変数を更新、または新規作成する。
//
// 検索順序:
//   1. 現在のスコープ
//   2. 親スコープ（再帰的に）
//   3. 見つからなければ現在のスコープに新規作成
//
// 引数:
//   state - 対象スコープ
//   name  - 変数名（内部化文字列）
//   value - 設定する値
//
// 戻り値:
//   STRM_OK - 成功
//   STRM_NG - 失敗
strm_var_set_sym :: proc(state: ^Strm_State, name: Strm_String, value: Strm_Value) -> int {
	if state == nil {
		return STRM_NG
	}
	// スコープチェーンを辿って既存の変数を検索
	s := state
	for s != nil {
		if name in s.env {
			// 既存の変数を更新
			s.env[name] = value
			return STRM_OK
		}
		s = s.prev
	}
	// 見つからなければ現在のスコープに新規作成
	state.env[name] = value
	return STRM_OK
}

// strm_var_set - オーバーロード版
strm_var_set :: proc {
	strm_var_set_str,
	strm_var_set_sym,
}

// ----------------------------------------------------------------------------
// strm_var_get_str - 変数を取得（文字列キー版）
// ----------------------------------------------------------------------------
// スコープチェーンを検索して変数の値を取得する。
//
// 引数:
//   state - 対象スコープ
//   name  - 変数名（文字列）
//
// 戻り値:
//   (value, found) - 値と発見フラグ
strm_var_get_str :: proc(state: ^Strm_State, name: string) -> (Strm_Value, bool) {
	key := strm_str_intern(name)
	return strm_var_get_sym(state, key)
}

// ----------------------------------------------------------------------------
// strm_var_get_sym - 変数を取得（Strm_Stringキー版）
// ----------------------------------------------------------------------------
// スコープチェーンを検索して変数の値を取得する。
// 現在のスコープから開始し、見つかるまで親スコープを辿る。
//
// 引数:
//   state - 対象スコープ
//   name  - 変数名（内部化文字列）
//
// 戻り値:
//   (value, found) - 値と発見フラグ
//   見つからなければ (nil値, false)
strm_var_get_sym :: proc(state: ^Strm_State, name: Strm_String) -> (Strm_Value, bool) {
	// スコープチェーンを辿って検索
	s := state
	for s != nil {
		if val, ok := s.env[name]; ok {
			return val, true
		}
		s = s.prev
	}
	return strm_nil_value(), false
}

// ----------------------------------------------------------------------------
// strm_var_get_val - 変数を取得（C互換版）
// ----------------------------------------------------------------------------
// ステータスコードを返すC言語スタイルのインターフェース。
//
// 引数:
//   state - 対象スコープ
//   name  - 変数名
//   val   - 値の格納先（nilでない場合）
//
// 戻り値:
//   STRM_OK - 成功（値はvalに格納）
//   STRM_NG - 失敗（変数が見つからない）
strm_var_get_val :: proc(state: ^Strm_State, name: Strm_String, val: ^Strm_Value) -> int {
	v, found := strm_var_get_sym(state, name)
	if !found {
		return STRM_NG
	}
	if val != nil {
		val^ = v
	}
	return STRM_OK
}

// strm_var_get - オーバーロード版
strm_var_get :: proc {
	strm_var_get_str,
	strm_var_get_sym,
}

// ----------------------------------------------------------------------------
// strm_var_match - パターンマッチ代入
// ----------------------------------------------------------------------------
// 分割代入（destructuring）で使用される。
// 例: `[a, b] = [1, 2]` のような構文
//
// 動作:
//   - 変数が未定義: 新しくバインド
//   - 変数が定義済み: 既存の値と比較（同じならOK、異なればNG）
//
// この比較動作により、パターンマッチで同じ変数が複数回出現した場合に
// 全ての出現箇所で同じ値であることを検証できる。
//
// 引数:
//   state - 対象スコープ
//   name  - 変数名
//   value - マッチさせる値
//
// 戻り値:
//   STRM_OK - 成功（バインドまたは一致）
//   STRM_NG - 失敗（既存値と不一致）
strm_var_match :: proc(state: ^Strm_State, name: Strm_String, value: Strm_Value) -> int {
	if state == nil {
		return STRM_NG
	}
	// このスコープで既にバインドされているか確認
	if existing, ok := state.env[name]; ok {
		// 既にバインド済み: 値を比較
		if strm_value_eq(existing, value) {
			return STRM_OK
		}
		return STRM_NG  // 値が一致しない
	}
	// 未バインド: 新しくバインド
	state.env[name] = value
	return STRM_OK
}

// ----------------------------------------------------------------------------
// strm_env_copy - 環境をコピー（import用）
// ----------------------------------------------------------------------------
// ソーススコープの全変数を宛先スコープにコピーする。
// `import` 文の実装に使用される。
//
// 引数:
//   dst - コピー先スコープ
//   src - コピー元スコープ
//
// 戻り値:
//   STRM_OK - 成功
//   STRM_NG - 失敗
strm_env_copy :: proc(dst: ^Strm_State, src: ^Strm_State) -> int {
	if dst == nil || src == nil {
		return STRM_NG
	}
	// 全ての変数をコピー
	for name, value in src.env {
		dst.env[name] = value
	}
	return STRM_OK
}

// ============================================================================
// 名前空間操作 (Namespace Operations)
// ============================================================================
// グローバルに登録される名前付きスコープを管理する。
// モジュールシステムの基盤となる機能。

// 名前空間レジストリ（グローバル）
// 全ての名前空間を名前でインデックスする
@(private = "file")
namespace_registry: map[Strm_String]^Strm_State

@(private = "file")
namespace_registry_initialized := false

// ----------------------------------------------------------------------------
// ensure_registry_init - レジストリの初期化確認
// ----------------------------------------------------------------------------
// 名前空間レジストリが初期化されていなければ初期化する。
// 遅延初期化パターン。
@(private)
ensure_registry_init :: proc() {
	if !namespace_registry_initialized {
		namespace_registry = make(map[Strm_String]^Strm_State)
		namespace_registry_initialized = true
	}
}

// ----------------------------------------------------------------------------
// strm_ns_create - 名前空間を作成して登録
// ----------------------------------------------------------------------------
// 新しい名前空間を作成し、グローバルレジストリに登録する。
// 既に同名の名前空間が存在する場合は失敗する。
//
// 引数:
//   parent - 親スコープ
//   name   - 名前空間名（内部化文字列）
//
// 戻り値:
//   作成された名前空間、または nil（既に存在する場合）
strm_ns_create :: proc(parent: ^Strm_State, name: Strm_String) -> ^Strm_State {
	ensure_registry_init()

	// 既存の名前空間をチェック
	existing := strm_ns_get(name)
	if existing != nil {
		return nil // 既に存在
	}

	// 新しい名前空間を作成
	ns := strm_state_new(parent)
	ns.name = name
	ns.flags = {.Udef}

	// レジストリに登録
	namespace_registry[name] = ns
	return ns
}

// ----------------------------------------------------------------------------
// strm_ns_create_str - 名前空間を作成して登録（文字列版）
// ----------------------------------------------------------------------------
// 文字列名で名前空間を作成する便利関数。
//
// 引数:
//   parent - 親スコープ
//   name   - 名前空間名（文字列）
//
// 戻り値:
//   作成された名前空間、または nil
strm_ns_create_str :: proc(parent: ^Strm_State, name: string) -> ^Strm_State {
	return strm_ns_create(parent, strm_str_intern(name))
}

// ----------------------------------------------------------------------------
// strm_ns_get - 名前空間を検索（Strm_String版）
// ----------------------------------------------------------------------------
// 名前で名前空間を検索する。
//
// 引数:
//   name - 名前空間名（内部化文字列）
//
// 戻り値:
//   見つかった名前空間、または nil
strm_ns_get :: proc(name: Strm_String) -> ^Strm_State {
	ensure_registry_init()
	if ns, ok := namespace_registry[name]; ok {
		return ns
	}
	return nil
}

// ----------------------------------------------------------------------------
// strm_ns_get_str - 名前空間を検索（文字列版）
// ----------------------------------------------------------------------------
// 文字列名で名前空間を検索する。
//
// 引数:
//   name - 名前空間名（文字列）
//
// 戻り値:
//   見つかった名前空間、または nil
strm_ns_get_str :: proc(name: string) -> ^Strm_State {
	return strm_ns_get(strm_str_intern(name))
}

// ----------------------------------------------------------------------------
// strm_ns_name - スコープの名前空間名を取得
// ----------------------------------------------------------------------------
// スコープが属する名前空間の名前を取得する。
//
// 引数:
//   state - 対象スコープ
//
// 戻り値:
//   名前空間名、または STRM_STR_NULL（匿名または未登録）
strm_ns_name :: proc(state: ^Strm_State) -> Strm_String {
	ensure_registry_init()
	if state == nil {
		return STRM_STR_NULL
	}
	// まずスコープ自身の名前をチェック
	if u64(state.name) != 0 {
		return state.name
	}
	// なければレジストリを検索
	for name, ns in namespace_registry {
		if ns == state {
			return name
		}
	}
	return STRM_STR_NULL
}

// ----------------------------------------------------------------------------
// strm_value_ns - 値の名前空間を取得
// ----------------------------------------------------------------------------
// 値が属する名前空間を取得する。
// これにより、値の型に応じたメソッドディスパッチが可能になる。
//
// 動作:
//   - 配列/構造体: 関連付けられた名前空間、またはArray名前空間
//   - 文字列: String名前空間
//   - 数値: Number名前空間
//   - その他: nil
//
// 引数:
//   v - 対象の値
//
// 戻り値:
//   値の名前空間、または nil
strm_value_ns :: proc(v: Strm_Value) -> ^Strm_State {
	tag := strm_value_tag(v)

	// 配列/構造体の名前空間チェック
	if tag == .Array || tag == .Struct {
		ary := Strm_Array(v)
		ns := strm_ary_ns(ary)
		if ns != nil {
			return ns
		}
		// 名前空間が設定されていない配列はArray名前空間に属する
		return strm_ns_array
	}

	// 文字列の場合
	if strm_string_p(v) {
		return strm_ns_string
	}

	// 数値の場合
	if strm_number_p(v) {
		return strm_ns_number
	}

	return nil
}

// ============================================================================
// グローバル名前空間 (Global Namespaces)
// ============================================================================
// 組み込み型の名前空間。プリミティブ型のメソッドを格納する。
//
// 例: length("hello") → String名前空間のlengthメソッドが呼ばれる

// 組み込み型の名前空間（グローバル変数）
strm_ns_array: ^Strm_State = nil   // Array名前空間
strm_ns_string: ^Strm_State = nil  // String名前空間
strm_ns_number: ^Strm_State = nil  // Number名前空間

// ----------------------------------------------------------------------------
// strm_ns_init - 組み込み名前空間を初期化
// ----------------------------------------------------------------------------
// プログラム起動時に呼び出され、基本的な名前空間を設定する。
// この関数は builtin.odin の strm_init() から呼ばれる。
strm_ns_init :: proc() {
	// まず文字列インターンテーブルを初期化
	strm_intern_init()

	ensure_registry_init()

	// Array名前空間を作成（または既存を取得）
	array_name := strm_str_intern("Array")
	strm_ns_array = strm_ns_get(array_name)
	if strm_ns_array == nil {
		strm_ns_array = strm_ns_create(nil, array_name)
	}
	if strm_ns_array != nil {
		// Udefフラグをクリア: 組み込み名前空間はインスタンスを直接作成できない
		strm_ns_array.flags = {}
	}

	// String名前空間を作成
	string_name := strm_str_intern("String")
	strm_ns_string = strm_ns_get(string_name)
	if strm_ns_string == nil {
		strm_ns_string = strm_ns_create(nil, string_name)
	}
	if strm_ns_string != nil {
		strm_ns_string.flags = {}
	}

	// Number名前空間を作成
	number_name := strm_str_intern("Number")
	strm_ns_number = strm_ns_get(number_name)
	if strm_ns_number == nil {
		strm_ns_number = strm_ns_create(nil, number_name)
	}
	if strm_ns_number != nil {
		strm_ns_number.flags = {}
	}
}

// ----------------------------------------------------------------------------
// strm_ns_cleanup - 名前空間レジストリをクリーンアップ
// ----------------------------------------------------------------------------
// プログラム終了時に呼び出され、全ての名前空間を解放する。
strm_ns_cleanup :: proc() {
	if !namespace_registry_initialized {
		return
	}
	// 全ての名前空間を破棄
	for _, ns in namespace_registry {
		strm_state_destroy(ns)
	}
	delete(namespace_registry)
	namespace_registry_initialized = false

	// グローバルポインタをクリア
	strm_ns_array = nil
	strm_ns_string = nil
	strm_ns_number = nil

	// 文字列インターンテーブルをクリーンアップ
	strm_intern_cleanup()
}

// ============================================================================
// ユーティリティ定数 (Utility Constants)
// ============================================================================
// C言語スタイルのステータスコード

STRM_OK :: 0  // 成功
STRM_NG :: 1  // 失敗
