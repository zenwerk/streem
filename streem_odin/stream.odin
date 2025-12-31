package streem

import "core:fmt"
import "core:thread"

// Stream runtime
// Reference: src/core.c, src/strm.h

// Return codes are defined in state.odin
// STRM_OK :: 0
// STRM_NG :: 1

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
}

// Stream callback function types
Stream_Start_Func :: #type proc(strm: ^Strm_Stream, data: Strm_Value) -> int
Stream_Close_Func :: #type proc(strm: ^Strm_Stream, data: Strm_Value) -> int

// Stream structure
// Reference: src/strm.h strm_stream
Strm_Stream :: struct {
	type:       Ptr_Type,            // MUST be first field - identifies this as a stream
	mode:       Stream_Mode,
	flags:      Stream_Flags,
	start_func: Stream_Start_Func,
	close_func: Stream_Close_Func,
	data:       rawptr,              // user data pointer
	dst:        ^Strm_Stream,        // primary downstream connection
	rest:       [dynamic]^Strm_Stream, // additional downstream connections
	queue:      ^Strm_Queue,         // per-stream task queue
	refcnt:     int,                 // reference count
	excl:       int,                 // exclusion flag for thread safety (0 = available, 1 = in use)
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
// Reference: src/core.c strm_stream_new, strm_stream_close
// ============================================================================

// Create a new stream
strm_stream_new :: proc(mode: Stream_Mode, start_func: Stream_Start_Func, close_func: Stream_Close_Func, data: rawptr) -> ^Strm_Stream {
	strm := new(Strm_Stream)
	strm.type = .Stream    // Ptr_Type tag for value system
	strm.mode = mode
	strm.flags = {}
	strm.start_func = start_func
	strm.close_func = close_func
	strm.data = data
	strm.dst = nil
	strm.rest = make([dynamic]^Strm_Stream)
	strm.queue = strm_queue_new()
	strm.refcnt = 0
	strm.excl = 0
	strm.exc = nil

	// Increment global stream count
	strm_stream_count_inc()

	return strm
}

// Close stream and propagate to downstream
// Reference: src/core.c strm_stream_close
strm_stream_close :: proc(strm: ^Strm_Stream) {
	if strm == nil {
		return
	}

	mode := strm.mode
	if mode == .Killed {
		return
	}

	// Decrement reference count
	atomic_dec(&strm.refcnt)
	if strm.refcnt > 0 {
		return
	}

	// Try to atomically set mode to Killed
	if !atomic_cas(&strm.mode, mode, Stream_Mode.Killed) {
		return
	}

	// Call close callback
	if strm.close_func != nil {
		if strm.close_func(strm, strm_nil_value()) == STRM_NG {
			return
		}
	} else {
		// Free data if no close callback
		if strm.data != nil {
			free(strm.data)
			strm.data = nil
		}
	}

	// Propagate close to downstream
	if strm.dst != nil {
		strm_task_push(strm.dst, cast(Task_Func)strm_stream_close, strm_nil_value())
	}

	for dst in strm.rest {
		strm_task_push(dst, cast(Task_Func)strm_stream_close, strm_nil_value())
	}

	// Free rest array
	if len(strm.rest) > 0 {
		delete(strm.rest)
	}

	// Decrement global stream count
	strm_stream_count_dec()
}

// Destroy stream (immediate cleanup without propagation)
strm_stream_destroy :: proc(strm: ^Strm_Stream) {
	if strm == nil {
		return
	}

	delete(strm.rest)
	strm_queue_destroy(strm.queue)
	if strm.exc != nil {
		free(strm.exc)
	}
	free(strm)
}

// ============================================================================
// Stream connection
// Reference: src/core.c strm_stream_connect
// ============================================================================

// Connect two streams (src | dst)
strm_stream_connect :: proc(src: ^Strm_Stream, dst: ^Strm_Stream) -> int {
	if src == nil || dst == nil {
		return STRM_NG
	}

	// Validate modes
	assert(src.mode != .Consumer, "cannot connect from consumer")
	assert(dst.mode != .Producer, "cannot connect to producer")

	if src.dst == nil {
		src.dst = dst
	} else {
		append(&src.rest, dst)
	}

	// Increment reference count atomically
	atomic_inc(&dst.refcnt)

	// If source is a producer, initialize workers and start it
	if src.mode == .Producer {
		worker_init()
		strm_task_push(src, src.start_func, strm_nil_value())
	}

	return STRM_OK
}

// Convert value to stream
// Reference: src/exec.c strm_connect (value conversion logic)
@(private = "file")
value_to_src_stream :: proc(strm: ^Strm_Stream, val: Strm_Value) -> Strm_Value {
	// Already a stream
	if strm_stream_p(val) {
		return val
	}

	// IO -> read stream
	if strm_io_p(val) {
		// TODO: Phase 13 - strm_io_stream
		// return strm_stream_value(strm_io_stream(val, STRM_IO_READ))
		return val
	}

	// Lambda -> filter stream
	if strm_lambda_p(val) {
		lambda := strm_value_ptr(val, Strm_Lambda)
		new_strm := strm_stream_new(.Filter, blk_exec, nil, rawptr(lambda))
		return strm_stream_value(new_strm)
	}

	// Array -> producer stream
	if strm_array_p(val) {
		arrd := new(Array_Data)
		arrd.arr = Strm_Array(val)
		arrd.n = 0
		new_strm := strm_stream_new(.Producer, arr_exec, nil, rawptr(arrd))
		return strm_stream_value(new_strm)
	}

	return val
}

@(private = "file")
value_to_dst_stream :: proc(strm: ^Strm_Stream, val: Strm_Value) -> Strm_Value {
	// Already a stream
	if strm_stream_p(val) {
		return val
	}

	// IO -> write stream
	if strm_io_p(val) {
		// TODO: Phase 13 - strm_io_stream
		// return strm_stream_value(strm_io_stream(val, STRM_IO_WRITE))
		return val
	}

	// Lambda -> filter stream
	if strm_lambda_p(val) {
		lambda := strm_value_ptr(val, Strm_Lambda)
		new_strm := strm_stream_new(.Filter, blk_exec, nil, rawptr(lambda))
		return strm_stream_value(new_strm)
	}

	// Cfunc -> filter stream
	if strm_cfunc_p(val) {
		func_ := strm_value_cfunc(val)
		new_strm := strm_stream_new(.Filter, cfunc_exec, cfunc_closer, rawptr(func_))
		return strm_stream_value(new_strm)
	}

	return val
}

// High-level pipe operator (|)
// Converts IO/lambda/array to stream as needed
// Reference: src/exec.c strm_connect
strm_connect :: proc(strm: ^Strm_Stream, src_val: Strm_Value, dst_val: Strm_Value, ret: ^Strm_Value) -> int {
	// Convert source value to stream
	src := value_to_src_stream(strm, src_val)

	// Convert destination value to stream
	dst := value_to_dst_stream(strm, dst_val)

	// Validate both are streams
	if strm_stream_p(src) && strm_stream_p(dst) {
		lstrm := strm_value_ptr(src, Strm_Stream)
		rstrm := strm_value_ptr(dst, Strm_Stream)

		if lstrm == nil || rstrm == nil ||
		   lstrm.mode == .Consumer ||
		   rstrm.mode == .Producer {
			strm_raise(strm, "stream error")
			return STRM_NG
		}

		strm_stream_connect(lstrm, rstrm)
		ret^ = dst
		return STRM_OK
	}

	return STRM_NG
}

// Create stream value from stream pointer
strm_stream_value :: proc(strm: ^Strm_Stream) -> Strm_Value {
	return strm_ptr_value(rawptr(strm))
}

// Extract stream from value
strm_value_stream :: proc(v: Strm_Value) -> ^Strm_Stream {
	if !strm_stream_p(v) {
		return nil
	}
	return strm_value_ptr(v, Strm_Stream)
}

// ============================================================================
// Data emission
// Reference: src/core.c strm_emit
// ============================================================================

// Emit data to downstream
// Pushes task to destination's queue
strm_emit :: proc(strm: ^Strm_Stream, data: Strm_Value, cb: Stream_Start_Func) {
	if strm == nil {
		return
	}

	if strm.mode == .Dying {
		return
	}

	// Only emit non-nil data
	if !strm_nil_p(data) {
		// Emit to primary downstream
		if strm.dst != nil {
			strm_task_push(strm.dst, strm.dst.start_func, data)
			// Check if downstream was killed
			if strm.dst.mode == .Killed {
				strm.dst = nil
			}
		}

		// Emit to additional downstream connections
		for dst in strm.rest {
			strm_task_push(dst, dst.start_func, data)
		}

		// Termination check - if all downstream are gone/killed
		if strm.dst == nil {
			closed := true
			for dst in strm.rest {
				if dst.mode != .Killed {
					closed = false
					break
				}
			}
			if closed {
				strm.mode = .Dying
				return
			}
		}
	}

	// Yield to other threads
	thread.yield()

	// Schedule callback on self if provided
	// This allows recursive generators (like seq) to continue producing
	if cb != nil {
		strm_task_push(strm, cb, strm_nil_value())
	}
}

// Emit with IO callback
strm_io_emit :: proc(strm: ^Strm_Stream, data: Strm_Value, fd: int, cb: Stream_Start_Func) {
	// TODO: Phase 13 - implement IO-aware emission with epoll/kqueue
	strm_emit(strm, data, cb)
}

// ============================================================================
// Exception handling
// Reference: src/exec.c
// ============================================================================

// Raise runtime error
strm_raise :: proc(strm: ^Strm_Stream, msg: string) {
	if strm == nil {
		return
	}

	strm_set_exc(strm, .Runtime, strm_str_value(strm_str_new(msg)))
}

// Set exception
strm_set_exc :: proc(strm: ^Strm_Stream, type: Exception_Type, arg: Strm_Value) -> ^Node_Error {
	if strm == nil {
		return nil
	}

	// Clear any existing exception
	strm_clear_exc(strm)

	// Create new exception
	exc := new(Node_Error)
	exc.type = type
	exc.arg = arg
	exc.fname = ""
	exc.lineno = 0
	strm.exc = exc

	return exc
}

// Clear exception
strm_clear_exc :: proc(strm: ^Strm_Stream) {
	if strm == nil || strm.exc == nil {
		return
	}
	free(strm.exc)
	strm.exc = nil
}

// Print exception
// Reference: src/exec.c strm_eprint
strm_eprint :: proc(strm: ^Strm_Stream) {
	if strm == nil || strm.exc == nil {
		return
	}

	exc := strm.exc

	// Skip printing for skip exceptions
	if exc.type == .Skip {
		return
	}

	// Print file:line: if available
	if exc.fname != "" {
		fmt.eprintf("%s:%d:", exc.fname, exc.lineno)
	}

	// Print error message
	msg := strm_to_str(exc.arg)
	fmt.eprintln(msg)

	// Clear exception after printing
	strm_clear_exc(strm)
}

// ============================================================================
// Stream helper structures and functions for exec
// Reference: src/exec.c
// ============================================================================

// Array data for array-to-producer conversion
Array_Data :: struct {
	n:   int,
	arr: Strm_Array,
}

// Array producer execution function
// Reference: src/exec.c arr_exec
arr_exec :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	arrd := cast(^Array_Data)strm.data
	ary_len := int(strm_ary_len(arrd.arr))

	if arrd.n == ary_len {
		strm_stream_close(strm)
		return STRM_OK
	}

	ptr := strm_ary_ptr(arrd.arr)
	strm_emit(strm, ptr[arrd.n], arr_exec)
	arrd.n += 1

	return STRM_OK
}

