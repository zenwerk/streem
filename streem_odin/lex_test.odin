package streem

import "core:testing"

// ============================================================================
// Lexer Tests
// ============================================================================

@(test)
test_lex_keywords :: proc(t: ^testing.T) {
	input := "if else case emit skip return namespace class import def method new nil true false"

	lex: Lex
	lex_init(&lex, input)

	expected := []Token_Type{
		.Kw_If, .Kw_Else, .Kw_Case, .Kw_Emit, .Kw_Skip, .Kw_Return,
		.Kw_Namespace, .Kw_Class, .Kw_Import, .Kw_Def, .Kw_Method, .Kw_New,
		.Kw_Nil, .Kw_True, .Kw_False, .Eof,
	}

	for exp in expected {
		tok := lex_scan_token(&lex)
		testing.expect_value(t, tok.type, exp)
	}
}

@(test)
test_lex_operators :: proc(t: ^testing.T) {
	input := "+ - * / % == != < <= > >= && || & | ~ = <- => -> ::"

	lex: Lex
	lex_init(&lex, input)

	expected := []Token_Type{
		.Op_Plus, .Op_Minus, .Op_Mult, .Op_Div, .Op_Mod,
		.Op_Eq, .Op_Neq, .Op_Lt, .Op_Le, .Op_Gt, .Op_Ge,
		.Op_And, .Op_Or, .Op_Amper, .Op_Bar, .Op_Tilde,
		.Op_Assign, .Op_Lasgn, .Op_Rasgn, .Op_Lambda, .Op_Colon2,
		.Eof,
	}

	for exp in expected {
		tok := lex_scan_token(&lex)
		testing.expect_value(t, tok.type, exp)
	}
}

@(test)
test_lex_delimiters :: proc(t: ^testing.T) {
	input := "( ) [ ] { } , ; . @"

	lex: Lex
	lex_init(&lex, input)

	expected := []Token_Type{
		.Left_Paren, .Right_Paren, .Left_Bracket, .Right_Bracket,
		.Left_Brace, .Right_Brace, .Comma, .Semicolon, .Dot, .At,
		.Eof,
	}

	for exp in expected {
		tok := lex_scan_token(&lex)
		testing.expect_value(t, tok.type, exp)
	}
}

@(test)
test_lex_integers :: proc(t: ^testing.T) {
	input := "0 1 42 123456"

	lex: Lex
	lex_init(&lex, input)

	for {
		tok := lex_scan_token(&lex)
		if tok.type == .Eof {
			break
		}
		testing.expect_value(t, tok.type, Token_Type.Lit_Int)
	}
}

@(test)
test_lex_hex_octal :: proc(t: ^testing.T) {
	input := "0x1F 0xFF 0o17 0o777"

	lex: Lex
	lex_init(&lex, input)

	for {
		tok := lex_scan_token(&lex)
		if tok.type == .Eof {
			break
		}
		testing.expect_value(t, tok.type, Token_Type.Lit_Int)
	}
}

@(test)
test_lex_floats :: proc(t: ^testing.T) {
	input := "0.0 1.5 3.14159 123.456"

	lex: Lex
	lex_init(&lex, input)

	for {
		tok := lex_scan_token(&lex)
		if tok.type == .Eof {
			break
		}
		testing.expect_value(t, tok.type, Token_Type.Lit_Float)
	}
}

@(test)
test_lex_strings :: proc(t: ^testing.T) {
	input := `"hello" "world" "with spaces" "escaped\"quote"`

	lex: Lex
	lex_init(&lex, input)

	for {
		tok := lex_scan_token(&lex)
		if tok.type == .Eof {
			break
		}
		testing.expect_value(t, tok.type, Token_Type.Lit_String)
	}
}

@(test)
test_lex_symbols :: proc(t: ^testing.T) {
	input := ":foo :bar :baz"

	lex: Lex
	lex_init(&lex, input)

	for {
		tok := lex_scan_token(&lex)
		if tok.type == .Eof {
			break
		}
		testing.expect_value(t, tok.type, Token_Type.Lit_Symbol)
	}
}

@(test)
test_lex_identifiers :: proc(t: ^testing.T) {
	input := "foo bar baz _private camelCase"

	lex: Lex
	lex_init(&lex, input)

	for {
		tok := lex_scan_token(&lex)
		if tok.type == .Eof {
			break
		}
		testing.expect_value(t, tok.type, Token_Type.Ident)
	}
}

@(test)
test_lex_labels :: proc(t: ^testing.T) {
	input := "foo: bar: baz:"

	lex: Lex
	lex_init(&lex, input)

	for {
		tok := lex_scan_token(&lex)
		if tok.type == .Eof {
			break
		}
		testing.expect_value(t, tok.type, Token_Type.Label)
	}
}

