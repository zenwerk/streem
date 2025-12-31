package streem

import "core:testing"

// ============================================================================
// State Tests
// ============================================================================

@(test)
test_state_var_def :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	// Test with string key
	ok := strm_var_def(state, "x", strm_int_value(42))
	testing.expect(t, ok, "Expected var_def to succeed")

	ok = strm_var_def(state, "x", strm_int_value(43))
	testing.expect(t, !ok, "Expected second var_def to fail")

	// Test with Strm_String key
	key := strm_str_intern("y")
	ok = strm_var_def(state, key, strm_int_value(100))
	testing.expect(t, ok, "Expected var_def with Strm_String key to succeed")

	ok = strm_var_def(state, key, strm_int_value(101))
	testing.expect(t, !ok, "Expected second var_def with Strm_String key to fail")
}

@(test)
test_state_var_get :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	strm_var_def(state, "x", strm_int_value(42))

	// Test with string key
	val, found := strm_var_get(state, "x")
	testing.expect(t, found, "Expected var to be found")
	testing.expect_value(t, strm_value_int(val), 42)

	_, found = strm_var_get(state, "y")
	testing.expect(t, !found, "Expected var to not be found")

	// Test with Strm_String key
	key := strm_str_intern("x")
	val, found = strm_var_get(state, key)
	testing.expect(t, found, "Expected var to be found with Strm_String key")
	testing.expect_value(t, strm_value_int(val), 42)
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

@(test)
test_state_var_set :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	// Test var_set creates new variable
	result := strm_var_set(state, "x", strm_int_value(42))
	testing.expect_value(t, result, STRM_OK)

	val, found := strm_var_get(state, "x")
	testing.expect(t, found, "Expected var to be found after set")
	testing.expect_value(t, strm_value_int(val), 42)

	// Test var_set updates existing variable
	result = strm_var_set(state, "x", strm_int_value(100))
	testing.expect_value(t, result, STRM_OK)

	val, _ = strm_var_get(state, "x")
	testing.expect_value(t, strm_value_int(val), 100)
}

@(test)
test_state_var_set_scoping :: proc(t: ^testing.T) {
	outer := strm_state_new()
	defer strm_state_destroy(outer)

	strm_var_def(outer, "x", strm_int_value(1))

	inner := strm_state_new(outer)
	defer strm_state_destroy(inner)

	// Setting x in inner should update outer's x
	strm_var_set(inner, "x", strm_int_value(999))

	// Check outer's x was updated
	val, found := strm_var_get(outer, "x")
	testing.expect(t, found, "Expected var to exist in outer")
	testing.expect_value(t, strm_value_int(val), 999)
}

@(test)
test_state_var_match :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	key := strm_str_intern("a")
	result := strm_var_match(state, key, strm_int_value(42))
	testing.expect_value(t, result, STRM_OK)

	val, found := strm_var_get(state, key)
	testing.expect(t, found, "Expected var to be found after match")
	testing.expect_value(t, strm_value_int(val), 42)
}

@(test)
test_state_env_copy :: proc(t: ^testing.T) {
	src := strm_state_new()
	defer strm_state_destroy(src)

	dst := strm_state_new()
	defer strm_state_destroy(dst)

	strm_var_def(src, "a", strm_int_value(1))
	strm_var_def(src, "b", strm_int_value(2))

	result := strm_env_copy(dst, src)
	testing.expect_value(t, result, STRM_OK)

	// Check copied variables
	val, found := strm_var_get(dst, "a")
	testing.expect(t, found, "Expected 'a' to be copied")
	testing.expect_value(t, strm_value_int(val), 1)

	val, found = strm_var_get(dst, "b")
	testing.expect(t, found, "Expected 'b' to be copied")
	testing.expect_value(t, strm_value_int(val), 2)
}

// ============================================================================
// Namespace Tests
// ============================================================================

@(test)
test_ns_create_and_get :: proc(t: ^testing.T) {
	defer strm_ns_cleanup()

	// Create a namespace (use short name ≤6 bytes for inline string interning to work)
	ns := strm_ns_create_str(nil, "NS1")
	testing.expect(t, ns != nil, "Expected namespace to be created")

	// Get it back
	found := strm_ns_get_str("NS1")
	testing.expect(t, found == ns, "Expected to find the same namespace")

	// Creating duplicate should return nil
	ns2 := strm_ns_create_str(nil, "NS1")
	testing.expect(t, ns2 == nil, "Expected duplicate creation to return nil")
}

