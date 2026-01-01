package streem

// Built-in functions initialization
// Reference: src/init.c, src/exec.c

// Initialize all built-in functions and namespaces
// Reference: src/init.c strm_init
strm_init :: proc(state: ^Strm_State) {
	// Initialize type namespaces (defined in state.odin)
	strm_ns_init()

	// Number operations (arithmetic, comparison, logical, bitwise)
	strm_number_init(state)

	// Iterator/Stream functions (seq, map, filter, reduce, etc.)
	strm_iter_init(state)

	// Core functions (stdin, stdout, puts, ==, !=, |, fread, fwrite, exit, match)
	strm_misc_init(state)

	// Array functions are registered in strm_iter_init via strm_ns_array
	// String functions would be added here when implemented
}
