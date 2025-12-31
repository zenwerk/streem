package streem

import "core:fmt"
import "core:math"
import "core:strings"
import "core:unicode"

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

// Pointer type tags (for STRM_TAG_PTR payloads)
// These identify what kind of object the pointer points to
Ptr_Type :: enum u8 {
	Stream,   // strm_stream
	Lambda,   // strm_lambda
	Genfunc,  // generic function reference
	IO,       // strm_io
	Aux,      // auxiliary objects with namespace
}

// Streem value - NaN-boxed 64-bit value
Strm_Value :: distinct u64

// C function callback type (matches original C signature)
Strm_Cfunc :: #type proc(strm: ^Strm_Stream, argc: int, argv: []Strm_Value, ret: ^Strm_Value) -> int

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

// Create C function value
strm_cfunc_value :: proc(f: Strm_Cfunc) -> Strm_Value {
	val := u64(uintptr(rawptr(f))) & STRM_VAL_MASK
	return Strm_Value((u64(Value_Tag.Cfunc) << 48) | val)
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
// Also handles int values by converting them to float
strm_value_float :: proc(v: Strm_Value) -> f64 {
	if strm_int_p(v) {
		return f64(strm_value_int(v))
	}
	return transmute(f64)v
}

// Extract pointer from value (generic version)
strm_value_ptr :: proc(v: Strm_Value, $T: typeid) -> ^T {
	val := strm_value_val(v)
	return cast(^T)uintptr(val)
}

// Extract raw pointer from value
strm_value_rawptr :: proc(v: Strm_Value) -> rawptr {
	val := strm_value_val(v)
	return rawptr(uintptr(val))
}

// Extract C function from value
strm_value_cfunc :: proc(v: Strm_Value) -> Strm_Cfunc {
	val := strm_value_val(v)
	return cast(Strm_Cfunc)rawptr(uintptr(val))
}

// Extract foreign pointer from value
strm_value_foreign :: proc(v: Strm_Value) -> rawptr {
	val := strm_value_val(v)
	return rawptr(uintptr(val))
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

// Check if value is a pointer with specific type tag
strm_ptr_tag_p :: proc(v: Strm_Value, expected_type: Ptr_Type) -> bool {
	if strm_value_tag(v) != .Ptr {
		return false
	}
	ptr := strm_value_rawptr(v)
	if ptr == nil {
		return false
	}
	// The first field of any ptr-tagged object is Ptr_Type
	obj_type := (cast(^Ptr_Type)ptr)^
	return obj_type == expected_type
}

// Check if value is lambda (checked via Ptr to lambda struct)
strm_lambda_p :: proc(v: Strm_Value) -> bool {
	return strm_ptr_tag_p(v, .Lambda)
}

// Check if value is stream (checked via Ptr to stream struct)
strm_stream_p :: proc(v: Strm_Value) -> bool {
	return strm_ptr_tag_p(v, .Stream)
}

// Check if value is IO (checked via Ptr to IO struct)
strm_io_p :: proc(v: Strm_Value) -> bool {
	return strm_ptr_tag_p(v, .IO)
}

// Check if value is C function
strm_cfunc_p :: proc(v: Strm_Value) -> bool {
	return strm_value_tag(v) == .Cfunc
}

// ============================================================================
// Value equality and conversion
// ============================================================================

// Compare two values for equality
strm_value_eq :: proc(a: Strm_Value, b: Strm_Value) -> bool {
	// Fast path: identical bit patterns
	if u64(a) == u64(b) {
		return true
	}

	tag_a := strm_value_tag(a)
	tag_b := strm_value_tag(b)

	// Handle array and struct comparison
	if tag_a == .Array || tag_a == .Struct {
		if tag_b == .Array || tag_b == .Struct {
			// TODO: Implement strm_ary_eq when array type is complete
			return false
		}
	}

	// Handle string comparison (owned and foreign strings need content comparison)
	if tag_a == .String_O || tag_a == .String_F {
		if tag_b == .String_O || tag_b == .String_F {
			// TODO: Implement strm_str_eq when string type is complete
			return false
		}
	}

	// Handle cfunc comparison
	if tag_a == .Cfunc && tag_b == .Cfunc {
		return strm_value_cfunc(a) == strm_value_cfunc(b)
	}

	// Handle pointer comparison
	if tag_a == .Ptr && tag_b == .Ptr {
		return strm_value_rawptr(a) == strm_value_rawptr(b)
	}

	// Handle numeric comparison (int vs float)
	if strm_number_p(a) && strm_number_p(b) {
		return strm_value_float(a) == strm_value_float(b)
	}

	return false
}

// Convert value to string representation
strm_to_str :: proc(v: Strm_Value, allocator := context.allocator) -> string {
	context.allocator = allocator

	tag := strm_value_tag(v)

	#partial switch tag {
	case .Int:
		return fmt.aprintf("%d", strm_value_int(v))

	case .Bool:
		return strm_value_bool(v) ? "true" : "false"

	case .Cfunc:
		return fmt.aprintf("<cfunc:%p>", strm_value_cfunc(v))

	case .String_I, .String_6, .String_O, .String_F:
		// TODO: Extract actual string when string type is complete
		return "<string>"

	case .Array, .Struct:
		return strm_inspect(v, allocator)

	case .Ptr:
		if strm_value_val(v) == 0 {
			return "nil"
		} else {
			ptr := strm_value_rawptr(v)
			obj_type := (cast(^Ptr_Type)ptr)^
			#partial switch obj_type {
			case .Stream:
				return fmt.aprintf("<stream:%p>", ptr)
			case .IO:
				return fmt.aprintf("<io:%p>", ptr)
			case .Lambda:
				return fmt.aprintf("<lambda:%p>", ptr)
			case .Genfunc:
				return fmt.aprintf("<genfunc:%p>", ptr)
			case .Aux:
				return fmt.aprintf("<obj:%p>", ptr)
			}
			return fmt.aprintf("<ptr:%p>", ptr)
		}

	case:
		// Float or other
		if strm_float_p(v) {
			f := strm_value_float(v)
			if math.is_nan(f) {
				return "NaN"
			} else if math.is_inf(f, 1) {
				return "Inf"
			} else if math.is_inf(f, -1) {
				return "-Inf"
			}
			return fmt.aprintf("%.14g", f)
		}
		return fmt.aprintf("<%x>", u64(v))
	}
}

// Debug representation of value (with escaping for strings, etc.)
strm_inspect :: proc(v: Strm_Value, allocator := context.allocator) -> string {
	context.allocator = allocator

	tag := strm_value_tag(v)

	// For strings, add quotes and escape special characters
	if strm_string_p(v) {
		// TODO: Implement proper string escaping when string type is complete
		return "\"<string>\""
	}

	// For arrays/structs, format with brackets
	if tag == .Array || tag == .Struct {
		// TODO: Implement proper array inspection when array type is complete
		return "[...]"
	}

	// For other types, use normal string conversion
	return strm_to_str(v, allocator)
}
