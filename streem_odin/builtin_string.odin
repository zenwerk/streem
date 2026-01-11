package streem

import "core:strings"

// =============================================================================
// 文字列ビルトインモジュール (String Built-in Module)
// =============================================================================
//
// 参照元: src/string.c
//
// このモジュールは、Streem言語の文字列操作ビルトイン関数を提供します。
// 文字列の長さ取得、分割、結合、部分文字列抽出、トリム、大文字/小文字変換、
// 検索、置換などの基本的な文字列操作を実装しています。
//
// ビルトイン関数のシグネチャ:
//   proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int
//
// 戻り値:
//   STRM_OK (0) - 成功
//   STRM_NG (1) - 失敗（引数エラーなど）
//
// 文字列の内部表現:
//   Streem言語の文字列は Strm_String 型で表現され、strm_str_ptr() で
//   Odinの文字列として取得できます。新しい文字列は strm_str_new() で作成します。
// =============================================================================

// =============================================================================
// 文字列長 (String Length)
// =============================================================================

// -----------------------------------------------------------------------------
// exec_str_length - 文字列の長さを取得
// -----------------------------------------------------------------------------
// 文字列のバイト長を返します。
//
// Streem言語での使用例:
//   "hello".length()   # => 5
//   "日本語".length()  # => 9 (UTF-8バイト数)
//
// パラメータ:
//   argc - 必ず1
//   args - [文字列]
//
// 戻り値:
//   整数（文字列のバイト長）
//
// 注意:
//   マルチバイト文字の場合、文字数ではなくバイト数を返します。
// -----------------------------------------------------------------------------
exec_str_length :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 {
		return STRM_NG
	}

	if !strm_string_p(args[0]) {
		return STRM_NG
	}

	str := Strm_String(args[0])
	ret^ = strm_int_value(strm_str_len(str))
	return STRM_OK
}

// =============================================================================
// 文字列分割 (String Split)
// =============================================================================

// -----------------------------------------------------------------------------
// exec_str_split - 文字列を区切り文字で分割
// -----------------------------------------------------------------------------
// 文字列を指定した区切り文字で分割し、配列として返します。
//
// Streem言語での使用例:
//   split("a,b,c", ",")      # => ["a", "b", "c"]
//   split("hello world")     # => ["hello", "world"] (スペースがデフォルト)
//   "a:b:c".split(":")       # => ["a", "b", "c"]
//
// パラメータ:
//   argc - 1 または 2
//   args - [文字列] または [文字列, 区切り文字]
//
// 動作:
//   - 区切り文字を省略した場合、スペース(" ")で分割
//   - 区切り文字が見つからない場合、元の文字列を含む1要素の配列を返す
//
// 戻り値:
//   文字列の配列
// -----------------------------------------------------------------------------
exec_str_split :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc < 1 || argc > 2 {
		return STRM_NG
	}

	if !strm_string_p(args[0]) {
		return STRM_NG
	}

	str_val := Strm_String(args[0])
	str_copy := str_val
	s := strm_str_ptr(&str_copy)

	// Default delimiter is whitespace
	delim := " "
	if argc == 2 {
		if !strm_string_p(args[1]) {
			return STRM_NG
		}
		delim_val := Strm_String(args[1])
		delim_copy := delim_val
		delim = strm_str_ptr(&delim_copy)
	}

	// Split the string
	parts := strings.split(s, delim)
	defer delete(parts)

	// Create array of string values
	result := make([]Strm_Value, len(parts))
	defer delete(result)

	for part, i in parts {
		result[i] = strm_str_value(strm_str_new(part))
	}

	ret^ = strm_ary_value(strm_ary_new(result))
	return STRM_OK
}

// =============================================================================
// 文字列結合 (String Concatenation)
// =============================================================================

// -----------------------------------------------------------------------------
// exec_str_concat - 文字列を結合
// -----------------------------------------------------------------------------
// 複数の値を文字列として結合します。
//
// Streem言語での使用例:
//   concat("hello", " ", "world")  # => "hello world"
//   concat("value: ", 42)          # => "value: 42" (数値は文字列に変換)
//   concat("a", "b", "c")          # => "abc"
//
// パラメータ:
//   argc - 1以上の任意
//   args - [値1, 値2, ...]
//
// 動作:
//   - 文字列以外の値は strm_to_str で文字列に変換される
//   - すべての値を順番に結合して新しい文字列を作成
//
// 戻り値:
//   結合された文字列
// -----------------------------------------------------------------------------
exec_str_concat :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc < 1 {
		return STRM_NG
	}

	builder: strings.Builder
	strings.builder_init(&builder)
	defer strings.builder_destroy(&builder)

	for i in 0 ..< argc {
		if strm_string_p(args[i]) {
			str_val := Strm_String(args[i])
			str_copy := str_val
			s := strm_str_ptr(&str_copy)
			strings.write_string(&builder, s)
		} else {
			// Convert to string
			s := strm_to_str(args[i])
			strings.write_string(&builder, s)
		}
	}

	result := strings.to_string(builder)
	ret^ = strm_str_value(strm_str_new(result))
	return STRM_OK
}

