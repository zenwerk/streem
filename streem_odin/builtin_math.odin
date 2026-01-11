package streem

import "core:math"

// =============================================================================
// 数学関数モジュール (Math Functions Module)
// =============================================================================
//
// 参照元: src/math.c
//
// このモジュールは、Streem言語で使用可能な数学関数を提供します。
// 標準的な数学関数（三角関数、指数関数、対数関数など）が含まれています。
//
// すべての関数は、Odin の core:math パッケージをラップしています。
// 角度はラジアン単位で指定します。
//
// 各関数のシグネチャ:
//   proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int
// =============================================================================

// =============================================================================
// 三角関数 (Trigonometric Functions)
// =============================================================================

// -----------------------------------------------------------------------------
// math_sin - 正弦関数 (Sine)
// -----------------------------------------------------------------------------
// 角度（ラジアン）の正弦値を計算します。
//
// Streem言語での使用例:
//   sin(0)       # => 0.0
//   sin(PI/2)    # => 1.0
//   sin(PI)      # => 0.0 (ほぼ0)
//
// パラメータ: 角度（ラジアン）
// 戻り値: -1.0 から 1.0 の範囲の値
// -----------------------------------------------------------------------------
math_sin :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.sin(strm_value_float(args[0])))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_cos - 余弦関数 (Cosine)
// -----------------------------------------------------------------------------
// 角度（ラジアン）の余弦値を計算します。
//
// Streem言語での使用例:
//   cos(0)       # => 1.0
//   cos(PI/2)    # => 0.0 (ほぼ0)
//   cos(PI)      # => -1.0
//
// パラメータ: 角度（ラジアン）
// 戻り値: -1.0 から 1.0 の範囲の値
// -----------------------------------------------------------------------------
math_cos :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.cos(strm_value_float(args[0])))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_tan - 正接関数 (Tangent)
// -----------------------------------------------------------------------------
// 角度（ラジアン）の正接値を計算します。
//
// Streem言語での使用例:
//   tan(0)       # => 0.0
//   tan(PI/4)    # => 1.0
//
// パラメータ: 角度（ラジアン）
// 戻り値: 正接値（任意の実数）
// 注意: PI/2 の奇数倍では無限大になります
// -----------------------------------------------------------------------------
math_tan :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.tan(strm_value_float(args[0])))
	return STRM_OK
}

// =============================================================================
// 双曲線関数 (Hyperbolic Functions)
// =============================================================================

// -----------------------------------------------------------------------------
// math_sinh - 双曲線正弦関数 (Hyperbolic Sine)
// -----------------------------------------------------------------------------
// 双曲線正弦を計算します: sinh(x) = (e^x - e^(-x)) / 2
//
// Streem言語での使用例:
//   sinh(0)   # => 0.0
//   sinh(1)   # => 1.1752...
// -----------------------------------------------------------------------------
math_sinh :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.sinh(strm_value_float(args[0])))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_cosh - 双曲線余弦関数 (Hyperbolic Cosine)
// -----------------------------------------------------------------------------
// 双曲線余弦を計算します: cosh(x) = (e^x + e^(-x)) / 2
//
// Streem言語での使用例:
//   cosh(0)   # => 1.0
//   cosh(1)   # => 1.5430...
// -----------------------------------------------------------------------------
math_cosh :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.cosh(strm_value_float(args[0])))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_tanh - 双曲線正接関数 (Hyperbolic Tangent)
// -----------------------------------------------------------------------------
// 双曲線正接を計算します: tanh(x) = sinh(x) / cosh(x)
//
// Streem言語での使用例:
//   tanh(0)   # => 0.0
//   tanh(1)   # => 0.7615...
//
// 戻り値: -1.0 から 1.0 の範囲の値
// -----------------------------------------------------------------------------
math_tanh :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.tanh(strm_value_float(args[0])))
	return STRM_OK
}

// =============================================================================
// 逆三角関数 (Inverse Trigonometric Functions)
// =============================================================================

