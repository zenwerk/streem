package streem

import "core:fmt"
import "core:strconv"

// Push parser for streem language
// Reference: calc_odin/parse.odin, src/parse.y

// Parser state kinds - defines all grammar states
Parse_State_Kind :: enum {
	// Special states
	Start,
	End,
	Error,

	// Program/Top-level states
	Program,
	Program_Term,     // after term in program
	Topstmts,
	Topstmt,

	// Namespace/Class
	Namespace_Body,
	Namespace_Close,

	// Import
	Import_,

	// Method definition
	Method_Def,
	Method_Args,
	Method_Close_Paren,
	Method_Body_Start,
	Method_Body,

	// Statement states
	Stmts,
	Stmt,
	Stmt_Term,        // after term in stmt_list

	// Let assignment
	Let_Assign,
	Let_Assign_Rasgn, // expr => var

	// Def function
	Def_Func,
	Def_Args,
	Def_Close_Paren,
	Def_Body_Start,
	Def_Body,

	// Emit/Skip/Return
	Emit_,
	Skip_,
	Return_,

	// Expression states (precedence-based)
	Expr,
	Expr_Op,          // waiting for binary operator
	Expr_Rhs,         // parsing right-hand side
	Expr_Rhs_Op,      // check for more operators on RHS

	// Unary operators
	Unary,

	// Primary states
	Primary,
	Paren_Expr,
	Paren_Close,

	// Array literal
	Array_Literal,
	Array_Args,
	Array_Args_Next,
	Array_Close,

	// Block
	Block,
	Block_Content,    // after '{'
	Block_Params,
	Block_Body,
	Block_Close,

	// If expression
	If_Cond,
	If_Cond_Close,
	If_Then,
	If_Else,

	// Function call
	Func_Call,
	Func_Args,
	Func_Args_Expr,
	Func_Args_Next,
	Func_Close,
	Func_Opt_Block,

	// Method call
	Method_Call,
	Method_Name,
	Method_Args_Start,

	// Lambda expression
	Lambda_Expr,
	Lambda_Args,
	Lambda_Body,

	// New expression
	New_Expr,
	New_Args,
	New_Close,

	// Genfunc (&fname)
	Genfunc,

	// Pattern matching states
	Pattern,
	Pterm,
	Pary,
	Pary_Next,
	Pstruct,
	Pstruct_Next,
	Psplat,

	// Case/Pattern lambda
	Case_Body,
	Case_Pattern,
	Case_Cond,
	Case_Stmts,
	Plambda,
}

// Parser state with current state kind and node pointer
Parse_State :: struct {
	kind:  Parse_State_Kind,
	node:  ^^Node, // pointer to where the node should be stored
	saved: ^Node,  // saved node for compound constructs
	op:    string, // saved operator for binary expressions
	prec:  Precedence, // minimum precedence for expression parsing
}

// Parser result status
Parse_Result :: enum {
	Ok,          // continue parsing
	Done,        // parsing complete
	Need_Token,  // need more tokens
	Error,       // parse error
}

// Parse loop action
Parse_Loop_Action :: enum {
	Break,
	Continue,
}

// Parser structure
Parser :: struct {
	state_stack:   [dynamic]Parse_State,
	root:          ^Node,       // root of the AST
	current_token: Token,       // current lookahead token
	fname:         string,      // source file name
	lineno:        int,         // current line number
	error_msg:     string,      // error message if parse failed
	nerr:          int,         // error count
}

// ============================================================================
// Parser Core Functions
// ============================================================================

// Create and initialize parser
parser_new :: proc() -> ^Parser {
	p := new(Parser)
	p.state_stack = make([dynamic]Parse_State)
	p.root = nil
	p.fname = ""
	p.lineno = 0
	p.error_msg = ""
	p.nerr = 0
	return p
}

// Destroy parser
parser_destroy :: proc(p: ^Parser) {
	if p == nil {
		return
	}
	delete(p.state_stack)
	free(p)
}

// Reset parser for new input
parser_reset :: proc(p: ^Parser) {
	clear(&p.state_stack)
	p.root = nil
	p.error_msg = ""
	p.nerr = 0
	// Push initial state
	parser_begin(p, .Start, &p.root)
}

// Push new state onto stack
parser_begin :: proc(p: ^Parser, kind: Parse_State_Kind, node: ^^Node, prec: Precedence = .Lowest) {
	state := Parse_State{
		kind  = kind,
		node  = node,
		saved = nil,
		op    = "",
		prec  = prec,
	}
	append(&p.state_stack, state)
}

// Pop state from stack
parser_end :: proc(p: ^Parser) -> Parse_State {
	if len(p.state_stack) == 0 {
		return Parse_State{kind = .Error}
	}
	return pop(&p.state_stack)
}

// Get current state
parser_get_state :: proc(p: ^Parser) -> ^Parse_State {
	if len(p.state_stack) == 0 {
		return nil
	}
	return &p.state_stack[len(p.state_stack) - 1]
}

// Set current state kind
parser_set_state :: proc(p: ^Parser, kind: Parse_State_Kind) {
	if len(p.state_stack) > 0 {
		p.state_stack[len(p.state_stack) - 1].kind = kind
	}
}

// Transition to error state
parser_error :: proc(p: ^Parser, msg: string) {
	p.error_msg = msg
	p.nerr += 1
	clear(&p.state_stack)
	parser_begin(p, .Error, &p.root)
}

// Check if token is consumed
@(private = "file")
consumed :: proc(tk: ^Token, expected: Token_Type) -> bool {
	if tk.type == expected {
		tk.consumed = true
		return true
	}
	return false
}

// Check if token is a term (newline or semicolon)
@(private = "file")
is_term :: proc(tk: ^Token) -> bool {
	return tk.type == .Newline || tk.type == .Semicolon
}

// Consume term if present
@(private = "file")
consume_term :: proc(tk: ^Token) -> bool {
	if is_term(tk) {
		tk.consumed = true
		return true
	}
	return false
}