@(test)
test_lex_newlines :: proc(t: ^testing.T) {
	input := "foo\nbar\nbaz"

	lex: Lex
	lex_init(&lex, input)

	expected := []Token_Type{
		.Ident, .Newline, .Ident, .Newline, .Ident, .Eof,
	}

	for exp in expected {
		tok := lex_scan_token(&lex)
		testing.expect_value(t, tok.type, exp)
	}
}

@(test)
test_lex_comments :: proc(t: ^testing.T) {
	input := "foo # this is a comment\nbar"

	lex: Lex
	lex_init(&lex, input)

	expected := []Token_Type{
		.Ident, .Newline, .Ident, .Eof,
	}

	for exp in expected {
		tok := lex_scan_token(&lex)
		testing.expect_value(t, tok.type, exp)
	}
}

@(test)
test_lex_lambda_operators :: proc(t: ^testing.T) {
	input := ")-> )->{"

	lex: Lex
	lex_init(&lex, input)

	expected := []Token_Type{
		.Op_Lambda2, .Op_Lambda3, .Eof,
	}

	for exp in expected {
		tok := lex_scan_token(&lex)
		testing.expect_value(t, tok.type, exp)
	}
}

@(test)
test_lex_time_literals :: proc(t: ^testing.T) {
	// Test various time literal formats
	inputs := []struct {
		input:  string,
		lexeme: string,
	}{
		{"2024.01.15", "2024.01.15"},
		{"2024.1.5", "2024.1.5"},
		{"2024.12.31T23:59:59", "2024.12.31T23:59:59"},
		{"2024.12.31T23:59:59Z", "2024.12.31T23:59:59Z"},
		{"2024.12.31T23:59:59+09:00", "2024.12.31T23:59:59+09:00"},
		{"2024.12.31T23:59:59.123", "2024.12.31T23:59:59.123"},
	}

	for input in inputs {
		lex: Lex
		lex_init(&lex, input.input)

		tok := lex_scan_token(&lex)
		testing.expect_value(t, tok.type, Token_Type.Lit_Time)
		testing.expect_value(t, tok.lexeme, input.lexeme)
	}
}

@(test)
test_lex_time_vs_float :: proc(t: ^testing.T) {
	// Test that regular floats are not mistaken for time literals
	inputs := []struct {
		input: string,
		type:  Token_Type,
	}{
		{"123.456", .Lit_Float},    // 3 digits, not 4
		{"12345.67", .Lit_Float},   // 5 digits, not 4
		{"2024.5", .Lit_Float},     // only one part after dot
		{"1.5", .Lit_Float},        // small float
	}

	for input in inputs {
		lex: Lex
		lex_init(&lex, input.input)

		tok := lex_scan_token(&lex)
		testing.expect_value(t, tok.type, input.type)
	}
}

@(test)
test_lex_trail_multiline :: proc(t: ^testing.T) {
	// Test that operators with TRAIL allow continuation
	input := "a +\nb"

	lex: Lex
	lex_init(&lex, input)

	expected := []Token_Type{
		.Ident,     // a
		.Op_Plus,   // + (consumes trailing newline)
		.Ident,     // b
		.Eof,
	}

	for exp in expected {
		tok := lex_scan_token(&lex)
		testing.expect_value(t, tok.type, exp)
	}
}

@(test)
test_lex_trail_with_comment :: proc(t: ^testing.T) {
	// Test that operators with TRAIL skip comments
	input := "a + # comment\nb"

	lex: Lex
	lex_init(&lex, input)

	expected := []Token_Type{
		.Ident,     // a
		.Op_Plus,   // + (consumes trailing comment and newline)
		.Ident,     // b
		.Eof,
	}

	for exp in expected {
		tok := lex_scan_token(&lex)
		testing.expect_value(t, tok.type, exp)
	}
}

@(test)
test_lex_pipe_with_trail :: proc(t: ^testing.T) {
	// Test pipe operator with TRAIL
	input := "stdin |\nstdout"

	lex: Lex
	lex_init(&lex, input)

	expected := []Token_Type{
		.Ident,     // stdin
		.Op_Bar,    // | (consumes trailing newline)
		.Ident,     // stdout
		.Eof,
	}

	for exp in expected {
		tok := lex_scan_token(&lex)
		testing.expect_value(t, tok.type, exp)
	}
}

@(test)
test_lex_position_tracking :: proc(t: ^testing.T) {
	input := "foo\nbar"

	lex: Lex
	lex_init(&lex, input)

	tok := lex_scan_token(&lex)
	testing.expect_value(t, tok.line, 1)
	testing.expect_value(t, tok.type, Token_Type.Ident)

	tok = lex_scan_token(&lex)
	testing.expect_value(t, tok.type, Token_Type.Newline)

	tok = lex_scan_token(&lex)
	testing.expect_value(t, tok.line, 2)
	testing.expect_value(t, tok.type, Token_Type.Ident)
}