// -----------------------------------------------------------------------------
// math_asin - 逆正弦関数 (Arcsine)
// -----------------------------------------------------------------------------
// 正弦値からラジアン角度を計算します。
//
// Streem言語での使用例:
//   asin(0)   # => 0.0
//   asin(1)   # => PI/2 (1.5707...)
//
// パラメータ: -1.0 から 1.0 の範囲の値
// 戻り値: -PI/2 から PI/2 の範囲のラジアン
// -----------------------------------------------------------------------------
math_asin :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.asin(strm_value_float(args[0])))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_acos - 逆余弦関数 (Arccosine)
// -----------------------------------------------------------------------------
// 余弦値からラジアン角度を計算します。
//
// Streem言語での使用例:
//   acos(1)   # => 0.0
//   acos(0)   # => PI/2 (1.5707...)
//   acos(-1)  # => PI (3.1415...)
//
// パラメータ: -1.0 から 1.0 の範囲の値
// 戻り値: 0 から PI の範囲のラジアン
// -----------------------------------------------------------------------------
math_acos :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.acos(strm_value_float(args[0])))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_atan - 逆正接関数 (Arctangent)
// -----------------------------------------------------------------------------
// 正接値からラジアン角度を計算します。
//
// Streem言語での使用例:
//   atan(0)   # => 0.0
//   atan(1)   # => PI/4 (0.7853...)
//
// パラメータ: 任意の実数
// 戻り値: -PI/2 から PI/2 の範囲のラジアン
// -----------------------------------------------------------------------------
math_atan :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.atan(strm_value_float(args[0])))
	return STRM_OK
}

// =============================================================================
// 逆双曲線関数 (Inverse Hyperbolic Functions)
// =============================================================================

// -----------------------------------------------------------------------------
// math_asinh - 逆双曲線正弦関数 (Inverse Hyperbolic Sine)
// -----------------------------------------------------------------------------
// 双曲線正弦の逆関数を計算します。
//
// Streem言語での使用例:
//   asinh(0)   # => 0.0
//   asinh(1)   # => 0.8813...
//
// パラメータ: 任意の実数
// -----------------------------------------------------------------------------
math_asinh :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.asinh(strm_value_float(args[0])))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_acosh - 逆双曲線余弦関数 (Inverse Hyperbolic Cosine)
// -----------------------------------------------------------------------------
// 双曲線余弦の逆関数を計算します。
//
// Streem言語での使用例:
//   acosh(1)   # => 0.0
//   acosh(2)   # => 1.3169...
//
// パラメータ: 1.0 以上の値
// -----------------------------------------------------------------------------
math_acosh :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.acosh(strm_value_float(args[0])))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_atanh - 逆双曲線正接関数 (Inverse Hyperbolic Tangent)
// -----------------------------------------------------------------------------
// 双曲線正接の逆関数を計算します。
//
// Streem言語での使用例:
//   atanh(0)     # => 0.0
//   atanh(0.5)   # => 0.5493...
//
// パラメータ: -1.0 から 1.0 の範囲の値（両端は含まない）
// -----------------------------------------------------------------------------
math_atanh :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.atanh(strm_value_float(args[0])))
	return STRM_OK
}

// =============================================================================
// 指数・対数関数 (Exponential and Logarithmic Functions)
// =============================================================================

