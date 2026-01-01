package streem

import "core:math"
import "core:testing"

// ============================================================================
// Math Constants Tests
// ============================================================================

@(test)
test_math_constants :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)
	strm_init(state)

	// Test PI
	pi_val, found_pi := strm_var_get(state, "PI")
	testing.expect(t, found_pi, "PI should be defined")
	testing.expect(t, strm_float_p(pi_val), "PI should be float")
	testing.expect(t, abs(strm_value_float(pi_val) - 3.14159265) < 0.0001, "PI should be ~3.14159")

	// Test E
	e_val, found_e := strm_var_get(state, "E")
	testing.expect(t, found_e, "E should be defined")
	testing.expect(t, strm_float_p(e_val), "E should be float")
	testing.expect(t, abs(strm_value_float(e_val) - 2.71828182) < 0.0001, "E should be ~2.71828")
}

// ============================================================================
// Trigonometric Functions Tests
// ============================================================================

@(test)
test_math_sin :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(0.0)}

	result := math_sin(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret)) < 0.0001, "sin(0) should be 0")

	// sin(PI/2) = 1
	args[0] = strm_float_value(MATH_PI / 2)
	result = math_sin(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 1.0) < 0.0001, "sin(PI/2) should be 1")
}

@(test)
test_math_cos :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(0.0)}

	result := math_cos(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 1.0) < 0.0001, "cos(0) should be 1")

	// cos(PI) = -1
	args[0] = strm_float_value(MATH_PI)
	result = math_cos(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) + 1.0) < 0.0001, "cos(PI) should be -1")
}

@(test)
test_math_tan :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(0.0)}

	result := math_tan(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret)) < 0.0001, "tan(0) should be 0")

	// tan(PI/4) = 1
	args[0] = strm_float_value(MATH_PI / 4)
	result = math_tan(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 1.0) < 0.0001, "tan(PI/4) should be 1")
}

// ============================================================================
// Inverse Trigonometric Functions Tests
// ============================================================================

@(test)
test_math_asin :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(0.0)}

	result := math_asin(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret)) < 0.0001, "asin(0) should be 0")

	// asin(1) = PI/2
	args[0] = strm_float_value(1.0)
	result = math_asin(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - MATH_PI/2) < 0.0001, "asin(1) should be PI/2")
}

@(test)
test_math_acos :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(1.0)}

	result := math_acos(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret)) < 0.0001, "acos(1) should be 0")

	// acos(0) = PI/2
	args[0] = strm_float_value(0.0)
	result = math_acos(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - MATH_PI/2) < 0.0001, "acos(0) should be PI/2")
}

@(test)
test_math_atan :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(0.0)}

	result := math_atan(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret)) < 0.0001, "atan(0) should be 0")

	// atan(1) = PI/4
	args[0] = strm_float_value(1.0)
	result = math_atan(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - MATH_PI/4) < 0.0001, "atan(1) should be PI/4")
}

// ============================================================================
// Hyperbolic Functions Tests
// ============================================================================

@(test)
test_math_sinh :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(0.0)}

	result := math_sinh(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret)) < 0.0001, "sinh(0) should be 0")
}

@(test)
test_math_cosh :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(0.0)}

	result := math_cosh(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 1.0) < 0.0001, "cosh(0) should be 1")
}

@(test)
test_math_tanh :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(0.0)}

	result := math_tanh(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret)) < 0.0001, "tanh(0) should be 0")
}

// ============================================================================
// Inverse Hyperbolic Functions Tests
// ============================================================================

@(test)
test_math_asinh :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(0.0)}

	result := math_asinh(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret)) < 0.0001, "asinh(0) should be 0")
}

@(test)
test_math_acosh :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(1.0)}

	result := math_acosh(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret)) < 0.0001, "acosh(1) should be 0")
}

@(test)
test_math_atanh :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(0.0)}

	result := math_atanh(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret)) < 0.0001, "atanh(0) should be 0")
}

