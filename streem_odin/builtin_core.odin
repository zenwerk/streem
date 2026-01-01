package streem

import "core:fmt"
import "core:os"
import "core:strings"

// Core built-in functions
// Reference: src/exec.c

// ============================================================================
// I/O Functions
// ============================================================================

// puts - print values with newline
exec_puts :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	for i in 0 ..< argc {
		if i > 0 {
			fmt.print(" ")
		}
		s := strm_to_str(args[i])
		fmt.print(s)
	}
	fmt.println()
	ret^ = strm_nil_value()
	return STRM_OK
}

// ============================================================================
// Comparison Operations
// ============================================================================

// == operator
exec_eq :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	ret^ = strm_bool_value(strm_value_eq(args[0], args[1]))
	return STRM_OK
}

// != operator
exec_neq :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	ret^ = strm_bool_value(!strm_value_eq(args[0], args[1]))
	return STRM_OK
}

// ============================================================================
// Pipe Operator
// ============================================================================

// | operator - connect streams
exec_bar :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	// For integers, use bitwise OR
	if strm_int_p(args[0]) && strm_int_p(args[1]) {
		ret^ = strm_int_value(strm_value_int(args[0]) | strm_value_int(args[1]))
		return STRM_OK
	}

	// Otherwise, connect streams
	return strm_connect(strm, args[0], args[1], ret)
}

// ============================================================================
// File Operations
// ============================================================================

// fread(path) - open file for reading
exec_fread :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_string_p(args[0]) {
		return STRM_NG
	}

	str := Strm_String(args[0])
	path := strm_str_ptr(&str)
	ret^ = strm_fread(path)
	return STRM_OK
}

// fwrite(path) - open file for writing
exec_fwrite :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_string_p(args[0]) {
		return STRM_NG
	}

	str := Strm_String(args[0])
	path := strm_str_ptr(&str)
	ret^ = strm_fwrite(path)
	return STRM_OK
}

// ============================================================================
// Control Flow
// ============================================================================

// exit(code?) - exit program
exec_exit :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	code := 0
	if argc > 0 && strm_int_p(args[0]) {
		code = int(strm_value_int(args[0]))
	}
	os.exit(code)
}

// ============================================================================
// Pattern Matching
// ============================================================================

// match(value, patterns...) - pattern matching helper
exec_match :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc < 2 {
		return STRM_NG
	}

	val := args[0]
	func_ := args[1]

	// Call the pattern function with the value
	return int(strm_funcall(strm, nil, func_, []Strm_Value{val}, ret))
}

// ============================================================================
// Misc initialization
// ============================================================================

strm_misc_init :: proc(state: ^Strm_State) {
	// I/O objects
	strm_var_def(state, strm_str_intern("stdin"), strm_io_new(os.stdin, STRM_IO_READ))
	strm_var_def(state, strm_str_intern("stdout"), strm_io_new(os.stdout, STRM_IO_WRITE))
	strm_var_def(state, strm_str_intern("stderr"), strm_io_new(os.stderr, STRM_IO_WRITE))

	// Output functions
	strm_var_def(state, strm_str_intern("puts"), strm_cfunc_value(exec_puts))
	strm_var_def(state, strm_str_intern("print"), strm_cfunc_value(exec_puts))

	// Comparison operators
	strm_var_def(state, strm_str_intern("=="), strm_cfunc_value(exec_eq))
	strm_var_def(state, strm_str_intern("!="), strm_cfunc_value(exec_neq))

	// Pipe operator
	strm_var_def(state, strm_str_intern("|"), strm_cfunc_value(exec_bar))

	// File operations
	strm_var_def(state, strm_str_intern("fread"), strm_cfunc_value(exec_fread))
	strm_var_def(state, strm_str_intern("fwrite"), strm_cfunc_value(exec_fwrite))

	// Control flow
	strm_var_def(state, strm_str_intern("exit"), strm_cfunc_value(exec_exit))

	// Pattern matching
	strm_var_def(state, strm_str_intern("match"), strm_cfunc_value(exec_match))
}