// ============================================================================
// Operator Precedence (from parse.y)
// ============================================================================

// Precedence levels (lowest to highest)
Precedence :: enum {
	Lowest  = 0,  // marker
	Lambda  = 1,  // -> )-> )->{ (right assoc)
	Else    = 2,  // else (right assoc)
	If      = 3,  // if (right assoc)
	Pipe    = 4,  // | (left assoc)
	Amper   = 5,  // & (left assoc)
	Or      = 6,  // || (left assoc)
	And     = 7,  // && (left assoc)
	Eq      = 8,  // == != (nonassoc)
	Cmp     = 9,  // < <= > >= (left assoc)
	Add     = 10, // + - (left assoc)
	Mul     = 11, // * / % (left assoc)
	Unary   = 12, // ! ~ (right assoc)
	Highest = 13, // marker
}

// Get precedence for token type
token_precedence :: proc(t: Token_Type) -> Precedence {
	#partial switch t {
	case .Op_Lambda, .Op_Lambda2, .Op_Lambda3:
		return .Lambda
	case .Kw_Else:
		return .Else
	case .Kw_If:
		return .If
	case .Op_Bar:
		return .Pipe
	case .Op_Amper:
		return .Amper
	case .Op_Or:
		return .Or
	case .Op_And:
		return .And
	case .Op_Eq, .Op_Neq:
		return .Eq
	case .Op_Lt, .Op_Le, .Op_Gt, .Op_Ge:
		return .Cmp
	case .Op_Plus, .Op_Minus:
		return .Add
	case .Op_Mult, .Op_Div, .Op_Mod:
		return .Mul
	case .Op_Not, .Op_Tilde:
		return .Unary
	}
	return .Lowest
}

// Get operator string for token type
token_to_op :: proc(t: Token_Type) -> string {
	#partial switch t {
	case .Op_Plus:  return "+"
	case .Op_Minus: return "-"
	case .Op_Mult:  return "*"
	case .Op_Div:   return "/"
	case .Op_Mod:   return "%"
	case .Op_Bar:   return "|"
	case .Op_Amper: return "&"
	case .Op_Gt:    return ">"
	case .Op_Ge:    return ">="
	case .Op_Lt:    return "<"
	case .Op_Le:    return "<="
	case .Op_Eq:    return "=="
	case .Op_Neq:   return "!="
	case .Op_And:   return "&&"
	case .Op_Or:    return "||"
	case .Op_Not:   return "!"
	case .Op_Tilde: return "~"
	}
	return ""
}

// Check if operator is right associative
is_right_assoc :: proc(t: Token_Type) -> bool {
	#partial switch t {
	case .Op_Lambda, .Op_Lambda2, .Op_Lambda3, .Kw_Else, .Kw_If, .Op_Not, .Op_Tilde:
		return true
	}
	return false
}

// Check if token is a binary operator
is_binary_op :: proc(t: Token_Type) -> bool {
	prec := token_precedence(t)
	return prec >= .Pipe && prec <= .Mul
}

// ============================================================================
// Parse Functions
// ============================================================================

// Parse start state
parse_start :: proc(p: ^Parser, tk: ^Token) -> Parse_Loop_Action {
	top := parser_get_state(p)
	if top == nil {
		return .Break
	}

	#partial switch top.kind {
	case .Start:
		if tk.type == .Eof {
			parser_set_state(p, .End)
			return .Break
		}
		// Skip leading terms
		if consume_term(tk) {
			return .Continue
		}
		// Start parsing program
		parser_set_state(p, .End)
		parser_begin(p, .Program, top.node)
		return .Continue
	case .End:
		return .Break
	case .Error:
		tk.consumed = true
	}

	return .Break
}

// Parse program level
parse_program :: proc(p: ^Parser, tk: ^Token) -> Parse_Loop_Action {
	top := parser_get_state(p)
	if top == nil {
		return .Break
	}

	#partial switch top.kind {
	case .Program:
		// End on EOF or '}' (for namespace/class body)
		if tk.type == .Eof || tk.type == .Right_Brace {
			parser_end(p)
			return .Continue
		}
		// Skip terms
		if consume_term(tk) {
			return .Continue
		}
		// Create nodes container if needed
		if top.node^ == nil {
			top.node^ = node_nodes_new(p.fname, p.lineno)
		}
		// Parse a top-level statement
		nodes := &top.node^.data.(Node_Nodes)
		append(&nodes.nodes, nil)
		idx := len(nodes.nodes) - 1
		parser_set_state(p, .Program_Term)
		parser_begin(p, .Topstmt, &nodes.nodes[idx])
		return .Continue

	case .Program_Term:
		// After a statement, expect term, EOF, or '}'
		if tk.type == .Eof || tk.type == .Right_Brace {
			parser_end(p)
			return .Continue
		}
		if consume_term(tk) {
			parser_set_state(p, .Program)
			return .Continue
		}
		// Multiple statements without term - might be OK in some contexts
		parser_set_state(p, .Program)
		return .Continue
	}

	return .Break
}