// -----------------------------------------------------------------------------
// math_sqrt - 平方根 (Square Root)
// -----------------------------------------------------------------------------
// 平方根を計算します: sqrt(x) = x^0.5
//
// Streem言語での使用例:
//   sqrt(4)    # => 2.0
//   sqrt(2)    # => 1.4142...
//
// パラメータ: 0以上の値
// -----------------------------------------------------------------------------
math_sqrt :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.sqrt(strm_value_float(args[0])))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_cbrt - 立方根 (Cube Root)
// -----------------------------------------------------------------------------
// 立方根を計算します: cbrt(x) = x^(1/3)
// 負の値も処理可能です。
//
// Streem言語での使用例:
//   cbrt(8)    # => 2.0
//   cbrt(-8)   # => -2.0
//   cbrt(27)   # => 3.0
// -----------------------------------------------------------------------------
math_cbrt :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	x := strm_value_float(args[0])
	// cbrt(x) = sign(x) * |x|^(1/3)
	if x >= 0 {
		ret^ = strm_float_value(math.pow(x, 1.0 / 3.0))
	} else {
		ret^ = strm_float_value(-math.pow(-x, 1.0 / 3.0))
	}
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_pow - べき乗 (Power)
// -----------------------------------------------------------------------------
// x の y 乗を計算します: pow(x, y) = x^y
//
// Streem言語での使用例:
//   pow(2, 10)   # => 1024.0
//   pow(10, 3)   # => 1000.0
//   pow(2, 0.5)  # => 1.4142... (sqrt(2)と同じ)
// -----------------------------------------------------------------------------
math_pow :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 || !strm_number_p(args[0]) || !strm_number_p(args[1]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.pow(strm_value_float(args[0]), strm_value_float(args[1])))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_log - 自然対数 (Natural Logarithm)
// -----------------------------------------------------------------------------
// 自然対数（底がe）を計算します: log(x) = ln(x)
//
// Streem言語での使用例:
//   log(E)     # => 1.0
//   log(1)     # => 0.0
//   log(10)    # => 2.3025...
//
// パラメータ: 0より大きい値
// -----------------------------------------------------------------------------
math_log :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.ln(strm_value_float(args[0])))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_log10 - 常用対数 (Base-10 Logarithm)
// -----------------------------------------------------------------------------
// 常用対数（底が10）を計算します。
//
// Streem言語での使用例:
//   log10(10)    # => 1.0
//   log10(100)   # => 2.0
//   log10(1000)  # => 3.0
//
// パラメータ: 0より大きい値
// -----------------------------------------------------------------------------
math_log10 :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.log10(strm_value_float(args[0])))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_log2 - 2進対数 (Base-2 Logarithm)
// -----------------------------------------------------------------------------
// 2進対数（底が2）を計算します。
//
// Streem言語での使用例:
//   log2(2)    # => 1.0
//   log2(8)    # => 3.0
//   log2(1024) # => 10.0
//
// パラメータ: 0より大きい値
// -----------------------------------------------------------------------------
math_log2 :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.log2(strm_value_float(args[0])))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_exp - 指数関数 (Exponential)
// -----------------------------------------------------------------------------
// e の x 乗を計算します: exp(x) = e^x
//
// Streem言語での使用例:
//   exp(0)   # => 1.0
//   exp(1)   # => E (2.7182...)
//   exp(2)   # => 7.3890...
// -----------------------------------------------------------------------------
math_exp :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.exp(strm_value_float(args[0])))
	return STRM_OK
}

// =============================================================================
// 丸め関数 (Rounding Functions)
// =============================================================================

