package streem

import "core:fmt"
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

// ============================================================================
// Value Tests
// ============================================================================

@(test)
test_value_nil :: proc(t: ^testing.T) {
	v := strm_nil_value()
	testing.expect(t, strm_nil_p(v), "Expected nil value to be nil")
	testing.expect(t, !strm_bool_p(v), "Expected nil value to not be bool")
	testing.expect(t, !strm_int_p(v), "Expected nil value to not be int")
}

@(test)
test_value_bool :: proc(t: ^testing.T) {
	v_true := strm_bool_value(true)
	v_false := strm_bool_value(false)

	testing.expect(t, strm_bool_p(v_true), "Expected bool value to be bool")
	testing.expect(t, strm_bool_p(v_false), "Expected bool value to be bool")
	testing.expect(t, strm_value_bool(v_true), "Expected true value")
	testing.expect(t, !strm_value_bool(v_false), "Expected false value")
}

@(test)
test_value_int :: proc(t: ^testing.T) {
	v := strm_int_value(42)
	testing.expect(t, strm_int_p(v), "Expected int value to be int")
	testing.expect_value(t, strm_value_int(v), 42)

	v_neg := strm_int_value(-123)
	testing.expect(t, strm_int_p(v_neg), "Expected negative int value to be int")
	testing.expect_value(t, strm_value_int(v_neg), -123)
}

@(test)
test_value_float :: proc(t: ^testing.T) {
	v := strm_float_value(3.14)
	testing.expect(t, strm_float_p(v), "Expected float value to be float")
	testing.expect(t, strm_number_p(v), "Expected float value to be number")

	extracted := strm_value_float(v)
	testing.expect(t, extracted > 3.13 && extracted < 3.15, "Expected float value to be approximately 3.14")
}

@(test)
test_value_equality :: proc(t: ^testing.T) {
	v1 := strm_int_value(42)
	v2 := strm_int_value(42)
	v3 := strm_int_value(43)

	testing.expect(t, strm_value_eq(v1, v2), "Expected equal int values to be equal")
	testing.expect(t, !strm_value_eq(v1, v3), "Expected different int values to not be equal")
}

// ============================================================================
// Node Tests
// ============================================================================

@(test)
test_node_int :: proc(t: ^testing.T) {
	n := node_int_new(42)
	defer node_free(n)

	testing.expect_value(t, n.type, Node_Type.Int)
	data := &n.data.(Node_Int)
	testing.expect_value(t, data.value, i64(42))
}

@(test)
test_node_float :: proc(t: ^testing.T) {
	n := node_float_new(3.14)
	defer node_free(n)

	testing.expect_value(t, n.type, Node_Type.Float)
	data := &n.data.(Node_Float)
	testing.expect(t, data.value > 3.13 && data.value < 3.15, "Expected float value")
}

@(test)
test_node_string :: proc(t: ^testing.T) {
	n := node_string_new("hello")
	defer node_free(n)

	testing.expect_value(t, n.type, Node_Type.Str)
	data := &n.data.(Node_Str)
	testing.expect_value(t, data.value, "hello")
}

@(test)
test_node_bool :: proc(t: ^testing.T) {
	n_true := node_bool_new(true)
	n_false := node_bool_new(false)
	defer {
		node_free(n_true)
		node_free(n_false)
	}

	testing.expect_value(t, n_true.type, Node_Type.Bool)
	testing.expect_value(t, n_false.type, Node_Type.Bool)

	data_true := &n_true.data.(Node_Bool)
	data_false := &n_false.data.(Node_Bool)
	testing.expect(t, data_true.value, "Expected true")
	testing.expect(t, !data_false.value, "Expected false")
}

@(test)
test_node_op :: proc(t: ^testing.T) {
	lhs := node_int_new(1)
	rhs := node_int_new(2)
	n := node_op_new("+", lhs, rhs)
	defer node_free(n)

	testing.expect_value(t, n.type, Node_Type.Op)
	data := &n.data.(Node_Op)
	testing.expect_value(t, data.op, "+")
}

@(test)
test_node_array :: proc(t: ^testing.T) {
	arr := node_array_new()
	node_array_add(arr, node_int_new(1))
	node_array_add(arr, node_int_new(2))
	node_array_add(arr, node_int_new(3))
	defer node_free(arr)

	testing.expect_value(t, arr.type, Node_Type.Array)
	data := &arr.data.(Node_Array)
	testing.expect_value(t, len(data.elements), 3)
}