// Parse top-level statement
parse_topstmt :: proc(p: ^Parser, tk: ^Token) -> Parse_Loop_Action {
	top := parser_get_state(p)
	if top == nil {
		return .Break
	}

	#partial switch top.kind {
	case .Topstmt:
		// namespace identifier { ... }
		if consumed(tk, .Kw_Namespace) || consumed(tk, .Kw_Class) {
			parser_set_state(p, .Namespace_Body)
			return .Continue
		}
		// import identifier
		if consumed(tk, .Kw_Import) {
			parser_set_state(p, .Import_)
			return .Continue
		}
		// method fname(...) { ... }
		if consumed(tk, .Kw_Method) {
			parser_set_state(p, .Method_Def)
			return .Continue
		}
		// Fall through to stmt
		parser_set_state(p, .Stmt)
		return .Continue

	case .Namespace_Body:
		// Expect identifier
		if tk.type == .Ident {
			ns_name := tk.lexeme
			tk.consumed = true
			// Create namespace node
			ns_node := node_ns_new(ns_name, nil, p.fname, p.lineno)
			top.node^ = ns_node
			top.saved = ns_node
			parser_set_state(p, .Namespace_Close)
			return .Continue
		}
		parser_error(p, "Expected identifier after namespace/class")

	case .Namespace_Close:
		// Expect '{'
		if consumed(tk, .Left_Brace) {
			// Parse body
			ns_node := &top.saved.data.(Node_Ns)
			parser_begin(p, .Program, &ns_node.body)
			return .Continue
		}
		// After body parsed, expect '}'
		if consumed(tk, .Right_Brace) {
			parser_end(p)
			return .Continue
		}
		parser_error(p, "Expected '{' or '}' in namespace")

	case .Import_:
		// Expect identifier
		if tk.type == .Ident {
			top.node^ = node_import_new(tk.lexeme, p.fname, p.lineno)
			tk.consumed = true
			parser_end(p)
			return .Continue
		}
		parser_error(p, "Expected identifier after import")

	case .Method_Def:
		// Expect fname (identifier or string)
		if tk.type == .Ident || tk.type == .Lit_String {
			method_name := tk.lexeme
			tk.consumed = true
			top.op = method_name // save method name
			parser_set_state(p, .Method_Args)
			return .Continue
		}
		parser_error(p, "Expected method name")

	case .Method_Args:
		// Expect '('
		if consumed(tk, .Left_Paren) {
			// Create args node
			args_node := node_args_new(p.fname, p.lineno)
			top.saved = args_node
			parser_set_state(p, .Method_Close_Paren)
			return .Continue
		}
		parser_error(p, "Expected '(' after method name")

	case .Method_Close_Paren:
		// Parse args or ')'
		if consumed(tk, .Right_Paren) {
			parser_set_state(p, .Method_Body_Start)
			return .Continue
		}
		if tk.type == .Ident {
			// Add arg
			if top.saved != nil {
				node_args_add(top.saved, tk.lexeme)
			}
			tk.consumed = true
			return .Continue
		}
		if consumed(tk, .Comma) {
			return .Continue
		}
		parser_error(p, "Expected ')' or identifier in method args")

	case .Method_Body_Start:
		// Expect '{' or '='
		if consumed(tk, .Left_Brace) {
			// Create the lambda node for method body
			body_node: ^Node = nil
			lambda := node_lambda_new(top.saved, body_node, p.fname, p.lineno)
			// Create let assignment: method_name = lambda
			top.node^ = node_let_new(top.op, lambda, p.fname, p.lineno)
			// Parse body stmts
			lambda_data := &lambda.data.(Node_Lambda)
			parser_set_state(p, .Method_Body)
			parser_begin(p, .Stmts, &lambda_data.body)
			return .Continue
		}
		if consumed(tk, .Op_Assign) {
			// Alternative: method fname(args) = expr
			lambda := node_lambda_new(top.saved, nil, p.fname, p.lineno)
			top.node^ = node_let_new(top.op, lambda, p.fname, p.lineno)
			lambda_data := &lambda.data.(Node_Lambda)
			parser_set_state(p, .Method_Body)
			parser_begin(p, .Expr, &lambda_data.body)
			return .Continue
		}
		parser_error(p, "Expected '{' or '=' after method args")

	case .Method_Body:
		// After body, expect '}'
		if consumed(tk, .Right_Brace) {
			parser_end(p)
			return .Continue
		}
		// If expr form, end here
		parser_end(p)
		return .Continue
	}

	return .Break
}

// Parse statements
parse_stmts :: proc(p: ^Parser, tk: ^Token) -> Parse_Loop_Action {
	top := parser_get_state(p)
	if top == nil {
		return .Break
	}

	#partial switch top.kind {
	case .Stmts:
		// Skip terms
		if consume_term(tk) {
			return .Continue
		}
		// Check for end of block
		if tk.type == .Right_Brace || tk.type == .Eof {
			parser_end(p)
			return .Continue
		}
		// Create nodes container if needed
		if top.node^ == nil {
			top.node^ = node_nodes_new(p.fname, p.lineno)
		}
		// Parse a statement
		nodes := &top.node^.data.(Node_Nodes)
		append(&nodes.nodes, nil)
		idx := len(nodes.nodes) - 1
		parser_set_state(p, .Stmt_Term)
		parser_begin(p, .Stmt, &nodes.nodes[idx])
		return .Continue

	case .Stmt_Term:
		// After stmt, expect term or end
		if tk.type == .Right_Brace || tk.type == .Eof {
			parser_end(p)
			return .Continue
		}
		if consume_term(tk) {
			parser_set_state(p, .Stmts)
			return .Continue
		}
		// Allow continuation without term
		parser_set_state(p, .Stmts)
		return .Continue
	}

	return .Break
}

