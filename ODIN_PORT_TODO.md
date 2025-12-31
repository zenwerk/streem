# Streem Odin Port - Implementation Plan

## Overview

Port streem language from C (flex/bison) to Odin with a push-style parser.
Reference implementation: `calc_odin/` directory.

**Scope**: Full runtime implementation including stream processing and built-in functions.

---

## Phase 1: Project Setup & Token Definition

### 1.1 Create project structure
- [x] Create `streem_odin/` directory
- [x] Create `lex.odin` - Lexer
- [x] Create `token.odin` - Token types
- [x] Create `node.odin` - AST nodes
- [x] Create `parse.odin` - Push parser
- [x] Create `value.odin` - Runtime values (NaN-boxing)
- [x] Create `state.odin` - Namespace/scope management
- [x] Create `stream.odin` - Stream runtime
- [x] Create `queue.odin` - Thread-safe task queue
- [x] Create `exec.odin` - AST evaluator
- [x] Create `builtin/` - Built-in functions directory
- [x] Create `main.odin` - Entry point
- [x] Create `test.odin` - Unit tests

### 1.2 Define Token Types (from lex.l)
- [x] Keywords:
  - `if`, `else`, `case`, `emit`, `skip`, `return`
  - `namespace`, `class`, `import`
  - `def`, `method`, `new`
  - `nil`, `true`, `false`
- [x] Operators:
  - Arithmetic: `+`, `-`, `*`, `/`, `%`
  - Comparison: `==`, `!=`, `<`, `<=`, `>`, `>=`
  - Logical: `&&`, `||`, `!`
  - Bitwise: `&`, `|`, `~`
  - Assignment: `=`, `<-`, `=>`
  - Lambda: `->`, `)-> `, `)->{`
  - Scope: `::`
- [x] Delimiters: `(`, `)`, `[`, `]`, `{`, `}`, `,`, `;`, `:`, `.`, `@`
- [x] Literals:
  - Integer (decimal, hex `0x`, octal `0o`)
  - Float
  - String (double-quoted with escapes)
  - Symbol (`:identifier`)
  - Time (`YYYY.MM.DD` or `YYYY.MM.DDThh:mm:ss`)
- [x] Identifier (unicode-aware)
- [x] Label (`identifier:`)
- [x] Newline (significant for statement termination)
- [x] EOF, Error

---

## Phase 2: Lexer Implementation

### 2.1 Core lexer structure
- [x] `Lex` struct with position tracking (offset, line, column)
- [x] `lex_init()` - Initialize lexer with input string
- [x] `lex_peek()` - Peek next character without consuming
- [x] `lex_advance()` - Consume and return next character
- [x] `lex_create_token()` - Create token with position info

