package streem

import "core:strings"

// Built-in string functions
// Reference: src/string.c

// ============================================================================
// String length
// ============================================================================

// length(str) - get string length
exec_str_length :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 {
		return STRM_NG
	}

	if !strm_string_p(args[0]) {
		return STRM_NG
	}

	str := Strm_String(args[0])
	ret^ = strm_int_value(strm_str_len(str))
	return STRM_OK
}

// ============================================================================
// String split
// ============================================================================

// split(str, delim) - split string by delimiter
exec_str_split :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc < 1 || argc > 2 {
		return STRM_NG
	}

	if !strm_string_p(args[0]) {
		return STRM_NG
	}

	str_val := Strm_String(args[0])
	str_copy := str_val
	s := strm_str_ptr(&str_copy)

	// Default delimiter is whitespace
	delim := " "
	if argc == 2 {
		if !strm_string_p(args[1]) {
			return STRM_NG
		}
		delim_val := Strm_String(args[1])
		delim_copy := delim_val
		delim = strm_str_ptr(&delim_copy)
	}

	// Split the string
	parts := strings.split(s, delim)
	defer delete(parts)

	// Create array of string values
	result := make([]Strm_Value, len(parts))
	defer delete(result)

	for part, i in parts {
		result[i] = strm_str_value(strm_str_new(part))
	}

	ret^ = strm_ary_value(strm_ary_new(result))
	return STRM_OK
}

// ============================================================================
// String concatenation
// ============================================================================

// concat(str1, str2, ...) - concatenate strings
exec_str_concat :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc < 1 {
		return STRM_NG
	}

	builder: strings.Builder
	strings.builder_init(&builder)
	defer strings.builder_destroy(&builder)

	for i in 0 ..< argc {
		if strm_string_p(args[i]) {
			str_val := Strm_String(args[i])
			str_copy := str_val
			s := strm_str_ptr(&str_copy)
			strings.write_string(&builder, s)
		} else {
			// Convert to string
			s := strm_to_str(args[i])
			strings.write_string(&builder, s)
		}
	}

	result := strings.to_string(builder)
	ret^ = strm_str_value(strm_str_new(result))
	return STRM_OK
}

// ============================================================================
// String substring
// ============================================================================

// substr(str, start) - substring from start to end
// substr(str, start, length) - substring with length
exec_str_substr :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc < 2 || argc > 3 {
		return STRM_NG
	}

	if !strm_string_p(args[0]) || !strm_int_p(args[1]) {
		return STRM_NG
	}

	str_val := Strm_String(args[0])
	str_copy := str_val
	s := strm_str_ptr(&str_copy)
	start := int(strm_value_int(args[1]))

	// Handle negative indices
	if start < 0 {
		start = len(s) + start
	}
	if start < 0 {
		start = 0
	}
	if start > len(s) {
		ret^ = strm_str_value(strm_str_new(""))
		return STRM_OK
	}

	end := len(s)
	if argc == 3 {
		if !strm_int_p(args[2]) {
			return STRM_NG
		}
		length := int(strm_value_int(args[2]))
		if length < 0 {
			ret^ = strm_str_value(strm_str_new(""))
			return STRM_OK
		}
		end = start + length
		if end > len(s) {
			end = len(s)
		}
	}

	result := s[start:end]
	ret^ = strm_str_value(strm_str_new(result))
	return STRM_OK
}

// ============================================================================
// String trim
// ============================================================================

// trim(str) - trim whitespace from both ends
exec_str_trim :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 {
		return STRM_NG
	}

	if !strm_string_p(args[0]) {
		return STRM_NG
	}

	str_val := Strm_String(args[0])
	str_copy := str_val
	s := strm_str_ptr(&str_copy)

	result := strings.trim_space(s)
	ret^ = strm_str_value(strm_str_new(result))
	return STRM_OK
}

// ============================================================================
// String uppercase/lowercase
// ============================================================================

// upper(str) - convert to uppercase
exec_str_upper :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 {
		return STRM_NG
	}

	if !strm_string_p(args[0]) {
		return STRM_NG
	}

	str_val := Strm_String(args[0])
	str_copy := str_val
	s := strm_str_ptr(&str_copy)

	result := strings.to_upper(s)
	defer delete(result)
	ret^ = strm_str_value(strm_str_new(result))
	return STRM_OK
}

