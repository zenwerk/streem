package streem

import "core:fmt"
import "core:os"
import "core:strings"
import "core:bufio"

// I/O Streams
// Reference: src/io.c

// IO mode flags
IO_Mode :: enum {
	Read,
	Write,
	Flush,
	Reading,
}

IO_Modes :: bit_set[IO_Mode]

STRM_IO_READ :: IO_Modes{.Read}
STRM_IO_WRITE :: IO_Modes{.Write}
STRM_IO_FLUSH :: IO_Modes{.Flush}

// IO structure
// Reference: src/strm.h strm_io
Strm_IO :: struct {
	type:         Ptr_Type,       // MUST be first field - Ptr_Type.IO
	fd:           os.Handle,      // file descriptor
	mode:         IO_Modes,
	read_stream:  ^Strm_Stream,   // cached read stream
	write_stream: ^Strm_Stream,   // cached write stream
}

// ============================================================================
// IO Creation
// ============================================================================

// Create a new IO object
// Reference: src/io.c strm_io_new
strm_io_new :: proc(fd: os.Handle, mode: IO_Modes) -> Strm_Value {
	io := new(Strm_IO)
	io.type = .IO
	io.fd = fd
	io.mode = mode
	io.read_stream = nil
	io.write_stream = nil
	return strm_ptr_value(rawptr(io))
}

// Get IO from value
strm_value_io :: proc(v: Strm_Value) -> ^Strm_IO {
	if !strm_io_p(v) {
		return nil
	}
	return strm_value_ptr(v, Strm_IO)
}

// ============================================================================
// Read Buffer
// ============================================================================

// Read buffer structure for line-buffered reading
FD_Read_Buffer :: struct {
	fd:   os.Handle,
	io:   ^Strm_IO,
	buf:  [4096]byte,        // Buffer (BUFSIZ equivalent)
	beg:  int,               // Start position in buffer
	end_: int,               // End position in buffer
}

// ============================================================================
// Read Stream
// ============================================================================

// Read callback - reads data from fd into buffer
@(private = "file")
read_cb :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	b := cast(^FD_Read_Buffer)strm.data

	// Calculate available space
	count := len(b.buf) - b.end_
	if count <= 0 {
		// Buffer full, need to process
		return readline_cb(strm, strm_nil_value())
	}

	// Read from fd
	n, err := os.read(b.fd, b.buf[b.end_:])
	if err != nil || n <= 0 {
		// EOF or error
		if b.beg < b.end_ {
			// Emit remaining data
			s := strm_str_new(string(b.buf[b.beg:b.end_]))
			b.beg = 0
			b.end_ = 0
			strm_emit(strm, strm_str_value(s), nil)
		}
		strm_stream_close(strm)
		return STRM_OK
	}

	b.end_ += n
	return readline_cb(strm, strm_nil_value())
}

// Readline callback - emits lines from buffer
@(private = "file")
readline_cb :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	b := cast(^FD_Read_Buffer)strm.data

	// Find newline
	for i in b.beg ..< b.end_ {
		if b.buf[i] == '\n' {
			// Found newline, emit line
			line_len := i - b.beg
			s := strm_str_new(string(b.buf[b.beg:b.beg + line_len]))
			b.beg = i + 1
			strm_emit(strm, strm_str_value(s), readline_cb)
			return STRM_OK
		}
	}

	// No newline found
	if b.beg > 0 && b.end_ > b.beg {
		// Move remaining data to beginning
		copy(b.buf[:], b.buf[b.beg:b.end_])
		b.end_ -= b.beg
		b.beg = 0
	}

	// Schedule next read
	strm_task_push(strm, read_cb, strm_nil_value())
	return STRM_OK
}

// Start reading from fd
@(private = "file")
stdio_read :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	// Start reading
	return read_cb(strm, strm_nil_value())
}

// Close read stream
@(private = "file")
read_close :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	b := cast(^FD_Read_Buffer)strm.data
	if b != nil {
		// Close fd if not stdin
		if b.fd != os.stdin {
			os.close(b.fd)
		}
		free(b)
	}
	return STRM_OK
}

// Create read stream from IO
@(private = "file")
strm_readio :: proc(io: ^Strm_IO) -> ^Strm_Stream {
	if io.read_stream != nil {
		return io.read_stream
	}

	// Create buffer
	buf := new(FD_Read_Buffer)
	buf.fd = io.fd
	buf.io = io
	buf.beg = 0
	buf.end_ = 0

	// Mark as reading
	io.mode += {.Reading}

	// Create producer stream
	io.read_stream = strm_stream_new(.Producer, stdio_read, read_close, rawptr(buf))
	return io.read_stream
}

// ============================================================================
// Write Stream
// ============================================================================

// Write data structure
Write_Data :: struct {
	fd: os.Handle,
	io: ^Strm_IO,
}

// Write callback - writes data to fd
@(private = "file")
write_cb :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Write_Data)strm.data

	// Convert to string
	s := strm_to_str(data)

	// Write to fd with newline
	os.write_string(d.fd, s)
	os.write_string(d.fd, "\n")

	// Flush if needed
	if .Flush in d.io.mode {
		// Note: os.sync would be needed for proper flushing
	}

	return STRM_OK
}

// Close write stream
@(private = "file")
write_close :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Write_Data)strm.data
	if d != nil {
		// Close fd if not stdout/stderr
		if d.fd != os.stdout && d.fd != os.stderr {
			os.close(d.fd)
		}
		free(d)
	}
	return STRM_OK
}

// Create write stream from IO
@(private = "file")
strm_writeio :: proc(io: ^Strm_IO) -> ^Strm_Stream {
	if io.write_stream != nil {
		return io.write_stream
	}

	// Create write data
	d := new(Write_Data)
	d.fd = io.fd
	d.io = io

	// Create consumer stream
	io.write_stream = strm_stream_new(.Consumer, write_cb, write_close, rawptr(d))
	return io.write_stream
}

// ============================================================================
// IO Stream Interface
// ============================================================================

// Get stream for IO (read or write)
// Reference: src/io.c strm_io_stream
strm_io_stream :: proc(iov: Strm_Value, mode: IO_Modes) -> ^Strm_Stream {
	if !strm_io_p(iov) {
		return nil
	}

	io := strm_value_io(iov)
	if io == nil {
		return nil
	}

	if .Read in mode {
		return strm_readio(io)
	} else if .Write in mode {
		return strm_writeio(io)
	}

	return nil
}

// ============================================================================
// File Operations
// ============================================================================

// Open file for reading
strm_fread :: proc(path: string) -> Strm_Value {
	fd, err := os.open(path, os.O_RDONLY)
	if err != nil {
		return strm_nil_value()
	}
	return strm_io_new(fd, STRM_IO_READ)
}

// Open file for writing
strm_fwrite :: proc(path: string) -> Strm_Value {
	fd, err := os.open(path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, 0o644)
	if err != nil {
		return strm_nil_value()
	}
	return strm_io_new(fd, STRM_IO_WRITE)
}
