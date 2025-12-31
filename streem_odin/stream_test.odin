package streem

import "core:testing"

// ============================================================================
// Stream Tests
// ============================================================================

@(test)
test_stream_new :: proc(t: ^testing.T) {
	// Test stream creation
	strm := strm_stream_new(.Producer, nil, nil, nil)
	defer strm_stream_destroy(strm)

	testing.expect(t, strm != nil, "Expected stream to be created")
	testing.expect(t, strm.type == .Stream, "Expected stream type tag")
	testing.expect(t, strm.mode == .Producer, "Expected producer mode")
	testing.expect(t, strm.dst == nil, "Expected no downstream")
	testing.expect(t, strm.queue != nil, "Expected queue to be created")
	testing.expect(t, strm.excl == 0, "Expected excl to be 0")
}

@(test)
test_stream_connect :: proc(t: ^testing.T) {
	// Test stream connection without starting (just structure test)
	src := strm_stream_new(.Producer, nil, nil, nil)
	dst := strm_stream_new(.Filter, nil, nil, nil)
	defer {
		strm_stream_destroy(src)
		strm_stream_destroy(dst)
	}

	// Connect before producer is started
	src.dst = dst  // Manual connection for test (avoid worker init)

	testing.expect(t, src.dst == dst, "Expected src.dst to be dst")
}

@(test)
test_stream_mode :: proc(t: ^testing.T) {
	// Test stream mode transitions
	strm := strm_stream_new(.Filter, nil, nil, nil)
	defer strm_stream_destroy(strm)

	testing.expect(t, strm.mode == .Filter, "Expected filter mode")

	strm.mode = .Dying
	testing.expect(t, strm.mode == .Dying, "Expected dying mode")

	strm.mode = .Killed
	testing.expect(t, strm.mode == .Killed, "Expected killed mode")
}

@(test)
test_stream_value :: proc(t: ^testing.T) {
	// Test stream to/from value conversion
	strm := strm_stream_new(.Consumer, nil, nil, nil)
	defer strm_stream_destroy(strm)

	val := strm_stream_value(strm)

	testing.expect(t, strm_stream_p(val), "Expected stream predicate to be true")

	extracted := strm_value_stream(val)
	testing.expect(t, extracted == strm, "Expected extracted stream to match original")
}

@(test)
test_stream_exception :: proc(t: ^testing.T) {
	// Test exception handling
	strm := strm_stream_new(.Filter, nil, nil, nil)
	defer strm_stream_destroy(strm)

	testing.expect(t, strm.exc == nil, "Expected no exception initially")

	// Raise exception
	strm_raise(strm, "test error")

	testing.expect(t, strm.exc != nil, "Expected exception after raise")
	testing.expect(t, strm.exc.type == .Runtime, "Expected runtime exception")

	// Clear exception
	strm_clear_exc(strm)

	testing.expect(t, strm.exc == nil, "Expected no exception after clear")
}

@(test)
test_stream_set_exc :: proc(t: ^testing.T) {
	// Test set exception directly
	strm := strm_stream_new(.Filter, nil, nil, nil)
	defer strm_stream_destroy(strm)

	test_val := strm_int_value(42)
	strm_set_exc(strm, .Return, test_val)

	testing.expect(t, strm.exc != nil, "Expected exception")
	testing.expect(t, strm.exc.type == .Return, "Expected return exception")
	testing.expect(t, strm_value_int(strm.exc.arg) == 42, "Expected correct arg value")

	strm_clear_exc(strm)
}

// ============================================================================
// Task Queue Integration Tests
// ============================================================================

@(test)
test_task_new :: proc(t: ^testing.T) {
	// Test task creation
	dummy_func :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
		return STRM_OK
	}

	task := strm_task_new(dummy_func, strm_int_value(123))
	defer strm_task_destroy(task)

	testing.expect(t, task != nil, "Expected task to be created")
	testing.expect(t, task.func_ != nil, "Expected function to be set")
	testing.expect(t, strm_value_int(task.data) == 123, "Expected data to be 123")
}

@(test)
test_worker_count :: proc(t: ^testing.T) {
	// Test worker count returns a positive number
	count := worker_count()
	testing.expect(t, count > 0, "Expected positive worker count")
	testing.expect(t, count <= 1024, "Expected reasonable worker count")  // sanity check
}

// ============================================================================
// Atomic Operations Tests
// ============================================================================

@(test)
test_atomic_inc_dec :: proc(t: ^testing.T) {
	// Test atomic increment/decrement
	val: int = 0

	old := atomic_inc(&val)
	testing.expect(t, old == 0, "Expected old value 0")
	testing.expect(t, val == 1, "Expected new value 1")

	old = atomic_inc(&val)
	testing.expect(t, old == 1, "Expected old value 1")
	testing.expect(t, val == 2, "Expected new value 2")

	old = atomic_dec(&val)
	testing.expect(t, old == 2, "Expected old value 2")
	testing.expect(t, val == 1, "Expected new value 1")
}

@(test)
test_atomic_cas :: proc(t: ^testing.T) {
	// Test compare-and-swap
	val: int = 10

	// CAS should succeed when expected value matches
	success := atomic_cas(&val, 10, 20)
	testing.expect(t, success, "Expected CAS to succeed")
	testing.expect(t, val == 20, "Expected value to be 20")

	// CAS should fail when expected value doesn't match
	success = atomic_cas(&val, 10, 30)
	testing.expect(t, !success, "Expected CAS to fail")
	testing.expect(t, val == 20, "Expected value to remain 20")
}

@(test)
test_atomic_add :: proc(t: ^testing.T) {
	// Test atomic add
	val: int = 5

	old := atomic_add(&val, 3)
	testing.expect(t, old == 5, "Expected old value 5")
	testing.expect(t, val == 8, "Expected new value 8")

	old = atomic_add(&val, -2)
	testing.expect(t, old == 8, "Expected old value 8")
	testing.expect(t, val == 6, "Expected new value 6")
}

@(test)
test_atomic_load_store :: proc(t: ^testing.T) {
	// Test atomic load/store
	val: int = 0

	atomic_store(&val, 42)
	loaded := atomic_load(&val)
	testing.expect(t, loaded == 42, "Expected loaded value 42")

	atomic_store(&val, 100)
	loaded = atomic_load(&val)
	testing.expect(t, loaded == 100, "Expected loaded value 100")
}