// lower(str) - convert to lowercase
exec_str_lower :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 {
		return STRM_NG
	}

	if !strm_string_p(args[0]) {
		return STRM_NG
	}

	str_val := Strm_String(args[0])
	str_copy := str_val
	s := strm_str_ptr(&str_copy)

	result := strings.to_lower(s)
	defer delete(result)
	ret^ = strm_str_value(strm_str_new(result))
	return STRM_OK
}

// ============================================================================
// String contains/index
// ============================================================================

// contains(str, substr) - check if string contains substring
exec_str_contains :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	if !strm_string_p(args[0]) || !strm_string_p(args[1]) {
		return STRM_NG
	}

	str_val := Strm_String(args[0])
	str_copy := str_val
	s := strm_str_ptr(&str_copy)

	substr_val := Strm_String(args[1])
	substr_copy := substr_val
	substr := strm_str_ptr(&substr_copy)

	ret^ = strm_bool_value(strings.contains(s, substr))
	return STRM_OK
}

// index(str, substr) - find index of substring, returns -1 if not found
exec_str_index :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	if !strm_string_p(args[0]) || !strm_string_p(args[1]) {
		return STRM_NG
	}

	str_val := Strm_String(args[0])
	str_copy := str_val
	s := strm_str_ptr(&str_copy)

	substr_val := Strm_String(args[1])
	substr_copy := substr_val
	substr := strm_str_ptr(&substr_copy)

	idx := strings.index(s, substr)
	ret^ = strm_int_value(i32(idx))
	return STRM_OK
}

// ============================================================================
// String replace
// ============================================================================

// replace(str, old, new) - replace all occurrences
exec_str_replace :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 3 {
		return STRM_NG
	}

	if !strm_string_p(args[0]) || !strm_string_p(args[1]) || !strm_string_p(args[2]) {
		return STRM_NG
	}

	str_val := Strm_String(args[0])
	str_copy := str_val
	s := strm_str_ptr(&str_copy)

	old_val := Strm_String(args[1])
	old_copy := old_val
	old := strm_str_ptr(&old_copy)

	new_val := Strm_String(args[2])
	new_copy := new_val
	new_str := strm_str_ptr(&new_copy)

	result, _ := strings.replace_all(s, old, new_str)
	defer delete(result)
	ret^ = strm_str_value(strm_str_new(result))
	return STRM_OK
}

// ============================================================================
// String initialization
// ============================================================================

strm_string_init :: proc(state: ^Strm_State) {
	// String functions as top-level
	strm_var_def(state, strm_str_intern("split"), strm_cfunc_value(exec_str_split))
	strm_var_def(state, strm_str_intern("concat"), strm_cfunc_value(exec_str_concat))
	strm_var_def(state, strm_str_intern("substr"), strm_cfunc_value(exec_str_substr))
	strm_var_def(state, strm_str_intern("trim"), strm_cfunc_value(exec_str_trim))
	strm_var_def(state, strm_str_intern("upper"), strm_cfunc_value(exec_str_upper))
	strm_var_def(state, strm_str_intern("lower"), strm_cfunc_value(exec_str_lower))
	strm_var_def(state, strm_str_intern("contains"), strm_cfunc_value(exec_str_contains))
	strm_var_def(state, strm_str_intern("str_index"), strm_cfunc_value(exec_str_index))
	strm_var_def(state, strm_str_intern("replace"), strm_cfunc_value(exec_str_replace))

	// String namespace methods
	strm_var_def(strm_ns_string, strm_str_intern("length"), strm_cfunc_value(exec_str_length))
	strm_var_def(strm_ns_string, strm_str_intern("split"), strm_cfunc_value(exec_str_split))
	strm_var_def(strm_ns_string, strm_str_intern("substr"), strm_cfunc_value(exec_str_substr))
	strm_var_def(strm_ns_string, strm_str_intern("trim"), strm_cfunc_value(exec_str_trim))
	strm_var_def(strm_ns_string, strm_str_intern("upper"), strm_cfunc_value(exec_str_upper))
	strm_var_def(strm_ns_string, strm_str_intern("lower"), strm_cfunc_value(exec_str_lower))
	strm_var_def(strm_ns_string, strm_str_intern("contains"), strm_cfunc_value(exec_str_contains))
	strm_var_def(strm_ns_string, strm_str_intern("index"), strm_cfunc_value(exec_str_index))
	strm_var_def(strm_ns_string, strm_str_intern("replace"), strm_cfunc_value(exec_str_replace))
}