// ============================================================================
// Exponential and Logarithmic Functions Tests
// ============================================================================

@(test)
test_math_sqrt :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(4.0)}

	result := math_sqrt(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 2.0) < 0.0001, "sqrt(4) should be 2")

	// sqrt(9) = 3
	args[0] = strm_float_value(9.0)
	result = math_sqrt(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 3.0) < 0.0001, "sqrt(9) should be 3")
}

@(test)
test_math_cbrt :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(8.0)}

	result := math_cbrt(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 2.0) < 0.0001, "cbrt(8) should be 2")

	// cbrt(27) = 3
	args[0] = strm_float_value(27.0)
	result = math_cbrt(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 3.0) < 0.0001, "cbrt(27) should be 3")
}

@(test)
test_math_pow :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(2.0), strm_float_value(3.0)}

	result := math_pow(nil, 2, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 8.0) < 0.0001, "pow(2,3) should be 8")

	// pow(3, 2) = 9
	args[0] = strm_float_value(3.0)
	args[1] = strm_float_value(2.0)
	result = math_pow(nil, 2, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 9.0) < 0.0001, "pow(3,2) should be 9")
}

@(test)
test_math_log :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(MATH_E)}

	result := math_log(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 1.0) < 0.0001, "log(e) should be 1")

	// log(1) = 0
	args[0] = strm_float_value(1.0)
	result = math_log(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret)) < 0.0001, "log(1) should be 0")
}

@(test)
test_math_log10 :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(10.0)}

	result := math_log10(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 1.0) < 0.0001, "log10(10) should be 1")

	// log10(100) = 2
	args[0] = strm_float_value(100.0)
	result = math_log10(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 2.0) < 0.0001, "log10(100) should be 2")
}

@(test)
test_math_log2 :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(2.0)}

	result := math_log2(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 1.0) < 0.0001, "log2(2) should be 1")

	// log2(8) = 3
	args[0] = strm_float_value(8.0)
	result = math_log2(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 3.0) < 0.0001, "log2(8) should be 3")
}

@(test)
test_math_exp :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(0.0)}

	result := math_exp(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 1.0) < 0.0001, "exp(0) should be 1")

	// exp(1) = e
	args[0] = strm_float_value(1.0)
	result = math_exp(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - MATH_E) < 0.0001, "exp(1) should be e")
}

// ============================================================================
// Rounding Functions Tests
// ============================================================================

@(test)
test_math_fabs :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(-5.0)}

	result := math_fabs(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 5.0) < 0.0001, "fabs(-5) should be 5")

	// fabs(3.5) = 3.5
	args[0] = strm_float_value(3.5)
	result = math_fabs(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 3.5) < 0.0001, "fabs(3.5) should be 3.5")
}

@(test)
test_math_round :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(3.5)}

	result := math_round(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 4.0) < 0.0001, "round(3.5) should be 4")

	// round(3.4) = 3
	args[0] = strm_float_value(3.4)
	result = math_round(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 3.0) < 0.0001, "round(3.4) should be 3")

	// round(3.14159, 2) = 3.14
	args2 := []Strm_Value{strm_float_value(3.14159), strm_int_value(2)}
	result = math_round(nil, 2, args2, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 3.14) < 0.0001, "round(3.14159, 2) should be 3.14")
}

@(test)
test_math_ceil :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(3.2)}

	result := math_ceil(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 4.0) < 0.0001, "ceil(3.2) should be 4")

	// ceil(-3.2) = -3
	args[0] = strm_float_value(-3.2)
	result = math_ceil(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) + 3.0) < 0.0001, "ceil(-3.2) should be -3")
}

@(test)
test_math_floor :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(3.8)}

	result := math_floor(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 3.0) < 0.0001, "floor(3.8) should be 3")

	// floor(-3.2) = -4
	args[0] = strm_float_value(-3.2)
	result = math_floor(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) + 4.0) < 0.0001, "floor(-3.2) should be -4")
}

