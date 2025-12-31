package streem

// AST Node types for streem language
// Reference: src/node.h

// Node type enumeration
Node_Type :: enum {
	// Literals
	Int,
	Float,
	Time,
	Str,
	Nil,
	Bool,

	// Collections and Arguments
	Args,   // function argument names list
	Pair,   // key:value pair (for labeled arguments)
	Array,  // array literal with optional headers
	Nodes,  // list of statements/expressions

	// Splat
	Splat, // *expr

	// Expressions
	Ident,   // identifier reference
	Op,      // binary/unary operation
	If,      // conditional
	Lambda,  // function/block
	Call,    // function call
	Fcall,   // indirect function call
	Genfunc, // generic function reference (&fname)

	// Statements
	Let,    // variable binding
	Emit,   // emit statement
	Skip,   // skip statement
	Return, // return statement

	// Top-level
	Ns,     // namespace/class definition
	Import, // import statement

	// Pattern matching
	PArray,  // pattern array
	PStruct, // pattern struct
	PSplat,  // pattern with splat (head, mid, tail)
	PLambda, // pattern lambda (pat, cond, body, next)
}

// Position information for error reporting
Node_Pos :: struct {
	fname:  string,
	lineno: int,
}

// Forward declaration
Node :: struct {
	type:      Node_Type,
	using pos: Node_Pos,
	data:      Node_Data,
}

// Node data union - holds the specific data for each node type
Node_Data :: union {
	Node_Int,
	Node_Float,
	Node_Time,
	Node_Str,
	Node_Bool,
	Node_Args,
	Node_Pair,
	Node_Array,
	Node_Nodes,
	Node_Splat,
	Node_Ident,
	Node_Op,
	Node_If,
	Node_Lambda,
	Node_Call,
	Node_Fcall,
	Node_Genfunc,
	Node_Let,
	Node_Emit,
	Node_Return,
	Node_Ns,
	Node_Import,
	Node_PSplat,
	Node_PLambda,
}

// Integer literal
Node_Int :: struct {
	value: i64,
}

// Float literal
Node_Float :: struct {
	value: f64,
}

// Time literal
Node_Time :: struct {
	sec:        i64,
	usec:       i64,
	utc_offset: int,
}

// String literal
Node_Str :: struct {
	value: string,
}

// Boolean literal
Node_Bool :: struct {
	value: bool,
}

// Argument names list (for function definitions)
Node_Args :: struct {
	names: [dynamic]string,
}

// Key-value pair
Node_Pair :: struct {
	key:   string,
	value: ^Node,
}

// Array literal with optional headers (for struct-like arrays)
Node_Array :: struct {
	elements: [dynamic]^Node,
	headers:  [dynamic]string, // optional field names
	ns:       string,          // optional namespace name
}

// List of nodes (statements/expressions)
Node_Nodes :: struct {
	nodes: [dynamic]^Node,
}

// Splat expression (*expr)
Node_Splat :: struct {
	expr: ^Node,
}

// Identifier reference
Node_Ident :: struct {
	name: string,
}

// Binary/unary operation
Node_Op :: struct {
	op:  string,
	lhs: ^Node, // nil for unary prefix
	rhs: ^Node,
}

// Conditional expression
Node_If :: struct {
	cond:     ^Node,
	then_:    ^Node,
	opt_else: ^Node, // nil if no else
}

// Lambda/function definition
Node_Lambda :: struct {
	args:     ^Node, // Node_Args or nil
	body:     ^Node,
	is_block: bool,  // true if {stmts}, false if -> expr
}

// Function call
Node_Call :: struct {
	name: string,
	args: ^Node, // Node_Array or nil
}

// Indirect function call (func_expr(args))
Node_Fcall :: struct {
	func_: ^Node, // expression evaluating to function
	args:  ^Node, // Node_Array or nil
}

// Generic function reference (&fname)
Node_Genfunc :: struct {
	name: string,
}

// Variable binding (let)
Node_Let :: struct {
	lhs: string, // variable name
	rhs: ^Node,  // value expression
}

