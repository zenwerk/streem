package streem

import "core:math"

// Built-in number operations
// Reference: src/number.c

// ============================================================================
// Arithmetic Operations
// ============================================================================

// Addition: + operator
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

// Subtraction: - operator (binary and unary)
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

// Multiplication: * operator
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

// Division: / operator
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

// Modulo: % operator
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

// ============================================================================
// Bitwise Operations
// ============================================================================

// Bitwise OR: | operator for integers
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

// Bitwise AND: & operator for integers
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

// Bitwise NOT: ~ operator
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

// ============================================================================
// Comparison Operations
// ============================================================================

// Greater than: > operator
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

// Greater or equal: >= operator
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

// Less than: < operator
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

// Less or equal: <= operator
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

// ============================================================================
// Logical Operations
// ============================================================================

// Logical AND: && operator
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

// Logical OR: || operator
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

// Logical NOT: ! operator
num_not :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 {
		return STRM_NG
	}

	// Treat nil and false as false, everything else as true
	a := !strm_nil_p(args[0]) && (!strm_bool_p(args[0]) || strm_value_bool(args[0]))

	ret^ = strm_bool_value(!a)
	return STRM_OK
}

// ============================================================================
// Number namespace initialization
// ============================================================================

// Initialize number namespace
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