// Parse a statement
parse_stmt :: proc(p: ^Parser, tk: ^Token) -> Parse_Loop_Action {
	top := parser_get_state(p)
	if top == nil {
		return .Break
	}

	#partial switch top.kind {
	case .Stmt:
		// def fname(...) { ... }
		if consumed(tk, .Kw_Def) {
			parser_set_state(p, .Def_Func)
			return .Continue
		}
		// skip
		if consumed(tk, .Kw_Skip) {
			top.node^ = node_skip_new(p.fname, p.lineno)
			parser_end(p)
			return .Continue
		}
		// emit expr
		if consumed(tk, .Kw_Emit) {
			parser_set_state(p, .Emit_)
			return .Continue
		}
		// return expr
		if consumed(tk, .Kw_Return) {
			parser_set_state(p, .Return_)
			return .Continue
		}
		// var = expr or expr => var or just expr
		parser_set_state(p, .Let_Assign)
		parser_begin(p, .Expr, top.node)
		return .Continue

	case .Let_Assign:
		// After parsing first expr, check for '=' or '=>'
		if consumed(tk, .Op_Assign) {
			// var = expr
			// The parsed node should be an identifier
			if top.node^ != nil && top.node^.type == .Ident {
				var_name := top.node^.data.(Node_Ident).name
				node_free(top.node^)
				top.node^ = nil
				// Now parse the RHS
				top.op = var_name
				parser_set_state(p, .Let_Assign_Rasgn)
				parser_begin(p, .Expr, top.node)
				return .Continue
			}
			parser_error(p, "Left-hand side of assignment must be an identifier")
			return .Break
		}
		if consumed(tk, .Op_Rasgn) {
			// expr => var
			top.saved = top.node^
			top.node^ = nil
			parser_set_state(p, .Let_Assign_Rasgn)
			return .Continue
		}
		// Just an expression
		parser_end(p)
		return .Continue

	case .Let_Assign_Rasgn:
		// After '=', parse RHS
		if top.op != "" {
			// var = expr form: create let node after RHS is parsed
			let_node := node_let_new(top.op, top.node^, p.fname, p.lineno)
			top.node^ = let_node
			parser_end(p)
			return .Continue
		}
		// expr => var form: expect identifier
		if tk.type == .Ident {
			let_node := node_let_new(tk.lexeme, top.saved, p.fname, p.lineno)
			top.node^ = let_node
			tk.consumed = true
			parser_end(p)
			return .Continue
		}
		parser_error(p, "Expected identifier after '=>'")

	case .Def_Func:
		// Expect fname
		if tk.type == .Ident || tk.type == .Lit_String {
			top.op = tk.lexeme
			tk.consumed = true
			parser_set_state(p, .Def_Args)
			return .Continue
		}
		parser_error(p, "Expected function name after 'def'")

	case .Def_Args:
		// Expect '(' or '='
		if consumed(tk, .Left_Paren) {
			top.saved = node_args_new(p.fname, p.lineno)
			parser_set_state(p, .Def_Close_Paren)
			return .Continue
		}
		if consumed(tk, .Op_Assign) {
			// def foo = expr
			parser_set_state(p, .Def_Body)
			lambda := node_lambda_new(nil, nil, p.fname, p.lineno)
			top.node^ = node_let_new(top.op, lambda, p.fname, p.lineno)
			lambda_data := &lambda.data.(Node_Lambda)
			parser_begin(p, .Expr, &lambda_data.body)
			return .Continue
		}
		parser_error(p, "Expected '(' or '=' after function name")

	case .Def_Close_Paren:
		// Parse args or ')'
		if consumed(tk, .Right_Paren) {
			parser_set_state(p, .Def_Body_Start)
			return .Continue
		}
		if tk.type == .Ident {
			node_args_add(top.saved, tk.lexeme)
			tk.consumed = true
			return .Continue
		}
		if consumed(tk, .Comma) {
			return .Continue
		}
		parser_error(p, "Expected ')' or identifier in function args")

	case .Def_Body_Start:
		// Expect '{' or '='
		if consumed(tk, .Left_Brace) {
			lambda := node_lambda_new(top.saved, nil, p.fname, p.lineno)
			top.node^ = node_let_new(top.op, lambda, p.fname, p.lineno)
			lambda_data := &lambda.data.(Node_Lambda)
			parser_set_state(p, .Def_Body)
			parser_begin(p, .Stmts, &lambda_data.body)
			return .Continue
		}
		if consumed(tk, .Op_Assign) {
			lambda := node_lambda_new(top.saved, nil, p.fname, p.lineno)
			top.node^ = node_let_new(top.op, lambda, p.fname, p.lineno)
			lambda_data := &lambda.data.(Node_Lambda)
			parser_set_state(p, .Def_Body)
			parser_begin(p, .Expr, &lambda_data.body)
			return .Continue
		}
		parser_error(p, "Expected '{' or '=' after function args")

	case .Def_Body:
		// After body
		if consumed(tk, .Right_Brace) {
			parser_end(p)
			return .Continue
		}
		parser_end(p)
		return .Continue

	case .Emit_:
		// emit can have optional args
		if is_term(tk) || tk.type == .Right_Brace || tk.type == .Eof {
			top.node^ = node_emit_new(nil, p.fname, p.lineno)
			parser_end(p)
			return .Continue
		}
		// Parse expression
		emit := node_emit_new(nil, p.fname, p.lineno)
		top.node^ = emit
		emit_data := &emit.data.(Node_Emit)
		parser_set_state(p, .Skip_) // reuse for completion
		parser_begin(p, .Expr, &emit_data.value)
		return .Continue

	case .Return_:
		// return can have optional args
		if is_term(tk) || tk.type == .Right_Brace || tk.type == .Eof {
			top.node^ = node_return_new(nil, p.fname, p.lineno)
			parser_end(p)
			return .Continue
		}
		// Parse expression
		ret := node_return_new(nil, p.fname, p.lineno)
		top.node^ = ret
		ret_data := &ret.data.(Node_Return)
		parser_set_state(p, .Skip_)
		parser_begin(p, .Expr, &ret_data.value)
		return .Continue

	case .Skip_:
		// After emit/return expr
		parser_end(p)
		return .Continue
	}

	return .Break
}