// Lambda/block execution function for filter streams
// Reference: src/exec.c blk_exec
blk_exec :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	lambda := cast(^Strm_Lambda)strm.data
	ret := strm_nil_value()

	// Create execution state with closure as parent
	c := strm_state_new(lambda.state)
	defer strm_state_destroy(c)

	// Get lambda arguments
	nlmbd := lambda.body
	if nlmbd.type != .Lambda {
		return STRM_NG
	}

	lambda_data := &nlmbd.data.(Node_Lambda)

	// Bind argument if lambda has one
	if lambda_data.args != nil && lambda_data.args.type == .Args {
		arg_names := &lambda_data.args.data.(Node_Args)
		if len(arg_names.names) == 1 {
			arg_name := strm_str_intern(arg_names.names[0])
			strm_var_set(c, arg_name, data)
		}
	}

	// Execute lambda body
	result := exec_expr(strm, c, lambda_data.body, &ret)

	// Handle exceptions
	exc := strm.exc
	if exc != nil {
		if exc.type == .Return {
			ret = exc.arg
			strm_clear_exc(strm)
		} else {
			// TODO: if verbose, strm_eprint(strm)
			return STRM_NG
		}
	}

	if result != .Ok {
		return STRM_NG
	}

	strm_emit(strm, ret, nil)
	return STRM_OK
}

// C function execution for cfunc filter streams
// Reference: src/exec.c cfunc_exec
cfunc_exec :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	func_ := cast(Strm_Cfunc)strm.data
	ret: Strm_Value

	args := []Strm_Value{data}
	if func_(strm, 1, args, &ret) == STRM_OK {
		strm_emit(strm, ret, nil)
		return STRM_OK
	}
	return STRM_NG
}

// C function closer (no-op)
// Reference: src/exec.c cfunc_closer
cfunc_closer :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	return STRM_OK
}
