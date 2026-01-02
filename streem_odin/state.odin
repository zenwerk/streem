package streem

// Namespace and scope management
// Reference: src/strm.h, src/ns.c

// State flags
State_Flags :: bit_set[State_Flag]

State_Flag :: enum {
	Udef, // user-defined namespace that can create instances
}

// State structure represents a scope/namespace
// - env: hash table for variable bindings
// - prev: parent scope (lexical scoping)
// - flags: namespace properties
Strm_State :: struct {
	env:   map[Strm_String]Strm_Value, // variable bindings (using interned strings as keys)
	prev:  ^Strm_State,                // parent scope
	name:  Strm_String,                // namespace name (STRM_STR_NULL for anonymous)
	flags: State_Flags,
}

// ============================================================================
// State creation and destruction
// ============================================================================

// Create a new state with optional parent
strm_state_new :: proc(prev: ^Strm_State = nil) -> ^Strm_State {
	s := new(Strm_State)
	s.env = make(map[Strm_String]Strm_Value)
	s.prev = prev
	s.name = STRM_STR_NULL
	s.flags = {}
	return s
}

// Create a named namespace
strm_ns_new :: proc(prev: ^Strm_State, name: string) -> ^Strm_State {
	s := strm_state_new(prev)
	s.name = strm_str_intern(name)
	s.flags = {.Udef}
	return s
}

// Destroy a state
strm_state_destroy :: proc(s: ^Strm_State) {
	if s == nil {
		return
	}
	delete(s.env)
	free(s)
}

// ============================================================================
// Variable operations (with string key)
// ============================================================================

// Define a new variable in current scope (string key version)
// Returns false if variable already exists
strm_var_def_str :: proc(state: ^Strm_State, name: string, value: Strm_Value) -> bool {
	if state == nil {
		return false
	}
	key := strm_str_intern(name)
	if key in state.env {
		return false // already defined
	}
	state.env[key] = value
	return true
}

// Define a new variable in current scope (Strm_String key version)
// Returns false if variable already exists
strm_var_def_sym :: proc(state: ^Strm_State, name: Strm_String, value: Strm_Value) -> bool {
	if state == nil {
		return false
	}
	if name in state.env {
		return false // already defined
	}
	state.env[name] = value
	return true
}

// Overloaded var_def
strm_var_def :: proc {
	strm_var_def_str,
	strm_var_def_sym,
}

// Set variable (create if not exists in current scope) - string key version
strm_var_set_str :: proc(state: ^Strm_State, name: string, value: Strm_Value) -> int {
	if state == nil {
		return STRM_NG
	}
	key := strm_str_intern(name)
	return strm_var_set_sym(state, key, value)
}

// Set variable (create if not exists in current scope) - Strm_String key version
strm_var_set_sym :: proc(state: ^Strm_State, name: Strm_String, value: Strm_Value) -> int {
	if state == nil {
		return STRM_NG
	}
	// First, try to find in current and parent scopes
	s := state
	for s != nil {
		if name in s.env {
			s.env[name] = value
			return STRM_OK
		}
		s = s.prev
	}
	// Not found, create in current scope
	state.env[name] = value
	return STRM_OK
}

// Overloaded var_set
strm_var_set :: proc {
	strm_var_set_str,
	strm_var_set_sym,
}

// Get variable value (searches parent scopes) - string key version
// Returns (value, found)
strm_var_get_str :: proc(state: ^Strm_State, name: string) -> (Strm_Value, bool) {
	key := strm_str_intern(name)
	return strm_var_get_sym(state, key)
}

// Get variable value (searches parent scopes) - Strm_String key version
// Returns (value, found)
strm_var_get_sym :: proc(state: ^Strm_State, name: Strm_String) -> (Strm_Value, bool) {
	s := state
	for s != nil {
		if val, ok := s.env[name]; ok {
			return val, true
		}
		s = s.prev
	}
	return strm_nil_value(), false
}

// C-compatible version that returns status code
strm_var_get_val :: proc(state: ^Strm_State, name: Strm_String, val: ^Strm_Value) -> int {
	v, found := strm_var_get_sym(state, name)
	if !found {
		return STRM_NG
	}
	if val != nil {
		val^ = v
	}
	return STRM_OK
}

// Overloaded var_get
strm_var_get :: proc {
	strm_var_get_str,
	strm_var_get_sym,
}

// Pattern match assignment
// This is used for destructuring patterns like `[a, b] = [1, 2]`
// If the variable is already bound, compare with the new value
// Returns STRM_OK on success, STRM_NG on failure
strm_var_match :: proc(state: ^Strm_State, name: Strm_String, value: Strm_Value) -> int {
	if state == nil {
		return STRM_NG
	}
	// Check if variable is already bound in this scope
	if existing, ok := state.env[name]; ok {
		// Variable already bound - compare values
		if strm_value_eq(existing, value) {
			return STRM_OK
		}
		return STRM_NG
	}
	// Not bound yet - set the variable
	state.env[name] = value
	return STRM_OK
}

