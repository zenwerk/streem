package streem

// Push parser for streem language
// Reference: calc_odin/parse.odin, src/parse.y

// Parser state kinds - defines all grammar states
// TODO: Phase 4 will implement the full state machine
Parse_State_Kind :: enum {
	// Special states
	Start,
	End,
	Error,

	// Program/Top-level states
	Program,
	Topstmts,
	Topstmt_List,
	Topstmt,
	Namespace_Body,
	Class_Body,
	Import_,
	Method_Def,
	Method_Args,
	Method_Body,

	// Statement states
	Stmts,
	Stmt_List,
	Stmt,
	Let_Assign,
	Def_Func,
	Def_Args,
	Def_Body,
	Emit_,
	Skip_,
	Return_,

	// Expression states (precedence-based)
	Expr,
	Expr_Or,      // ||
	Expr_And,     // &&
	Expr_Eq,      // ==, !=
	Expr_Cmp,     // <, <=, >, >=
	Expr_Add,     // +, -
	Expr_Mul,     // *, /, %
	Expr_Unary,   // !, ~, unary +/-
	Expr_Pipe,    // |
	Expr_Amper,   // &

	// Primary states
	Primary,
	Paren_Expr,
	Paren_Close,
	Array_Literal,
	Array_Args,
	Block,
	Block_Params,
	Block_Body,
	If_Cond,
	If_Then,
	If_Else,
	Func_Call,
	Func_Args,
	Func_Args_Next,
	Method_Call,
	New_Expr,
	Lambda_Expr,

	// Pattern matching states
	Pattern,
	Pterm,
	Pary,
	Pstruct,
	Psplat,
	Case_Body,
	Case_Pattern,
	Case_Cond,
	Plambda,
}

// Parser state with current state kind and node pointer
Parse_State :: struct {
	kind:  Parse_State_Kind,
	node:  ^^Node, // pointer to where the node should be stored
	saved: ^Node,  // saved node for compound constructs
}

// Parser result status
Parse_Result :: enum {
	Ok,          // token consumed, continue
	Done,        // parsing complete
	Need_Token,  // need more tokens
	Error,       // parse error
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
	// Note: root node should be freed separately if needed
	free(p)
}

// Reset parser for new input
parser_reset :: proc(p: ^Parser) {
	clear(&p.state_stack)
	p.root = nil
	p.error_msg = ""
	p.nerr = 0
	// Push initial state
	parser_begin(p, .Program, &p.root)
}

// Push new state onto stack
parser_begin :: proc(p: ^Parser, kind: Parse_State_Kind, node: ^^Node) {
	state := Parse_State{
		kind  = kind,
		node  = node,
		saved = nil,
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
	parser_set_state(p, .Error)
}

// Push token to parser (main entry point for push parser)
// Returns Parse_Result indicating what to do next
parser_push_token :: proc(p: ^Parser, token: Token) -> Parse_Result {
	p.current_token = token
	p.lineno = token.line

	// TODO: Phase 4 will implement the full state dispatch
	// For now, this is a stub that accepts any input

	state := parser_get_state(p)
	if state == nil {
		return .Error
	}

	#partial switch state.kind {
	case .Start:
		parser_set_state(p, .Program)
		return .Need_Token

	case .Program:
		// TODO: implement program parsing
		if token.type == .Eof {
			parser_set_state(p, .End)
			return .Done
		}
		return .Need_Token

	case .End:
		return .Done

	case .Error:
		return .Error

	case:
		// TODO: implement other states
		return .Need_Token
	}
}

// ============================================================================
// Operator Precedence (from parse.y)
// ============================================================================

// Precedence levels (lowest to highest)
// Reference: Phase 5 of ODIN_PORT_TODO.md
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

// Check if operator is right associative
is_right_assoc :: proc(t: Token_Type) -> bool {
	#partial switch t {
	case .Op_Lambda, .Op_Lambda2, .Op_Lambda3, .Kw_Else, .Kw_If, .Op_Not, .Op_Tilde:
		return true
	}
	return false
}

// ============================================================================
// Helper functions (stubs for Phase 4)
// ============================================================================

// Parse a complete expression from lexer
// This is a convenience function that creates a parser and feeds tokens
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
parse_program :: proc(lex: ^Lex) -> (^Node, bool) {
	return parse_expression(lex) // TODO: proper program parsing
}
