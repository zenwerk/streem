# Streem Odin Port - Implementation Plan

## Overview

Port streem language from C (flex/bison) to Odin with a push-style parser.
Reference implementation: `calc_odin/` directory.

**Scope**: Full runtime implementation including stream processing and built-in functions.

---

## Phase 1: Project Setup & Token Definition

### 1.1 Create project structure
- [ ] Create `streem_odin/` directory
- [ ] Create `lex.odin` - Lexer
- [ ] Create `token.odin` - Token types
- [ ] Create `node.odin` - AST nodes
- [ ] Create `parse.odin` - Push parser
- [ ] Create `value.odin` - Runtime values (NaN-boxing)
- [ ] Create `state.odin` - Namespace/scope management
- [ ] Create `stream.odin` - Stream runtime
- [ ] Create `queue.odin` - Thread-safe task queue
- [ ] Create `exec.odin` - AST evaluator
- [ ] Create `builtin/` - Built-in functions directory
- [ ] Create `main.odin` - Entry point
- [ ] Create `test.odin` - Unit tests

### 1.2 Define Token Types (from lex.l)
- [ ] Keywords:
  - `if`, `else`, `case`, `emit`, `skip`, `return`
  - `namespace`, `class`, `import`
  - `def`, `method`, `new`
  - `nil`, `true`, `false`
- [ ] Operators:
  - Arithmetic: `+`, `-`, `*`, `/`, `%`
  - Comparison: `==`, `!=`, `<`, `<=`, `>`, `>=`
  - Logical: `&&`, `||`, `!`
  - Bitwise: `&`, `|`, `~`
  - Assignment: `=`, `<-`, `=>`
  - Lambda: `->`, `)-> `, `)->{`
  - Scope: `::`
- [ ] Delimiters: `(`, `)`, `[`, `]`, `{`, `}`, `,`, `;`, `:`, `.`, `@`
- [ ] Literals:
  - Integer (decimal, hex `0x`, octal `0o`)
  - Float
  - String (double-quoted with escapes)
  - Symbol (`:identifier`)
  - Time (`YYYY.MM.DD` or `YYYY.MM.DDThh:mm:ss`)
- [ ] Identifier (unicode-aware)
- [ ] Label (`identifier:`)
- [ ] Newline (significant for statement termination)
- [ ] EOF, Error

---

## Phase 2: Lexer Implementation

### 2.1 Core lexer structure
- [ ] `Lex` struct with position tracking (offset, line, column)
- [ ] `lex_init()` - Initialize lexer with input string
- [ ] `lex_peek()` - Peek next character without consuming
- [ ] `lex_advance()` - Consume and return next character
- [ ] `lex_create_token()` - Create token with position info

