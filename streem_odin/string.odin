package streem

import "core:hash"
import "core:mem"
import "core:strings"
import "core:sync"

// String type - NaN-boxed 64-bit value with string-specific tags
// Reference: src/strm.h, src/string.c
//
// String types:
// - STRING_I: short interned string (≤5 bytes inline, 1 byte for length)
// - STRING_6: exact 6 bytes inline
// - STRING_O: owned string (heap allocated, needs free)
// - STRING_F: foreign/static string (no ownership)

// Strm_String is a NaN-boxed value type that can hold different string representations
Strm_String :: distinct Strm_Value

// String struct for heap-allocated strings (STRING_O and STRING_F)
Strm_String_Struct :: struct {
	ptr: cstring,
	len: i32,
}

// Null string value
STRM_STR_NULL :: Strm_String(0)

// ============================================================================
// String interning table
// ============================================================================

// Intern table entry
@(private)
Intern_Entry :: struct {
	str:  Strm_String,  // The interned string value
	hash: u64,          // Cached hash for quick comparison
}

// Global intern table for long strings (>6 bytes)
// Uses FNV-1a hash for string hashing
@(private)
intern_table: map[u64]Intern_Entry

// Mutex for thread-safe access to intern table
@(private)
intern_mutex: sync.Mutex

// Initialize intern table
strm_intern_init :: proc() {
	sync.mutex_lock(&intern_mutex)
	defer sync.mutex_unlock(&intern_mutex)

	if intern_table == nil {
		intern_table = make(map[u64]Intern_Entry)
	}
}

// Cleanup intern table
strm_intern_cleanup :: proc() {
	sync.mutex_lock(&intern_mutex)
	defer sync.mutex_unlock(&intern_mutex)

	// Free all interned strings
	for _, entry in intern_table {
		strm_str_free(entry.str)
	}
	delete(intern_table)
	intern_table = nil
}

// Get hash for a string using FNV-1a
@(private)
str_hash :: proc(s: string) -> u64 {
	return hash.fnv64a(transmute([]u8)s)
}

// ============================================================================
// String creation
// ============================================================================

// Create owned string (heap allocated, streem takes ownership)
strm_str_new :: proc(s: string, allocator := context.allocator) -> Strm_String {
	return str_new_internal(s, false, allocator)
}

// Create owned string from raw pointer and length
strm_str_new_raw :: proc(ptr: [^]u8, len: i32, allocator := context.allocator) -> Strm_String {
	if ptr == nil {
		return str_new_internal("", false, allocator)
	}
	s := string(ptr[:len])
	return str_new_internal(s, false, allocator)
}

// Create static string reference (no ownership, caller must ensure string lives long enough)
strm_str_static :: proc(s: string) -> Strm_String {
	return str_new_internal(s, true, context.allocator)
}

// Internal string creation
@(private)
str_new_internal :: proc(s: string, is_static: bool, allocator := context.allocator) -> Strm_String {
	slen := i32(len(s))

	if slen < 6 {
		// STRING_I: short string with length byte + up to 5 chars inline
		val: u64 = 0
		val_bytes := transmute([8]u8)val

		// Store length in first byte (after tag)
		val_bytes[0] = u8(slen)
		// Copy string data
		for i in 0 ..< slen {
			val_bytes[1 + i] = s[i]
		}
		val = transmute(u64)val_bytes
		return Strm_String((u64(Value_Tag.String_I) << 48) | (val & STRM_VAL_MASK))
	} else if slen == 6 {
		// STRING_6: exactly 6 bytes inline
		val: u64 = 0
		val_bytes := transmute([8]u8)val
		for i in 0 ..< 6 {
			val_bytes[i] = s[i]
		}
		val = transmute(u64)val_bytes
		return Strm_String((u64(Value_Tag.String_6) << 48) | (val & STRM_VAL_MASK))
	} else {
		// Heap allocated string
		context.allocator = allocator
		str_struct := new(Strm_String_Struct)

		if is_static {
			// STRING_F: foreign/static - just store pointer
			str_struct.ptr = strings.clone_to_cstring(s)
			str_struct.len = slen
			ptr_val := u64(uintptr(str_struct)) & STRM_VAL_MASK
			return Strm_String((u64(Value_Tag.String_F) << 48) | ptr_val)
		} else {
			// STRING_O: owned - allocate buffer for null-terminated string
			buf := make([]u8, slen + 1)
			copy(buf[:slen], s)
			buf[slen] = 0
			str_struct.ptr = cstring(raw_data(buf))
			str_struct.len = slen
			ptr_val := u64(uintptr(str_struct)) & STRM_VAL_MASK
			return Strm_String((u64(Value_Tag.String_O) << 48) | ptr_val)
		}
	}
}

// Create/get interned string
// For short strings (≤6 bytes), always inline (no allocation needed)
// For longer strings, use hash table for deduplication
strm_str_intern :: proc(s: string, allocator := context.allocator) -> Strm_String {
	// Short strings are always inlined - no need for intern table
	if len(s) <= 6 {
		return str_new_internal(s, false, allocator)
	}

	// For longer strings, use intern table
	h := str_hash(s)

	sync.mutex_lock(&intern_mutex)
	defer sync.mutex_unlock(&intern_mutex)

	// Initialize table if needed
	if intern_table == nil {
		intern_table = make(map[u64]Intern_Entry)
	}

	// Check if already interned
	if entry, ok := intern_table[h]; ok {
		// Verify it's the same string (hash collision check)
		entry_copy := entry.str
		if strm_str_ptr(&entry_copy) == s {
			return entry.str
		}
		// Hash collision - need to handle (for now, just create new)
		// In practice, FNV-1a collisions are rare for short strings
	}

	// Create new interned string (as static/foreign - won't be freed individually)
	new_str := str_new_internal(s, true, allocator)
	intern_table[h] = Intern_Entry{str = new_str, hash = h}

	return new_str
}

