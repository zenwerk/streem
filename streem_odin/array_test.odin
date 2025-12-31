package streem

import "core:testing"

// ============================================================================
// Array Tests
// ============================================================================

@(test)
test_ary_new_empty :: proc(t: ^testing.T) {
	// Test empty array
	ary := strm_ary_new()
	defer strm_ary_free(ary)

	testing.expect(t, strm_value_tag(Strm_Value(ary)) == .Array, "Expected Array tag")
	testing.expect_value(t, strm_ary_len(ary), 0)
}

@(test)
test_ary_new_with_values :: proc(t: ^testing.T) {
	// Test array with values
	values := []Strm_Value{strm_int_value(1), strm_int_value(2), strm_int_value(3)}
	ary := strm_ary_new(values)
	defer strm_ary_free(ary)

	testing.expect(t, strm_value_tag(Strm_Value(ary)) == .Array, "Expected Array tag")
	testing.expect_value(t, strm_ary_len(ary), 3)

	ptr := strm_ary_ptr(ary)
	testing.expect_value(t, strm_value_int(ptr[0]), 1)
	testing.expect_value(t, strm_value_int(ptr[1]), 2)
	testing.expect_value(t, strm_value_int(ptr[2]), 3)
}

@(test)
test_ary_new_len :: proc(t: ^testing.T) {
	// Test array with length (zero-initialized)
	ary := strm_ary_new_len(5)
	defer strm_ary_free(ary)

	testing.expect_value(t, strm_ary_len(ary), 5)

	// Elements should be nil
	ptr := strm_ary_ptr(ary)
	for i in 0 ..< 5 {
		testing.expect(t, strm_nil_p(ptr[i]), "Expected nil element")
	}
}

@(test)
test_ary_get_set :: proc(t: ^testing.T) {
	// Test get and set
	ary := strm_ary_new_len(3)
	defer strm_ary_free(ary)

	// Set values
	testing.expect(t, strm_ary_set(ary, 0, strm_int_value(10)), "Expected set to succeed")
	testing.expect(t, strm_ary_set(ary, 1, strm_int_value(20)), "Expected set to succeed")
	testing.expect(t, strm_ary_set(ary, 2, strm_int_value(30)), "Expected set to succeed")

	// Out of bounds should fail
	testing.expect(t, !strm_ary_set(ary, 3, strm_int_value(40)), "Expected out of bounds set to fail")
	testing.expect(t, !strm_ary_set(ary, -1, strm_int_value(40)), "Expected negative index set to fail")

	// Get values
	v0, ok0 := strm_ary_get(ary, 0)
	testing.expect(t, ok0, "Expected get to succeed")
	testing.expect_value(t, strm_value_int(v0), 10)

	v1, ok1 := strm_ary_get(ary, 1)
	testing.expect(t, ok1, "Expected get to succeed")
	testing.expect_value(t, strm_value_int(v1), 20)

	// Out of bounds should fail
	_, ok3 := strm_ary_get(ary, 3)
	testing.expect(t, !ok3, "Expected out of bounds get to fail")
}

@(test)
test_ary_eq :: proc(t: ^testing.T) {
	// Test array equality
	v1 := []Strm_Value{strm_int_value(1), strm_int_value(2)}
	v2 := []Strm_Value{strm_int_value(1), strm_int_value(2)}
	v3 := []Strm_Value{strm_int_value(1), strm_int_value(3)}
	v4 := []Strm_Value{strm_int_value(1)}

	a1 := strm_ary_new(v1)
	a2 := strm_ary_new(v2)
	a3 := strm_ary_new(v3)
	a4 := strm_ary_new(v4)

	defer strm_ary_free(a1)
	defer strm_ary_free(a2)
	defer strm_ary_free(a3)
	defer strm_ary_free(a4)

	// Same content should be equal
	testing.expect(t, strm_ary_eq(a1, a2), "Expected equal arrays to be equal")
	// Same array should equal itself
	testing.expect(t, strm_ary_eq(a1, a1), "Expected array to equal itself")
	// Different content should not be equal
	testing.expect(t, !strm_ary_eq(a1, a3), "Expected different arrays to not be equal")
	// Different length should not be equal
	testing.expect(t, !strm_ary_eq(a1, a4), "Expected arrays of different length to not be equal")
}

@(test)
test_ary_slice :: proc(t: ^testing.T) {
	// Test array slice
	values := []Strm_Value{strm_int_value(10), strm_int_value(20), strm_int_value(30)}
	ary := strm_ary_new(values)
	defer strm_ary_free(ary)

	slice := strm_ary_slice(ary)
	testing.expect_value(t, len(slice), 3)
	testing.expect_value(t, strm_value_int(slice[0]), 10)
	testing.expect_value(t, strm_value_int(slice[1]), 20)
	testing.expect_value(t, strm_value_int(slice[2]), 30)
}