// Parse expression with precedence climbing
parse_expr :: proc(p: ^Parser, tk: ^Token) -> Parse_Loop_Action {
	top := parser_get_state(p)
	if top == nil {
		return .Break
	}

	#partial switch top.kind {
	case .Expr:
		// Check for unary operators
		if consumed(tk, .Op_Plus) {
			// Unary plus is a no-op, parse next expr
			return .Continue
		}
		if consumed(tk, .Op_Minus) {
			// Unary minus
			unary := node_op_new("-", nil, nil, p.fname, p.lineno)
			top.node^ = unary
			op_data := &unary.data.(Node_Op)
			parser_set_state(p, .Unary)
			parser_begin(p, .Expr, &op_data.rhs, .Unary)
			return .Continue
		}
		if consumed(tk, .Op_Not) {
			unary := node_op_new("!", nil, nil, p.fname, p.lineno)
			top.node^ = unary
			op_data := &unary.data.(Node_Op)
			parser_set_state(p, .Unary)
			parser_begin(p, .Expr, &op_data.rhs, .Unary)
			return .Continue
		}
		if consumed(tk, .Op_Tilde) {
			unary := node_op_new("~", nil, nil, p.fname, p.lineno)
			top.node^ = unary
			op_data := &unary.data.(Node_Op)
			parser_set_state(p, .Unary)
			parser_begin(p, .Expr, &op_data.rhs, .Unary)
			return .Continue
		}
		// Check for lambda: (args)-> expr or (args)->{stmts}
		// if condition expr else expr
		if consumed(tk, .Kw_If) {
			parser_set_state(p, .If_Cond)
			return .Continue
		}
		// Parse primary
		parser_set_state(p, .Expr_Op)
		parser_begin(p, .Primary, top.node)
		return .Continue

	case .Unary:
		// After unary operand
		parser_end(p)
		return .Continue

	case .Expr_Op:
		// After primary, check for binary operator
		prec := token_precedence(tk.type)
		if prec > .Lowest && prec >= top.prec {
			// This is a binary operator we can handle
			op := token_to_op(tk.type)
			if op == "" {
				parser_end(p)
				return .Continue  // Let parent handle token
			}
			tk.consumed = true

			// Get left operand
			left := top.node^

			// Create binary node
			bin := node_op_new(op, left, nil, p.fname, p.lineno)
			top.node^ = bin

			// Compute next precedence
			next_prec := prec
			if !is_right_assoc(tk.type) {
				next_prec = Precedence(int(prec) + 1)
			}

			// Parse right operand - stay in Expr_Op to check for more operators
			bin_data := &bin.data.(Node_Op)
			parser_begin(p, .Expr_Rhs, &bin_data.rhs, next_prec)
			return .Continue
		}
		// Check for => (right assign) - don't consume, let parent handle
		if tk.type == .Op_Rasgn || tk.type == .Op_Assign {
			parser_end(p)
			return .Continue  // Let parent state handle assignment
		}
		// No more operators, end expression and let parent handle token
		parser_end(p)
		return .Continue

	case .Expr_Rhs:
		// Parse RHS primary first
		parser_set_state(p, .Expr_Rhs_Op)
		parser_begin(p, .Primary, top.node)
		return .Continue

	case .Expr_Rhs_Op:
		// After RHS primary, check if there's a higher-precedence operator
		prec := token_precedence(tk.type)
		if prec > .Lowest && prec >= top.prec {
			op := token_to_op(tk.type)
			if op == "" {
				parser_end(p)
				return .Continue
			}
			tk.consumed = true

			// Get left operand
			left := top.node^

			// Create binary node
			bin := node_op_new(op, left, nil, p.fname, p.lineno)
			top.node^ = bin

			// Compute next precedence
			next_prec := prec
			if !is_right_assoc(tk.type) {
				next_prec = Precedence(int(prec) + 1)
			}

			// Parse RHS
			bin_data := &bin.data.(Node_Op)
			parser_begin(p, .Expr_Rhs, &bin_data.rhs, next_prec)
			return .Continue
		}
		// No more operators at this precedence level, return to parent
		parser_end(p)
		return .Continue
	}

	return .Break
}

// Parse if expression
parse_if :: proc(p: ^Parser, tk: ^Token) -> Parse_Loop_Action {
	top := parser_get_state(p)
	if top == nil {
		return .Break
	}

	#partial switch top.kind {
	case .If_Cond:
		// Expect '('
		if consumed(tk, .Left_Paren) {
			// Create if node
			if_node := node_if_new(nil, nil, nil, p.fname, p.lineno)
			top.node^ = if_node
			top.saved = if_node
			if_data := &if_node.data.(Node_If)
			parser_set_state(p, .If_Cond_Close)
			parser_begin(p, .Expr, &if_data.cond)
			return .Continue
		}
		parser_error(p, "Expected '(' after 'if'")

	case .If_Cond_Close:
		// Expect ')'
		if consumed(tk, .Right_Paren) {
			if_data := &top.saved.data.(Node_If)
			parser_set_state(p, .If_Then)
			parser_begin(p, .Expr, &if_data.then_)
			return .Continue
		}
		parser_error(p, "Expected ')' after if condition")

	case .If_Then:
		// After then expr, check for else
		if consumed(tk, .Kw_Else) {
			if_data := &top.saved.data.(Node_If)
			parser_set_state(p, .If_Else)
			parser_begin(p, .Expr, &if_data.opt_else)
			return .Continue
		}
		// No else
		parser_end(p)
		return .Continue

	case .If_Else:
		// After else expr
		parser_end(p)
		return .Continue
	}

	return .Break
}

