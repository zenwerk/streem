package streem

// Stream runtime
// Reference: src/core.c, src/strm.h

// Stream modes
Stream_Mode :: enum {
	Producer, // generates data (e.g., seq, file read)
	Filter,   // transforms data (e.g., map, filter)
	Consumer, // consumes data (e.g., file write, stdout)
	Dying,    // closing
	Killed,   // closed
}

// Stream flags
Stream_Flags :: bit_set[Stream_Flag]

Stream_Flag :: enum {
	Started,  // stream has been started
	Closed,   // stream is closed
	Excl,     // exclusion flag for thread safety
}

// Stream callback function types
Stream_Start_Func :: #type proc(strm: ^Strm_Stream, data: Strm_Value) -> int
Stream_Close_Func :: #type proc(strm: ^Strm_Stream, data: Strm_Value) -> int

// Stream structure
Strm_Stream :: struct {
	mode:       Stream_Mode,
	flags:      Stream_Flags,
	start_func: Stream_Start_Func,
	close_func: Stream_Close_Func,
	data:       rawptr,              // user data pointer
	dst:        ^Strm_Stream,        // primary downstream connection
	rest:       [dynamic]^Strm_Stream, // additional downstream connections
	queue:      ^Strm_Queue,         // per-stream task queue
	refcnt:     int,                 // reference count
	exc:        ^Node_Error,         // current exception
}

// Exception types
Exception_Type :: enum {
	None,
	Runtime,
	Return,
	Skip,
}

// Node error structure (for exceptions)
Node_Error :: struct {
	type:   Exception_Type,
	arg:    Strm_Value,
	fname:  string,
	lineno: int,
}

// ============================================================================
// Stream creation and destruction
// ============================================================================

// Create a new stream
strm_stream_new :: proc(mode: Stream_Mode, start_func: Stream_Start_Func, close_func: Stream_Close_Func, data: rawptr) -> ^Strm_Stream {
	strm := new(Strm_Stream)
	strm.mode = mode
	strm.flags = {}
	strm.start_func = start_func
	strm.close_func = close_func
	strm.data = data
	strm.dst = nil
	strm.rest = make([dynamic]^Strm_Stream)
	strm.queue = strm_queue_new()
	strm.refcnt = 1
	strm.exc = nil
	return strm
}

// Close stream and propagate to downstream
strm_stream_close :: proc(strm: ^Strm_Stream) {
	if strm == nil {
		return
	}

	if .Closed in strm.flags {
		return
	}

	strm.flags += {.Closed}
	strm.mode = .Dying

	// Call close callback
	if strm.close_func != nil {
		strm.close_func(strm, strm_nil_value())
	}

	// Close downstream
	if strm.dst != nil {
		strm_stream_close(strm.dst)
	}

	// Close additional downstream
	for dst in strm.rest {
		strm_stream_close(dst)
	}

	strm.mode = .Killed
}

// Destroy stream
strm_stream_destroy :: proc(strm: ^Strm_Stream) {
	if strm == nil {
		return
	}

	strm_stream_close(strm)
	delete(strm.rest)
	strm_queue_destroy(strm.queue)
	if strm.exc != nil {
		free(strm.exc)
	}
	free(strm)
}

// ============================================================================
// Stream connection
// ============================================================================

// Connect two streams (src | dst)
strm_stream_connect :: proc(src: ^Strm_Stream, dst: ^Strm_Stream) {
	if src == nil || dst == nil {
		return
	}

	if src.dst == nil {
		src.dst = dst
	} else {
		append(&src.rest, dst)
	}

	dst.refcnt += 1
}

// High-level pipe operator (|)
// Converts IO/lambda/array to stream as needed
strm_connect :: proc(strm: ^Strm_Stream, src_val: Strm_Value, dst_val: Strm_Value, ret: ^Strm_Value) -> int {
	// TODO: Implement value-to-stream conversion and connection
	// This is called by the | operator
	return -1
}

// ============================================================================
// Data emission
// ============================================================================

// Emit data to downstream
// Pushes task to destination's queue
strm_emit :: proc(strm: ^Strm_Stream, data: Strm_Value, cb: Stream_Start_Func) -> int {
	if strm == nil || strm.dst == nil {
		return -1
	}

	// Push task to destination's queue
	strm_task_push(strm.dst, strm.dst.start_func, data)

	// Schedule callback on self if provided
	if cb != nil {
		strm_task_push(strm, cb, strm_nil_value())
	}

	return 0
}

// Emit with IO callback
strm_io_emit :: proc(strm: ^Strm_Stream, data: Strm_Value, fd: int, cb: Stream_Start_Func) -> int {
	// TODO: Implement IO-aware emission
	return strm_emit(strm, data, cb)
}

// ============================================================================
// Exception handling
// ============================================================================

// Raise runtime error
strm_raise :: proc(strm: ^Strm_Stream, msg: string) {
	if strm == nil {
		return
	}

	if strm.exc == nil {
		strm.exc = new(Node_Error)
	}

	strm.exc.type = .Runtime
	strm.exc.fname = ""
	strm.exc.lineno = 0
	// TODO: Store message in arg
}

// Set exception
strm_set_exc :: proc(strm: ^Strm_Stream, type: Exception_Type, arg: Strm_Value) {
	if strm == nil {
		return
	}

	if strm.exc == nil {
		strm.exc = new(Node_Error)
	}

	strm.exc.type = type
	strm.exc.arg = arg
}

// Clear exception
strm_clear_exc :: proc(strm: ^Strm_Stream) {
	if strm == nil || strm.exc == nil {
		return
	}
	strm.exc.type = .None
}

// Print exception
strm_eprint :: proc(strm: ^Strm_Stream) {
	// TODO: Implement exception printing
}