@(test)
test_node_nodes :: proc(t: ^testing.T) {
	nodes := node_nodes_new()
	node_nodes_add(nodes, node_int_new(1))
	node_nodes_add(nodes, node_int_new(2))
	defer node_free(nodes)

	testing.expect_value(t, nodes.type, Node_Type.Nodes)
	data := &nodes.data.(Node_Nodes)
	testing.expect_value(t, len(data.nodes), 2)
}

// ============================================================================
// State Tests
// ============================================================================

@(test)
test_state_var_def :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	ok := strm_var_def(state, "x", strm_int_value(42))
	testing.expect(t, ok, "Expected var_def to succeed")

	ok = strm_var_def(state, "x", strm_int_value(43))
	testing.expect(t, !ok, "Expected second var_def to fail")
}

@(test)
test_state_var_get :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	strm_var_def(state, "x", strm_int_value(42))

	val, found := strm_var_get(state, "x")
	testing.expect(t, found, "Expected var to be found")
	testing.expect_value(t, strm_value_int(val), 42)

	_, found = strm_var_get(state, "y")
	testing.expect(t, !found, "Expected var to not be found")
}

@(test)
test_state_scoping :: proc(t: ^testing.T) {
	outer := strm_state_new()
	defer strm_state_destroy(outer)

	strm_var_def(outer, "x", strm_int_value(1))

	inner := strm_state_new(outer)
	defer strm_state_destroy(inner)

	strm_var_def(inner, "y", strm_int_value(2))

	// Inner can access outer's variables
	val, found := strm_var_get(inner, "x")
	testing.expect(t, found, "Expected outer var to be visible")
	testing.expect_value(t, strm_value_int(val), 1)

	// Inner has its own variables
	val, found = strm_var_get(inner, "y")
	testing.expect(t, found, "Expected inner var to be visible")
	testing.expect_value(t, strm_value_int(val), 2)

	// Outer cannot access inner's variables
	_, found = strm_var_get(outer, "y")
	testing.expect(t, !found, "Expected inner var to not be visible in outer")
}

// ============================================================================
// Queue Tests
// ============================================================================

@(test)
test_queue_basic :: proc(t: ^testing.T) {
	q := strm_queue_new()
	defer strm_queue_destroy(q)

	testing.expect(t, strm_queue_empty_p(q), "Expected empty queue")

	// Add items
	data1 := rawptr(uintptr(1))
	data2 := rawptr(uintptr(2))
	data3 := rawptr(uintptr(3))

	strm_queue_add(q, data1)
	strm_queue_add(q, data2)
	strm_queue_add(q, data3)

	testing.expect(t, !strm_queue_empty_p(q), "Expected non-empty queue")

	// Get items in FIFO order
	testing.expect_value(t, strm_queue_get(q), data1)
	testing.expect_value(t, strm_queue_get(q), data2)
	testing.expect_value(t, strm_queue_get(q), data3)

	testing.expect(t, strm_queue_empty_p(q), "Expected empty queue after gets")
	testing.expect_value(t, strm_queue_get(q), rawptr(nil))
}

// ============================================================================
// Token Utility Tests
// ============================================================================

@(test)
test_token_is_keyword :: proc(t: ^testing.T) {
	testing.expect(t, token_is_keyword(.Kw_If), "if should be keyword")
	testing.expect(t, token_is_keyword(.Kw_Def), "def should be keyword")
	testing.expect(t, !token_is_keyword(.Ident), "Ident should not be keyword")
	testing.expect(t, !token_is_keyword(.Op_Plus), "Op_Plus should not be keyword")
}

@(test)
test_token_is_binary_op :: proc(t: ^testing.T) {
	testing.expect(t, token_is_binary_op(.Op_Plus), "+ should be binary op")
	testing.expect(t, token_is_binary_op(.Op_Eq), "== should be binary op")
	testing.expect(t, !token_is_binary_op(.Kw_If), "if should not be binary op")
}

@(test)
test_token_is_unary_op :: proc(t: ^testing.T) {
	testing.expect(t, token_is_unary_op(.Op_Minus), "- should be unary op")
	testing.expect(t, token_is_unary_op(.Op_Not), "! should be unary op")
	testing.expect(t, token_is_unary_op(.Op_Tilde), "~ should be unary op")
	testing.expect(t, !token_is_unary_op(.Op_Plus), "+ should not be unary op")
}

@(test)
test_token_is_literal :: proc(t: ^testing.T) {
	testing.expect(t, token_is_literal(.Lit_Int), "Lit_Int should be literal")
	testing.expect(t, token_is_literal(.Lit_String), "Lit_String should be literal")
	testing.expect(t, token_is_literal(.Kw_Nil), "nil should be literal")
	testing.expect(t, token_is_literal(.Kw_True), "true should be literal")
	testing.expect(t, !token_is_literal(.Ident), "Ident should not be literal")
}