// Parse primary expression
parse_primary :: proc(p: ^Parser, tk: ^Token) -> Parse_Loop_Action {
	top := parser_get_state(p)
	if top == nil {
		return .Break
	}

	#partial switch top.kind {
	case .Primary:
		// Literals
		if tk.type == .Lit_Int {
			value, ok := strconv.parse_i64(tk.lexeme)
			if ok {
				top.node^ = node_int_new(value, p.fname, p.lineno)
			} else {
				top.node^ = node_int_new(0, p.fname, p.lineno)
			}
			tk.consumed = true
			parser_end(p)
			return .Continue
		}
		if tk.type == .Lit_Float {
			value, ok := strconv.parse_f64(tk.lexeme)
			if ok {
				top.node^ = node_float_new(value, p.fname, p.lineno)
			} else {
				top.node^ = node_float_new(0.0, p.fname, p.lineno)
			}
			tk.consumed = true
			parser_end(p)
			return .Continue
		}
		if tk.type == .Lit_String {
			top.node^ = node_string_new(tk.lexeme, p.fname, p.lineno)
			tk.consumed = true
			parser_end(p)
			return .Continue
		}
		if tk.type == .Lit_Symbol {
			top.node^ = node_string_new(tk.lexeme, p.fname, p.lineno)
			tk.consumed = true
			parser_end(p)
			return .Continue
		}
		if consumed(tk, .Kw_Nil) {
			top.node^ = node_nil_new(p.fname, p.lineno)
			parser_end(p)
			return .Continue
		}
		if consumed(tk, .Kw_True) {
			top.node^ = node_bool_new(true, p.fname, p.lineno)
			parser_end(p)
			return .Continue
		}
		if consumed(tk, .Kw_False) {
			top.node^ = node_bool_new(false, p.fname, p.lineno)
			parser_end(p)
			return .Continue
		}
		// Identifier (variable or function call)
		if tk.type == .Ident {
			ident_name := tk.lexeme
			tk.consumed = true
			parser_set_state(p, .Func_Call)
			top.op = ident_name
			return .Continue
		}
		// Parenthesized expression or lambda
		if consumed(tk, .Left_Paren) {
			parser_set_state(p, .Paren_Expr)
			return .Continue
		}
		// Array literal [args]
		if consumed(tk, .Left_Bracket) {
			parser_set_state(p, .Array_Literal)
			return .Continue
		}
		// Block {stmts}
		if consumed(tk, .Left_Brace) {
			parser_set_state(p, .Block_Content)
			return .Continue
		}
		// new ClassName[args]
		if consumed(tk, .Kw_New) {
			parser_set_state(p, .New_Expr)
			return .Continue
		}
		// &fname (genfunc)
		if consumed(tk, .Op_Amper) {
			parser_set_state(p, .Genfunc)
			return .Continue
		}
		// if expression
		if consumed(tk, .Kw_If) {
			parser_set_state(p, .If_Cond)
			return .Continue
		}
		parser_error(p, fmt.tprintf("Unexpected token in primary: %v", tk.type))

	case .Paren_Expr:
		// Start parsing expression or lambda args
		// For simplicity, first try expression, then check for lambda
		parser_set_state(p, .Paren_Close)
		parser_begin(p, .Expr, top.node)
		return .Continue

	case .Paren_Close:
		// Expect ')' or lambda operators
		if consumed(tk, .Right_Paren) {
			parser_end(p)
			return .Continue
		}
		if consumed(tk, .Op_Lambda2) {
			// (args)-> expr - need to convert parsed expr to args
			// For now, treat as simple lambda
			args := top.node^
			top.node^ = nil
			lambda := node_lambda_new(args, nil, p.fname, p.lineno)
			top.node^ = lambda
			lambda_data := &lambda.data.(Node_Lambda)
			parser_set_state(p, .Lambda_Body)
			parser_begin(p, .Expr, &lambda_data.body)
			return .Continue
		}
		if consumed(tk, .Op_Lambda3) {
			// (args)->{stmts}
			args := top.node^
			top.node^ = nil
			lambda := node_lambda_new(args, nil, p.fname, p.lineno)
			top.node^ = lambda
			lambda_data := &lambda.data.(Node_Lambda)
			parser_set_state(p, .Lambda_Body)
			parser_begin(p, .Stmts, &lambda_data.body)
			return .Continue
		}
		parser_error(p, "Expected ')' or lambda operator")

	case .Lambda_Body:
		// After lambda body
		if consumed(tk, .Right_Brace) {
			parser_end(p)
			return .Continue
		}
		parser_end(p)
		return .Continue

	case .Array_Literal:
		// Empty array or args
		if consumed(tk, .Right_Bracket) {
			top.node^ = node_array_new(p.fname, p.lineno)
			parser_end(p)
			return .Continue
		}
		// Parse args
		arr := node_array_new(p.fname, p.lineno)
		top.node^ = arr
		arr_data := &arr.data.(Node_Array)
		append(&arr_data.elements, nil)
		parser_set_state(p, .Array_Args_Next)
		parser_begin(p, .Expr, &arr_data.elements[0])
		return .Continue

	case .Array_Args_Next:
		// Expect ',' or ']'
		if consumed(tk, .Right_Bracket) {
			parser_end(p)
			return .Continue
		}
		if consumed(tk, .Comma) {
			arr_data := &top.node^.data.(Node_Array)
			append(&arr_data.elements, nil)
			idx := len(arr_data.elements) - 1
			parser_begin(p, .Expr, &arr_data.elements[idx])
			return .Continue
		}
		parser_error(p, "Expected ',' or ']' in array")

	case .Block_Content:
		// Check for block variants
		// Simple block {stmts}
		// Lambda block {params -> stmts}
		// Case block {case pattern -> stmts ...}
		if tk.type == .Kw_Case {
			// Case block
			parser_set_state(p, .Case_Body)
			return .Continue
		}
		// Check for lambda: {params -> stmts}
		if consumed(tk, .Op_Lambda) {
			// Empty params
			block := node_block_new(nil, p.fname, p.lineno)
			top.node^ = block
			block_data := &block.data.(Node_Lambda)
			parser_set_state(p, .Block_Close)
			parser_begin(p, .Stmts, &block_data.body)
			return .Continue
		}
		// Default: simple block {stmts}
		block := node_block_new(nil, p.fname, p.lineno)
		top.node^ = block
		block_data := &block.data.(Node_Lambda)
		parser_set_state(p, .Block_Close)
		parser_begin(p, .Stmts, &block_data.body)
		return .Continue

	case .Block_Close:
		if consumed(tk, .Right_Brace) {
			parser_end(p)
			return .Continue
		}
		parser_error(p, "Expected '}' to close block")

	case .Genfunc:
		// Expect identifier
		if tk.type == .Ident || tk.type == .Lit_String {
			top.node^ = node_genfunc_new(tk.lexeme, p.fname, p.lineno)
			tk.consumed = true
			parser_end(p)
			return .Continue
		}
		parser_error(p, "Expected identifier after '&'")

	case .New_Expr:
		// Expect identifier
		if tk.type == .Ident {
			class_name := tk.lexeme
			tk.consumed = true
			top.op = class_name
			parser_set_state(p, .New_Args)
			return .Continue
		}
		parser_error(p, "Expected class name after 'new'")

	case .New_Args:
		// Expect '['
		if consumed(tk, .Left_Bracket) {
			// Create array for args
			arr := node_array_new(p.fname, p.lineno)
			top.saved = arr
			parser_set_state(p, .New_Close)
			return .Continue
		}
		parser_error(p, "Expected '[' after class name")

	case .New_Close:
		// Parse args or ']'
		if consumed(tk, .Right_Bracket) {
			// Create new expression as call
			call := node_call_new(top.op, top.saved, p.fname, p.lineno)
			top.node^ = call
			parser_end(p)
			return .Continue
		}
		// Parse arg
		if top.saved != nil {
			arr_data := &top.saved.data.(Node_Array)
			append(&arr_data.elements, nil)
			idx := len(arr_data.elements) - 1
			parser_begin(p, .Expr, &arr_data.elements[idx])
			return .Continue
		}
		parser_error(p, "Expected ']' or args")
	}

	return .Break
}

