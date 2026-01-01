package streem

import "core:testing"
import "core:os"

// ============================================================================
// IO Tests
// ============================================================================

@(test)
test_io_new :: proc(t: ^testing.T) {
	// Test IO creation
	iov := strm_io_new(os.stdin, STRM_IO_READ)

	testing.expect(t, strm_io_p(iov), "Expected IO value")

	io := strm_value_io(iov)
	testing.expect(t, io != nil, "Expected IO to be created")
	testing.expect(t, io.type == .IO, "Expected IO type tag")
	testing.expect(t, io.fd == os.stdin, "Expected stdin fd")
	testing.expect(t, .Read in io.mode, "Expected read mode")
}

@(test)
test_io_modes :: proc(t: ^testing.T) {
	// Test different IO modes
	read_io := strm_io_new(os.stdin, STRM_IO_READ)
	write_io := strm_io_new(os.stdout, STRM_IO_WRITE)

	io_r := strm_value_io(read_io)
	io_w := strm_value_io(write_io)

	testing.expect(t, .Read in io_r.mode, "Expected read mode")
	testing.expect(t, .Write in io_w.mode, "Expected write mode")
}

// ============================================================================
// Built-in Number Tests
// ============================================================================

@(test)
test_builtin_plus :: proc(t: ^testing.T) {
	args := []Strm_Value{strm_int_value(2), strm_int_value(3)}
	ret: Strm_Value

	result := num_plus(nil, 2, args, &ret)
	testing.expect(t, result == STRM_OK, "Expected OK result")
	testing.expect(t, strm_int_p(ret), "Expected int result")
	testing.expect(t, strm_value_int(ret) == 5, "Expected 2 + 3 = 5")
}

@(test)
test_builtin_minus :: proc(t: ^testing.T) {
	// Binary minus
	args := []Strm_Value{strm_int_value(10), strm_int_value(3)}
	ret: Strm_Value

	result := num_minus(nil, 2, args, &ret)
	testing.expect(t, result == STRM_OK, "Expected OK result")
	testing.expect(t, strm_value_int(ret) == 7, "Expected 10 - 3 = 7")

	// Unary minus
	args2 := []Strm_Value{strm_int_value(5)}
	result = num_minus(nil, 1, args2, &ret)
	testing.expect(t, result == STRM_OK, "Expected OK result")
	testing.expect(t, strm_value_int(ret) == -5, "Expected -5")
}

@(test)
test_builtin_mult :: proc(t: ^testing.T) {
	args := []Strm_Value{strm_int_value(4), strm_int_value(5)}
	ret: Strm_Value

	result := num_mult(nil, 2, args, &ret)
	testing.expect(t, result == STRM_OK, "Expected OK result")
	testing.expect(t, strm_value_int(ret) == 20, "Expected 4 * 5 = 20")
}

@(test)
test_builtin_div :: proc(t: ^testing.T) {
	args := []Strm_Value{strm_float_value(10.0), strm_float_value(4.0)}
	ret: Strm_Value

	result := num_div(nil, 2, args, &ret)
	testing.expect(t, result == STRM_OK, "Expected OK result")
	testing.expect(t, strm_float_p(ret), "Expected float result")
	testing.expect(t, strm_value_float(ret) == 2.5, "Expected 10 / 4 = 2.5")
}

@(test)
test_builtin_comparison :: proc(t: ^testing.T) {
	args := []Strm_Value{strm_int_value(5), strm_int_value(3)}
	ret: Strm_Value

	// Greater than
	num_gt(nil, 2, args, &ret)
	testing.expect(t, strm_value_bool(ret) == true, "Expected 5 > 3")

	// Less than
	num_lt(nil, 2, args, &ret)
	testing.expect(t, strm_value_bool(ret) == false, "Expected 5 < 3 to be false")

	// Greater or equal
	args2 := []Strm_Value{strm_int_value(5), strm_int_value(5)}
	num_ge(nil, 2, args2, &ret)
	testing.expect(t, strm_value_bool(ret) == true, "Expected 5 >= 5")

	// Less or equal
	num_le(nil, 2, args2, &ret)
	testing.expect(t, strm_value_bool(ret) == true, "Expected 5 <= 5")
}

@(test)
test_builtin_logical :: proc(t: ^testing.T) {
	ret: Strm_Value

	// AND
	args_tt := []Strm_Value{strm_bool_value(true), strm_bool_value(true)}
	num_and(nil, 2, args_tt, &ret)
	testing.expect(t, strm_value_bool(ret) == true, "Expected true && true = true")

	args_tf := []Strm_Value{strm_bool_value(true), strm_bool_value(false)}
	num_and(nil, 2, args_tf, &ret)
	testing.expect(t, strm_value_bool(ret) == false, "Expected true && false = false")

	// OR
	num_or(nil, 2, args_tf, &ret)
	testing.expect(t, strm_value_bool(ret) == true, "Expected true || false = true")

	// NOT
	args_t := []Strm_Value{strm_bool_value(true)}
	num_not(nil, 1, args_t, &ret)
	testing.expect(t, strm_value_bool(ret) == false, "Expected !true = false")
}

@(test)
test_builtin_eq :: proc(t: ^testing.T) {
	ret: Strm_Value

	// Equal integers
	args := []Strm_Value{strm_int_value(5), strm_int_value(5)}
	exec_eq(nil, 2, args, &ret)
	testing.expect(t, strm_value_bool(ret) == true, "Expected 5 == 5")

	// Not equal integers
	args2 := []Strm_Value{strm_int_value(5), strm_int_value(3)}
	exec_eq(nil, 2, args2, &ret)
	testing.expect(t, strm_value_bool(ret) == false, "Expected 5 != 3")

	// Not equal operator
	exec_neq(nil, 2, args2, &ret)
	testing.expect(t, strm_value_bool(ret) == true, "Expected 5 != 3 to be true")
}
