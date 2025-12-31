package streem

import "core:testing"

// ============================================================================
// State Tests
// ============================================================================

@(test)
test_state_var_def :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	ok := strm_var_def(state, "x", strm_int_value(42))
	testing.expect(t, ok, "Expected var_def to succeed")

	ok = strm_var_def(state, "x", strm_int_value(43))
	testing.expect(t, !ok, "Expected second var_def to fail")
}

@(test)
test_state_var_get :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	strm_var_def(state, "x", strm_int_value(42))

	val, found := strm_var_get(state, "x")
	testing.expect(t, found, "Expected var to be found")
	testing.expect_value(t, strm_value_int(val), 42)

	_, found = strm_var_get(state, "y")
	testing.expect(t, !found, "Expected var to not be found")
}

@(test)
test_state_scoping :: proc(t: ^testing.T) {
	outer := strm_state_new()
	defer strm_state_destroy(outer)

	strm_var_def(outer, "x", strm_int_value(1))

	inner := strm_state_new(outer)
	defer strm_state_destroy(inner)

	strm_var_def(inner, "y", strm_int_value(2))

	// Inner can access outer's variables
	val, found := strm_var_get(inner, "x")
	testing.expect(t, found, "Expected outer var to be visible")
	testing.expect_value(t, strm_value_int(val), 1)

	// Inner has its own variables
	val, found = strm_var_get(inner, "y")
	testing.expect(t, found, "Expected inner var to be visible")
	testing.expect_value(t, strm_value_int(val), 2)

	// Outer cannot access inner's variables
	_, found = strm_var_get(outer, "y")
	testing.expect(t, !found, "Expected inner var to not be visible in outer")
}
