package streem

// Runtime value representation using NaN-boxing
// Reference: src/strm.h, src/value.c

// NaN-boxing tag layout (upper 16 bits when NaN):
// 0xFFF0 | tag_id << 48
//
// Tags:
// - STRM_TAG_NAN      = 0xFFF0 (actual NaN)
// - STRM_TAG_BOOL     = 0xFFF1
// - STRM_TAG_INT      = 0xFFF2
// - STRM_TAG_LIST     = 0xFFF3
// - STRM_TAG_ARRAY    = 0xFFF4
// - STRM_TAG_STRUCT   = 0xFFF5
// - STRM_TAG_STRING_I = 0xFFF7 (interned)
// - STRM_TAG_STRING_6 = 0xFFF8 (short, inline)
// - STRM_TAG_STRING_O = 0xFFF9 (owned)
// - STRM_TAG_STRING_F = 0xFFFA (foreign/static)
// - STRM_TAG_CFUNC    = 0xFFFB
// - STRM_TAG_PTR      = 0xFFFD
// - STRM_TAG_FOREIGN  = 0xFFFF

// Value tags
Value_Tag :: enum u16 {
	Nan      = 0xFFF0, // actual NaN
	Bool     = 0xFFF1,
	Int      = 0xFFF2,
	List     = 0xFFF3,
	Array    = 0xFFF4,
	Struct   = 0xFFF5,
	String_I = 0xFFF7, // interned string
	String_6 = 0xFFF8, // short string (<=6 bytes inline)
	String_O = 0xFFF9, // owned string
	String_F = 0xFFFA, // foreign/static string
	Cfunc    = 0xFFFB,
	Ptr      = 0xFFFD,
	Foreign  = 0xFFFF,
}

// Streem value - NaN-boxed 64-bit value
Strm_Value :: distinct u64

// NaN mask for checking tagged values
STRM_NAN_MASK :: 0xFFF0_0000_0000_0000
STRM_TAG_MASK :: 0xFFFF_0000_0000_0000
STRM_VAL_MASK :: 0x0000_FFFF_FFFF_FFFF

// ============================================================================
// Value tag extraction
// ============================================================================

// Extract tag from value
strm_value_tag :: proc(v: Strm_Value) -> Value_Tag {
	bits := u64(v)
	// Check if it's a tagged value (NaN)
	if (bits & STRM_NAN_MASK) != STRM_NAN_MASK {
		// It's a regular float
		return .Nan
	}
	return Value_Tag((bits >> 48) & 0xFFFF)
}

// Extract payload from value
strm_value_val :: proc(v: Strm_Value) -> u64 {
	return u64(v) & STRM_VAL_MASK
}

// ============================================================================
// Value constructors
// ============================================================================

// Create nil value (PTR tag with 0 payload)
strm_nil_value :: proc() -> Strm_Value {
	return Strm_Value((u64(Value_Tag.Ptr) << 48) | 0)
}

// Create boolean value
strm_bool_value :: proc(b: bool) -> Strm_Value {
	val: u64 = b ? 1 : 0
	return Strm_Value((u64(Value_Tag.Bool) << 48) | val)
}

// Create integer value (32-bit signed)
strm_int_value :: proc(i: i32) -> Strm_Value {
	// Sign-extend to 48 bits if negative
	val := u64(u32(i)) & STRM_VAL_MASK
	return Strm_Value((u64(Value_Tag.Int) << 48) | val)
}

// Create float value (raw bits, no tag for valid floats)
strm_float_value :: proc(f: f64) -> Strm_Value {
	return transmute(Strm_Value)f
}

// Create pointer value
strm_ptr_value :: proc(ptr: rawptr) -> Strm_Value {
	val := u64(uintptr(ptr)) & STRM_VAL_MASK
	return Strm_Value((u64(Value_Tag.Ptr) << 48) | val)
}

// Create foreign pointer value
strm_foreign_value :: proc(ptr: rawptr) -> Strm_Value {
	val := u64(uintptr(ptr)) & STRM_VAL_MASK
	return Strm_Value((u64(Value_Tag.Foreign) << 48) | val)
}

// ============================================================================
// Value extractors
// ============================================================================

// Extract boolean from value
strm_value_bool :: proc(v: Strm_Value) -> bool {
	return strm_value_val(v) != 0
}

// Extract integer from value
strm_value_int :: proc(v: Strm_Value) -> i32 {
	val := strm_value_val(v)
	// Sign-extend from 32 bits
	return i32(u32(val))
}

// Extract float from value
strm_value_float :: proc(v: Strm_Value) -> f64 {
	return transmute(f64)v
}

// Extract pointer from value
strm_value_ptr :: proc(v: Strm_Value, $T: typeid) -> ^T {
	val := strm_value_val(v)
	return cast(^T)uintptr(val)
}

// ============================================================================
// Type predicates
// ============================================================================

// Check if value is nil
strm_nil_p :: proc(v: Strm_Value) -> bool {
	tag := strm_value_tag(v)
	if tag != .Ptr {
		return false
	}
	return strm_value_val(v) == 0
}

// Check if value is boolean
strm_bool_p :: proc(v: Strm_Value) -> bool {
	return strm_value_tag(v) == .Bool
}

// Check if value is integer
strm_int_p :: proc(v: Strm_Value) -> bool {
	return strm_value_tag(v) == .Int
}

// Check if value is float
strm_float_p :: proc(v: Strm_Value) -> bool {
	bits := u64(v)
	// A value is a float if it's NOT a tagged value
	// (i.e., top bits don't match NaN pattern)
	// Also handle actual NaN
	tag := strm_value_tag(v)
	return tag == .Nan || (bits & STRM_NAN_MASK) != STRM_NAN_MASK
}

// Check if value is number (int or float)
strm_number_p :: proc(v: Strm_Value) -> bool {
	return strm_int_p(v) || strm_float_p(v)
}

// Check if value is string (any string type)
strm_string_p :: proc(v: Strm_Value) -> bool {
	tag := strm_value_tag(v)
	#partial switch tag {
	case .String_I, .String_6, .String_O, .String_F:
		return true
	}
	return false
}

// Check if value is array
strm_array_p :: proc(v: Strm_Value) -> bool {
	return strm_value_tag(v) == .Array
}

// Check if value is struct
strm_struct_p :: proc(v: Strm_Value) -> bool {
	return strm_value_tag(v) == .Struct
}

// Check if value is lambda (checked via Ptr to lambda struct)
strm_lambda_p :: proc(v: Strm_Value) -> bool {
	// TODO: Need to check ptr type
	return false
}

// Check if value is stream (checked via Ptr to stream struct)
strm_stream_p :: proc(v: Strm_Value) -> bool {
	// TODO: Need to check ptr type
	return false
}

// Check if value is C function
strm_cfunc_p :: proc(v: Strm_Value) -> bool {
	return strm_value_tag(v) == .Cfunc
}

// ============================================================================
// Value equality and conversion (stubs for Phase 8)
// ============================================================================

// Compare two values for equality
strm_value_eq :: proc(a: Strm_Value, b: Strm_Value) -> bool {
	// TODO: Implement proper value comparison
	return u64(a) == u64(b)
}

// Convert value to string representation
strm_to_str :: proc(v: Strm_Value) -> string {
	// TODO: Implement value to string conversion
	return "<value>"
}

// Debug representation of value
strm_inspect :: proc(v: Strm_Value) -> string {
	// TODO: Implement debug representation
	return "<inspect>"
}