// Copy environment from source to destination (for import)
// Returns STRM_OK on success, STRM_NG on failure
strm_env_copy :: proc(dst: ^Strm_State, src: ^Strm_State) -> int {
	if dst == nil || src == nil {
		return STRM_NG
	}
	for name, value in src.env {
		dst.env[name] = value
	}
	return STRM_OK
}

// ============================================================================
// Namespace operations
// ============================================================================

// Global namespace registry
@(private = "file")
namespace_registry: map[Strm_String]^Strm_State

@(private = "file")
namespace_registry_initialized := false

// Ensure registry is initialized
@(private)
ensure_registry_init :: proc() {
	if !namespace_registry_initialized {
		namespace_registry = make(map[Strm_String]^Strm_State)
		namespace_registry_initialized = true
	}
}

// Create and register a namespace
// Returns the namespace, or nil if it already exists
strm_ns_create :: proc(parent: ^Strm_State, name: Strm_String) -> ^Strm_State {
	ensure_registry_init()

	// Check if namespace already exists
	existing := strm_ns_get(name)
	if existing != nil {
		return nil // already exists
	}

	// Create new namespace
	ns := strm_state_new(parent)
	ns.name = name
	ns.flags = {.Udef}

	// Register it
	namespace_registry[name] = ns
	return ns
}

// Create namespace with string name
strm_ns_create_str :: proc(parent: ^Strm_State, name: string) -> ^Strm_State {
	return strm_ns_create(parent, strm_str_intern(name))
}

// Look up namespace by name (Strm_String version)
strm_ns_get :: proc(name: Strm_String) -> ^Strm_State {
	ensure_registry_init()
	if ns, ok := namespace_registry[name]; ok {
		return ns
	}
	return nil
}

// Look up namespace by string name
strm_ns_get_str :: proc(name: string) -> ^Strm_State {
	return strm_ns_get(strm_str_intern(name))
}

// Get namespace name from state
// Returns STRM_STR_NULL if not found
strm_ns_name :: proc(state: ^Strm_State) -> Strm_String {
	ensure_registry_init()
	if state == nil {
		return STRM_STR_NULL
	}
	// First check if state has a name
	if u64(state.name) != 0 {
		return state.name
	}
	// Otherwise search registry
	for name, ns in namespace_registry {
		if ns == state {
			return name
		}
	}
	return STRM_STR_NULL
}

// Get the namespace of a value
// Returns namespace for arrays with ns set, or type namespaces for primitives
strm_value_ns :: proc(v: Strm_Value) -> ^Strm_State {
	tag := strm_value_tag(v)

	// Check for array/struct with namespace
	if tag == .Array || tag == .Struct {
		ary := Strm_Array(v)
		ns := strm_ary_ns(ary)
		if ns != nil {
			return ns
		}
		// Return array namespace for plain arrays
		return strm_ns_array
	}

	// Check for string
	if strm_string_p(v) {
		return strm_ns_string
	}

	// Check for number
	if strm_number_p(v) {
		return strm_ns_number
	}

	return nil
}

// ============================================================================
// Global namespaces (built-in type namespaces)
// ============================================================================

// Built-in type namespaces
strm_ns_array: ^Strm_State = nil
strm_ns_string: ^Strm_State = nil
strm_ns_number: ^Strm_State = nil

// Initialize built-in namespaces
strm_ns_init :: proc() {
	// Initialize string intern table first
	strm_intern_init()

	ensure_registry_init()

	// Create Array namespace (or get existing)
	array_name := strm_str_intern("Array")
	strm_ns_array = strm_ns_get(array_name)
	if strm_ns_array == nil {
		strm_ns_array = strm_ns_create(nil, array_name)
	}
	if strm_ns_array != nil {
		// Clear Udef flag - primitive namespaces cannot create instances directly
		strm_ns_array.flags = {}
	}

	// Create String namespace (or get existing)
	string_name := strm_str_intern("String")
	strm_ns_string = strm_ns_get(string_name)
	if strm_ns_string == nil {
		strm_ns_string = strm_ns_create(nil, string_name)
	}
	if strm_ns_string != nil {
		strm_ns_string.flags = {}
	}

	// Create Number namespace (or get existing)
	number_name := strm_str_intern("Number")
	strm_ns_number = strm_ns_get(number_name)
	if strm_ns_number == nil {
		strm_ns_number = strm_ns_create(nil, number_name)
	}
	if strm_ns_number != nil {
		strm_ns_number.flags = {}
	}
}

// Cleanup namespace registry
strm_ns_cleanup :: proc() {
	if !namespace_registry_initialized {
		return
	}
	for _, ns in namespace_registry {
		strm_state_destroy(ns)
	}
	delete(namespace_registry)
	namespace_registry_initialized = false

	// Clear global pointers
	strm_ns_array = nil
	strm_ns_string = nil
	strm_ns_number = nil

	// Cleanup string intern table
	strm_intern_cleanup()
}

// ============================================================================
// Utility constants
// ============================================================================

STRM_OK :: 0
STRM_NG :: 1