// =============================================================================
// 部分文字列 (Substring)
// =============================================================================

// -----------------------------------------------------------------------------
// exec_str_substr - 部分文字列を抽出
// -----------------------------------------------------------------------------
// 文字列から指定位置の部分文字列を抽出します。
//
// Streem言語での使用例:
//   substr("hello", 1)        # => "ello" (位置1から末尾まで)
//   substr("hello", 1, 3)     # => "ell" (位置1から3文字)
//   substr("hello", -2)       # => "lo" (末尾から2文字)
//   "hello".substr(0, 2)      # => "he"
//
// パラメータ:
//   argc - 2 または 3
//   args - [文字列, 開始位置] または [文字列, 開始位置, 長さ]
//
// 動作:
//   - 開始位置が負の場合、末尾からの位置として解釈（-1 = 最後の文字）
//   - 長さを省略した場合、開始位置から末尾まで
//   - 範囲外の場合は空文字列を返す
//
// 戻り値:
//   部分文字列
// -----------------------------------------------------------------------------
exec_str_substr :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc < 2 || argc > 3 {
		return STRM_NG
	}

	if !strm_string_p(args[0]) || !strm_int_p(args[1]) {
		return STRM_NG
	}

	str_val := Strm_String(args[0])
	str_copy := str_val
	s := strm_str_ptr(&str_copy)
	start := int(strm_value_int(args[1]))

	// Handle negative indices
	if start < 0 {
		start = len(s) + start
	}
	if start < 0 {
		start = 0
	}
	if start > len(s) {
		ret^ = strm_str_value(strm_str_new(""))
		return STRM_OK
	}

	end := len(s)
	if argc == 3 {
		if !strm_int_p(args[2]) {
			return STRM_NG
		}
		length := int(strm_value_int(args[2]))
		if length < 0 {
			ret^ = strm_str_value(strm_str_new(""))
			return STRM_OK
		}
		end = start + length
		if end > len(s) {
			end = len(s)
		}
	}

	result := s[start:end]
	ret^ = strm_str_value(strm_str_new(result))
	return STRM_OK
}

// =============================================================================
// 空白除去 (String Trim)
// =============================================================================

// -----------------------------------------------------------------------------
// exec_str_trim - 前後の空白を除去
// -----------------------------------------------------------------------------
// 文字列の先頭と末尾から空白文字を除去します。
//
// Streem言語での使用例:
//   trim("  hello  ")     # => "hello"
//   trim("\t\nhello\n")   # => "hello"
//   "  spaced  ".trim()   # => "spaced"
//
// パラメータ:
//   argc - 必ず1
//   args - [文字列]
//
// 動作:
//   スペース、タブ、改行などの空白文字を両端から除去します。
//   文字列の中間にある空白は保持されます。
//
// 戻り値:
//   空白を除去した文字列
// -----------------------------------------------------------------------------
exec_str_trim :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 {
		return STRM_NG
	}

	if !strm_string_p(args[0]) {
		return STRM_NG
	}

	str_val := Strm_String(args[0])
	str_copy := str_val
	s := strm_str_ptr(&str_copy)

	result := strings.trim_space(s)
	ret^ = strm_str_value(strm_str_new(result))
	return STRM_OK
}

// =============================================================================
// 大文字/小文字変換 (Case Conversion)
// =============================================================================