### 2.2 Token scanning
- [ ] `lex_scan_token()` - Main scanning dispatch
- [ ] Whitespace handling (space, tab, but NOT newline - it's significant)
- [ ] Comment handling (`#` to end of line -> treat as newline)
- [ ] Keyword recognition (after identifier scan)
- [ ] Operator scanning (handle multi-char ops like `==`, `->`, etc.)
- [ ] Special lambda tokens: `)-> ` and `)->{` (includes trailing chars)

### 2.3 Literal scanning
- [ ] `lex_scan_number()` - integers, floats, hex, octal
- [ ] `lex_scan_string()` - double-quoted with escape sequences
- [ ] `lex_scan_identifier()` - unicode-aware identifiers
- [ ] `lex_scan_symbol()` - `:identifier`
- [ ] `lex_scan_time()` - date/time literals

### 2.4 TRAIL handling
- [ ] Implement optional trailing whitespace/comment/newline after operators
- [ ] This allows operators to span lines in certain contexts

---

## Phase 3: AST Node Definition

### 3.1 Literal nodes
- [ ] `Node_Int` - integer value (i64)
- [ ] `Node_Float` - float value (f64)
- [ ] `Node_Time` - sec, usec, utc_offset
- [ ] `Node_String` - string value
- [ ] `Node_Bool` - boolean (true/false)
- [ ] `Node_Nil` - nil singleton

### 3.2 Collection nodes
- [ ] `Node_Array` - array literal with optional headers (for structs)
- [ ] `Node_Nodes` - list of statements/expressions
- [ ] `Node_Args` - function argument names list
- [ ] `Node_Pair` - key:value pair (for labeled arguments)
- [ ] `Node_Splat` - splat operator (*expr)

### 3.3 Expression nodes
- [ ] `Node_Ident` - identifier reference
- [ ] `Node_Op` - binary/unary operation (op, lhs, rhs)
- [ ] `Node_If` - conditional (cond, then, opt_else)
- [ ] `Node_Lambda` - function/block (args, body, is_block)
- [ ] `Node_Call` - function call (ident, args)
- [ ] `Node_Fcall` - indirect call (func_expr, args)
- [ ] `Node_Genfunc` - generic function reference (&fname)

### 3.4 Statement nodes
- [ ] `Node_Let` - variable binding (lhs, rhs)
- [ ] `Node_Emit` - emit statement
- [ ] `Node_Skip` - skip statement
- [ ] `Node_Return` - return statement

### 3.5 Top-level nodes
- [ ] `Node_Namespace` - namespace/class definition
- [ ] `Node_Import` - import statement

### 3.6 Pattern matching nodes
- [ ] `Node_PArray` - pattern array
- [ ] `Node_PStruct` - pattern struct
- [ ] `Node_PSplat` - pattern with splat (head, mid, tail)
- [ ] `Node_PLambda` - pattern lambda (pat, cond, body, next)

### 3.7 Node utilities
- [ ] `node_new()` - generic node creation
- [ ] `node_free()` - recursive node deallocation
- [ ] Position info in nodes (fname, lineno)

---

## Phase 4: Push Parser Implementation

### 4.1 Parser state machine
Reference: calc_odin's `Parse_State_Kind` enum approach

- [ ] Define `Parse_State_Kind` enum for all grammar states
- [ ] `Parse_State` struct with state and current node pointer
- [ ] `Parse` struct with state stack, root node, error info

### 4.2 State groups (from parse.y grammar)

#### Program/Top-level states
- [ ] `Start`, `End`, `Error`
- [ ] `Program` - entry point
- [ ] `Topstmts`, `Topstmt_List`, `Topstmt`
- [ ] `Namespace_Body`, `Class_Body`
- [ ] `Import`
- [ ] `Method_Def`, `Method_Args`, `Method_Body`

#### Statement states
- [ ] `Stmts`, `Stmt_List`, `Stmt`
- [ ] `Let_Assign` - var = expr
- [ ] `Def_Func`, `Def_Args`, `Def_Body` - function definition
- [ ] `Emit`, `Skip`, `Return`

#### Expression states (precedence-based like calc_odin)
- [ ] `Expr` - full expression
- [ ] `Expr_Or` - || operator
- [ ] `Expr_And` - && operator
- [ ] `Expr_Eq` - ==, != operators
- [ ] `Expr_Cmp` - <, <=, >, >= operators
- [ ] `Expr_Add` - +, - operators
- [ ] `Expr_Mul` - *, /, % operators
- [ ] `Expr_Unary` - !, ~, unary +/-
- [ ] `Expr_Pipe` - | operator (stream pipe)
- [ ] `Expr_Amper` - & operator

#### Primary states
- [ ] `Primary` - base expressions
- [ ] `Paren_Expr`, `Paren_Close` - parenthesized expression
- [ ] `Array_Literal`, `Array_Args` - [args]
- [ ] `Block`, `Block_Params`, `Block_Body` - {stmts} or {params -> stmts}
- [ ] `If_Cond`, `If_Then`, `If_Else` - if condition
- [ ] `Func_Call`, `Func_Args`, `Func_Args_Next` - function(args)
- [ ] `Method_Call` - expr.method(args)
- [ ] `New_Expr` - new ClassName[args]
- [ ] `Lambda_Expr` - (args)-> expr or (args)->{stmts}

#### Pattern matching states
- [ ] `Pattern`, `Pterm`, `Pary`, `Pstruct`
- [ ] `Psplat` - pattern with *
- [ ] `Case_Body`, `Case_Pattern`, `Case_Cond`
- [ ] `Plambda` - pattern lambda

### 4.3 Core parser functions
- [ ] `parse_new()` - create and initialize parser
- [ ] `parse_destroy()` - cleanup parser
- [ ] `parse_reset()` - reset for new input
- [ ] `parse_begin()` - push new state
- [ ] `parse_end()` - pop state
- [ ] `parse_set_state()` - update current state
- [ ] `parse_get_state()` - get current state
- [ ] `parse_error()` - transition to error state

### 4.4 Token push interface
- [ ] `parse_push_token()` - main entry point
- [ ] State dispatch loop (like calc_odin's `is_between` approach)
- [ ] Token consumption tracking

### 4.5 Grammar-specific parse functions
Following calc_odin pattern of separate functions per state group:
- [ ] `parse_program()` - program entry
- [ ] `parse_topstmt()` - top-level statements
- [ ] `parse_stmt()` - statements
- [ ] `parse_expr_*()` - expression by precedence level
- [ ] `parse_primary()` - primary expressions
- [ ] `parse_block()` - blocks
- [ ] `parse_func_call()` - function calls
- [ ] `parse_pattern()` - pattern matching
- [ ] `parse_lambda()` - lambda expressions

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

- [ ] Implement precedence climbing or Pratt parser variant
- [ ] Handle associativity correctly
- [ ] Handle special cases (if-else, lambdas)

---

## Phase 6: Parser Testing

### 6.1 Lexer tests
- [ ] All token types
- [ ] Edge cases (unicode, escapes, special literals)
- [ ] Error handling

### 6.2 Parser tests
- [ ] Simple expressions: `1 + 2`, `a * b + c`
- [ ] Operator precedence: `1 + 2 * 3`, `(1 + 2) * 3`
- [ ] Statements: `x = 1`, `emit x`
- [ ] Function definitions: `def foo(x) { x + 1 }`
- [ ] Function calls: `foo(1, 2)`, `obj.method()`
- [ ] Lambdas: `{x -> x + 1}`, `(x, y)-> x + y`
- [ ] Conditionals: `if (x > 0) x else -x`
- [ ] Pattern matching: `{case [h, *t] -> h}`
- [ ] Pipelines: `stdin | filter | stdout`
- [ ] Namespaces: `namespace Foo { ... }`

### 6.3 Integration tests
- [ ] Parse example files from `examples/` directory
- [ ] Compare AST structure with C implementation output

---

## Phase 7: Main Program (Parser Only)

### 7.1 CLI interface
- [ ] File input mode
- [ ] String input mode (`-e`)
- [ ] Syntax check mode (`-c`)
- [ ] Verbose/AST dump mode (`-v`)

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
- [ ] `Strm_Value` - u64 type alias
- [ ] `strm_value_tag()` - extract tag from value
- [ ] `strm_value_val()` - extract payload from value

### 8.3 Value constructors
- [ ] `strm_nil_value()` - create nil (PTR tag with 0 payload)
- [ ] `strm_bool_value(bool)` - create boolean
- [ ] `strm_int_value(i32)` - create integer
- [ ] `strm_float_value(f64)` - create float (raw bits, no tag for valid floats)
- [ ] `strm_cfunc_value(cfunc)` - create C function reference
- [ ] `strm_ptr_value(ptr)` - create pointer value
- [ ] `strm_foreign_value(ptr)` - create foreign pointer

### 8.4 Value extractors
- [ ] `strm_value_bool()` - extract boolean
- [ ] `strm_value_int()` - extract integer
- [ ] `strm_value_float()` - extract float
- [ ] `strm_value_cfunc()` - extract C function
- [ ] `strm_value_ptr()` - extract pointer with type check

### 8.5 Type predicates
- [ ] `strm_nil_p()` - is nil?
- [ ] `strm_bool_p()` - is boolean?
- [ ] `strm_int_p()` - is integer?
- [ ] `strm_float_p()` - is float?
- [ ] `strm_number_p()` - is int or float?
- [ ] `strm_cfunc_p()` - is C function?
- [ ] `strm_string_p()` - is string?
- [ ] `strm_array_p()` - is array?
- [ ] `strm_lambda_p()` - is lambda?
- [ ] `strm_stream_p()` - is stream?

### 8.6 Value equality and conversion
- [ ] `strm_value_eq()` - compare two values
- [ ] `strm_to_str()` - convert any value to string
- [ ] `strm_inspect()` - debug representation

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

- [ ] `Strm_String` type
- [ ] `strm_str_new(ptr, len)` - create owned string
- [ ] `strm_str_static(ptr, len)` - create static string reference
- [ ] `strm_str_intern(ptr, len)` - create/get interned string
- [ ] `strm_str_ptr()` - get string pointer
- [ ] `strm_str_len()` - get string length
- [ ] `strm_str_eq()` - compare strings
- [ ] `strm_str_cstr()` - get null-terminated C string

### 9.2 Array representation
```
struct strm_array {
  len: i32,
  ptr: ^Strm_Value,   // array elements
  headers: strm_array, // optional field names (for struct-like arrays)
  ns: ^Strm_State,    // optional namespace (for typed objects)
}
```

- [ ] `Strm_Array` type (tagged pointer to struct)
- [ ] `strm_ary_new(ptr, len)` - create array
- [ ] `strm_ary_ptr()` - get element pointer
- [ ] `strm_ary_len()` - get length
- [ ] `strm_ary_headers()` - get headers array
- [ ] `strm_ary_ns()` - get namespace
- [ ] `strm_ary_eq()` - compare arrays

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

- [ ] `Strm_State` struct
- [ ] Hash table for environment (khash or custom)

### 10.2 Variable operations
- [ ] `strm_var_def(state, name, value)` - define new variable
- [ ] `strm_var_set(state, name, value)` - set variable (create if not exists)
- [ ] `strm_var_get(state, name, *value)` - get variable value
- [ ] `strm_var_match(state, name, value)` - pattern match assignment
- [ ] `strm_env_copy(dst, src)` - copy environment (for import)

### 10.3 Namespace operations
- [ ] `strm_ns_new(parent, name)` - create named namespace
- [ ] `strm_ns_create(parent, name)` - create and register namespace
- [ ] `strm_ns_get(name)` - look up namespace by name
- [ ] `strm_value_ns(value)` - get namespace of a value
- [ ] Global namespaces: `strm_ns_array`, `strm_ns_string`, `strm_ns_number`

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

---

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1. Setup | Not Started | Project structure |
| 2. Lexer | Not Started | Token scanning |
| 3. Nodes | Not Started | AST definition |
| 4. Parser | Not Started | Push parser |
| 5. Precedence | Not Started | Operator handling |
| 6. Parser Test | Not Started | Parser verification |
| 7. Main (Parse) | Not Started | CLI for parsing |
| 8. Values | Not Started | NaN-boxing |
| 9. Str/Array | Not Started | String/Array types |
| 10. Namespace | Not Started | Scope management |
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
