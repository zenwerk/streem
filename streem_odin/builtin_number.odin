package streem

import "core:math"

// =============================================================================
// 数値ビルトインモジュール (Number Built-in Module)
// =============================================================================
//
// 参照元: src/number.c
//
// このモジュールは、Streem言語の数値演算ビルトイン関数を提供します。
// 算術演算、ビット演算、比較演算、論理演算を含み、数値型（整数・浮動小数点）に
// 対する基本的な操作を実装しています。
//
// ビルトイン関数のシグネチャ:
//   proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int
//
// 戻り値:
//   STRM_OK (0) - 成功
//   STRM_NG (1) - 失敗（引数エラーなど）
//
// 型の扱い:
//   - 整数同士の演算は整数結果を返す
//   - 浮動小数点が含まれる演算は浮動小数点結果を返す
//   - strm_number_p() は整数と浮動小数点の両方を数値として扱う
// =============================================================================

// =============================================================================
// 算術演算 (Arithmetic Operations)
// =============================================================================

// -----------------------------------------------------------------------------
// num_plus - 加算演算子 (+)
// -----------------------------------------------------------------------------
// 2つの数値を加算します。
//
// Streem言語での使用例:
//   1 + 2      # => 3 (整数)
//   1.5 + 2.5  # => 4.0 (浮動小数点)
//   1 + 2.0    # => 3.0 (浮動小数点に昇格)
//
// パラメータ:
//   argc - 必ず2
//   args - [左辺の値, 右辺の値]
//
// 動作:
//   - 両方が整数: 整数の加算結果を返す
//   - どちらかが浮動小数点: 浮動小数点の加算結果を返す
// -----------------------------------------------------------------------------
num_plus :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	x := args[0]
	y := args[1]

	// Integer + Integer
	if strm_int_p(x) && strm_int_p(y) {
		ret^ = strm_int_value(strm_value_int(x) + strm_value_int(y))
		return STRM_OK
	}

	// Number + Number (float result)
	if strm_number_p(x) && strm_number_p(y) {
		ret^ = strm_float_value(strm_value_float(x) + strm_value_float(y))
		return STRM_OK
	}

	return STRM_NG
}

// -----------------------------------------------------------------------------
// num_minus - 減算演算子 (-) / 単項マイナス
// -----------------------------------------------------------------------------
// 2つの数値を減算、または単項マイナス演算を行います。
//
// Streem言語での使用例:
//   5 - 3      # => 2 (二項演算)
//   -5         # => -5 (単項マイナス)
//   3.0 - 1.5  # => 1.5
//
// パラメータ:
//   argc - 1（単項）または2（二項）
//   args - [値] または [左辺の値, 右辺の値]
//
// 動作:
//   - 単項（argc == 1）: 符号を反転
//   - 二項（argc == 2）: 左辺から右辺を減算
//   - 整数同士: 整数結果
//   - 浮動小数点含む: 浮動小数点結果
// -----------------------------------------------------------------------------
num_minus :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	// Unary minus
	if argc == 1 {
		if strm_int_p(args[0]) {
			ret^ = strm_int_value(-strm_value_int(args[0]))
			return STRM_OK
		}
		if strm_float_p(args[0]) {
			ret^ = strm_float_value(-strm_value_float(args[0]))
			return STRM_OK
		}
		return STRM_NG
	}

	// Binary minus
	if argc != 2 {
		return STRM_NG
	}

	x := args[0]
	y := args[1]

	// Integer - Integer
	if strm_int_p(x) && strm_int_p(y) {
		ret^ = strm_int_value(strm_value_int(x) - strm_value_int(y))
		return STRM_OK
	}

	// Number - Number
	if strm_number_p(x) && strm_number_p(y) {
		ret^ = strm_float_value(strm_value_float(x) - strm_value_float(y))
		return STRM_OK
	}

	return STRM_NG
}

// -----------------------------------------------------------------------------
// num_mult - 乗算演算子 (*)
// -----------------------------------------------------------------------------
// 2つの数値を乗算します。
//
// Streem言語での使用例:
//   3 * 4      # => 12 (整数)
//   2.5 * 2    # => 5.0 (浮動小数点)
//
// パラメータ:
//   argc - 必ず2
//   args - [左辺の値, 右辺の値]
//
// 動作:
//   - 両方が整数: 整数の乗算結果を返す
//   - どちらかが浮動小数点: 浮動小数点の乗算結果を返す
// -----------------------------------------------------------------------------
num_mult :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	x := args[0]
	y := args[1]

	// Integer * Integer
	if strm_int_p(x) && strm_int_p(y) {
		ret^ = strm_int_value(strm_value_int(x) * strm_value_int(y))
		return STRM_OK
	}

	// Number * Number
	if strm_number_p(x) && strm_number_p(y) {
		ret^ = strm_float_value(strm_value_float(x) * strm_value_float(y))
		return STRM_OK
	}

	return STRM_NG
}