### 2.2 Token scanning
- [x] `lex_scan_token()` - Main scanning dispatch
- [x] Whitespace handling (space, tab, but NOT newline - it's significant)
- [x] Comment handling (`#` to end of line -> treat as newline)
- [x] Keyword recognition (after identifier scan)
- [x] Operator scanning (handle multi-char ops like `==`, `->`, etc.)
- [x] Special lambda tokens: `)-> ` and `)->{` (includes trailing chars)

### 2.3 Literal scanning
- [x] `lex_scan_number()` - integers, floats, hex, octal
- [x] `lex_scan_string()` - double-quoted with escape sequences
- [x] `lex_scan_identifier()` - unicode-aware identifiers
- [x] `lex_scan_symbol()` - `:identifier`
- [x] `lex_scan_time()` - date/time literals

### 2.4 TRAIL handling
- [x] Implement optional trailing whitespace/comment/newline after operators
- [x] This allows operators to span lines in certain contexts

---

## Phase 3: AST Node Definition

### 3.1 Literal nodes
- [x] `Node_Int` - integer value (i64)
- [x] `Node_Float` - float value (f64)
- [x] `Node_Time` - sec, usec, utc_offset
- [x] `Node_String` - string value
- [x] `Node_Bool` - boolean (true/false)
- [x] `Node_Nil` - nil singleton

### 3.2 Collection nodes
- [x] `Node_Array` - array literal with optional headers (for structs)
- [x] `Node_Nodes` - list of statements/expressions
- [x] `Node_Args` - function argument names list
- [x] `Node_Pair` - key:value pair (for labeled arguments)
- [x] `Node_Splat` - splat operator (*expr)

### 3.3 Expression nodes
- [x] `Node_Ident` - identifier reference
- [x] `Node_Op` - binary/unary operation (op, lhs, rhs)
- [x] `Node_If` - conditional (cond, then, opt_else)
- [x] `Node_Lambda` - function/block (args, body, is_block)
- [x] `Node_Call` - function call (ident, args)
- [x] `Node_Fcall` - indirect call (func_expr, args)
- [x] `Node_Genfunc` - generic function reference (&fname)

### 3.4 Statement nodes
- [x] `Node_Let` - variable binding (lhs, rhs)
- [x] `Node_Emit` - emit statement
- [x] `Node_Skip` - skip statement
- [x] `Node_Return` - return statement

### 3.5 Top-level nodes
- [x] `Node_Namespace` - namespace/class definition
- [x] `Node_Import` - import statement

### 3.6 Pattern matching nodes
- [x] `Node_PArray` - pattern array
- [x] `Node_PStruct` - pattern struct
- [x] `Node_PSplat` - pattern with splat (head, mid, tail)
- [x] `Node_PLambda` - pattern lambda (pat, cond, body, next)

### 3.7 Node utilities
- [x] `node_new()` - generic node creation
- [x] `node_free()` - recursive node deallocation
- [x] Position info in nodes (fname, lineno)

---

## Phase 4: Push Parser Implementation

### 4.1 Parser state machine
Reference: calc_odin's `Parse_State_Kind` enum approach

- [x] Define `Parse_State_Kind` enum for all grammar states
- [x] `Parse_State` struct with state and current node pointer
- [x] `Parser` struct with state stack, root node, error info

### 4.2 State groups (from parse.y grammar)

#### Program/Top-level states
- [x] `Start`, `End`, `Error`
- [x] `Program` - entry point
- [x] `Topstmts`, `Topstmt_List`, `Topstmt`
- [x] `Namespace_Body`, `Namespace_Close`
- [x] `Import_`
- [x] `Method_Def`, `Method_Args`, `Method_Body`

#### Statement states
- [x] `Stmts`, `Stmt_Term`, `Stmt`
- [x] `Let_Assign`, `Let_Assign_Rasgn` - var = expr
- [x] `Def_Func`, `Def_Args`, `Def_Close_Paren`, `Def_Body_Start`, `Def_Body`
- [x] `Emit_`, `Skip_`, `Return_`

#### Expression states (precedence-based)
- [x] `Expr` - full expression
- [x] `Expr_Op` - operator handling
- [x] `Expr_Rhs`, `Expr_Rhs_Op` - right-hand side parsing
- [x] `Unary` - unary operators

#### Primary states
- [x] `Primary` - base expressions
- [x] `Paren_Expr`, `Paren_Close` - parenthesized expression
- [x] `Array_Literal`, `Array_Args`, `Array_Args_Next`, `Array_Close`
- [x] `Block`, `Block_Content`, `Block_Params`, `Block_Body`, `Block_Close`
- [x] `If_Cond`, `If_Cond_Close`, `If_Then`, `If_Else`
- [x] `Func_Call`, `Func_Args`, `Func_Args_Expr`, `Func_Args_Next`, `Func_Close`, `Func_Opt_Block`
- [x] `Method_Call`, `Method_Name`, `Method_Args_Start`
- [x] `New_Expr`, `New_Args`, `New_Close`
- [x] `Lambda_Expr`, `Lambda_Args`, `Lambda_Body`
- [x] `Genfunc`

#### Pattern matching states
- [x] `Pattern`, `Pterm`, `Pary`, `Pary_Next`, `Pstruct`, `Pstruct_Next`, `Psplat`
- [x] `Case_Body`, `Case_Pattern`, `Case_Cond`, `Case_Stmts`
- [x] `Plambda`

### 4.3 Core parser functions
- [x] `parser_new()` - create and initialize parser
- [x] `parser_destroy()` - cleanup parser
- [x] `parser_reset()` - reset for new input
- [x] `parser_begin()` - push new state
- [x] `parser_end()` - pop state
- [x] `parser_set_state()` - update current state
- [x] `parser_get_state()` - get current state
- [x] `parser_error()` - transition to error state

### 4.4 Token push interface
- [x] `parser_push_token()` - main entry point
- [x] State dispatch with switch statement
- [x] Token consumption tracking

### 4.5 Grammar-specific parse functions
Following calc_odin pattern of separate functions per state group:
- [x] `parse_program()` - program entry
- [x] `parse_topstmt()` - top-level statements
- [x] `parse_stmts()` - statement lists
- [x] `parse_stmt()` - statements
- [x] `parse_expr()` - expression with precedence climbing
- [x] `parse_primary()` - primary expressions
- [x] `parse_if()` - if expression
- [x] `parse_func_call()` - function calls
- [x] `parse_case()` - pattern matching

---

## Phase 5: Operator Precedence

From parse.y (lowest to highest):
```
1.  op_LOWEST (marker)
2.  -> )-> )->{  (lambda, right assoc)
3.  else        (right assoc)
4.  if          (right assoc)
5.  |           (pipe, left assoc)
6.  &           (bitwise and, left assoc)
7.  ||          (logical or, left assoc)
8.  &&          (logical and, left assoc)
9.  == !=       (equality, nonassoc)
10. < <= > >=   (comparison, left assoc)
11. + -         (additive, left assoc)
12. * / %       (multiplicative, left assoc)
13. ! ~         (unary, right assoc)
14. op_HIGHEST  (marker)
```

- [x] Implement precedence climbing in `parse_expr()`
- [x] Handle associativity correctly with `is_right_assoc()`
- [x] Handle special cases (if-else, lambdas)

---

## Phase 6: Parser Testing

### 6.1 Lexer tests
- [x] All token types (lex_test.odin)
- [x] Edge cases (unicode, escapes, special literals)
- [x] Error handling

### 6.2 Parser tests (parse_test.odin - 25+ tests)
- [x] Simple expressions: `1 + 2`, `a * b + c`
- [x] Operator precedence: `1 + 2 * 3`
- [x] Statements: `x = 1`, `emit x`
- [x] Function definitions: `def foo(a, b) { a + b }`
- [x] Function calls: `foo(1, 2)`
- [x] Blocks: `{ 1 }`
- [x] Conditionals: `if (x) 1 else 2`
- [x] Pipelines: `a | b`
- [x] Namespaces: `namespace Foo { x = 1 }`
- [x] Import: `import Foo`
- [x] Genfunc: `&foo`
- [x] Arrays: `[1, 2, 3]`, `[]`
- [x] Literals: integers, floats, strings, nil, true, false
- [x] Skip, emit, return statements

### 6.3 Integration tests
- [ ] Parse example files from `examples/` directory
- [ ] Compare AST structure with C implementation output

---

## Phase 7: Main Program (Parser Only)

### 7.1 CLI interface
- [x] File input mode
- [x] String input mode (`-e`)
- [x] Syntax check mode (`-c`)
- [x] Verbose/AST dump mode (`-v`)

### 7.2 REPL (optional)
- [ ] Interactive parsing mode
- [ ] Line continuation for incomplete input

---

## Phase 8: Value Representation (NaN-boxing)

Reference: `src/strm.h`, `src/value.c`

### 8.1 Value type system
streem uses NaN-boxing: 64-bit values where NaN bit patterns encode type tags.

```
Tag Layout (upper 16 bits when NaN):
0xFFF0 | tag_id << 48

Tags:
- STRM_TAG_NAN      = 0xFFF0 (actual NaN)
- STRM_TAG_BOOL     = 0xFFF1
- STRM_TAG_INT      = 0xFFF2
- STRM_TAG_LIST     = 0xFFF3
- STRM_TAG_ARRAY    = 0xFFF4
- STRM_TAG_STRUCT   = 0xFFF5
- STRM_TAG_STRING_I = 0xFFF7 (interned)
- STRM_TAG_STRING_6 = 0xFFF8 (short, inline)
- STRM_TAG_STRING_O = 0xFFF9 (owned)
- STRM_TAG_STRING_F = 0xFFFA (foreign/static)
- STRM_TAG_CFUNC    = 0xFFFB
- STRM_TAG_PTR      = 0xFFFD
- STRM_TAG_FOREIGN  = 0xFFFF
```

### 8.2 Value struct and operations
- [x] `Strm_Value` - u64 type alias
- [x] `strm_value_tag()` - extract tag from value
- [x] `strm_value_val()` - extract payload from value

### 8.3 Value constructors
- [x] `strm_nil_value()` - create nil (PTR tag with 0 payload)
- [x] `strm_bool_value(bool)` - create boolean
- [x] `strm_int_value(i32)` - create integer
- [x] `strm_float_value(f64)` - create float (raw bits, no tag for valid floats)
- [x] `strm_cfunc_value(cfunc)` - create C function reference
- [x] `strm_ptr_value(ptr)` - create pointer value
- [x] `strm_foreign_value(ptr)` - create foreign pointer

### 8.4 Value extractors
- [x] `strm_value_bool()` - extract boolean
- [x] `strm_value_int()` - extract integer
- [x] `strm_value_float()` - extract float
- [x] `strm_value_cfunc()` - extract C function
- [x] `strm_value_ptr()` - extract pointer with type check

### 8.5 Type predicates
- [x] `strm_nil_p()` - is nil?
- [x] `strm_bool_p()` - is boolean?
- [x] `strm_int_p()` - is integer?
- [x] `strm_float_p()` - is float?
- [x] `strm_number_p()` - is int or float?
- [x] `strm_cfunc_p()` - is C function?
- [x] `strm_string_p()` - is string?
- [x] `strm_array_p()` - is array?
- [x] `strm_lambda_p()` - is lambda?
- [x] `strm_stream_p()` - is stream?

### 8.6 Value equality and conversion
- [x] `strm_value_eq()` - compare two values
- [x] `strm_to_str()` - convert any value to string
- [x] `strm_inspect()` - debug representation

---

## Phase 9: String and Array Types

Reference: `src/strm.h`, `src/string.c`, `src/array.c`

### 9.1 String representation
```
strm_string is a u64 with various tag types:
- STRING_I: interned (symbol-like, unique)
- STRING_6: short string (≤6 bytes inline)
- STRING_O: owned (heap allocated, needs free)
- STRING_F: foreign/static (no ownership)
```

- [x] `Strm_String` type
- [x] `strm_str_new(ptr, len)` - create owned string
- [x] `strm_str_static(ptr, len)` - create static string reference
- [x] `strm_str_intern(ptr, len)` - create/get interned string
- [x] `strm_str_ptr()` - get string pointer
- [x] `strm_str_len()` - get string length
- [x] `strm_str_eq()` - compare strings
- [x] `strm_str_cstr()` - get null-terminated C string

### 9.2 Array representation
```
struct strm_array {
  len: i32,
  ptr: ^Strm_Value,   // array elements
  headers: strm_array, // optional field names (for struct-like arrays)
  ns: ^Strm_State,    // optional namespace (for typed objects)
}
```

- [x] `Strm_Array` type (tagged pointer to struct)
- [x] `strm_ary_new(ptr, len)` - create array
- [x] `strm_ary_ptr()` - get element pointer
- [x] `strm_ary_len()` - get length
- [x] `strm_ary_headers()` - get headers array
- [x] `strm_ary_ns()` - get namespace
- [x] `strm_ary_eq()` - compare arrays

---

## Phase 10: Namespace and State Management

Reference: `src/strm.h`, `src/ns.c`

### 10.1 State structure
```
strm_state represents a scope/namespace:
- env: hash table for variable bindings
- prev: parent scope (lexical scoping)
- flags: namespace properties (e.g., STRM_NS_UDEF for user-defined)
```

- [x] `Strm_State` struct
- [x] Hash table for environment (using Odin map with Strm_String keys)

### 10.2 Variable operations
- [x] `strm_var_def(state, name, value)` - define new variable
- [x] `strm_var_set(state, name, value)` - set variable (create if not exists)
- [x] `strm_var_get(state, name, *value)` - get variable value
- [x] `strm_var_match(state, name, value)` - pattern match assignment
- [x] `strm_env_copy(dst, src)` - copy environment (for import)

### 10.3 Namespace operations
- [x] `strm_ns_new(parent, name)` - create named namespace
- [x] `strm_ns_create(parent, name)` - create and register namespace
- [x] `strm_ns_get(name)` - look up namespace by name
- [x] `strm_value_ns(value)` - get namespace of a value
- [x] Global namespaces: `strm_ns_array`, `strm_ns_string`, `strm_ns_number`

---

## Phase 11: AST Evaluator

Reference: `src/exec.c`

### 11.1 Core evaluation
- [ ] `exec_expr(strm, state, node, *ret)` - main evaluation dispatch
- [ ] Error handling with `node_error` struct
- [ ] Error types: RUNTIME, RETURN, SKIP

### 11.2 Literal evaluation
- [ ] NODE_INT -> `strm_int_value`
- [ ] NODE_FLOAT -> `strm_float_value`
- [ ] NODE_BOOL -> `strm_bool_value`
- [ ] NODE_NIL -> `strm_nil_value`
- [ ] NODE_STR -> `strm_str_value`
- [ ] NODE_TIME -> `strm_time_new`

### 11.3 Expression evaluation
- [ ] NODE_IDENT - variable lookup
- [ ] NODE_OP - operator dispatch (calls registered functions)
- [ ] NODE_IF - conditional evaluation
- [ ] NODE_ARRAY - array construction with splat support

### 11.4 Statement evaluation
- [ ] NODE_LET - variable assignment
- [ ] NODE_EMIT - emit to downstream
- [ ] NODE_SKIP - skip current value (set exception)
- [ ] NODE_RETURN - return value (set exception)
- [ ] NODE_NODES - sequential evaluation

### 11.5 Function handling
- [ ] NODE_LAMBDA / NODE_PLAMBDA - create lambda closure
- [ ] NODE_CALL - named function call
- [ ] NODE_FCALL - indirect function call
- [ ] NODE_GENFUNC - generic function reference
- [ ] `strm_funcall()` - dispatch function call by type
- [ ] `lambda_call()` - evaluate lambda body with arguments

### 11.6 Pattern matching
- [ ] `pmatch(strm, state, pat, val)` - match value against pattern
- [ ] `pattern_match(strm, state, npat, argc, argv)` - match array of args
- [ ] NODE_PARRAY - array pattern
- [ ] NODE_PSTRUCT - struct pattern (labeled fields)
- [ ] NODE_PSPLAT - splat pattern (head, *mid, tail)
- [ ] Placeholder `_` handling

### 11.7 Namespace/Import
- [ ] NODE_NS - create and enter namespace
- [ ] NODE_IMPORT - copy bindings from namespace

---

## Phase 12: Stream Runtime

Reference: `src/core.c`, `src/queue.c`

### 12.1 Stream modes
```
strm_stream_mode:
- strm_producer: generates data (e.g., seq, file read)
- strm_filter: transforms data (e.g., map, filter)
- strm_consumer: consumes data (e.g., file write, stdout)
- strm_dying: closing
- strm_killed: closed
```

### 12.2 Stream structure
```
strm_stream:
- type: STRM_PTR_STREAM
- flags: state flags
- mode: producer/filter/consumer
- start_func: callback when data arrives
- close_func: callback when stream closes
- data: user data pointer
- dst: primary downstream connection
- rest: additional downstream connections
- queue: per-stream task queue
- refcnt: reference count
- excl: exclusion flag for thread safety
- exc: current exception
```

- [ ] `Strm_Stream` struct
- [ ] `strm_stream_new(mode, start_func, close_func, data)` - create stream
- [ ] `strm_stream_close(strm)` - close stream and propagate

### 12.3 Stream connection
- [ ] `strm_stream_connect(src, dst)` - connect two streams
- [ ] `strm_connect(strm, src_val, dst_val, *ret)` - high-level pipe operator
  - Converts IO/lambda/array to stream as needed
  - Called by `|` operator

### 12.4 Data emission
- [ ] `strm_emit(strm, data, cb)` - emit data to downstream
  - Pushes task to destination's queue
  - Optionally schedules callback on self
- [ ] `strm_io_emit(strm, data, fd, cb)` - emit with IO callback

### 12.5 Task queue (lock-free)
Reference: `src/queue.c`, `src/atomic.h`

```
strm_task:
- func: callback function
- data: argument value

strm_queue: lock-free FIFO queue
```

- [ ] `Strm_Task` struct
- [ ] `Strm_Queue` struct (lock-free linked list)
- [ ] `strm_task_new(func, data)` - create task
- [ ] `strm_task_push(strm, func, data)` - add task to stream's queue
- [ ] `strm_task_add(strm, task)` - add task and enqueue stream
- [ ] `strm_queue_new()` - create queue
- [ ] `strm_queue_add(q, val)` - enqueue (lock-free CAS)
- [ ] `strm_queue_get(q)` - dequeue (lock-free CAS)
- [ ] `strm_queue_empty_p(q)` - check if empty
- [ ] Atomic operations: CAS, increment, decrement

### 12.6 Worker thread pool
```
Global queues:
- prod_queue: producer tasks (prioritized)
- queue: filter/consumer tasks
```

- [ ] `worker_init()` - initialize worker threads
- [ ] `task_loop()` - worker thread function
  - Dequeue from prod_queue first, then queue
  - Execute tasks with exclusion flag
- [ ] `strm_loop()` - main event loop (waits for completion)
- [ ] `worker_count()` - determine thread count (env STRM_WORKER_MAX or CPU count)

### 12.7 Exception handling
- [ ] `strm_raise(strm, msg)` - set runtime error
- [ ] `strm_set_exc(strm, type, arg)` - set exception
- [ ] `strm_clear_exc(strm)` - clear exception
- [ ] `strm_eprint(strm)` - print exception

---

## Phase 13: I/O Streams

Reference: `src/io.c`

### 13.1 IO structure
```
strm_io:
- type: STRM_PTR_IO
- fd: file descriptor
- mode: READ/WRITE/FLUSH/READING flags
- read_stream: cached read stream
- write_stream: cached write stream
```

- [ ] `Strm_IO` struct
- [ ] `strm_io_new(fd, mode)` - create IO object
- [ ] `strm_io_stream(io, mode)` - get stream for IO (read or write)

### 13.2 Read stream
- [ ] Line-buffered reading with `fd_read_buffer`
- [ ] `stdio_read()` - start async read
- [ ] `read_cb()` - read callback (fills buffer)
- [ ] `readline_cb()` - emit lines from buffer
- [ ] `strm_io_start_read(strm, fd, cb)` - register for epoll

### 13.3 Write stream
- [ ] `write_cb()` - write callback
- [ ] `write_close()` - close callback

### 13.4 Event loop (epoll/kqueue)
- [ ] `strm_init_io_loop()` - initialize epoll
- [ ] `io_loop()` - IO worker thread
- [ ] `io_push()` / `io_kick()` / `io_pop()` - epoll operations

---

## Phase 14: Built-in Functions

Reference: `src/init.c`, `src/iter.c`, `src/number.c`, etc.

### 14.1 Initialization
- [ ] `strm_init(state)` - register all built-ins

### 14.2 Core built-ins (exec.c)
- [ ] `stdin`, `stdout`, `stderr` - IO objects
- [ ] `puts`, `print` - output functions
- [ ] `==`, `!=` - equality operators
- [ ] `|` - pipe operator
- [ ] `fread`, `fwrite` - file IO
- [ ] `exit` - exit program
- [ ] `match` - pattern matching helper

### 14.3 Number operations (number.c)
- [ ] `+`, `-`, `*`, `/`, `%` - arithmetic
- [ ] `<`, `<=`, `>`, `>=` - comparison
- [ ] `&&`, `||` - logical
- [ ] `&`, `|` - bitwise (on integers)
- [ ] Unary `-`, `!`, `~`

### 14.4 Iterator/Stream functions (iter.c)
Producers:
- [ ] `seq(start, end, step)` - number sequence
- [ ] `repeat(value, count)` - repeat value
- [ ] `cycle(array, count)` - cycle through array

Transformers:
- [ ] `each(func)` - apply function (no emit)
- [ ] `map(func)` - transform elements
- [ ] `flatmap(func)` - transform and flatten
- [ ] `filter(func)` - filter elements

Aggregators:
- [ ] `count()` - count elements
- [ ] `min(func?)`, `max(func?)` - find min/max
- [ ] `reduce(init?, func)` - reduce to single value
- [ ] `reduce_by_key(func)` - group and reduce

Windowing:
- [ ] `slice(n)` - group into n-element arrays
- [ ] `consec(n)` - sliding window of n elements
- [ ] `take(n)` - take first n elements
- [ ] `drop(n)` - drop first n elements
- [ ] `uniq(func?)` - remove consecutive duplicates

### 14.5 Array functions (array.c)
- [ ] `each`, `map`, `flatmap` - array versions
- [ ] `length` - array length
- [ ] Index access via function call syntax

### 14.6 String functions (string.c)
- [ ] `length` - string length
- [ ] `split(delim)` - split string
- [ ] String comparison and manipulation

### 14.7 Math functions (math.c)
- [ ] `sin`, `cos`, `tan`, etc.
- [ ] `sqrt`, `pow`, `log`, etc.
- [ ] `abs`, `floor`, `ceil`, `round`

### 14.8 Other built-ins
- [ ] `random` - random number generation (random.c)
- [ ] `sort` - sorting (sort.c)
- [ ] `stat` - statistics (stat.c)
- [ ] `csv` - CSV parsing (csv.c)
- [ ] `socket`, `tcp_server`, `tcp_socket` - networking (socket.c)
- [ ] Time functions (time.c)
- [ ] Graph operations (graph.c)
- [ ] Key-value store (kvs.c)
- [ ] Latch/synchronization (latch.c)

---

## Phase 15: Full Integration Testing

### 15.1 Example programs
- [ ] `01cat.strm` - stdin | stdout
- [ ] `02hello.strm` - hello world
- [ ] Basic sequence operations
- [ ] Map/filter/reduce pipelines
- [ ] File I/O operations

### 15.2 Performance testing
- [ ] Stream throughput
- [ ] Memory usage
- [ ] Thread scaling

### 15.3 Edge cases
- [ ] Error propagation
- [ ] Stream cancellation
- [ ] Resource cleanup

---

## Implementation Notes

### Push Parser Pattern (from calc_odin)
1. State stack holds current parsing context
2. Each state knows what tokens it expects
3. On token input:
   - Check if token matches expected
   - If yes: consume, update state, possibly push new state
   - If no: either complete current state or error
4. States can push child states and wait for completion
5. Use `^^Node` (pointer to node pointer) for building AST bottom-up

### Key Differences from calc_odin
1. More complex grammar (statements, not just expressions)
2. Newline is significant (statement terminator)
3. Multiple top-level constructs (namespace, def, method)
4. Pattern matching support
5. Stream pipeline operators

### TRAIL Handling
Some operators in streem allow trailing whitespace/comments/newlines.
This affects how tokens are scanned and consumed.
May need lookahead or special token variants.

### Odin Threading Considerations
- Odin has `core:thread` and `core:sync` for threading
- May need custom lock-free queue implementation
- Consider using Odin's `core:sync/atomic` for CAS operations

### NaN-boxing in Odin
- Use `transmute` for float <-> u64 conversions
- Be careful with NaN propagation
- Test thoroughly on target architecture

### Test File Naming Convention
Test files should be separated by module and follow the naming pattern `{module}_test.odin`:

| Source File | Test File |
|------------|-----------|
| `lex.odin` | `lex_test.odin` |
| `token.odin` | `token_test.odin` |
| `node.odin` | `node_test.odin` |
| `value.odin` | `value_test.odin` |
| `state.odin` | `state_test.odin` |
| `queue.odin` | `queue_test.odin` |
| `stream.odin` | `stream_test.odin` |
| `exec.odin` | `exec_test.odin` |
| `parse.odin` | `parse_test.odin` |

Rules:
1. Each test file contains only tests for its corresponding module
2. Test files use the same `package streem` declaration
3. Test procedures are annotated with `@(test)`
4. Test procedure names follow the pattern `test_{module}_{what}` (e.g., `test_lex_keywords`)
5. Use `core:testing` package for assertions

Run tests with:
```shell
odin test streem_odin/
```

---

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1. Setup | **Completed** | Project structure and token definitions |
| 2. Lexer | **Completed** | Token scanning with TRAIL handling |
| 3. Nodes | **Completed** | AST node definitions with all types |
| 4. Parser | **Completed** | Push parser with state machine |
| 5. Precedence | **Completed** | Precedence climbing implementation |
| 6. Parser Test | **Completed** | 71 tests passing |
| 7. Main (Parse) | **Completed** | CLI for parsing (file, -e, -c, -v) |
| 8. Values | **Completed** | NaN-boxing with 76 tests passing |
| 9. Str/Array | **Completed** | String/Array types with 99 tests passing |
| 10. Namespace | **Completed** | State/namespace management with 109 tests passing |
| 11. Evaluator | Not Started | AST execution |
| 12. Runtime | Not Started | Stream/threading |
| 13. I/O | Not Started | File/network IO |
| 14. Built-ins | Not Started | Standard library |
| 15. Integration | Not Started | Full testing |

---

## References

### Parser
- `calc_odin/` - Reference push parser implementation
- `src/parse.y` - Original bison grammar
- `src/lex.l` - Original flex lexer
- `src/node.h` - Original AST node definitions
- `src/node.c` - Original node implementation

### Runtime
- `src/strm.h` - Main header (values, streams, state)
- `src/value.c` - Value operations
- `src/exec.c` - AST evaluator
- `src/core.c` - Stream runtime, worker threads
- `src/queue.c` - Lock-free task queue
- `src/atomic.h` - Atomic operations

### I/O and Built-ins
- `src/io.c` - I/O streams
- `src/iter.c` - Iterator functions
- `src/init.c` - Built-in registration
- `src/number.c`, `src/string.c`, `src/array.c` - Type operations