// -----------------------------------------------------------------------------
// exec_str_upper - 大文字に変換
// -----------------------------------------------------------------------------
// 文字列内のすべての小文字を大文字に変換します。
//
// Streem言語での使用例:
//   upper("hello")     # => "HELLO"
//   upper("Hello123")  # => "HELLO123"
//   "world".upper()    # => "WORLD"
//
// パラメータ:
//   argc - 必ず1
//   args - [文字列]
//
// 動作:
//   ASCII小文字（a-z）を大文字（A-Z）に変換します。
//   数字や記号は変更されません。
//
// 戻り値:
//   大文字に変換された文字列
// -----------------------------------------------------------------------------
exec_str_upper :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 {
		return STRM_NG
	}

	if !strm_string_p(args[0]) {
		return STRM_NG
	}

	str_val := Strm_String(args[0])
	str_copy := str_val
	s := strm_str_ptr(&str_copy)

	result := strings.to_upper(s)
	defer delete(result)
	ret^ = strm_str_value(strm_str_new(result))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// exec_str_lower - 小文字に変換
// -----------------------------------------------------------------------------
// 文字列内のすべての大文字を小文字に変換します。
//
// Streem言語での使用例:
//   lower("HELLO")     # => "hello"
//   lower("Hello123")  # => "hello123"
//   "WORLD".lower()    # => "world"
//
// パラメータ:
//   argc - 必ず1
//   args - [文字列]
//
// 動作:
//   ASCII大文字（A-Z）を小文字（a-z）に変換します。
//   数字や記号は変更されません。
//
// 戻り値:
//   小文字に変換された文字列
// -----------------------------------------------------------------------------
exec_str_lower :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 {
		return STRM_NG
	}

	if !strm_string_p(args[0]) {
		return STRM_NG
	}

	str_val := Strm_String(args[0])
	str_copy := str_val
	s := strm_str_ptr(&str_copy)

	result := strings.to_lower(s)
	defer delete(result)
	ret^ = strm_str_value(strm_str_new(result))
	return STRM_OK
}

// =============================================================================
// 文字列検索 (String Search)
// =============================================================================

// -----------------------------------------------------------------------------
// exec_str_contains - 部分文字列の存在確認
// -----------------------------------------------------------------------------
// 文字列が指定した部分文字列を含むかどうかを判定します。
//
// Streem言語での使用例:
//   contains("hello world", "world")  # => true
//   contains("hello", "xyz")          # => false
//   "foobar".contains("bar")          # => true
//
// パラメータ:
//   argc - 必ず2
//   args - [検索対象文字列, 検索する部分文字列]
//
// 戻り値:
//   真偽値（含まれていれば true、そうでなければ false）
// -----------------------------------------------------------------------------
exec_str_contains :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	if !strm_string_p(args[0]) || !strm_string_p(args[1]) {
		return STRM_NG
	}

	str_val := Strm_String(args[0])
	str_copy := str_val
	s := strm_str_ptr(&str_copy)

	substr_val := Strm_String(args[1])
	substr_copy := substr_val
	substr := strm_str_ptr(&substr_copy)

	ret^ = strm_bool_value(strings.contains(s, substr))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// exec_str_index - 部分文字列の位置を検索
// -----------------------------------------------------------------------------
// 文字列内で部分文字列が最初に出現する位置を返します。
//
// Streem言語での使用例:
//   str_index("hello world", "world")  # => 6
//   str_index("hello", "xyz")          # => -1 (見つからない)
//   "foobar".index("bar")              # => 3
//
// パラメータ:
//   argc - 必ず2
//   args - [検索対象文字列, 検索する部分文字列]
//
// 戻り値:
//   整数（見つかった位置のインデックス、見つからなければ -1）
//
// 注意:
//   インデックスは0から始まります（バイト位置）。
// -----------------------------------------------------------------------------
exec_str_index :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	if !strm_string_p(args[0]) || !strm_string_p(args[1]) {
		return STRM_NG
	}

	str_val := Strm_String(args[0])
	str_copy := str_val
	s := strm_str_ptr(&str_copy)

	substr_val := Strm_String(args[1])
	substr_copy := substr_val
	substr := strm_str_ptr(&substr_copy)

	idx := strings.index(s, substr)
	ret^ = strm_int_value(i32(idx))
	return STRM_OK
}

// =============================================================================
// 文字列置換 (String Replace)
// =============================================================================