// Check if string is interned (short or foreign)
strm_str_intern_p :: proc(str: Strm_String) -> bool {
	tag := strm_value_tag(Strm_Value(str))
	#partial switch tag {
	case .String_I, .String_6, .String_F:
		return true
	case .String_O:
		return false
	case:
		return false
	}
}

// ============================================================================
// String extraction
// ============================================================================

// Get string length
strm_str_len :: proc(str: Strm_String) -> i32 {
	tag := strm_value_tag(Strm_Value(str))
	#partial switch tag {
	case .String_I:
		// Length stored in first byte of payload
		val_bytes := transmute([8]u8)u64(str)
		return i32(val_bytes[0])
	case .String_6:
		return 6
	case .String_O, .String_F:
		ptr := strm_value_rawptr(Strm_Value(str))
		str_struct := cast(^Strm_String_Struct)ptr
		return str_struct.len
	case:
		return 0
	}
}

// Get string as Odin string (for inline strings, returns a view into the value)
// WARNING: For inline strings, the returned slice is only valid while str is alive
strm_str_ptr :: proc(str: ^Strm_String) -> string {
	tag := strm_value_tag(Strm_Value(str^))
	#partial switch tag {
	case .String_I:
		// Get pointer to data in the value itself
		val_bytes := cast([^]u8)str
		length := val_bytes[0]
		return string(val_bytes[1:][:length])
	case .String_6:
		val_bytes := cast([^]u8)str
		return string(val_bytes[:6])
	case .String_O, .String_F:
		ptr := strm_value_rawptr(Strm_Value(str^))
		str_struct := cast(^Strm_String_Struct)ptr
		return string(str_struct.ptr)[:str_struct.len]
	case:
		return ""
	}
}

// Get null-terminated C string
// For inline strings, copies to provided buffer
// For heap strings, returns pointer directly
strm_str_cstr :: proc(str: Strm_String, buf: []u8 = nil) -> cstring {
	tag := strm_value_tag(Strm_Value(str))
	#partial switch tag {
	case .String_I:
		if buf == nil || len(buf) < 7 {
			return nil
		}
		val_bytes := transmute([8]u8)u64(str)
		length := int(val_bytes[0])
		for i in 0 ..< length {
			buf[i] = val_bytes[1 + i]
		}
		buf[length] = 0
		return cstring(raw_data(buf))
	case .String_6:
		if buf == nil || len(buf) < 7 {
			return nil
		}
		val_bytes := transmute([8]u8)u64(str)
		for i in 0 ..< 6 {
			buf[i] = val_bytes[i]
		}
		buf[6] = 0
		return cstring(raw_data(buf))
	case .String_O, .String_F:
		ptr := strm_value_rawptr(Strm_Value(str))
		str_struct := cast(^Strm_String_Struct)ptr
		return str_struct.ptr
	case:
		return nil
	}
}

// ============================================================================
// String comparison
// ============================================================================

// Compare two strings for equality
strm_str_eq :: proc(a: Strm_String, b: Strm_String) -> bool {
	// Fast path: identical bit patterns
	if u64(a) == u64(b) {
		return true
	}

	// Check if both are foreign (interned) - pointer comparison is sufficient
	tag_a := strm_value_tag(Strm_Value(a))
	tag_b := strm_value_tag(Strm_Value(b))
	if tag_a == .String_F && tag_b == .String_F {
		// If both are foreign/interned and bits differ, they're different strings
		return false
	}

	// Compare lengths
	len_a := strm_str_len(a)
	len_b := strm_str_len(b)
	if len_a != len_b {
		return false
	}

	// Compare contents
	a_copy := a
	b_copy := b
	str_a := strm_str_ptr(&a_copy)
	str_b := strm_str_ptr(&b_copy)
	return str_a == str_b
}

// ============================================================================
// String utilities
// ============================================================================

// Convert Strm_String to Odin string (allocates new string)
strm_str_to_string :: proc(str: Strm_String, allocator := context.allocator) -> string {
	str_copy := str
	s := strm_str_ptr(&str_copy)
	return strings.clone(s, allocator)
}

// Convert Strm_String to Strm_Value
strm_str_value :: proc(str: Strm_String) -> Strm_Value {
	return Strm_Value(str)
}

// Convert Strm_Value to Strm_String (assumes value is a string)
strm_value_str :: proc(v: Strm_Value) -> Strm_String {
	return Strm_String(v)
}

// Free string resources (only for owned strings)
strm_str_free :: proc(str: Strm_String, allocator := context.allocator) {
	tag := strm_value_tag(Strm_Value(str))
	if tag == .String_O {
		context.allocator = allocator
		ptr := strm_value_rawptr(Strm_Value(str))
		str_struct := cast(^Strm_String_Struct)ptr
		// Free the string buffer
		if str_struct.ptr != nil {
			free(rawptr(str_struct.ptr))
		}
		// Free the struct
		free(str_struct)
	} else if tag == .String_F {
		context.allocator = allocator
		ptr := strm_value_rawptr(Strm_Value(str))
		str_struct := cast(^Strm_String_Struct)ptr
		// Free the cstring copy
		if str_struct.ptr != nil {
			free(rawptr(str_struct.ptr))
		}
		free(str_struct)
	}
}