// -----------------------------------------------------------------------------
// math_fabs - 絶対値 (Absolute Value)
// -----------------------------------------------------------------------------
// 浮動小数点数の絶対値を計算します。
//
// Streem言語での使用例:
//   fabs(-5.5)  # => 5.5
//   fabs(3.14)  # => 3.14
//   fabs(0)     # => 0.0
// -----------------------------------------------------------------------------
math_fabs :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(abs(strm_value_float(args[0])))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_round - 四捨五入 (Round to Nearest)
// -----------------------------------------------------------------------------
// 最も近い整数（または指定精度）に丸めます。
//
// Streem言語での使用例:
//   round(3.4)     # => 3.0
//   round(3.5)     # => 4.0
//   round(3.14159, 2)  # => 3.14 (小数点以下2桁に丸め)
//
// 引数パターン:
//   round(x)           - 整数に丸める
//   round(x, precision) - 指定桁数に丸める
// -----------------------------------------------------------------------------
math_round :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc < 1 || argc > 2 || !strm_number_p(args[0]) {
		return STRM_NG
	}

	x := strm_value_float(args[0])

	if argc == 1 {
		ret^ = strm_float_value(math.round(x))
	} else {
		if !strm_int_p(args[1]) {
			return STRM_NG
		}
		d := strm_value_int(args[1])
		f := math.pow(f64(10), f64(d))
		ret^ = strm_float_value(math.round(x * f) / f)
	}
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_ceil - 切り上げ (Ceiling)
// -----------------------------------------------------------------------------
// 値以上の最小の整数（または指定精度）に丸めます。
//
// Streem言語での使用例:
//   ceil(3.1)      # => 4.0
//   ceil(-3.1)     # => -3.0
//   ceil(3.14159, 2)   # => 3.15
// -----------------------------------------------------------------------------
math_ceil :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc < 1 || argc > 2 || !strm_number_p(args[0]) {
		return STRM_NG
	}

	x := strm_value_float(args[0])

	if argc == 1 {
		ret^ = strm_float_value(math.ceil(x))
	} else {
		if !strm_int_p(args[1]) {
			return STRM_NG
		}
		d := strm_value_int(args[1])
		f := math.pow(f64(10), f64(d))
		ret^ = strm_float_value(math.ceil(x * f) / f)
	}
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_floor - 切り捨て (Floor)
// -----------------------------------------------------------------------------
// 値以下の最大の整数（または指定精度）に丸めます。
//
// Streem言語での使用例:
//   floor(3.9)     # => 3.0
//   floor(-3.1)    # => -4.0
//   floor(3.14159, 2)  # => 3.14
// -----------------------------------------------------------------------------
math_floor :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc < 1 || argc > 2 || !strm_number_p(args[0]) {
		return STRM_NG
	}

	x := strm_value_float(args[0])

	if argc == 1 {
		ret^ = strm_float_value(math.floor(x))
	} else {
		if !strm_int_p(args[1]) {
			return STRM_NG
		}
		d := strm_value_int(args[1])
		f := math.pow(f64(10), f64(d))
		ret^ = strm_float_value(math.floor(x * f) / f)
	}
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_trunc - 0方向への切り捨て (Truncate)
// -----------------------------------------------------------------------------
// 0方向に向かって整数部分を取り出します。
//
// Streem言語での使用例:
//   trunc(3.9)   # => 3.0
//   trunc(-3.9)  # => -3.0 (floor と異なる)
//   int(3.9)     # => 3.0 (trunc のエイリアス)
// -----------------------------------------------------------------------------
math_trunc :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc < 1 || argc > 2 || !strm_number_p(args[0]) {
		return STRM_NG
	}

	x := strm_value_float(args[0])

	if argc == 1 {
		ret^ = strm_float_value(math.trunc(x))
	} else {
		if !strm_int_p(args[1]) {
			return STRM_NG
		}
		d := strm_value_int(args[1])
		f := math.pow(f64(10), f64(d))
		ret^ = strm_float_value(math.trunc(x * f) / f)
	}
	return STRM_OK
}

// =============================================================================
// その他の数学関数 (Other Mathematical Functions)
// =============================================================================

// -----------------------------------------------------------------------------
// math_hypot - 斜辺の長さ (Hypotenuse)
// -----------------------------------------------------------------------------
// 直角三角形の斜辺の長さを計算します: hypot(x, y) = sqrt(x^2 + y^2)
// オーバーフローを避ける安全な計算を行います。
//
// Streem言語での使用例:
//   hypot(3, 4)  # => 5.0
//   hypot(1, 1)  # => 1.4142...
// -----------------------------------------------------------------------------
math_hypot :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 || !strm_number_p(args[0]) || !strm_number_p(args[1]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.hypot(strm_value_float(args[0]), strm_value_float(args[1])))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// gcd_helper - 最大公約数計算のヘルパー（ユークリッドの互除法）
// -----------------------------------------------------------------------------
gcd_helper :: proc(a, b: i32) -> i32 {
	if b == 0 {
		return a
	}
	return gcd_helper(b, a % b)
}

// -----------------------------------------------------------------------------
// math_gcd - 最大公約数 (Greatest Common Divisor)
// -----------------------------------------------------------------------------
// 2つの整数の最大公約数を計算します（ユークリッドの互除法）。
//
// Streem言語での使用例:
//   gcd(12, 18)  # => 6
//   gcd(7, 13)   # => 1 （互いに素）
//   gcd(100, 25) # => 25
// -----------------------------------------------------------------------------
math_gcd :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 || !strm_int_p(args[0]) || !strm_int_p(args[1]) {
		return STRM_NG
	}
	a := strm_value_int(args[0])
	b := strm_value_int(args[1])
	ret^ = strm_int_value(gcd_helper(abs(a), abs(b)))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_erfc - 相補誤差関数 (Complementary Error Function)
