package streem

import "core:testing"

// ============================================================================
// Queue Tests
// ============================================================================

@(test)
test_queue_basic :: proc(t: ^testing.T) {
	q := strm_queue_new()
	defer strm_queue_destroy(q)

	testing.expect(t, strm_queue_empty_p(q), "Expected empty queue")

	// Add items
	data1 := rawptr(uintptr(1))
	data2 := rawptr(uintptr(2))
	data3 := rawptr(uintptr(3))

	strm_queue_add(q, data1)
	strm_queue_add(q, data2)
	strm_queue_add(q, data3)

	testing.expect(t, !strm_queue_empty_p(q), "Expected non-empty queue")

	// Get items in FIFO order
	testing.expect_value(t, strm_queue_get(q), data1)
	testing.expect_value(t, strm_queue_get(q), data2)
	testing.expect_value(t, strm_queue_get(q), data3)

	testing.expect(t, strm_queue_empty_p(q), "Expected empty queue after gets")
	testing.expect_value(t, strm_queue_get(q), rawptr(nil))
}
