package streem

import "core:sync"

// Thread-safe task queue
// Reference: src/queue.c, src/atomic.h

// Task callback function type
Task_Func :: #type proc(strm: ^Strm_Stream, data: Strm_Value) -> int

// Task structure
Strm_Task :: struct {
	func_: Task_Func,
	data:  Strm_Value,
	next:  ^Strm_Task,
}

// Lock-free queue node
Queue_Node :: struct {
	value: rawptr,
	next:  ^Queue_Node,
}

// Lock-free FIFO queue
Strm_Queue :: struct {
	head:  ^Queue_Node,
	tail:  ^Queue_Node,
	mutex: sync.Mutex, // Using mutex for now, can be replaced with lock-free later
}

// ============================================================================
// Task operations
// ============================================================================

// Create a new task
strm_task_new :: proc(func_: Task_Func, data: Strm_Value) -> ^Strm_Task {
	task := new(Strm_Task)
	task.func_ = func_
	task.data = data
	task.next = nil
	return task
}

// Destroy a task
strm_task_destroy :: proc(task: ^Strm_Task) {
	if task != nil {
		free(task)
	}
}

// Push task to stream's queue
strm_task_push :: proc(strm: ^Strm_Stream, func_: Task_Func, data: Strm_Value) {
	if strm == nil || strm.queue == nil {
		return
	}

	task := strm_task_new(func_, data)
	strm_queue_add(strm.queue, task)
}

// Add task and enqueue stream to global queue
strm_task_add :: proc(strm: ^Strm_Stream, task: ^Strm_Task) {
	if strm == nil || strm.queue == nil {
		return
	}

	strm_queue_add(strm.queue, task)
	// TODO: Enqueue stream to global worker queue
}

// ============================================================================
// Queue operations
// ============================================================================

// Create a new queue
strm_queue_new :: proc() -> ^Strm_Queue {
	q := new(Strm_Queue)

	// Create sentinel node
	sentinel := new(Queue_Node)
	sentinel.value = nil
	sentinel.next = nil

	q.head = sentinel
	q.tail = sentinel

	return q
}

// Destroy a queue
strm_queue_destroy :: proc(q: ^Strm_Queue) {
	if q == nil {
		return
	}

	// Free all remaining nodes
	node := q.head
	for node != nil {
		next := node.next
		if node.value != nil {
			// Free the task
			strm_task_destroy(cast(^Strm_Task)node.value)
		}
		free(node)
		node = next
	}

	free(q)
}

// Enqueue (add to tail)
// TODO: Implement lock-free CAS version
strm_queue_add :: proc(q: ^Strm_Queue, val: rawptr) {
	if q == nil {
		return
	}

	node := new(Queue_Node)
	node.value = val
	node.next = nil

	sync.mutex_lock(&q.mutex)
	defer sync.mutex_unlock(&q.mutex)

	q.tail.next = node
	q.tail = node
}

// Dequeue (remove from head)
// TODO: Implement lock-free CAS version
strm_queue_get :: proc(q: ^Strm_Queue) -> rawptr {
	if q == nil {
		return nil
	}

	sync.mutex_lock(&q.mutex)
	defer sync.mutex_unlock(&q.mutex)

	node := q.head
	new_head := node.next

	if new_head == nil {
		return nil // queue is empty
	}

	val := new_head.value
	q.head = new_head

	// Free old head (sentinel)
	free(node)

	// Clear value from new head (it becomes the new sentinel)
	new_head.value = nil

	return val
}

// Check if queue is empty
strm_queue_empty_p :: proc(q: ^Strm_Queue) -> bool {
	if q == nil {
		return true
	}
	return q.head.next == nil
}

// ============================================================================
// Global worker queues (stubs for Phase 12)
// ============================================================================

// Global producer queue (prioritized)
@(private = "file")
prod_queue: ^Strm_Queue = nil

// Global consumer/filter queue
@(private = "file")
work_queue: ^Strm_Queue = nil

// Initialize worker queues
worker_init :: proc() {
	prod_queue = strm_queue_new()
	work_queue = strm_queue_new()
	// TODO: Start worker threads
}

// Cleanup worker queues
worker_cleanup :: proc() {
	strm_queue_destroy(prod_queue)
	strm_queue_destroy(work_queue)
	prod_queue = nil
	work_queue = nil
}

// Worker thread function
// Dequeue from prod_queue first, then work_queue
// Execute tasks with exclusion flag
task_loop :: proc() {
	// TODO: Implement worker thread loop
	for {
		// Try producer queue first
		task := cast(^Strm_Task)strm_queue_get(prod_queue)
		if task == nil {
			// Try work queue
			task = cast(^Strm_Task)strm_queue_get(work_queue)
		}

		if task != nil {
			// TODO: Execute task with proper stream context
			strm_task_destroy(task)
		} else {
			// TODO: Wait for work or shutdown signal
			break
		}
	}
}

// Main event loop (waits for completion)
strm_loop :: proc() {
	// TODO: Implement main event loop
	// - Start worker threads
	// - Wait for all streams to complete
}

// Get worker thread count (from env STRM_WORKER_MAX or CPU count)
worker_count :: proc() -> int {
	// TODO: Read from environment or detect CPU count
	return 4 // default
}
