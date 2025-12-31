package streem

import "core:testing"

// ============================================================================
// Value Tests
// ============================================================================

@(test)
test_value_nil :: proc(t: ^testing.T) {
	v := strm_nil_value()
	testing.expect(t, strm_nil_p(v), "Expected nil value to be nil")
	testing.expect(t, !strm_bool_p(v), "Expected nil value to not be bool")
	testing.expect(t, !strm_int_p(v), "Expected nil value to not be int")
}

@(test)
test_value_bool :: proc(t: ^testing.T) {
	v_true := strm_bool_value(true)
	v_false := strm_bool_value(false)

	testing.expect(t, strm_bool_p(v_true), "Expected bool value to be bool")
	testing.expect(t, strm_bool_p(v_false), "Expected bool value to be bool")
	testing.expect(t, strm_value_bool(v_true), "Expected true value")
	testing.expect(t, !strm_value_bool(v_false), "Expected false value")
}

@(test)
test_value_int :: proc(t: ^testing.T) {
	v := strm_int_value(42)
	testing.expect(t, strm_int_p(v), "Expected int value to be int")
	testing.expect_value(t, strm_value_int(v), 42)

	v_neg := strm_int_value(-123)
	testing.expect(t, strm_int_p(v_neg), "Expected negative int value to be int")
	testing.expect_value(t, strm_value_int(v_neg), -123)
}

@(test)
test_value_float :: proc(t: ^testing.T) {
	v := strm_float_value(3.14)
	testing.expect(t, strm_float_p(v), "Expected float value to be float")
	testing.expect(t, strm_number_p(v), "Expected float value to be number")

	extracted := strm_value_float(v)
	testing.expect(t, extracted > 3.13 && extracted < 3.15, "Expected float value to be approximately 3.14")
}

@(test)
test_value_equality :: proc(t: ^testing.T) {
	v1 := strm_int_value(42)
	v2 := strm_int_value(42)
	v3 := strm_int_value(43)

	testing.expect(t, strm_value_eq(v1, v2), "Expected equal int values to be equal")
	testing.expect(t, !strm_value_eq(v1, v3), "Expected different int values to not be equal")
}