@(test)
test_ns_name :: proc(t: ^testing.T) {
	defer strm_ns_cleanup()

	ns := strm_ns_create_str(nil, "MyNamespace")
	testing.expect(t, ns != nil, "Expected namespace to be created")

	name := strm_ns_name(ns)
	testing.expect(t, u64(name) != 0, "Expected name to be non-null")

	name_copy := name
	name_str := strm_str_ptr(&name_copy)
	testing.expect_value(t, name_str, "MyNamespace")
}

@(test)
test_ns_init :: proc(t: ^testing.T) {
	defer strm_ns_cleanup()

	strm_ns_init()

	// Check built-in namespaces were created
	testing.expect(t, strm_ns_array != nil, "Expected Array namespace to exist")
	testing.expect(t, strm_ns_string != nil, "Expected String namespace to exist")
	testing.expect(t, strm_ns_number != nil, "Expected Number namespace to exist")

	// Check they are registered
	ary_ns := strm_ns_get_str("Array")
	testing.expect(t, ary_ns == strm_ns_array, "Expected Array namespace to be registered")

	str_ns := strm_ns_get_str("String")
	testing.expect(t, str_ns == strm_ns_string, "Expected String namespace to be registered")

	num_ns := strm_ns_get_str("Number")
	testing.expect(t, num_ns == strm_ns_number, "Expected Number namespace to be registered")

	// Check flags - primitive namespaces should not have Udef
	testing.expect(t, .Udef not_in strm_ns_array.flags, "Array should not have Udef flag")
	testing.expect(t, .Udef not_in strm_ns_string.flags, "String should not have Udef flag")
	testing.expect(t, .Udef not_in strm_ns_number.flags, "Number should not have Udef flag")
}

@(test)
test_value_ns :: proc(t: ^testing.T) {
	defer strm_ns_cleanup()

	strm_ns_init()

	// Test number namespace
	num_val := strm_int_value(42)
	ns := strm_value_ns(num_val)
	testing.expect(t, ns == strm_ns_number, "Expected number to have Number namespace")

	// Test float namespace
	float_val := strm_float_value(3.14)
	ns = strm_value_ns(float_val)
	testing.expect(t, ns == strm_ns_number, "Expected float to have Number namespace")

	// Test string namespace
	str_val := strm_str_value(strm_str_new("hello"))
	ns = strm_value_ns(str_val)
	testing.expect(t, ns == strm_ns_string, "Expected string to have String namespace")

	// Test array namespace
	ary := strm_ary_new([]Strm_Value{strm_int_value(1), strm_int_value(2)})
	ary_val := strm_ary_value(ary)
	ns = strm_value_ns(ary_val)
	testing.expect(t, ns == strm_ns_array, "Expected array to have Array namespace")

	// Test array with custom namespace
	custom_ns := strm_ns_create_str(nil, "CustomType")
	testing.expect(t, custom_ns != nil, "Expected custom namespace to be created")

	ary2 := strm_ary_new([]Strm_Value{strm_int_value(1)})
	strm_ary_set_ns(ary2, custom_ns)
	ary2_val := strm_ary_value(ary2)
	ns = strm_value_ns(ary2_val)
	testing.expect(t, ns == custom_ns, "Expected array with custom ns to return that ns")
}

@(test)
test_ns_parent_scope :: proc(t: ^testing.T) {
	defer strm_ns_cleanup()

	// Create parent state with some variables
	parent := strm_state_new()
	defer strm_state_destroy(parent)
	strm_var_def(parent, "shared", strm_int_value(100))

	// Create child namespace
	child := strm_ns_create_str(parent, "ChildNS")
	// Note: don't destroy child - it's managed by registry

	// Child should be able to see parent's variables
	val, found := strm_var_get(child, "shared")
	testing.expect(t, found, "Expected child to see parent's variable")
	testing.expect_value(t, strm_value_int(val), 100)
}

@(test)
test_ns_udef_flag :: proc(t: ^testing.T) {
	defer strm_ns_cleanup()

	// User-defined namespace should have Udef flag
	user_ns := strm_ns_create_str(nil, "UserDefined")
	testing.expect(t, user_ns != nil, "Expected namespace to be created")
	testing.expect(t, .Udef in user_ns.flags, "User namespace should have Udef flag")
}