// Emit statement
Node_Emit :: struct {
	value: ^Node,
}

// Return statement
Node_Return :: struct {
	value: ^Node, // nil for bare return
}

// Namespace/class definition
Node_Ns :: struct {
	name: string,
	body: ^Node,
}

// Import statement
Node_Import :: struct {
	name: string,
}

// Pattern splat (head, *mid, tail)
Node_PSplat :: struct {
	head: ^Node,
	mid:  ^Node,
	tail: ^Node,
}

// Pattern lambda (case pattern -> body)
Node_PLambda :: struct {
	pat:   ^Node,
	cond:  ^Node, // optional condition
	body:  ^Node,
	next_: ^Node, // next pattern lambda in chain
}

// ============================================================================
// Node constructors
// ============================================================================

node_new :: proc($T: typeid, type: Node_Type, fname: string = "", lineno: int = 0) -> ^Node {
	n := new(Node)
	n.type = type
	n.fname = fname
	n.lineno = lineno
	n.data = T{}
	return n
}

node_int_new :: proc(value: i64, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Int, .Int, fname, lineno)
	(&n.data.(Node_Int)).value = value
	return n
}

node_float_new :: proc(value: f64, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Float, .Float, fname, lineno)
	(&n.data.(Node_Float)).value = value
	return n
}

node_time_new :: proc(sec: i64, usec: i64, utc_offset: int, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Time, .Time, fname, lineno)
	t := &n.data.(Node_Time)
	t.sec = sec
	t.usec = usec
	t.utc_offset = utc_offset
	return n
}

node_string_new :: proc(value: string, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Str, .Str, fname, lineno)
	(&n.data.(Node_Str)).value = value
	return n
}

node_bool_new :: proc(value: bool, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Bool, .Bool, fname, lineno)
	(&n.data.(Node_Bool)).value = value
	return n
}

node_nil_new :: proc(fname: string = "", lineno: int = 0) -> ^Node {
	n := new(Node)
	n.type = .Nil
	n.fname = fname
	n.lineno = lineno
	return n
}

node_ident_new :: proc(name: string, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Ident, .Ident, fname, lineno)
	(&n.data.(Node_Ident)).name = name
	return n
}

node_op_new :: proc(op: string, lhs: ^Node, rhs: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Op, .Op, fname, lineno)
	o := &n.data.(Node_Op)
	o.op = op
	o.lhs = lhs
	o.rhs = rhs
	return n
}

node_if_new :: proc(cond: ^Node, then_: ^Node, opt_else: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_If, .If, fname, lineno)
	i := &n.data.(Node_If)
	i.cond = cond
	i.then_ = then_
	i.opt_else = opt_else
	return n
}

node_lambda_new :: proc(args: ^Node, body: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Lambda, .Lambda, fname, lineno)
	l := &n.data.(Node_Lambda)
	l.args = args
	l.body = body
	l.is_block = false
	return n
}

node_block_new :: proc(body: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Lambda, .Lambda, fname, lineno)
	l := &n.data.(Node_Lambda)
	l.args = nil
	l.body = body
	l.is_block = true
	return n
}

node_call_new :: proc(name: string, args: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Call, .Call, fname, lineno)
	c := &n.data.(Node_Call)
	c.name = name
	c.args = args
	return n
}

node_fcall_new :: proc(func_: ^Node, args: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Fcall, .Fcall, fname, lineno)
	f := &n.data.(Node_Fcall)
	f.func_ = func_
	f.args = args
	return n
}

node_genfunc_new :: proc(name: string, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Genfunc, .Genfunc, fname, lineno)
	(&n.data.(Node_Genfunc)).name = name
	return n
}

node_let_new :: proc(lhs: string, rhs: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Let, .Let, fname, lineno)
	l := &n.data.(Node_Let)
	l.lhs = lhs
	l.rhs = rhs
	return n
}

node_emit_new :: proc(value: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Emit, .Emit, fname, lineno)
	(&n.data.(Node_Emit)).value = value
	return n
}

