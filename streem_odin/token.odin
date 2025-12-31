package streem

// Token types for streem language
// Reference: src/lex.l
Token_Type :: enum {
	// Special tokens
	Eof,
	Error,
	Newline, // significant for statement termination

	// Literals
	Lit_Int,    // integer literal (decimal, hex 0x, octal 0o)
	Lit_Float,  // floating point literal
	Lit_String, // double-quoted string with escapes
	Lit_Symbol, // :identifier
	Lit_Time,   // YYYY.MM.DD or YYYY.MM.DDThh:mm:ss

	// Identifier and Label
	Ident, // identifier (unicode-aware)
	Label, // identifier: (for labeled arguments)

	// Keywords
	Kw_If,
	Kw_Else,
	Kw_Case,
	Kw_Emit,
	Kw_Skip,
	Kw_Return,
	Kw_Namespace,
	Kw_Class,
	Kw_Import,
	Kw_Def,
	Kw_Method,
	Kw_New,
	Kw_Nil,
	Kw_True,
	Kw_False,

	// Arithmetic operators
	Op_Plus,  // +
	Op_Minus, // -
	Op_Mult,  // *
	Op_Div,   // /
	Op_Mod,   // %

	// Comparison operators
	Op_Eq,  // ==
	Op_Neq, // !=
	Op_Lt,  // <
	Op_Le,  // <=
	Op_Gt,  // >
	Op_Ge,  // >=

	// Logical operators
	Op_And, // &&
	Op_Or,  // ||
	Op_Not, // !

	// Bitwise operators
	Op_Amper, // &
	Op_Bar,   // |
	Op_Tilde, // ~

	// Assignment and Arrow operators
	Op_Assign, // =
	Op_Lasgn,  // <- (left assign)
	Op_Rasgn,  // => (right assign)

	// Lambda operators
	Op_Lambda,  // ->
	Op_Lambda2, // )-> (special: paren then arrow)
	Op_Lambda3, // )->{  (special: paren, arrow, brace)

	// Scope operator
	Op_Colon2, // ::

	// Delimiters
	Left_Paren,    // (
	Right_Paren,   // )
	Left_Bracket,  // [
	Right_Bracket, // ]
	Left_Brace,    // {
	Right_Brace,   // }
	Comma,         // ,
	Semicolon,     // ;
	Colon,         // :
	Dot,           // .
	At,            // @
}

// Position information in source
Pos :: struct {
	offset: int, // byte offset in source
	line:   int, // line number (1-based)
	column: int, // column number (1-based)
}

// Token with position and value information
Token :: struct {
	using pos: Pos,
	type:      Token_Type,
	lexeme:    string, // raw text of the token
	consumed:  bool,   // used by parser to track if token was consumed
}

// Check if token is a keyword
token_is_keyword :: proc(t: Token_Type) -> bool {
	#partial switch t {
	case .Kw_If, .Kw_Else, .Kw_Case, .Kw_Emit, .Kw_Skip, .Kw_Return,
	     .Kw_Namespace, .Kw_Class, .Kw_Import, .Kw_Def, .Kw_Method, .Kw_New,
	     .Kw_Nil, .Kw_True, .Kw_False:
		return true
	}
	return false
}

// Check if token is a binary operator
token_is_binary_op :: proc(t: Token_Type) -> bool {
	#partial switch t {
	case .Op_Plus, .Op_Minus, .Op_Mult, .Op_Div, .Op_Mod,
	     .Op_Eq, .Op_Neq, .Op_Lt, .Op_Le, .Op_Gt, .Op_Ge,
	     .Op_And, .Op_Or, .Op_Amper, .Op_Bar:
		return true
	}
	return false
}

// Check if token is a unary operator
token_is_unary_op :: proc(t: Token_Type) -> bool {
	#partial switch t {
	case .Op_Minus, .Op_Not, .Op_Tilde:
		return true
	}
	return false
}

// Check if token is a literal
token_is_literal :: proc(t: Token_Type) -> bool {
	#partial switch t {
	case .Lit_Int, .Lit_Float, .Lit_String, .Lit_Symbol, .Lit_Time,
	     .Kw_Nil, .Kw_True, .Kw_False:
		return true
	}
	return false
}

// Token type to string for debugging
token_type_string :: proc(t: Token_Type) -> string {
	return token_type_strings[t]
}

@(private = "file")
token_type_strings := [Token_Type]string {
	.Eof           = "EOF",
	.Error         = "ERROR",
	.Newline       = "NEWLINE",
	.Lit_Int       = "INT",
	.Lit_Float     = "FLOAT",
	.Lit_String    = "STRING",
	.Lit_Symbol    = "SYMBOL",
	.Lit_Time      = "TIME",
	.Ident         = "IDENT",
	.Label         = "LABEL",
	.Kw_If         = "if",
	.Kw_Else       = "else",
	.Kw_Case       = "case",
	.Kw_Emit       = "emit",
	.Kw_Skip       = "skip",
	.Kw_Return     = "return",
	.Kw_Namespace  = "namespace",
	.Kw_Class      = "class",
	.Kw_Import     = "import",
	.Kw_Def        = "def",
	.Kw_Method     = "method",
	.Kw_New        = "new",
	.Kw_Nil        = "nil",
	.Kw_True       = "true",
	.Kw_False      = "false",
	.Op_Plus       = "+",
	.Op_Minus      = "-",
	.Op_Mult       = "*",
	.Op_Div        = "/",
	.Op_Mod        = "%",
	.Op_Eq         = "==",
	.Op_Neq        = "!=",
	.Op_Lt         = "<",
	.Op_Le         = "<=",
	.Op_Gt         = ">",
	.Op_Ge         = ">=",
	.Op_And        = "&&",
	.Op_Or         = "||",
	.Op_Not        = "!",
	.Op_Amper      = "&",
	.Op_Bar        = "|",
	.Op_Tilde      = "~",
	.Op_Assign     = "=",
	.Op_Lasgn      = "<-",
	.Op_Rasgn      = "=>",
	.Op_Lambda     = "->",
	.Op_Lambda2    = ")->",
	.Op_Lambda3    = ")->{",
	.Op_Colon2     = "::",
	.Left_Paren    = "(",
	.Right_Paren   = ")",
	.Left_Bracket  = "[",
	.Right_Bracket = "]",
	.Left_Brace    = "{",
	.Right_Brace   = "}",
	.Comma         = ",",
	.Semicolon     = ";",
	.Colon         = ":",
	.Dot           = ".",
	.At            = "@",
}