// -----------------------------------------------------------------------------
// 相補誤差関数を計算します: erfc(x) = 1 - erf(x)
// 正規分布の確率計算などに使用されます。
//
// Streem言語での使用例:
//   erfc(0)   # => 1.0
//   erfc(1)   # => 0.1572...
// -----------------------------------------------------------------------------
math_erfc :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	// Odin の core:math には erfc がないため、近似計算を使用
	x := strm_value_float(args[0])
	ret^ = strm_float_value(erfc_approx(x))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// erfc_approx - 相補誤差関数の近似計算（内部関数）
// -----------------------------------------------------------------------------
// Abramowitz and Stegun の近似式を使用
// Horner法による効率的な多項式評価
// -----------------------------------------------------------------------------
erfc_approx :: proc(x: f64) -> f64 {
	// 近似の定数
	a1 :: 0.254829592
	a2 :: -0.284496736
	a3 :: 1.421413741
	a4 :: -1.453152027
	a5 :: 1.061405429
	p :: 0.3275911

	// 符号を保存
	sign: f64 = 1.0
	x_abs := x
	if x < 0 {
		sign = -1.0
		x_abs = -x
	}

	// 近似計算
	t := 1.0 / (1.0 + p * x_abs)
	t2 := t * t
	t3 := t2 * t
	t4 := t3 * t
	t5 := t4 * t

	y := 1.0 - (a1 * t + a2 * t2 + a3 * t3 + a4 * t4 + a5 * t5) * math.exp(-x_abs * x_abs)

	// erf(-x) = -erf(x) なので、erfc(-x) = 1 + erf(x) = 2 - erfc(x)
	if sign < 0 {
		return 2.0 - (1.0 - y)
	}
	return 1.0 - y
}

// -----------------------------------------------------------------------------
// math_frexp - 仮数と指数の分解 (Extract Mantissa and Exponent)
// -----------------------------------------------------------------------------
// 浮動小数点数を仮数と2の指数に分解します: x = mantissa * 2^exp
// この実装では仮数のみを返します。
//
// Streem言語での使用例:
//   frexp(8)    # => 0.5 （8 = 0.5 * 2^4）
//   frexp(1)    # => 0.5 （1 = 0.5 * 2^1）
// -----------------------------------------------------------------------------
math_frexp :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	frac, _ := math.frexp(strm_value_float(args[0]))
	ret^ = strm_float_value(frac)
	return STRM_OK
}

// -----------------------------------------------------------------------------
// math_ldexp - 仮数と指数から浮動小数点数を構成 (Load Exponent)
// -----------------------------------------------------------------------------
// 仮数と指数から浮動小数点数を計算します: ldexp(x, exp) = x * 2^exp
//
// Streem言語での使用例:
//   ldexp(0.5, 4)  # => 8.0
//   ldexp(1, 10)   # => 1024.0
// -----------------------------------------------------------------------------
math_ldexp :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 || !strm_number_p(args[0]) || !strm_int_p(args[1]) {
		return STRM_NG
	}
	x := strm_value_float(args[0])
	exp := strm_value_int(args[1])
	ret^ = strm_float_value(math.ldexp(x, int(exp)))
	return STRM_OK
}

// =============================================================================
// 初期化 (Initialization)
// =============================================================================

// -----------------------------------------------------------------------------
// 数学定数 (Math Constants)
// -----------------------------------------------------------------------------
MATH_PI :: 3.14159265358979323846  // 円周率
MATH_E :: 2.71828182845904523536   // 自然対数の底

