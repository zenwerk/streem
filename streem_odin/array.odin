package streem

import "core:mem"

// Array type - NaN-boxed 64-bit value with array-specific tags
// Reference: src/strm.h, src/array.c
//
// Array types:
// - ARRAY: regular array
// - STRUCT: array with named fields (headers)

// Strm_Array is a NaN-boxed value type that points to an array structure
Strm_Array :: distinct Strm_Value

// Array struct for heap-allocated arrays
Strm_Array_Struct :: struct {
	len:     i32,
	ptr:     [^]Strm_Value, // array elements
	headers: Strm_Array,    // optional field names (for struct-like arrays)
	ns:      ^Strm_State,   // optional namespace (for typed objects)
}

// Null array value
STRM_ARY_NULL :: Strm_Array(0)

// ============================================================================
// Array creation
// ============================================================================

// Create new array with given values
// If values is nil, creates zero-initialized array
strm_ary_new :: proc(values: []Strm_Value = nil, allocator := context.allocator) -> Strm_Array {
	context.allocator = allocator
	length := i32(len(values)) if values != nil else 0
	return strm_ary_new_len(length, values, allocator)
}

// Create new array with given length
// If values is provided and len(values) >= length, copies values
// Otherwise zero-initializes
strm_ary_new_len :: proc(length: i32, values: []Strm_Value = nil, allocator := context.allocator) -> Strm_Array {
	context.allocator = allocator

	// Allocate struct + buffer together
	total_size := size_of(Strm_Array_Struct) + size_of(Strm_Value) * int(length)
	raw_mem, _ := mem.alloc(total_size)

	ary := cast(^Strm_Array_Struct)raw_mem
	buf := cast([^]Strm_Value)(uintptr(raw_mem) + size_of(Strm_Array_Struct))

	if values != nil && len(values) >= int(length) {
		// Copy values
		for i in 0 ..< length {
			buf[i] = values[i]
		}
	} else {
		// Zero-initialize
		for i in 0 ..< length {
			buf[i] = strm_nil_value()
		}
	}

	ary.ptr = buf
	ary.len = length
	ary.ns = nil
	ary.headers = STRM_ARY_NULL

	// Create tagged pointer value
	ptr_val := u64(uintptr(ary)) & STRM_VAL_MASK
	return Strm_Array((u64(Value_Tag.Array) << 48) | ptr_val)
}

// Create array with headers (struct-like array)
strm_ary_new_struct :: proc(
	values: []Strm_Value,
	headers: Strm_Array,
	ns: ^Strm_State = nil,
	allocator := context.allocator,
) -> Strm_Array {
	ary := strm_ary_new(values, allocator)
	strm_ary_set_headers(ary, headers)
	strm_ary_set_ns(ary, ns)
	// Change tag to STRUCT
	ptr_val := u64(ary) & STRM_VAL_MASK
	return Strm_Array((u64(Value_Tag.Struct) << 48) | ptr_val)
}

// ============================================================================
// Array access
// ============================================================================

// Get array struct from value
strm_ary_struct :: proc(ary: Strm_Array) -> ^Strm_Array_Struct {
	ptr := strm_value_rawptr(Strm_Value(ary))
	return cast(^Strm_Array_Struct)ptr
}

// Get array length
strm_ary_len :: proc(ary: Strm_Array) -> i32 {
	if u64(ary) == 0 {
		return 0
	}
	return strm_ary_struct(ary).len
}

// Get pointer to array elements
strm_ary_ptr :: proc(ary: Strm_Array) -> [^]Strm_Value {
	if u64(ary) == 0 {
		return nil
	}
	return strm_ary_struct(ary).ptr
}

// Get array headers (field names for struct-like arrays)
strm_ary_headers :: proc(ary: Strm_Array) -> Strm_Array {
	if u64(ary) == 0 {
		return STRM_ARY_NULL
	}
	return strm_ary_struct(ary).headers
}

// Get array namespace
strm_ary_ns :: proc(ary: Strm_Array) -> ^Strm_State {
	if u64(ary) == 0 {
		return nil
	}
	return strm_ary_struct(ary).ns
}

// Set array headers
strm_ary_set_headers :: proc(ary: Strm_Array, headers: Strm_Array) {
	if u64(ary) == 0 {
		return
	}
	strm_ary_struct(ary).headers = headers
}

// Set array namespace
strm_ary_set_ns :: proc(ary: Strm_Array, ns: ^Strm_State) {
	if u64(ary) == 0 {
		return
	}
	strm_ary_struct(ary).ns = ns
}

// Get element at index
strm_ary_get :: proc(ary: Strm_Array, index: i32) -> (Strm_Value, bool) {
	if u64(ary) == 0 {
		return strm_nil_value(), false
	}
	ary_struct := strm_ary_struct(ary)
	if index < 0 || index >= ary_struct.len {
		return strm_nil_value(), false
	}
	return ary_struct.ptr[index], true
}

// Set element at index
strm_ary_set :: proc(ary: Strm_Array, index: i32, value: Strm_Value) -> bool {
	if u64(ary) == 0 {
		return false
	}
	ary_struct := strm_ary_struct(ary)
	if index < 0 || index >= ary_struct.len {
		return false
	}
	ary_struct.ptr[index] = value
	return true
}

// ============================================================================
// Array comparison
// ============================================================================

// Compare two arrays for equality
strm_ary_eq :: proc(a: Strm_Array, b: Strm_Array) -> bool {
	// Fast path: identical bit patterns
	if u64(a) == u64(b) {
		return true
	}

	// Handle null arrays
	if u64(a) == 0 || u64(b) == 0 {
		return false
	}

	// Compare lengths
	len_a := strm_ary_len(a)
	len_b := strm_ary_len(b)
	if len_a != len_b {
		return false
	}

	// Compare elements
	ptr_a := strm_ary_ptr(a)
	ptr_b := strm_ary_ptr(b)
	for i in 0 ..< len_a {
		if !strm_value_eq(ptr_a[i], ptr_b[i]) {
			return false
		}
	}

	return true
}

// ============================================================================
// Array utilities
// ============================================================================

// Convert Strm_Array to Strm_Value
strm_ary_value :: proc(ary: Strm_Array) -> Strm_Value {
	return Strm_Value(ary)
}

// Convert Strm_Value to Strm_Array (assumes value is an array)
strm_value_ary :: proc(v: Strm_Value) -> Strm_Array {
	return Strm_Array(v)
}

// Get array as slice (for convenience)
strm_ary_slice :: proc(ary: Strm_Array) -> []Strm_Value {
	if u64(ary) == 0 {
		return nil
	}
	ary_struct := strm_ary_struct(ary)
	return ary_struct.ptr[:ary_struct.len]
}

// Free array resources
strm_ary_free :: proc(ary: Strm_Array, allocator := context.allocator) {
	if u64(ary) == 0 {
		return
	}
	context.allocator = allocator
	ptr := strm_value_rawptr(Strm_Value(ary))
	// The array struct and buffer are allocated together
	free(ptr)
}

// Check if value is array or struct type
strm_is_array_like :: proc(v: Strm_Value) -> bool {
	tag := strm_value_tag(v)
	return tag == .Array || tag == .Struct
}