// Parse function call
parse_func_call :: proc(p: ^Parser, tk: ^Token) -> Parse_Loop_Action {
	top := parser_get_state(p)
	if top == nil {
		return .Break
	}

	#partial switch top.kind {
	case .Func_Call:
		// After identifier, check for '(' or just use as variable
		if consumed(tk, .Left_Paren) {
			// Function call
			call := node_call_new(top.op, nil, p.fname, p.lineno)
			top.node^ = call
			parser_set_state(p, .Func_Args)
			return .Continue
		}
		if consumed(tk, .Left_Brace) {
			// Function call with block: fname { block }
			call := node_call_new(top.op, nil, p.fname, p.lineno)
			top.node^ = call
			// Parse block
			call_data := &call.data.(Node_Call)
			parser_set_state(p, .Func_Opt_Block)
			parser_begin(p, .Block_Content, &call_data.args) // reuse args for block
			return .Continue
		}
		// Just a variable reference
		top.node^ = node_ident_new(top.op, p.fname, p.lineno)
		// Check for method call: primary.method
		parser_set_state(p, .Method_Call)
		return .Continue

	case .Func_Args:
		// Empty args or first arg
		if consumed(tk, .Right_Paren) {
			parser_set_state(p, .Func_Opt_Block)
			return .Continue
		}
		// Parse first arg
		call_data := &top.node^.data.(Node_Call)
		if call_data.args == nil {
			call_data.args = node_array_new(p.fname, p.lineno)
		}
		arr_data := &call_data.args.data.(Node_Array)
		append(&arr_data.elements, nil)
		idx := len(arr_data.elements) - 1
		parser_set_state(p, .Func_Args_Next)
		parser_begin(p, .Expr, &arr_data.elements[idx])
		return .Continue

	case .Func_Args_Next:
		// ',' or ')'
		if consumed(tk, .Right_Paren) {
			parser_set_state(p, .Func_Opt_Block)
			return .Continue
		}
		if consumed(tk, .Comma) {
			call_data := &top.node^.data.(Node_Call)
			arr_data := &call_data.args.data.(Node_Array)
			append(&arr_data.elements, nil)
			idx := len(arr_data.elements) - 1
			parser_begin(p, .Expr, &arr_data.elements[idx])
			return .Continue
		}
		parser_error(p, "Expected ',' or ')' in function call")

	case .Func_Opt_Block:
		// Optional block after function call
		if consumed(tk, .Left_Brace) {
			// Has block - for now just parse as stmts
			block := node_block_new(nil, p.fname, p.lineno)
			block_data := &block.data.(Node_Lambda)
			parser_set_state(p, .Block_Close)
			parser_begin(p, .Stmts, &block_data.body)
			// TODO: attach block to call
			return .Continue
		}
		// No block, check for method call
		parser_set_state(p, .Method_Call)
		return .Continue

	case .Method_Call:
		// Check for .method
		if consumed(tk, .Dot) {
			parser_set_state(p, .Method_Name)
			return .Continue
		}
		parser_end(p)
		return .Continue

	case .Method_Name:
		// Expect identifier
		if tk.type == .Ident {
			method_name := tk.lexeme
			tk.consumed = true
			// Create method call
			receiver := top.node^
			call := node_call_new(method_name, nil, p.fname, p.lineno)
			// Set receiver as first arg
			call_data := &call.data.(Node_Call)
			call_data.args = node_array_new(p.fname, p.lineno)
			arr_data := &call_data.args.data.(Node_Array)
			append(&arr_data.elements, receiver)
			top.node^ = call
			parser_set_state(p, .Method_Args_Start)
			return .Continue
		}
		// Indirect call: primary.(args)
		if consumed(tk, .Left_Paren) {
			receiver := top.node^
			fcall := node_fcall_new(receiver, nil, p.fname, p.lineno)
			top.node^ = fcall
			parser_set_state(p, .Func_Args)
			return .Continue
		}
		parser_error(p, "Expected identifier after '.'")

	case .Method_Args_Start:
		// Optional '(' for method args
		if consumed(tk, .Left_Paren) {
			parser_set_state(p, .Func_Args)
			return .Continue
		}
		// No args
		parser_set_state(p, .Func_Opt_Block)
		return .Continue
	}

	return .Break
}