// -----------------------------------------------------------------------------
// strm_math_init - 数学関数の初期化
// -----------------------------------------------------------------------------
// Streem言語のグローバルスコープに、全ての数学関数と定数を登録します。
//
// 登録される定数:
//   PI - 円周率 (3.14159...)
//   E  - 自然対数の底 (2.71828...)
//
// 登録される関数:
//
// 【三角関数】
//   sin, cos, tan - 正弦、余弦、正接
//
// 【双曲線関数】
//   sinh, cosh, tanh - 双曲線正弦、余弦、正接
//
// 【逆三角関数】
//   asin, acos, atan - 逆正弦、逆余弦、逆正接
//
// 【逆双曲線関数】
//   asinh, acosh, atanh - 逆双曲線正弦、余弦、正接
//
// 【指数・対数関数】
//   sqrt, cbrt, pow - 平方根、立方根、べき乗
//   log, log10, log2 - 自然対数、常用対数、2進対数
//   exp - 指数関数
//
// 【丸め関数】
//   fabs - 絶対値
//   round, ceil, floor, trunc - 四捨五入、切り上げ、切り捨て、0方向切り捨て
//   int - trunc のエイリアス
//
// 【その他】
//   hypot - 斜辺の長さ
//   gcd - 最大公約数
//   erfc - 相補誤差関数
//   frexp, ldexp - 浮動小数点数の分解・構成
// -----------------------------------------------------------------------------
strm_math_init :: proc(state: ^Strm_State) {
	// 定数
	strm_var_def(state, strm_str_intern("PI"), strm_float_value(MATH_PI))
	strm_var_def(state, strm_str_intern("E"), strm_float_value(MATH_E))

	// 三角関数
	strm_var_def(state, strm_str_intern("sin"), strm_cfunc_value(math_sin))
	strm_var_def(state, strm_str_intern("cos"), strm_cfunc_value(math_cos))
	strm_var_def(state, strm_str_intern("tan"), strm_cfunc_value(math_tan))

	// 双曲線関数
	strm_var_def(state, strm_str_intern("sinh"), strm_cfunc_value(math_sinh))
	strm_var_def(state, strm_str_intern("cosh"), strm_cfunc_value(math_cosh))
	strm_var_def(state, strm_str_intern("tanh"), strm_cfunc_value(math_tanh))

	// 逆三角関数
	strm_var_def(state, strm_str_intern("asin"), strm_cfunc_value(math_asin))
	strm_var_def(state, strm_str_intern("acos"), strm_cfunc_value(math_acos))
	strm_var_def(state, strm_str_intern("atan"), strm_cfunc_value(math_atan))

	// 逆双曲線関数
	strm_var_def(state, strm_str_intern("asinh"), strm_cfunc_value(math_asinh))
	strm_var_def(state, strm_str_intern("acosh"), strm_cfunc_value(math_acosh))
	strm_var_def(state, strm_str_intern("atanh"), strm_cfunc_value(math_atanh))

	// 指数・対数関数
	strm_var_def(state, strm_str_intern("sqrt"), strm_cfunc_value(math_sqrt))
	strm_var_def(state, strm_str_intern("cbrt"), strm_cfunc_value(math_cbrt))
	strm_var_def(state, strm_str_intern("pow"), strm_cfunc_value(math_pow))
	strm_var_def(state, strm_str_intern("log"), strm_cfunc_value(math_log))
	strm_var_def(state, strm_str_intern("log10"), strm_cfunc_value(math_log10))
	strm_var_def(state, strm_str_intern("log2"), strm_cfunc_value(math_log2))
	strm_var_def(state, strm_str_intern("exp"), strm_cfunc_value(math_exp))

	// 丸め関数
	strm_var_def(state, strm_str_intern("fabs"), strm_cfunc_value(math_fabs))
	strm_var_def(state, strm_str_intern("round"), strm_cfunc_value(math_round))
	strm_var_def(state, strm_str_intern("ceil"), strm_cfunc_value(math_ceil))
	strm_var_def(state, strm_str_intern("floor"), strm_cfunc_value(math_floor))
	strm_var_def(state, strm_str_intern("trunc"), strm_cfunc_value(math_trunc))
	strm_var_def(state, strm_str_intern("int"), strm_cfunc_value(math_trunc)) // trunc のエイリアス

	// その他の数学関数
	strm_var_def(state, strm_str_intern("hypot"), strm_cfunc_value(math_hypot))
	strm_var_def(state, strm_str_intern("gcd"), strm_cfunc_value(math_gcd))
	strm_var_def(state, strm_str_intern("erfc"), strm_cfunc_value(math_erfc))
	strm_var_def(state, strm_str_intern("frexp"), strm_cfunc_value(math_frexp))
	strm_var_def(state, strm_str_intern("ldexp"), strm_cfunc_value(math_ldexp))
}
