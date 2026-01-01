package streem

import "core:math"

// Built-in math functions
// Reference: src/math.c

// ============================================================================
// Trigonometric Functions
// ============================================================================

// Sine function
math_sin :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.sin(strm_value_float(args[0])))
	return STRM_OK
}

// Cosine function
math_cos :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.cos(strm_value_float(args[0])))
	return STRM_OK
}

// Tangent function
math_tan :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.tan(strm_value_float(args[0])))
	return STRM_OK
}

// ============================================================================
// Hyperbolic Functions
// ============================================================================

// Hyperbolic sine function
math_sinh :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.sinh(strm_value_float(args[0])))
	return STRM_OK
}

// Hyperbolic cosine function
math_cosh :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.cosh(strm_value_float(args[0])))
	return STRM_OK
}

// Hyperbolic tangent function
math_tanh :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.tanh(strm_value_float(args[0])))
	return STRM_OK
}

// ============================================================================
// Inverse Trigonometric Functions
// ============================================================================

// Arcsine function
math_asin :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.asin(strm_value_float(args[0])))
	return STRM_OK
}

// Arccosine function
math_acos :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.acos(strm_value_float(args[0])))
	return STRM_OK
}

// Arctangent function
math_atan :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.atan(strm_value_float(args[0])))
	return STRM_OK
}

// ============================================================================
// Inverse Hyperbolic Functions
// ============================================================================

// Inverse hyperbolic sine
math_asinh :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.asinh(strm_value_float(args[0])))
	return STRM_OK
}

// Inverse hyperbolic cosine
math_acosh :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.acosh(strm_value_float(args[0])))
	return STRM_OK
}

// Inverse hyperbolic tangent
math_atanh :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.atanh(strm_value_float(args[0])))
	return STRM_OK
}

// ============================================================================
// Exponential and Logarithmic Functions
// ============================================================================

// Square root function
math_sqrt :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.sqrt(strm_value_float(args[0])))
	return STRM_OK
}

// Cube root function
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

// Power function: pow(x, y) = x^y
math_pow :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 || !strm_number_p(args[0]) || !strm_number_p(args[1]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.pow(strm_value_float(args[0]), strm_value_float(args[1])))
	return STRM_OK
}

// Natural logarithm
math_log :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.ln(strm_value_float(args[0])))
	return STRM_OK
}

// Base-10 logarithm
math_log10 :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.log10(strm_value_float(args[0])))
	return STRM_OK
}

// Base-2 logarithm
math_log2 :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.log2(strm_value_float(args[0])))
	return STRM_OK
}

// Exponential function: e^x
math_exp :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.exp(strm_value_float(args[0])))
	return STRM_OK
}

// ============================================================================
// Rounding Functions
// ============================================================================

// Absolute value
math_fabs :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	ret^ = strm_float_value(abs(strm_value_float(args[0])))
	return STRM_OK
}

// Floor function: round(x, precision?) - rounds to nearest
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

// Ceiling function: ceil(x, precision?)
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

// Floor function: floor(x, precision?)
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

// Truncate function: trunc(x, precision?)
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

// ============================================================================
// Other Mathematical Functions
// ============================================================================

// Hypotenuse: hypot(x, y) = sqrt(x^2 + y^2)
math_hypot :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 || !strm_number_p(args[0]) || !strm_number_p(args[1]) {
		return STRM_NG
	}
	ret^ = strm_float_value(math.hypot(strm_value_float(args[0]), strm_value_float(args[1])))
	return STRM_OK
}

// Greatest common divisor
gcd_helper :: proc(a, b: i32) -> i32 {
	if b == 0 {
		return a
	}
	return gcd_helper(b, a % b)
}

math_gcd :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 || !strm_int_p(args[0]) || !strm_int_p(args[1]) {
		return STRM_NG
	}
	a := strm_value_int(args[0])
	b := strm_value_int(args[1])
	ret^ = strm_int_value(gcd_helper(abs(a), abs(b)))
	return STRM_OK
}

// Complementary error function
math_erfc :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	// Odin's core:math doesn't have erfc, so we use an approximation
	// erfc(x) = 1 - erf(x)
	// Using Horner's method approximation for erf
	x := strm_value_float(args[0])
	ret^ = strm_float_value(erfc_approx(x))
	return STRM_OK
}

// Approximation of erfc using Horner's method
// Reference: Abramowitz and Stegun approximation
erfc_approx :: proc(x: f64) -> f64 {
	// Constants for approximation
	a1 :: 0.254829592
	a2 :: -0.284496736
	a3 :: 1.421413741
	a4 :: -1.453152027
	a5 :: 1.061405429
	p :: 0.3275911

	// Save the sign
	sign: f64 = 1.0
	x_abs := x
	if x < 0 {
		sign = -1.0
		x_abs = -x
	}

	// Approximation
	t := 1.0 / (1.0 + p * x_abs)
	t2 := t * t
	t3 := t2 * t
	t4 := t3 * t
	t5 := t4 * t

	y := 1.0 - (a1 * t + a2 * t2 + a3 * t3 + a4 * t4 + a5 * t5) * math.exp(-x_abs * x_abs)

	// erf(-x) = -erf(x), so erfc(-x) = 1 + erf(x) = 2 - erfc(x)
	if sign < 0 {
		return 2.0 - (1.0 - y)
	}
	return 1.0 - y
}

