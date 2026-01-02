package streem

import "core:testing"

// ============================================================================
// String Tests
// ============================================================================

@(test)
test_str_short :: proc(t: ^testing.T) {
	// Test short string (≤5 bytes, uses STRING_I)
	s := strm_str_new("hello")
	defer strm_str_free(s)

	testing.expect(t, strm_value_tag(Strm_Value(s)) == .String_I, "Expected String_I tag for short string")
	testing.expect_value(t, strm_str_len(s), 5)

	s_copy := s
	ptr := strm_str_ptr(&s_copy)
	testing.expect(t, ptr == "hello", "Expected string content to match")
}

@(test)
test_str_6 :: proc(t: ^testing.T) {
	// Test exact 6 byte string (uses STRING_6)
	s := strm_str_new("abcdef")
	defer strm_str_free(s)

	testing.expect(t, strm_value_tag(Strm_Value(s)) == .String_6, "Expected String_6 tag for 6-byte string")
	testing.expect_value(t, strm_str_len(s), 6)

	s_copy := s
	ptr := strm_str_ptr(&s_copy)
	testing.expect(t, ptr == "abcdef", "Expected string content to match")
}

@(test)
test_str_owned :: proc(t: ^testing.T) {
	// Test owned string (>6 bytes, uses STRING_O)
	s := strm_str_new("hello world!")
	defer strm_str_free(s)

	testing.expect(t, strm_value_tag(Strm_Value(s)) == .String_O, "Expected String_O tag for owned string")
	testing.expect_value(t, strm_str_len(s), 12)

	s_copy := s
	ptr := strm_str_ptr(&s_copy)
	testing.expect(t, ptr == "hello world!", "Expected string content to match")
}

@(test)
test_str_empty :: proc(t: ^testing.T) {
	// Test empty string
	s := strm_str_new("")
	defer strm_str_free(s)

	testing.expect(t, strm_value_tag(Strm_Value(s)) == .String_I, "Expected String_I tag for empty string")
	testing.expect_value(t, strm_str_len(s), 0)

	s_copy := s
	ptr := strm_str_ptr(&s_copy)
	testing.expect(t, ptr == "", "Expected empty string content")
}

@(test)
test_str_eq :: proc(t: ^testing.T) {
	// Test string equality
	s1 := strm_str_new("hello")
	s2 := strm_str_new("hello")
	s3 := strm_str_new("world")
	s4 := strm_str_new("hello world!")
	s5 := strm_str_new("hello world!")

	defer strm_str_free(s1)
	defer strm_str_free(s2)
	defer strm_str_free(s3)
	defer strm_str_free(s4)
	defer strm_str_free(s5)

	// Same content should be equal
	testing.expect(t, strm_str_eq(s1, s2), "Expected equal strings to be equal")
	// Different content should not be equal
	testing.expect(t, !strm_str_eq(s1, s3), "Expected different strings to not be equal")
	// Same string should be equal to itself
	testing.expect(t, strm_str_eq(s1, s1), "Expected string to equal itself")
	// Owned strings with same content should be equal
	testing.expect(t, strm_str_eq(s4, s5), "Expected equal owned strings to be equal")
}

@(test)
test_str_cstr :: proc(t: ^testing.T) {
	// Test C string conversion
	buf: [16]u8

	// Short string
	s1 := strm_str_new("hi")
	defer strm_str_free(s1)
	c1 := strm_str_cstr(s1, buf[:])
	testing.expect(t, c1 != nil, "Expected cstr to not be nil")

	// 6-byte string
	s2 := strm_str_new("abcdef")
	defer strm_str_free(s2)
	c2 := strm_str_cstr(s2, buf[:])
	testing.expect(t, c2 != nil, "Expected cstr to not be nil")

	// Owned string (returns direct pointer)
	s3 := strm_str_new("hello world")
	defer strm_str_free(s3)
	c3 := strm_str_cstr(s3, nil)
	testing.expect(t, c3 != nil, "Expected cstr to not be nil for owned string")
}

@(test)
test_str_static :: proc(t: ^testing.T) {
	// Test static string
	s := strm_str_static("static string")
	defer strm_str_free(s)

	testing.expect(t, strm_value_tag(Strm_Value(s)) == .String_F, "Expected String_F tag for static string")
	testing.expect_value(t, strm_str_len(s), 13)
}

@(test)
test_str_intern_p :: proc(t: ^testing.T) {
	// Test intern predicate
	s1 := strm_str_new("hi")
	s2 := strm_str_new("abcdef")
	s3 := strm_str_new("hello world")
	s4 := strm_str_static("static")

	defer strm_str_free(s1)
	defer strm_str_free(s2)
	defer strm_str_free(s3)
	defer strm_str_free(s4)

	testing.expect(t, strm_str_intern_p(s1), "Expected short string to be internable")
	testing.expect(t, strm_str_intern_p(s2), "Expected 6-byte string to be internable")
	testing.expect(t, !strm_str_intern_p(s3), "Expected owned string to not be internable")
	testing.expect(t, strm_str_intern_p(s4), "Expected static string to be internable")
}

@(test)
test_str_to_value :: proc(t: ^testing.T) {
	// Test conversion between Strm_String and Strm_Value
	s := strm_str_new("test")
	defer strm_str_free(s)

	v := strm_str_value(s)
	testing.expect(t, strm_string_p(v), "Expected value to be string type")

	s2 := strm_value_str(v)
	testing.expect(t, strm_str_eq(s, s2), "Expected roundtrip to preserve string")
}

@(test)
test_str_value_eq :: proc(t: ^testing.T) {
	// Test strm_value_eq for strings
	s1 := strm_str_new("hello")
	s2 := strm_str_new("hello")
	s3 := strm_str_new("world")

	defer strm_str_free(s1)
	defer strm_str_free(s2)
	defer strm_str_free(s3)

	v1 := strm_str_value(s1)
	v2 := strm_str_value(s2)
	v3 := strm_str_value(s3)

	testing.expect(t, strm_value_eq(v1, v2), "Expected equal string values to be equal")
	testing.expect(t, !strm_value_eq(v1, v3), "Expected different string values to not be equal")
}

@(test)
test_str_intern_dedup :: proc(t: ^testing.T) {
	// Initialize intern table
	strm_intern_init()
	defer strm_intern_cleanup()

	// Test short string interning (<=6 bytes) - always inlined, same bit pattern
	s1 := strm_str_intern("short")
	s2 := strm_str_intern("short")
	testing.expect(t, u64(s1) == u64(s2), "Expected short interned strings to have same bits")

	// Test 6-byte string interning - same bit pattern
	s3 := strm_str_intern("sixchr")
	s4 := strm_str_intern("sixchr")
	testing.expect(t, u64(s3) == u64(s4), "Expected 6-byte interned strings to have same bits")

	// Test long string interning (>6 bytes) - should deduplicate via hash table
	long_str := "this_is_a_long_string_for_interning"
	s5 := strm_str_intern(long_str)
	s6 := strm_str_intern(long_str)
	testing.expect(t, u64(s5) == u64(s6), "Expected long interned strings to be deduplicated")

	// Different long strings should have different values
	s7 := strm_str_intern("another_long_string_different")
	testing.expect(t, u64(s5) != u64(s7), "Expected different long strings to be different")

	// Verify content is correct
	s5_copy := s5
	testing.expect(t, strm_str_ptr(&s5_copy) == long_str, "Expected interned string content to match")
}