// -----------------------------------------------------------------------------
// num_div - 除算演算子 (/)
// -----------------------------------------------------------------------------
// 2つの数値を除算します。結果は常に浮動小数点数です。
//
// Streem言語での使用例:
//   10 / 3     # => 3.333... (浮動小数点)
//   6.0 / 2.0  # => 3.0
//
// パラメータ:
//   argc - 必ず2
//   args - [被除数, 除数]
//
// 動作:
//   両方の値を浮動小数点に変換してから除算を行います。
//   整数同士の除算でも浮動小数点結果を返します。
//
// 注意:
//   ゼロ除算の場合、結果は IEEE 754 に従い無限大または NaN になります。
// -----------------------------------------------------------------------------
num_div :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	if !strm_number_p(args[0]) || !strm_number_p(args[1]) {
		return STRM_NG
	}

	x := strm_value_float(args[0])
	y := strm_value_float(args[1])

	ret^ = strm_float_value(x / y)
	return STRM_OK
}

// -----------------------------------------------------------------------------
// num_mod - 剰余演算子 (%)
// -----------------------------------------------------------------------------
// 2つの数値の剰余（モジュロ）を計算します。
//
// Streem言語での使用例:
//   10 % 3     # => 1 (整数)
//   10.5 % 3   # => 1.5 (浮動小数点)
//
// パラメータ:
//   argc - 必ず2
//   args - [被除数, 除数（整数のみ）]
//
// 動作:
//   - 左辺が整数: 整数の剰余演算
//   - 左辺が浮動小数点: math.mod による浮動小数点剰余
//   - 右辺は必ず整数である必要があります
// -----------------------------------------------------------------------------
num_mod :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	if !strm_number_p(args[0]) || !strm_int_p(args[1]) {
		return STRM_NG
	}

	y := strm_value_int(args[1])

	if strm_int_p(args[0]) {
		ret^ = strm_int_value(strm_value_int(args[0]) % y)
		return STRM_OK
	}

	if strm_float_p(args[0]) {
		ret^ = strm_float_value(math.mod(strm_value_float(args[0]), f64(y)))
		return STRM_OK
	}

	return STRM_NG
}

// =============================================================================
// ビット演算 (Bitwise Operations)
// =============================================================================

// -----------------------------------------------------------------------------
// num_bitor - ビット論理和演算子 (|)
// -----------------------------------------------------------------------------
// 2つの整数のビット単位の論理和を計算します。
//
// Streem言語での使用例:
//   0b1010 | 0b0110  # => 0b1110 (14)
//   5 | 3            # => 7
//
// パラメータ:
//   argc - 必ず2
//   args - [左辺の整数, 右辺の整数]
//
// 動作:
//   各ビット位置について、どちらかが1であれば1を返します。
//
// 注意:
//   両方の引数が整数である必要があります。
//   ストリーム接続の | 演算子は builtin_core.odin の exec_bar で処理されます。
// -----------------------------------------------------------------------------
num_bitor :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	if !strm_int_p(args[0]) || !strm_int_p(args[1]) {
		return STRM_NG
	}

	ret^ = strm_int_value(strm_value_int(args[0]) | strm_value_int(args[1]))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// num_bitand - ビット論理積演算子 (&)
// -----------------------------------------------------------------------------
// 2つの整数のビット単位の論理積を計算します。
//
// Streem言語での使用例:
//   0b1010 & 0b0110  # => 0b0010 (2)
//   5 & 3            # => 1
//
// パラメータ:
//   argc - 必ず2
//   args - [左辺の整数, 右辺の整数]
//
// 動作:
//   各ビット位置について、両方が1の場合のみ1を返します。
//
// 注意:
//   両方の引数が整数である必要があります。
// -----------------------------------------------------------------------------
num_bitand :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	if !strm_int_p(args[0]) || !strm_int_p(args[1]) {
		return STRM_NG
	}

	ret^ = strm_int_value(strm_value_int(args[0]) & strm_value_int(args[1]))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// num_bitnot - ビット否定演算子 (~)