@(test)
test_ary_null :: proc(t: ^testing.T) {
	// Test null array handling
	null_ary := STRM_ARY_NULL

	testing.expect_value(t, strm_ary_len(null_ary), 0)
	testing.expect(t, strm_ary_ptr(null_ary) == nil, "Expected null array ptr to be nil")
	testing.expect(t, strm_ary_headers(null_ary) == STRM_ARY_NULL, "Expected null array headers to be null")
	testing.expect(t, strm_ary_ns(null_ary) == nil, "Expected null array ns to be nil")
	testing.expect(t, strm_ary_slice(null_ary) == nil, "Expected null array slice to be nil")
}

@(test)
test_ary_headers :: proc(t: ^testing.T) {
	// Test array with headers (struct-like)
	values := []Strm_Value{strm_int_value(42), strm_bool_value(true)}

	// Create headers array with field names
	h1 := strm_str_new("age")
	h2 := strm_str_new("active")
	headers_values := []Strm_Value{strm_str_value(h1), strm_str_value(h2)}
	headers := strm_ary_new(headers_values)

	ary := strm_ary_new_struct(values, headers)

	// Clean up order matters - free headers after ary since ary references it
	defer strm_ary_free(ary)
	defer strm_ary_free(headers)
	defer strm_str_free(h1)
	defer strm_str_free(h2)

	testing.expect(t, strm_value_tag(Strm_Value(ary)) == .Struct, "Expected Struct tag")
	testing.expect(t, strm_ary_headers(ary) == headers, "Expected headers to match")
}

@(test)
test_ary_ns :: proc(t: ^testing.T) {
	// Test array with namespace
	values := []Strm_Value{strm_int_value(1)}
	ns := strm_ns_new(nil, "TestNS")
	ary := strm_ary_new_struct(values, STRM_ARY_NULL, ns)

	defer strm_ary_free(ary)
	defer strm_state_destroy(ns)

	testing.expect(t, strm_ary_ns(ary) == ns, "Expected namespace to match")
}

@(test)
test_ary_to_value :: proc(t: ^testing.T) {
	// Test conversion between Strm_Array and Strm_Value
	values := []Strm_Value{strm_int_value(1)}
	ary := strm_ary_new(values)
	defer strm_ary_free(ary)

	v := strm_ary_value(ary)
	testing.expect(t, strm_array_p(v), "Expected value to be array type")

	ary2 := strm_value_ary(v)
	testing.expect(t, strm_ary_eq(ary, ary2), "Expected roundtrip to preserve array")
}

@(test)
test_ary_value_eq :: proc(t: ^testing.T) {
	// Test strm_value_eq for arrays
	v1 := []Strm_Value{strm_int_value(1), strm_int_value(2)}
	v2 := []Strm_Value{strm_int_value(1), strm_int_value(2)}
	v3 := []Strm_Value{strm_int_value(3), strm_int_value(4)}

	a1 := strm_ary_new(v1)
	a2 := strm_ary_new(v2)
	a3 := strm_ary_new(v3)

	defer strm_ary_free(a1)
	defer strm_ary_free(a2)
	defer strm_ary_free(a3)

	val1 := strm_ary_value(a1)
	val2 := strm_ary_value(a2)
	val3 := strm_ary_value(a3)

	testing.expect(t, strm_value_eq(val1, val2), "Expected equal array values to be equal")
	testing.expect(t, !strm_value_eq(val1, val3), "Expected different array values to not be equal")
}

@(test)
test_ary_inspect :: proc(t: ^testing.T) {
	// Test array inspection
	values := []Strm_Value{strm_int_value(1), strm_int_value(2)}
	ary := strm_ary_new(values)
	defer strm_ary_free(ary)

	v := strm_ary_value(ary)
	s := strm_inspect(v)
	testing.expect(t, s == "[1, 2]", "Expected array inspect to be '[1, 2]'")
}

@(test)
test_ary_is_array_like :: proc(t: ^testing.T) {
	// Test strm_is_array_like
	values := []Strm_Value{strm_int_value(1)}
	ary := strm_ary_new(values)
	struct_ary := strm_ary_new_struct(values, STRM_ARY_NULL)

	defer strm_ary_free(ary)
	defer strm_ary_free(struct_ary)

	testing.expect(t, strm_is_array_like(Strm_Value(ary)), "Expected array to be array-like")
	testing.expect(t, strm_is_array_like(Strm_Value(struct_ary)), "Expected struct to be array-like")
	testing.expect(t, !strm_is_array_like(strm_int_value(42)), "Expected int to not be array-like")
	testing.expect(t, !strm_is_array_like(strm_nil_value()), "Expected nil to not be array-like")
}
