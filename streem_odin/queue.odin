package streem

import "core:container/queue"
import "core:sync"
import "core:thread"
import "core:os"
import "core:strconv"

// Thread-safe task queue
// Reference: src/queue.c, src/atomic.h, src/core.c
// Refactored to use core:container/queue and core:sync

// Task callback function type
// Same signature as Stream_Start_Func but used for tasks
Task_Func :: #type proc(strm: ^Strm_Stream, data: Strm_Value) -> int

// Task structure
Strm_Task :: struct {
	func_: Task_Func,
	data:  Strm_Value,
}

// Thread-safe FIFO queue using core:container/queue
// Wraps the standard queue with mutex for thread safety
Strm_Queue :: struct {
	data:  queue.Queue(rawptr),
	mutex: sync.Mutex,
}

// ============================================================================
// Global worker state
// Reference: src/core.c
// ============================================================================

// Worker thread structure
Strm_Worker :: struct {
	th: ^thread.Thread,
}

// Global producer queue (prioritized - data generation tasks)
@(private = "file")
prod_queue: ^Strm_Queue = nil

// Global consumer/filter queue (data processing tasks)
@(private = "file")
work_queue: ^Strm_Queue = nil

// Semaphore for worker threads to wait on tasks
// Posted when a task is added, workers wait on this
@(private = "file")
task_sema: sync.Sema

// Worker threads array
@(private = "file")
workers: [dynamic]Strm_Worker

// Maximum number of worker threads
@(private = "file")
worker_max: int = 0

// Active stream count (atomic)
@(private = "file")
stream_count: int = 0

// Flag indicating event loop has started
strm_event_loop_started: bool = false

// Flag to signal workers to stop
@(private = "file")
workers_should_stop: bool = false

// ============================================================================
// Task operations
// ============================================================================

// Create a new task
strm_task_new :: proc(func_: Task_Func, data: Strm_Value) -> ^Strm_Task {
	task := new(Strm_Task)
	task.func_ = func_
	task.data = data
	return task
}

// Destroy a task
strm_task_destroy :: proc(task: ^Strm_Task) {
	if task != nil {
		free(task)
	}
}

// Push task to stream's queue AND add stream to global queue
// Reference: src/core.c strm_task_push
strm_task_push :: proc(strm: ^Strm_Stream, func_: Task_Func, data: Strm_Value) {
	if strm == nil {
		return
	}
	if strm.mode == .Killed || strm.mode == .Dying {
		return
	}

	task := strm_task_new(func_, data)
	strm_task_add(strm, task)
}

// Add task to stream's queue and enqueue stream to global queue
// Reference: src/core.c strm_task_add
strm_task_add :: proc(strm: ^Strm_Stream, task: ^Strm_Task) {
	if strm == nil || strm.queue == nil {
		return
	}

	// Add task to stream's per-stream queue
	strm_queue_add(strm.queue, task)

	// Add stream to appropriate global queue
	if strm.mode == .Producer {
		strm_queue_add(prod_queue, strm)
	} else {
		strm_queue_add(work_queue, strm)
	}

	// Signal waiting workers that a task is available
	sync.sema_post(&task_sema)
}

// ============================================================================
// Queue operations
// ============================================================================

// Create a new queue using core:container/queue
strm_queue_new :: proc() -> ^Strm_Queue {
	q := new(Strm_Queue)
	queue.init(&q.data)
	return q
}

// Destroy a queue (only frees queue structure, not node values)
// Values are managed elsewhere (streams or tasks)
strm_queue_destroy :: proc(q: ^Strm_Queue) {
	if q == nil {
		return
	}
	queue.destroy(&q.data)
	free(q)
}

// Destroy a task queue (for stream's per-stream queue)
// This version frees remaining tasks
strm_task_queue_destroy :: proc(q: ^Strm_Queue) {
	if q == nil {
		return
	}

	// Free remaining tasks
	for queue.len(q.data) > 0 {
		val := queue.pop_front(&q.data)
		if val != nil {
			strm_task_destroy(cast(^Strm_Task)val)
		}
	}

	queue.destroy(&q.data)
	free(q)
}

// Enqueue (add to tail)
// Thread-safe using mutex
strm_queue_add :: proc(q: ^Strm_Queue, val: rawptr) {
	if q == nil {
		return
	}

	sync.mutex_lock(&q.mutex)
	defer sync.mutex_unlock(&q.mutex)

	queue.push_back(&q.data, val)
}

// Dequeue (remove from head)
// Thread-safe using mutex
strm_queue_get :: proc(q: ^Strm_Queue) -> rawptr {
	if q == nil {
		return nil
	}

	sync.mutex_lock(&q.mutex)
	defer sync.mutex_unlock(&q.mutex)

	if queue.len(q.data) == 0 {
		return nil
	}

	return queue.pop_front(&q.data)
}

// Check if queue is empty
strm_queue_empty_p :: proc(q: ^Strm_Queue) -> bool {
	if q == nil {
		return true
	}
	return queue.len(q.data) == 0
}