@(test)
test_math_trunc :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(3.8)}

	result := math_trunc(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 3.0) < 0.0001, "trunc(3.8) should be 3")

	// trunc(-3.8) = -3
	args[0] = strm_float_value(-3.8)
	result = math_trunc(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) + 3.0) < 0.0001, "trunc(-3.8) should be -3")
}

// ============================================================================
// Other Mathematical Functions Tests
// ============================================================================

@(test)
test_math_hypot :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(3.0), strm_float_value(4.0)}

	result := math_hypot(nil, 2, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 5.0) < 0.0001, "hypot(3,4) should be 5")
}

@(test)
test_math_gcd :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_int_value(12), strm_int_value(8)}

	result := math_gcd(nil, 2, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, strm_int_p(ret), "gcd should return int")
	testing.expect_value(t, strm_value_int(ret), 4)

	// gcd(17, 13) = 1 (coprime)
	args[0] = strm_int_value(17)
	args[1] = strm_int_value(13)
	result = math_gcd(nil, 2, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect_value(t, strm_value_int(ret), 1)

	// gcd(-12, 8) = 4 (handles negative)
	args[0] = strm_int_value(-12)
	args[1] = strm_int_value(8)
	result = math_gcd(nil, 2, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect_value(t, strm_value_int(ret), 4)
}

@(test)
test_math_erfc :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(0.0)}

	// erfc(0) = 1
	result := math_erfc(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 1.0) < 0.001, "erfc(0) should be ~1")
}

@(test)
test_math_frexp :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(8.0)}

	result := math_frexp(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	// 8.0 = 0.5 * 2^4, so frexp returns 0.5
	testing.expect(t, abs(strm_value_float(ret) - 0.5) < 0.0001, "frexp(8) mantissa should be 0.5")
}

@(test)
test_math_ldexp :: proc(t: ^testing.T) {
	ret: Strm_Value
	args := []Strm_Value{strm_float_value(0.5), strm_int_value(4)}

	// ldexp(0.5, 4) = 0.5 * 2^4 = 8.0
	result := math_ldexp(nil, 2, args, &ret)
	testing.expect_value(t, result, STRM_OK)
	testing.expect(t, abs(strm_value_float(ret) - 8.0) < 0.0001, "ldexp(0.5, 4) should be 8")
}

// ============================================================================
// Error Handling Tests
// ============================================================================

@(test)
test_math_invalid_args :: proc(t: ^testing.T) {
	ret: Strm_Value

	// sin with no args
	result := math_sin(nil, 0, nil, &ret)
	testing.expect_value(t, result, STRM_NG)

	// sin with string arg
	str_val := Strm_Value(strm_str_static("hello"))
	args := []Strm_Value{str_val}
	result = math_sin(nil, 1, args, &ret)
	testing.expect_value(t, result, STRM_NG)

	// pow with one arg
	args_num := []Strm_Value{strm_float_value(2.0)}
	result = math_pow(nil, 1, args_num, &ret)
	testing.expect_value(t, result, STRM_NG)

	// gcd with floats
	args2 := []Strm_Value{strm_float_value(1.5), strm_float_value(2.5)}
	result = math_gcd(nil, 2, args2, &ret)
	testing.expect_value(t, result, STRM_NG)
}

// ============================================================================
// Integration Test: Math from streem code
// ============================================================================

@(test)
test_math_integration :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)
	strm_init(state)

	// Test: sqrt(16) = 4
	node, ok := parse_string("sqrt(16)")
	defer node_free(node)

	testing.expect(t, ok, "Parser should succeed")

	ret: Strm_Value
	result := exec_expr(nil, state, node, &ret)
	testing.expect_value(t, result, Exec_Result.Ok)
	testing.expect(t, abs(strm_value_float(ret) - 4.0) < 0.0001, "sqrt(16) should be 4")
}