// -----------------------------------------------------------------------------
// exec_str_replace - 文字列を置換
// -----------------------------------------------------------------------------
// 文字列内のすべての出現箇所を別の文字列で置換します。
//
// Streem言語での使用例:
//   replace("hello world", "world", "there")  # => "hello there"
//   replace("aaa", "a", "b")                   # => "bbb"
//   "foo bar foo".replace("foo", "baz")       # => "baz bar baz"
//
// パラメータ:
//   argc - 必ず3
//   args - [対象文字列, 検索文字列, 置換文字列]
//
// 動作:
//   検索文字列のすべての出現箇所を置換文字列で置き換えます。
//   検索文字列が見つからない場合、元の文字列がそのまま返されます。
//
// 戻り値:
//   置換後の文字列
// -----------------------------------------------------------------------------
exec_str_replace :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 3 {
		return STRM_NG
	}

	if !strm_string_p(args[0]) || !strm_string_p(args[1]) || !strm_string_p(args[2]) {
		return STRM_NG
	}

	str_val := Strm_String(args[0])
	str_copy := str_val
	s := strm_str_ptr(&str_copy)

	old_val := Strm_String(args[1])
	old_copy := old_val
	old := strm_str_ptr(&old_copy)

	new_val := Strm_String(args[2])
	new_copy := new_val
	new_str := strm_str_ptr(&new_copy)

	result, _ := strings.replace_all(s, old, new_str)
	defer delete(result)
	ret^ = strm_str_value(strm_str_new(result))
	return STRM_OK
}

// =============================================================================
// 初期化 (Initialization)
// =============================================================================

// -----------------------------------------------------------------------------
// strm_string_init - 文字列関数の初期化
// -----------------------------------------------------------------------------
// Streem言語のグローバルスコープと文字列名前空間に文字列操作関数を登録します。
//
// 登録される関数:
//
// 【トップレベル関数】（グローバルスコープに登録）
//   split     - 文字列を分割
//   concat    - 文字列を結合
//   substr    - 部分文字列を抽出
//   trim      - 前後の空白を除去
//   upper     - 大文字に変換
//   lower     - 小文字に変換
//   contains  - 部分文字列の存在確認
//   str_index - 部分文字列の位置を検索
//   replace   - 文字列を置換
//
// 【名前空間メソッド】（strm_ns_string に登録）
//   length    - 文字列の長さを取得
//   split     - 文字列を分割
//   substr    - 部分文字列を抽出
//   trim      - 前後の空白を除去
//   upper     - 大文字に変換
//   lower     - 小文字に変換
//   contains  - 部分文字列の存在確認
//   index     - 部分文字列の位置を検索
//   replace   - 文字列を置換
//
// 使い分け:
//   - トップレベル: split("hello world") のように関数として呼び出す
//   - 名前空間: "hello world".split() のようにメソッドとして呼び出す
// -----------------------------------------------------------------------------
strm_string_init :: proc(state: ^Strm_State) {
	// String functions as top-level
	strm_var_def(state, strm_str_intern("split"), strm_cfunc_value(exec_str_split))
	strm_var_def(state, strm_str_intern("concat"), strm_cfunc_value(exec_str_concat))
	strm_var_def(state, strm_str_intern("substr"), strm_cfunc_value(exec_str_substr))
	strm_var_def(state, strm_str_intern("trim"), strm_cfunc_value(exec_str_trim))
	strm_var_def(state, strm_str_intern("upper"), strm_cfunc_value(exec_str_upper))
	strm_var_def(state, strm_str_intern("lower"), strm_cfunc_value(exec_str_lower))
	strm_var_def(state, strm_str_intern("contains"), strm_cfunc_value(exec_str_contains))
	strm_var_def(state, strm_str_intern("str_index"), strm_cfunc_value(exec_str_index))
	strm_var_def(state, strm_str_intern("replace"), strm_cfunc_value(exec_str_replace))

	// String namespace methods
	strm_var_def(strm_ns_string, strm_str_intern("length"), strm_cfunc_value(exec_str_length))
	strm_var_def(strm_ns_string, strm_str_intern("split"), strm_cfunc_value(exec_str_split))
	strm_var_def(strm_ns_string, strm_str_intern("substr"), strm_cfunc_value(exec_str_substr))
	strm_var_def(strm_ns_string, strm_str_intern("trim"), strm_cfunc_value(exec_str_trim))
	strm_var_def(strm_ns_string, strm_str_intern("upper"), strm_cfunc_value(exec_str_upper))
	strm_var_def(strm_ns_string, strm_str_intern("lower"), strm_cfunc_value(exec_str_lower))
	strm_var_def(strm_ns_string, strm_str_intern("contains"), strm_cfunc_value(exec_str_contains))
	strm_var_def(strm_ns_string, strm_str_intern("index"), strm_cfunc_value(exec_str_index))
	strm_var_def(strm_ns_string, strm_str_intern("replace"), strm_cfunc_value(exec_str_replace))
}