// -----------------------------------------------------------------------------
// 整数のすべてのビットを反転させます。
//
// Streem言語での使用例:
//   ~0         # => -1 (すべてのビットが1に)
//   ~1         # => -2
//   ~0b1010    # => ビット反転
//
// パラメータ:
//   argc - 必ず1
//   args - [整数値]
//
// 動作:
//   各ビットの0と1を反転させます（2の補数表現）。
//
// 注意:
//   引数は整数である必要があります。
// -----------------------------------------------------------------------------
num_bitnot :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 {
		return STRM_NG
	}

	if !strm_int_p(args[0]) {
		return STRM_NG
	}

	ret^ = strm_int_value(~strm_value_int(args[0]))
	return STRM_OK
}

// =============================================================================
// 比較演算 (Comparison Operations)
// =============================================================================

// -----------------------------------------------------------------------------
// num_gt - 大なり演算子 (>)
// -----------------------------------------------------------------------------
// 左辺が右辺より大きいかどうかを比較します。
//
// Streem言語での使用例:
//   5 > 3      # => true
//   3 > 5      # => false
//   3 > 3      # => false
//
// パラメータ:
//   argc - 必ず2
//   args - [左辺の数値, 右辺の数値]
//
// 戻り値:
//   真偽値（true または false）
// -----------------------------------------------------------------------------
num_gt :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	if !strm_number_p(args[0]) || !strm_number_p(args[1]) {
		return STRM_NG
	}

	x := strm_value_float(args[0])
	y := strm_value_float(args[1])

	ret^ = strm_bool_value(x > y)
	return STRM_OK
}

// -----------------------------------------------------------------------------
// num_ge - 以上演算子 (>=)
// -----------------------------------------------------------------------------
// 左辺が右辺以上かどうかを比較します。
//
// Streem言語での使用例:
//   5 >= 3     # => true
//   3 >= 5     # => false
//   3 >= 3     # => true
//
// パラメータ:
//   argc - 必ず2
//   args - [左辺の数値, 右辺の数値]
//
// 戻り値:
//   真偽値（true または false）
// -----------------------------------------------------------------------------
num_ge :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	if !strm_number_p(args[0]) || !strm_number_p(args[1]) {
		return STRM_NG
	}

	x := strm_value_float(args[0])
	y := strm_value_float(args[1])

	ret^ = strm_bool_value(x >= y)
	return STRM_OK
}

// -----------------------------------------------------------------------------
// num_lt - 小なり演算子 (<)
// -----------------------------------------------------------------------------
// 左辺が右辺より小さいかどうかを比較します。
//
// Streem言語での使用例:
//   3 < 5      # => true
//   5 < 3      # => false
//   3 < 3      # => false
//
// パラメータ:
//   argc - 必ず2
//   args - [左辺の数値, 右辺の数値]
//
// 戻り値:
//   真偽値（true または false）
// -----------------------------------------------------------------------------
num_lt :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	if !strm_number_p(args[0]) || !strm_number_p(args[1]) {
		return STRM_NG
	}

	x := strm_value_float(args[0])
	y := strm_value_float(args[1])

	ret^ = strm_bool_value(x < y)
	return STRM_OK
}

// -----------------------------------------------------------------------------
// num_le - 以下演算子 (<=)
// -----------------------------------------------------------------------------
// 左辺が右辺以下かどうかを比較します。
//
// Streem言語での使用例:
//   3 <= 5     # => true
//   5 <= 3     # => false
//   3 <= 3     # => true
//
// パラメータ:
//   argc - 必ず2
//   args - [左辺の数値, 右辺の数値]
//
// 戻り値:
//   真偽値（true または false）
// -----------------------------------------------------------------------------
num_le :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	if !strm_number_p(args[0]) || !strm_number_p(args[1]) {
		return STRM_NG
	}

	x := strm_value_float(args[0])
	y := strm_value_float(args[1])

	ret^ = strm_bool_value(x <= y)
	return STRM_OK
}

// =============================================================================
// 論理演算 (Logical Operations)
// =============================================================================

// -----------------------------------------------------------------------------
// num_and - 論理積演算子 (&&)
// -----------------------------------------------------------------------------
// 2つの値の論理積（AND）を計算します。
//
// Streem言語での使用例:
//   true && true    # => true
//   true && false   # => false
//   1 && 2          # => true (非nil/非falseは真として扱う)
//   nil && true     # => false
//
// パラメータ:
//   argc - 必ず2
//   args - [左辺の値, 右辺の値]
//
// 動作:
//   nil と false は偽として、それ以外は真として扱います。
//   両方が真の場合のみ true を返します。
// -----------------------------------------------------------------------------
num_and :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	// Treat nil and false as false, everything else as true
	a := !strm_nil_p(args[0]) && (!strm_bool_p(args[0]) || strm_value_bool(args[0]))
	b := !strm_nil_p(args[1]) && (!strm_bool_p(args[1]) || strm_value_bool(args[1]))

	ret^ = strm_bool_value(a && b)
	return STRM_OK
}