// ============================================================================
// Stream count management (atomic)
// ============================================================================

// Increment stream count (called when creating a stream)
strm_stream_count_inc :: proc() {
	atomic_inc(&stream_count)
}

// Decrement stream count (called when closing a stream)
strm_stream_count_dec :: proc() {
	atomic_dec(&stream_count)
}

// Get current stream count
strm_stream_count_get :: proc() -> int {
	return atomic_load(&stream_count)
}

// ============================================================================
// Worker thread pool
// Reference: src/core.c
// ============================================================================

// Get worker thread count (from env STRM_WORKER_MAX or CPU count)
worker_count :: proc() -> int {
	// Try to read from environment variable
	env_val, ok := os.lookup_env("STRM_WORKER_MAX")
	if ok {
		n, parse_ok := strconv.parse_int(env_val)
		if parse_ok && n > 0 {
			return n
		}
	}

	// Default to 4 workers
	// Note: Could use platform-specific CPU detection, but 4 is a reasonable default
	return 4
}

// Execute a single task
// Reference: src/core.c task_exec
@(private = "file")
task_exec :: proc(strm: ^Strm_Stream, task: ^Strm_Task) {
	func_ := task.func_
	data := task.data

	free(task)

	if strm.mode == .Killed {
		return
	}

	if func_ != nil {
		result := func_(strm, data)
		if result != STRM_OK {
			// Error occurred - propagate error
			if strm.exc != nil {
				strm_eprint(strm)
			}
			// Mark stream as dying to trigger cleanup
			if strm.mode != .Killed {
				strm.mode = .Dying
			}
		}
	}

	if strm.mode == .Dying {
		strm_stream_close(strm)
	}
}

// Worker thread function
// Reference: src/core.c task_loop
// Uses semaphore waiting instead of busy-wait for efficiency
@(private = "file")
task_loop :: proc(t: ^thread.Thread) {
	for {
		// Check if should stop
		if workers_should_stop {
			break
		}

		// Check if all streams are done
		if strm_stream_count_get() == 0 {
			break
		}

		// Wait for a task to be available
		// sema_wait blocks until a task is posted or woken up for shutdown
		sync.sema_wait(&task_sema)

		// Re-check stop condition after waking up
		if workers_should_stop {
			break
		}

		// Try work queue first (consumers/filters), then producer queue
		strm := cast(^Strm_Stream)strm_queue_get(work_queue)
		if strm == nil {
			strm = cast(^Strm_Stream)strm_queue_get(prod_queue)
		}

		if strm != nil {
			// Try to get exclusive access to this stream
			if atomic_cas(&strm.excl, 0, 1) {
				// Process all tasks in stream's queue
				for {
					task := cast(^Strm_Task)strm_queue_get(strm.queue)
					if task == nil {
						break
					}
					task_exec(strm, task)
				}
				// Release exclusive access
				atomic_cas(&strm.excl, 1, 0)
			}
		}
	}
}

// Initialize worker threads
// Reference: src/core.c worker_init
// Called lazily on first stream connection
worker_init :: proc() {
	// Already initialized?
	if len(workers) > 0 {
		return
	}

	// Set event loop started flag
	strm_event_loop_started = true
	workers_should_stop = false

	// Initialize global queues if not already done
	if prod_queue == nil {
		prod_queue = strm_queue_new()
	}
	if work_queue == nil {
		work_queue = strm_queue_new()
	}

	// TODO: Initialize IO loop (Phase 13)
	// strm_init_io_loop()

	// Determine number of workers
	worker_max = worker_count()

	// Create worker threads
	workers = make([dynamic]Strm_Worker, worker_max)
	for i in 0 ..< worker_max {
		workers[i].th = thread.create(task_loop)
		if workers[i].th != nil {
			thread.start(workers[i].th)
		}
	}
}

// Cleanup worker threads
worker_cleanup :: proc() {
	// Signal workers to stop
	workers_should_stop = true

	// Wake up all waiting workers so they can check the stop flag
	for _ in 0 ..< worker_max {
		sync.sema_post(&task_sema)
	}

	// Wait for all workers to finish
	for &w in workers {
		if w.th != nil {
			thread.join(w.th)
			thread.destroy(w.th)
			w.th = nil
		}
	}

	// Clean up workers array
	delete(workers)

	// Clean up global queues
	strm_queue_destroy(prod_queue)
	strm_queue_destroy(work_queue)
	prod_queue = nil
	work_queue = nil

	strm_event_loop_started = false
}

// Main event loop - waits for all streams to complete
// Reference: src/core.c strm_loop
strm_loop :: proc() -> int {
	// If no streams, nothing to do
	if strm_stream_count_get() == 0 {
		return STRM_OK
	}

	// Initialize workers if not already done
	worker_init()

	// Wait for all streams to complete
	for {
		thread.yield()
		if strm_stream_count_get() == 0 {
			break
		}
	}

	return STRM_OK
}