// Parse case/pattern matching
parse_case :: proc(p: ^Parser, tk: ^Token) -> Parse_Loop_Action {
	top := parser_get_state(p)
	if top == nil {
		return .Break
	}

	#partial switch top.kind {
	case .Case_Body:
		if consumed(tk, .Kw_Case) {
			// Create plambda
			plambda := node_plambda_new(nil, nil, p.fname, p.lineno)
			if top.node^ == nil {
				top.node^ = plambda
			} else {
				// Add to chain
				node_plambda_add(top.node^, plambda)
			}
			top.saved = plambda
			parser_set_state(p, .Case_Pattern)
			return .Continue
		}
		if consumed(tk, .Kw_Else) {
			// else -> stmts (default case)
			plambda := node_plambda_new(nil, nil, p.fname, p.lineno)
			if top.node^ != nil {
				node_plambda_add(top.node^, plambda)
			} else {
				top.node^ = plambda
			}
			top.saved = plambda
			parser_set_state(p, .Case_Stmts)
			return .Continue
		}
		if consumed(tk, .Right_Brace) {
			parser_end(p)
			return .Continue
		}
		parser_error(p, "Expected 'case', 'else' or '}' in case block")

	case .Case_Pattern:
		// Parse pattern or '->'
		if consumed(tk, .Op_Lambda) {
			// Empty pattern
			parser_set_state(p, .Case_Stmts)
			return .Continue
		}
		if consumed(tk, .Kw_If) {
			// Guard condition
			parser_set_state(p, .Case_Cond)
			return .Continue
		}
		// Parse pattern (simplified - just use expr for now)
		plambda_data := &top.saved.data.(Node_PLambda)
		parser_set_state(p, .Case_Cond)
		parser_begin(p, .Expr, &plambda_data.pat)
		return .Continue

	case .Case_Cond:
		// Check for 'if' guard or '->'
		if consumed(tk, .Kw_If) {
			plambda_data := &top.saved.data.(Node_PLambda)
			parser_begin(p, .Expr, &plambda_data.cond)
			return .Continue
		}
		if consumed(tk, .Op_Lambda) {
			parser_set_state(p, .Case_Stmts)
			return .Continue
		}
		parser_error(p, "Expected 'if' or '->' in case pattern")

	case .Case_Stmts:
		// Parse case body
		plambda_data := &top.saved.data.(Node_PLambda)
		parser_set_state(p, .Case_Body)
		parser_begin(p, .Stmts, &plambda_data.body)
		return .Continue
	}

	return .Break
}

// ============================================================================
// State range check helper
// ============================================================================

@(private = "file")
is_between :: proc(state, from, to: Parse_State_Kind) -> bool {
	return from <= state && state <= to
}

// ============================================================================
// Main Parser Entry Point
// ============================================================================

// Push token to parser (main entry point for push parser)
parser_push_token :: proc(p: ^Parser, token: Token) -> Parse_Result {
	tk := token
	p.current_token = tk
	p.lineno = tk.line

	max_iterations := 1000
	action: Parse_Loop_Action

	for i := 0; i < max_iterations; i += 1 {
		top := parser_get_state(p)
		if top == nil {
			break
		}
		pstate := top.kind

		// Token already consumed
		if tk.consumed {
			break
		}

		// Lexer error
		if tk.type == .Error && pstate != .Error {
			parser_error(p, fmt.tprintf("Lexer error: %s", tk.lexeme))
			break
		}

		// Dispatch to appropriate parser function based on state
		#partial switch pstate {
		case .Start, .End, .Error:
			action = parse_start(p, &tk)
		case .Program, .Program_Term:
			action = parse_program(p, &tk)
		case .Topstmts, .Topstmt, .Namespace_Body, .Namespace_Close, .Import_, .Method_Def, .Method_Args, .Method_Close_Paren, .Method_Body_Start, .Method_Body:
			action = parse_topstmt(p, &tk)
		case .Stmts, .Stmt_Term:
			action = parse_stmts(p, &tk)
		case .Stmt, .Let_Assign, .Let_Assign_Rasgn, .Def_Func, .Def_Args, .Def_Close_Paren, .Def_Body_Start, .Def_Body, .Emit_, .Skip_, .Return_:
			action = parse_stmt(p, &tk)
		case .Expr, .Expr_Op, .Expr_Rhs, .Expr_Rhs_Op, .Unary:
			action = parse_expr(p, &tk)
		case .If_Cond, .If_Cond_Close, .If_Then, .If_Else:
			action = parse_if(p, &tk)
		case .Primary, .Paren_Expr, .Paren_Close, .Array_Literal, .Array_Args, .Array_Args_Next, .Array_Close, .Block, .Block_Content, .Block_Params, .Block_Body, .Block_Close, .Genfunc, .New_Expr, .New_Args, .New_Close, .Lambda_Expr, .Lambda_Args, .Lambda_Body:
			action = parse_primary(p, &tk)
		case .Func_Call, .Func_Args, .Func_Args_Expr, .Func_Args_Next, .Func_Close, .Func_Opt_Block, .Method_Call, .Method_Name, .Method_Args_Start:
			action = parse_func_call(p, &tk)
		case .Case_Body, .Case_Pattern, .Case_Cond, .Case_Stmts, .Plambda:
			action = parse_case(p, &tk)
		case:
			// Unknown state
			fmt.eprintfln("Parse: Unknown state %v", pstate)
			break
		}

		if action == .Break {
			break
		}
	}

	// Check final state
	top := parser_get_state(p)
	if top != nil {
		if top.kind == .End {
			return .Done
		}
		if top.kind == .Error {
			return .Error
		}
	}
	return .Need_Token
}

// ============================================================================
// Convenience Functions
// ============================================================================

// Parse a complete expression from lexer
parse_expression :: proc(lex: ^Lex) -> (^Node, bool) {
	p := parser_new()
	defer parser_destroy(p)

	parser_reset(p)

	for {
		token := lex_scan_token(lex)
		result := parser_push_token(p, token)

		switch result {
		case .Done:
			return p.root, true
		case .Error:
			return nil, false
		case .Ok, .Need_Token:
			continue
		}
	}
}

// Parse a complete program from lexer
parse_program_from_lex :: proc(lex: ^Lex) -> (^Node, bool) {
	return parse_expression(lex)
}

// Parse string input
parse_string :: proc(input: string, fname: string = "<input>") -> (^Node, bool) {
	lex: Lex
	lex_init(&lex, input, fname)
	return parse_expression(&lex)
}
