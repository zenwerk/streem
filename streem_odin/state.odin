package streem

// Namespace and scope management
// Reference: src/strm.h, src/ns.c

// State flags
State_Flags :: bit_set[State_Flag]

State_Flag :: enum {
	Udef, // user-defined namespace
}

// State structure represents a scope/namespace
// - env: hash table for variable bindings
// - prev: parent scope (lexical scoping)
// - flags: namespace properties
Strm_State :: struct {
	env:   map[string]Strm_Value, // variable bindings
	prev:  ^Strm_State,           // parent scope
	name:  string,                // namespace name (empty for anonymous)
	flags: State_Flags,
}

// ============================================================================
// State creation and destruction
// ============================================================================

// Create a new state with optional parent
strm_state_new :: proc(prev: ^Strm_State = nil) -> ^Strm_State {
	s := new(Strm_State)
	s.env = make(map[string]Strm_Value)
	s.prev = prev
	s.name = ""
	s.flags = {}
	return s
}

// Create a named namespace
strm_ns_new :: proc(prev: ^Strm_State, name: string) -> ^Strm_State {
	s := strm_state_new(prev)
	s.name = name
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
// Variable operations
// ============================================================================

// Define a new variable in current scope
// Returns false if variable already exists
strm_var_def :: proc(state: ^Strm_State, name: string, value: Strm_Value) -> bool {
	if state == nil {
		return false
	}
	if name in state.env {
		return false // already defined
	}
	state.env[name] = value
	return true
}

// Set variable (create if not exists in current scope)
strm_var_set :: proc(state: ^Strm_State, name: string, value: Strm_Value) {
	if state == nil {
		return
	}
	// First, try to find in current and parent scopes
	s := state
	for s != nil {
		if name in s.env {
			s.env[name] = value
			return
		}
		s = s.prev
	}
	// Not found, create in current scope
	state.env[name] = value
}

// Get variable value (searches parent scopes)
// Returns (value, found)
strm_var_get :: proc(state: ^Strm_State, name: string) -> (Strm_Value, bool) {
	s := state
	for s != nil {
		if val, ok := s.env[name]; ok {
			return val, true
		}
		s = s.prev
	}
	return strm_nil_value(), false
}

// Pattern match assignment
// TODO: Implement pattern matching for destructuring
strm_var_match :: proc(state: ^Strm_State, name: string, value: Strm_Value) -> bool {
	// For simple assignment, same as var_def
	return strm_var_def(state, name, value)
}

// Copy environment from source to destination (for import)
strm_env_copy :: proc(dst: ^Strm_State, src: ^Strm_State) {
	if dst == nil || src == nil {
		return
	}
	for name, value in src.env {
		dst.env[name] = value
	}
}

// ============================================================================
// Namespace operations
// ============================================================================

// Global namespace registry
@(private = "file")
namespace_registry: map[string]^Strm_State

// Create and register a namespace
strm_ns_create :: proc(parent: ^Strm_State, name: string) -> ^Strm_State {
	ns := strm_ns_new(parent, name)
	namespace_registry[name] = ns
	return ns
}

// Look up namespace by name
strm_ns_get :: proc(name: string) -> ^Strm_State {
	if ns, ok := namespace_registry[name]; ok {
		return ns
	}
	return nil
}

// Get the namespace of a value
// TODO: Implement for typed values (arrays with ns, etc.)
strm_value_ns :: proc(v: Strm_Value) -> ^Strm_State {
	return nil
}

// ============================================================================
// Global namespaces (stubs for Phase 10)
// ============================================================================

// Built-in type namespaces
strm_ns_array: ^Strm_State = nil
strm_ns_string: ^Strm_State = nil
strm_ns_number: ^Strm_State = nil

// Initialize built-in namespaces
strm_ns_init :: proc() {
	strm_ns_array = strm_ns_create(nil, "Array")
	strm_ns_string = strm_ns_create(nil, "String")
	strm_ns_number = strm_ns_create(nil, "Number")
}

// Cleanup namespace registry
strm_ns_cleanup :: proc() {
	for _, ns in namespace_registry {
		strm_state_destroy(ns)
	}
	delete(namespace_registry)
}
