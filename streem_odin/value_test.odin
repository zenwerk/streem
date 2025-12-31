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
	testing.expect(t, !strm_float_p(v), "Expected nil value to not be float")
	testing.expect(t, !strm_cfunc_p(v), "Expected nil value to not be cfunc")
}

@(test)
test_value_bool :: proc(t: ^testing.T) {
	v_true := strm_bool_value(true)
	v_false := strm_bool_value(false)

	testing.expect(t, strm_bool_p(v_true), "Expected bool value to be bool")
	testing.expect(t, strm_bool_p(v_false), "Expected bool value to be bool")
	testing.expect(t, strm_value_bool(v_true), "Expected true value")
	testing.expect(t, !strm_value_bool(v_false), "Expected false value")
	testing.expect(t, !strm_nil_p(v_true), "Expected bool value to not be nil")
	testing.expect(t, !strm_int_p(v_true), "Expected bool value to not be int")
}

@(test)
test_value_int :: proc(t: ^testing.T) {
	v := strm_int_value(42)
	testing.expect(t, strm_int_p(v), "Expected int value to be int")
	testing.expect(t, strm_number_p(v), "Expected int value to be number")
	testing.expect_value(t, strm_value_int(v), 42)

	v_neg := strm_int_value(-123)
	testing.expect(t, strm_int_p(v_neg), "Expected negative int value to be int")
	testing.expect_value(t, strm_value_int(v_neg), -123)

	v_zero := strm_int_value(0)
	testing.expect(t, strm_int_p(v_zero), "Expected zero int value to be int")
	testing.expect_value(t, strm_value_int(v_zero), 0)

	// Edge cases
	v_max := strm_int_value(max(i32))
	testing.expect_value(t, strm_value_int(v_max), max(i32))

	v_min := strm_int_value(min(i32))
	testing.expect_value(t, strm_value_int(v_min), min(i32))
}

@(test)
test_value_float :: proc(t: ^testing.T) {
	v := strm_float_value(3.14)
	testing.expect(t, strm_float_p(v), "Expected float value to be float")
	testing.expect(t, strm_number_p(v), "Expected float value to be number")
	testing.expect(t, !strm_int_p(v), "Expected float value to not be int")

	extracted := strm_value_float(v)
	testing.expect(t, extracted > 3.13 && extracted < 3.15, "Expected float value to be approximately 3.14")

	// Zero
	v_zero := strm_float_value(0.0)
	testing.expect(t, strm_float_p(v_zero), "Expected zero float to be float")
	testing.expect_value(t, strm_value_float(v_zero), 0.0)

	// Negative
	v_neg := strm_float_value(-123.456)
	testing.expect(t, strm_float_p(v_neg), "Expected negative float to be float")
}

@(test)
test_value_ptr :: proc(t: ^testing.T) {
	// Test with nil pointer
	v_nil := strm_ptr_value(nil)
	testing.expect(t, strm_nil_p(v_nil), "Expected nil ptr to be nil")

	// Test with actual pointer (use a local variable's address)
	x: int = 42
	v := strm_ptr_value(&x)
	testing.expect(t, !strm_nil_p(v), "Expected non-nil ptr to not be nil")
	testing.expect(t, strm_value_tag(v) == .Ptr, "Expected ptr tag")

	// Extract and verify pointer
	extracted := strm_value_ptr(v, int)
	testing.expect(t, extracted == &x, "Expected extracted pointer to match original")
}

@(test)
test_value_cfunc :: proc(t: ^testing.T) {
	// Create a test function
	test_fn :: proc(strm: ^Strm_Stream, argc: int, argv: []Strm_Value, ret: ^Strm_Value) -> int {
		return 0
	}

	v := strm_cfunc_value(test_fn)
	testing.expect(t, strm_cfunc_p(v), "Expected cfunc value to be cfunc")
	testing.expect(t, !strm_nil_p(v), "Expected cfunc value to not be nil")
	testing.expect(t, !strm_int_p(v), "Expected cfunc value to not be int")

	// Extract and verify function pointer
	extracted := strm_value_cfunc(v)
	testing.expect(t, extracted == test_fn, "Expected extracted cfunc to match original")
}