// frexp: Extract mantissa and exponent
// Returns mantissa, stores exponent in second arg (not directly usable in streem)
// We return just the mantissa for simplicity
math_frexp :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_number_p(args[0]) {
		return STRM_NG
	}
	frac, _ := math.frexp(strm_value_float(args[0]))
	ret^ = strm_float_value(frac)
	return STRM_OK
}

// ldexp: Load exponent - x * 2^exp
math_ldexp :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 || !strm_number_p(args[0]) || !strm_int_p(args[1]) {
		return STRM_NG
	}
	x := strm_value_float(args[0])
	exp := strm_value_int(args[1])
	ret^ = strm_float_value(math.ldexp(x, int(exp)))
	return STRM_OK
}

// ============================================================================
// Math namespace initialization
// ============================================================================

// Math constants
MATH_PI :: 3.14159265358979323846
MATH_E :: 2.71828182845904523536

// Initialize math functions
strm_math_init :: proc(state: ^Strm_State) {
	// Constants
	strm_var_def(state, strm_str_intern("PI"), strm_float_value(MATH_PI))
	strm_var_def(state, strm_str_intern("E"), strm_float_value(MATH_E))

	// Trigonometric functions
	strm_var_def(state, strm_str_intern("sin"), strm_cfunc_value(math_sin))
	strm_var_def(state, strm_str_intern("cos"), strm_cfunc_value(math_cos))
	strm_var_def(state, strm_str_intern("tan"), strm_cfunc_value(math_tan))

	// Hyperbolic functions
	strm_var_def(state, strm_str_intern("sinh"), strm_cfunc_value(math_sinh))
	strm_var_def(state, strm_str_intern("cosh"), strm_cfunc_value(math_cosh))
	strm_var_def(state, strm_str_intern("tanh"), strm_cfunc_value(math_tanh))

	// Inverse trigonometric functions
	strm_var_def(state, strm_str_intern("asin"), strm_cfunc_value(math_asin))
	strm_var_def(state, strm_str_intern("acos"), strm_cfunc_value(math_acos))
	strm_var_def(state, strm_str_intern("atan"), strm_cfunc_value(math_atan))

	// Inverse hyperbolic functions
	strm_var_def(state, strm_str_intern("asinh"), strm_cfunc_value(math_asinh))
	strm_var_def(state, strm_str_intern("acosh"), strm_cfunc_value(math_acosh))
	strm_var_def(state, strm_str_intern("atanh"), strm_cfunc_value(math_atanh))

	// Exponential and logarithmic functions
	strm_var_def(state, strm_str_intern("sqrt"), strm_cfunc_value(math_sqrt))
	strm_var_def(state, strm_str_intern("cbrt"), strm_cfunc_value(math_cbrt))
	strm_var_def(state, strm_str_intern("pow"), strm_cfunc_value(math_pow))
	strm_var_def(state, strm_str_intern("log"), strm_cfunc_value(math_log))
	strm_var_def(state, strm_str_intern("log10"), strm_cfunc_value(math_log10))
	strm_var_def(state, strm_str_intern("log2"), strm_cfunc_value(math_log2))
	strm_var_def(state, strm_str_intern("exp"), strm_cfunc_value(math_exp))

	// Rounding functions
	strm_var_def(state, strm_str_intern("fabs"), strm_cfunc_value(math_fabs))
	strm_var_def(state, strm_str_intern("round"), strm_cfunc_value(math_round))
	strm_var_def(state, strm_str_intern("ceil"), strm_cfunc_value(math_ceil))
	strm_var_def(state, strm_str_intern("floor"), strm_cfunc_value(math_floor))
	strm_var_def(state, strm_str_intern("trunc"), strm_cfunc_value(math_trunc))
	strm_var_def(state, strm_str_intern("int"), strm_cfunc_value(math_trunc)) // Alias for trunc

	// Other mathematical functions
	strm_var_def(state, strm_str_intern("hypot"), strm_cfunc_value(math_hypot))
	strm_var_def(state, strm_str_intern("gcd"), strm_cfunc_value(math_gcd))
	strm_var_def(state, strm_str_intern("erfc"), strm_cfunc_value(math_erfc))
	strm_var_def(state, strm_str_intern("frexp"), strm_cfunc_value(math_frexp))
	strm_var_def(state, strm_str_intern("ldexp"), strm_cfunc_value(math_ldexp))
}
