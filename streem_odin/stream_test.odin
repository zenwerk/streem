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

// ============================================================================
// Edge Case Tests - Error Propagation
// ============================================================================

@(test)
test_error_propagation :: proc(t: ^testing.T) {
	// Test error propagation sets mode to dying
	strm := strm_stream_new(.Filter, nil, nil, nil)
	defer strm_stream_destroy(strm)

	testing.expect(t, strm.mode == .Filter, "Expected filter mode initially")
	testing.expect(t, strm.exc == nil, "Expected no exception initially")

	// Propagate error
	strm_propagate_error(strm, "test error propagation")

	testing.expect(t, strm.mode == .Dying, "Expected dying mode after error propagation")
}

@(test)
test_error_propagation_nil :: proc(t: ^testing.T) {
	// Test error propagation with nil stream doesn't crash
	strm_propagate_error(nil, "test error")
	// If we get here, the test passed (no crash)
}

// ============================================================================
// Edge Case Tests - Stream Cancellation
// ============================================================================

@(test)
test_stream_cancel :: proc(t: ^testing.T) {
	// Test stream cancellation
	strm := strm_stream_new(.Filter, nil, nil, nil)
	// Note: strm_cancel will call strm_stream_close which may free the stream
	// So we don't defer destroy

	testing.expect(t, strm.mode == .Filter, "Expected filter mode initially")

	// Cancel stream
	strm_cancel(strm)

	// After cancel, stream should be in Dying or Killed state
	// Note: The stream may already be freed by close, so this test is limited
}

@(test)
test_stream_cancel_nil :: proc(t: ^testing.T) {
	// Test cancel with nil stream doesn't crash
	strm_cancel(nil)
	// If we get here, the test passed (no crash)
}

@(test)
test_stream_cancel_upstream :: proc(t: ^testing.T) {
	// Test cancel upstream
	strm := strm_stream_new(.Filter, nil, nil, nil)
	defer strm_stream_destroy(strm)

	testing.expect(t, strm.mode == .Filter, "Expected filter mode initially")

	// Cancel upstream
	strm_cancel_upstream(strm)

	testing.expect(t, strm.mode == .Dying, "Expected dying mode after cancel upstream")
}

@(test)
test_stream_cancel_already_killed :: proc(t: ^testing.T) {
	// Test that cancelling an already killed stream is a no-op
	strm := strm_stream_new(.Filter, nil, nil, nil)
	defer strm_stream_destroy(strm)

	strm.mode = .Killed

	// Cancel should be a no-op
	strm_cancel(strm)

	testing.expect(t, strm.mode == .Killed, "Expected killed mode unchanged")
}

// ============================================================================
// Edge Case Tests - Resource Cleanup
// ============================================================================

@(test)
test_resource_cleanup_stream_destroy :: proc(t: ^testing.T) {
	// Test that stream destroy cleans up resources
	strm := strm_stream_new(.Filter, nil, nil, nil)

	// Set some exception
	strm_raise(strm, "test")
	testing.expect(t, strm.exc != nil, "Expected exception to be set")

	// Destroy should clean up
	strm_stream_destroy(strm)

	// Can't check strm after destroy, but if we get here without crash, it's good
}

@(test)
test_resource_cleanup_with_data :: proc(t: ^testing.T) {
	// Test that stream destroy cleans up user data
	data := new(int)
	data^ = 42

	strm := strm_stream_new(.Filter, nil, nil, rawptr(data))
	testing.expect(t, strm.data != nil, "Expected data to be set")

	// Destroy should free the data
	strm_stream_destroy(strm)

	// If we get here without crash, cleanup worked
}

@(test)
test_resource_cleanup_queue_destroy :: proc(t: ^testing.T) {
	// Test that queue destroy cleans up properly
	q := strm_queue_new()
	testing.expect(t, q != nil, "Expected queue to be created")

	// Add some tasks
	dummy_func :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
		return STRM_OK
	}
	task1 := strm_task_new(dummy_func, strm_int_value(1))
	task2 := strm_task_new(dummy_func, strm_int_value(2))

	strm_queue_add(q, task1)
	strm_queue_add(q, task2)

	// Destroy should clean up all tasks
	strm_queue_destroy(q)

	// If we get here without crash, cleanup worked
}

@(test)
test_resource_cleanup_multiple_rest :: proc(t: ^testing.T) {
	// Test cleanup with multiple downstream connections
	src := strm_stream_new(.Producer, nil, nil, nil)
	dst1 := strm_stream_new(.Filter, nil, nil, nil)
	dst2 := strm_stream_new(.Filter, nil, nil, nil)
	dst3 := strm_stream_new(.Consumer, nil, nil, nil)

	// Set up connections manually (avoid worker init)
	src.dst = dst1
	append(&src.rest, dst2)
	append(&src.rest, dst3)

	testing.expect(t, len(src.rest) == 2, "Expected 2 rest connections")

	// Destroy should clean up rest array
	strm_stream_destroy(src)
	strm_stream_destroy(dst1)
	strm_stream_destroy(dst2)
	strm_stream_destroy(dst3)

	// If we get here, cleanup worked
}

// ============================================================================
// Edge Case Tests - Exception Types
// ============================================================================

@(test)
test_exception_skip :: proc(t: ^testing.T) {
	// Test skip exception type
	strm := strm_stream_new(.Filter, nil, nil, nil)
	defer strm_stream_destroy(strm)

	strm_set_exc(strm, .Skip, strm_nil_value())

	testing.expect(t, strm.exc != nil, "Expected exception to be set")
	testing.expect(t, strm.exc.type == .Skip, "Expected skip exception type")

	// strm_eprint should not print for skip exceptions, and should NOT clear
	// (skip is handled specially by the caller)
	strm_eprint(strm)

	// Skip exceptions are NOT cleared by eprint - they need special handling
	testing.expect(t, strm.exc != nil, "Expected skip exception to remain after eprint")

	// Manually clear
	strm_clear_exc(strm)
	testing.expect(t, strm.exc == nil, "Expected exception to be cleared after manual clear")
}

@(test)
test_exception_return :: proc(t: ^testing.T) {
	// Test return exception type
	strm := strm_stream_new(.Filter, nil, nil, nil)
	defer strm_stream_destroy(strm)

	strm_set_exc(strm, .Return, strm_int_value(100))

	testing.expect(t, strm.exc != nil, "Expected exception to be set")
	testing.expect(t, strm.exc.type == .Return, "Expected return exception type")
	testing.expect(t, strm_value_int(strm.exc.arg) == 100, "Expected return value 100")

	strm_clear_exc(strm)
}