@(test)
test_value_foreign :: proc(t: ^testing.T) {
	x: int = 42
	v := strm_foreign_value(&x)
	testing.expect(t, strm_value_tag(v) == .Foreign, "Expected foreign tag")
	testing.expect(t, !strm_nil_p(v), "Expected foreign value to not be nil")

	extracted := strm_value_foreign(v)
	testing.expect(t, extracted == &x, "Expected extracted foreign pointer to match")
}

@(test)
test_value_equality :: proc(t: ^testing.T) {
	// Int equality
	v1 := strm_int_value(42)
	v2 := strm_int_value(42)
	v3 := strm_int_value(43)

	testing.expect(t, strm_value_eq(v1, v2), "Expected equal int values to be equal")
	testing.expect(t, !strm_value_eq(v1, v3), "Expected different int values to not be equal")

	// Float equality
	f1 := strm_float_value(3.14)
	f2 := strm_float_value(3.14)
	f3 := strm_float_value(2.71)

	testing.expect(t, strm_value_eq(f1, f2), "Expected equal float values to be equal")
	testing.expect(t, !strm_value_eq(f1, f3), "Expected different float values to not be equal")

	// Bool equality
	b1 := strm_bool_value(true)
	b2 := strm_bool_value(true)
	b3 := strm_bool_value(false)

	testing.expect(t, strm_value_eq(b1, b2), "Expected equal bool values to be equal")
	testing.expect(t, !strm_value_eq(b1, b3), "Expected different bool values to not be equal")

	// Nil equality
	n1 := strm_nil_value()
	n2 := strm_nil_value()
	testing.expect(t, strm_value_eq(n1, n2), "Expected nil values to be equal")

	// Cross-type inequality
	testing.expect(t, !strm_value_eq(v1, f1), "Expected int and float to not be equal")
	testing.expect(t, !strm_value_eq(v1, b1), "Expected int and bool to not be equal")
	testing.expect(t, !strm_value_eq(v1, n1), "Expected int and nil to not be equal")

	// Int/Float numeric comparison
	i42 := strm_int_value(42)
	f42 := strm_float_value(42.0)
	testing.expect(t, strm_value_eq(i42, f42), "Expected int 42 and float 42.0 to be equal")
}

@(test)
test_value_ptr_tag :: proc(t: ^testing.T) {
	// Create a stream and verify ptr_tag_p works
	strm := strm_stream_new(.Producer, nil, nil, nil)
	defer strm_stream_destroy(strm)

	v := strm_ptr_value(strm)
	testing.expect(t, strm_ptr_tag_p(v, .Stream), "Expected stream ptr to have Stream type")
	testing.expect(t, !strm_ptr_tag_p(v, .Lambda), "Expected stream ptr to not have Lambda type")
	testing.expect(t, !strm_ptr_tag_p(v, .IO), "Expected stream ptr to not have IO type")

	// Verify strm_stream_p works
	testing.expect(t, strm_stream_p(v), "Expected value to be identified as stream")
	testing.expect(t, !strm_lambda_p(v), "Expected value to not be identified as lambda")
}

@(test)
test_value_to_str :: proc(t: ^testing.T) {
	// Test nil
	n := strm_nil_value()
	testing.expect(t, strm_to_str(n) == "nil", "Expected nil to stringify to 'nil'")

	// Test bool
	bt := strm_bool_value(true)
	bf := strm_bool_value(false)
	testing.expect(t, strm_to_str(bt) == "true", "Expected true to stringify to 'true'")
	testing.expect(t, strm_to_str(bf) == "false", "Expected false to stringify to 'false'")

	// Test int
	i := strm_int_value(42)
	testing.expect(t, strm_to_str(i) == "42", "Expected int 42 to stringify to '42'")

	i_neg := strm_int_value(-123)
	testing.expect(t, strm_to_str(i_neg) == "-123", "Expected int -123 to stringify to '-123'")
}