// -----------------------------------------------------------------------------
// num_or - 論理和演算子 (||)
// -----------------------------------------------------------------------------
// 2つの値の論理和（OR）を計算します。
//
// Streem言語での使用例:
//   true || false   # => true
//   false || false  # => false
//   nil || 1        # => true
//   0 || false      # => true (0は真として扱う)
//
// パラメータ:
//   argc - 必ず2
//   args - [左辺の値, 右辺の値]
//
// 動作:
//   nil と false は偽として、それ以外は真として扱います。
//   どちらかが真であれば true を返します。
// -----------------------------------------------------------------------------
num_or :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	// Treat nil and false as false, everything else as true
	a := !strm_nil_p(args[0]) && (!strm_bool_p(args[0]) || strm_value_bool(args[0]))
	b := !strm_nil_p(args[1]) && (!strm_bool_p(args[1]) || strm_value_bool(args[1]))

	ret^ = strm_bool_value(a || b)
	return STRM_OK
}

// -----------------------------------------------------------------------------
// num_not - 論理否定演算子 (!)
// -----------------------------------------------------------------------------
// 値の論理否定を計算します。
//
// Streem言語での使用例:
//   !true       # => false
//   !false      # => true
//   !nil        # => true
//   !1          # => false
//
// パラメータ:
//   argc - 必ず1
//   args - [値]
//
// 動作:
//   nil と false は偽として、それ以外は真として扱います。
//   真偽を反転した結果を返します。
// -----------------------------------------------------------------------------
num_not :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 {
		return STRM_NG
	}

	// Treat nil and false as false, everything else as true
	a := !strm_nil_p(args[0]) && (!strm_bool_p(args[0]) || strm_value_bool(args[0]))

	ret^ = strm_bool_value(!a)
	return STRM_OK
}

// =============================================================================
// 初期化 (Initialization)
// =============================================================================

// -----------------------------------------------------------------------------
// strm_number_init - 数値名前空間の初期化
// -----------------------------------------------------------------------------
// Streem言語の数値名前空間を作成し、数値演算子を登録します。
//
// 登録される演算子:
//
// 【算術演算子】
//   +  - 加算
//   -  - 減算（二項）/ 単項マイナス
//   *  - 乗算
//   /  - 除算
//   %  - 剰余
//
// 【比較演算子】
//   <  - 小なり
//   <= - 以下
//   >  - 大なり
//   >= - 以上
//
// 【ビット演算子】
//   &  - ビット論理積
//   ~  - ビット否定
//
// 【論理演算子】
//   && - 論理積
//   || - 論理和
//   !  - 論理否定
//
// グローバル変数:
//   strm_ns_number - 数値名前空間への参照（他モジュールから使用）
// -----------------------------------------------------------------------------
strm_number_init :: proc(state: ^Strm_State) {
	// Create number namespace
	ns := strm_ns_new(nil, "number")
	strm_ns_number = ns

	// Register operators in number namespace
	strm_var_def(ns, strm_str_intern("+"), strm_cfunc_value(num_plus))
	strm_var_def(ns, strm_str_intern("-"), strm_cfunc_value(num_minus))
	strm_var_def(ns, strm_str_intern("*"), strm_cfunc_value(num_mult))
	strm_var_def(ns, strm_str_intern("/"), strm_cfunc_value(num_div))
	strm_var_def(ns, strm_str_intern("%"), strm_cfunc_value(num_mod))
	strm_var_def(ns, strm_str_intern("<"), strm_cfunc_value(num_lt))
	strm_var_def(ns, strm_str_intern("<="), strm_cfunc_value(num_le))
	strm_var_def(ns, strm_str_intern(">"), strm_cfunc_value(num_gt))
	strm_var_def(ns, strm_str_intern(">="), strm_cfunc_value(num_ge))
	strm_var_def(ns, strm_str_intern("&"), strm_cfunc_value(num_bitand))
	strm_var_def(ns, strm_str_intern("~"), strm_cfunc_value(num_bitnot))
	strm_var_def(ns, strm_str_intern("&&"), strm_cfunc_value(num_and))
	strm_var_def(ns, strm_str_intern("||"), strm_cfunc_value(num_or))
	strm_var_def(ns, strm_str_intern("!"), strm_cfunc_value(num_not))
}