node_skip_new :: proc(fname: string = "", lineno: int = 0) -> ^Node {
	n := new(Node)
	n.type = .Skip
	n.fname = fname
	n.lineno = lineno
	return n
}

node_return_new :: proc(value: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Return, .Return, fname, lineno)
	(&n.data.(Node_Return)).value = value
	return n
}

node_ns_new :: proc(name: string, body: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Ns, .Ns, fname, lineno)
	ns := &n.data.(Node_Ns)
	ns.name = name
	ns.body = body
	return n
}

node_import_new :: proc(name: string, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Import, .Import, fname, lineno)
	(&n.data.(Node_Import)).name = name
	return n
}

node_splat_new :: proc(expr: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Splat, .Splat, fname, lineno)
	(&n.data.(Node_Splat)).expr = expr
	return n
}

node_psplat_new :: proc(head: ^Node, mid: ^Node, tail: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_PSplat, .PSplat, fname, lineno)
	p := &n.data.(Node_PSplat)
	p.head = head
	p.mid = mid
	p.tail = tail
	return n
}

node_plambda_new :: proc(pat: ^Node, cond: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_PLambda, .PLambda, fname, lineno)
	p := &n.data.(Node_PLambda)
	p.pat = pat
	p.cond = cond
	p.body = nil
	p.next_ = nil
	return n
}

// ============================================================================
// Array/Nodes helpers
// ============================================================================

node_array_new :: proc(fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Array, .Array, fname, lineno)
	return n
}

node_array_add :: proc(arr: ^Node, elem: ^Node) {
	if arr == nil || arr.type != .Array {
		return
	}
	a := &arr.data.(Node_Array)
	append(&a.elements, elem)
}

node_nodes_new :: proc(fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Nodes, .Nodes, fname, lineno)
	return n
}

node_nodes_add :: proc(nodes: ^Node, node: ^Node) {
	if nodes == nil || nodes.type != .Nodes {
		return
	}
	ns := &nodes.data.(Node_Nodes)
	append(&ns.nodes, node)
}

node_args_new :: proc(fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Args, .Args, fname, lineno)
	return n
}

node_args_add :: proc(args: ^Node, name: string) {
	if args == nil || args.type != .Args {
		return
	}
	a := &args.data.(Node_Args)
	append(&a.names, name)
}

node_pair_new :: proc(key: string, value: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Pair, .Pair, fname, lineno)
	p := &n.data.(Node_Pair)
	p.key = key
	p.value = value
	return n
}

// ============================================================================
// Node deallocation
// ============================================================================

node_free :: proc(n: ^Node) {
	if n == nil {
		return
	}

	switch &d in n.data {
	case Node_Int, Node_Float, Node_Time, Node_Str, Node_Bool:
	// nothing to free

	case Node_Args:
		delete(d.names)

	case Node_Pair:
		node_free(d.value)

	case Node_Array:
		for elem in d.elements {
			node_free(elem)
		}
		delete(d.elements)
		delete(d.headers)

	case Node_Nodes:
		for node in d.nodes {
			node_free(node)
		}
		delete(d.nodes)

	case Node_Splat:
		node_free(d.expr)

	case Node_Ident:
	// nothing to free

	case Node_Op:
		node_free(d.lhs)
		node_free(d.rhs)

	case Node_If:
		node_free(d.cond)
		node_free(d.then_)
		node_free(d.opt_else)

	case Node_Lambda:
		node_free(d.args)
		node_free(d.body)

	case Node_Call:
		node_free(d.args)

	case Node_Fcall:
		node_free(d.func_)
		node_free(d.args)

	case Node_Genfunc:
	// nothing to free

	case Node_Let:
		node_free(d.rhs)

	case Node_Emit:
		node_free(d.value)

	case Node_Return:
		node_free(d.value)

	case Node_Ns:
		node_free(d.body)

	case Node_Import:
	// nothing to free

	case Node_PSplat:
		node_free(d.head)
		node_free(d.mid)
		node_free(d.tail)

	case Node_PLambda:
		node_free(d.pat)
		node_free(d.cond)
		node_free(d.body)
		node_free(d.next_)
	}

	free(n)
}
