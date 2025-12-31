package streem

import "core:testing"

// ============================================================================
// Literal Evaluation Tests
// ============================================================================

@(test)
test_exec_int :: proc(t: ^testing.T) {
	node := node_int_new(42)
	ret: Strm_Value
	result := exec_expr(nil, nil, node, &ret)

	testing.expect_value(t, result, Exec_Result.Ok)
	testing.expect(t, strm_int_p(ret), "Expected int value")
	testing.expect_value(t, strm_value_int(ret), 42)
}

@(test)
test_exec_float :: proc(t: ^testing.T) {
	node := node_float_new(3.14)
	ret: Strm_Value
	result := exec_expr(nil, nil, node, &ret)

	testing.expect_value(t, result, Exec_Result.Ok)
	testing.expect(t, strm_float_p(ret), "Expected float value")
	testing.expect(t, abs(strm_value_float(ret) - 3.14) < 0.0001, "Expected ~3.14")
}

@(test)
test_exec_string :: proc(t: ^testing.T) {
	node := node_string_new("hello")
	ret: Strm_Value
	result := exec_expr(nil, nil, node, &ret)

	testing.expect_value(t, result, Exec_Result.Ok)
	testing.expect(t, strm_string_p(ret), "Expected string value")
	str := Strm_String(ret)
	testing.expect_value(t, strm_str_ptr(&str), "hello")
}

@(test)
test_exec_bool :: proc(t: ^testing.T) {
	// Test true
	node_true := node_bool_new(true)
	ret: Strm_Value
	result := exec_expr(nil, nil, node_true, &ret)

	testing.expect_value(t, result, Exec_Result.Ok)
	testing.expect(t, strm_bool_p(ret), "Expected bool value")
	testing.expect(t, strm_value_bool(ret), "Expected true")

	// Test false
	node_false := node_bool_new(false)
	result = exec_expr(nil, nil, node_false, &ret)

	testing.expect_value(t, result, Exec_Result.Ok)
	testing.expect(t, strm_bool_p(ret), "Expected bool value")
	testing.expect(t, !strm_value_bool(ret), "Expected false")
}

@(test)
test_exec_nil :: proc(t: ^testing.T) {
	node := node_nil_new()
	ret: Strm_Value
	result := exec_expr(nil, nil, node, &ret)

	testing.expect_value(t, result, Exec_Result.Ok)
	testing.expect(t, strm_nil_p(ret), "Expected nil value")
}

// ============================================================================
// Identifier Evaluation Tests
// ============================================================================

@(test)
test_exec_ident :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	// Define a variable
	strm_var_def(state, "x", strm_int_value(100))

	// Create identifier node
	node := node_ident_new("x")
	ret: Strm_Value
	result := exec_expr(nil, state, node, &ret)

	testing.expect_value(t, result, Exec_Result.Ok)
	testing.expect(t, strm_int_p(ret), "Expected int value")
	testing.expect_value(t, strm_value_int(ret), 100)
}

@(test)
test_exec_ident_not_found :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	// Create identifier node for undefined variable
	node := node_ident_new("undefined_var")
	ret: Strm_Value
	result := exec_expr(nil, state, node, &ret)

	// Should return error for undefined variable
	testing.expect_value(t, result, Exec_Result.Error)
}

// ============================================================================
// Operator Evaluation Tests
// Note: Operator execution requires built-in functions to be registered (Phase 12+)
// These tests verify the operator dispatch mechanism structure
// ============================================================================

@(test)
test_exec_op_with_cfunc :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)
	defer strm_ns_cleanup()

	// Initialize namespaces
	strm_ns_init()

	// Register a simple add function in Number namespace
	add_func :: proc(strm: ^Strm_Stream, argc: int, argv: []Strm_Value, ret: ^Strm_Value) -> int {
		if argc != 2 {
			return STRM_NG
		}
		a := strm_value_float(argv[0])
		b := strm_value_float(argv[1])
		ret^ = strm_float_value(a + b)
		return STRM_OK
	}

	strm_var_def(strm_ns_number, "+", strm_cfunc_value(add_func))

	// 1 + 2 = 3
	lhs := node_int_new(1)
	rhs := node_int_new(2)
	node := node_op_new("+", lhs, rhs)

	ret: Strm_Value
	result := exec_expr(nil, state, node, &ret)

	testing.expect_value(t, result, Exec_Result.Ok)
	testing.expect(t, strm_float_p(ret), "Expected float value")
	testing.expect_value(t, strm_value_float(ret), 3.0)
}

// ============================================================================
// If Expression Tests
// ============================================================================

@(test)
test_exec_if_true :: proc(t: ^testing.T) {
	// if true { 42 } else { 0 }
	cond := node_bool_new(true)
	then_node := node_int_new(42)
	else_node := node_int_new(0)
	node := node_if_new(cond, then_node, else_node)

	ret: Strm_Value
	result := exec_expr(nil, nil, node, &ret)

	testing.expect_value(t, result, Exec_Result.Ok)
	testing.expect_value(t, strm_value_int(ret), 42)
}

@(test)
test_exec_if_false :: proc(t: ^testing.T) {
	// if false { 42 } else { 0 }
	cond := node_bool_new(false)
	then_node := node_int_new(42)
	else_node := node_int_new(0)
	node := node_if_new(cond, then_node, else_node)

	ret: Strm_Value
	result := exec_expr(nil, nil, node, &ret)

	testing.expect_value(t, result, Exec_Result.Ok)
	testing.expect_value(t, strm_value_int(ret), 0)
}

// ============================================================================
// Array Evaluation Tests
// ============================================================================

@(test)
test_exec_array :: proc(t: ^testing.T) {
	// [1, 2, 3]
	node := node_array_new()
	node_array_add(node, node_int_new(1))
	node_array_add(node, node_int_new(2))
	node_array_add(node, node_int_new(3))

	ret: Strm_Value
	result := exec_expr(nil, nil, node, &ret)

	testing.expect_value(t, result, Exec_Result.Ok)
	testing.expect(t, strm_array_p(ret), "Expected array value")

	ary := Strm_Array(ret)
	testing.expect_value(t, strm_ary_len(ary), 3)

	ptr := strm_ary_ptr(ary)
	testing.expect_value(t, strm_value_int(ptr[0]), 1)
	testing.expect_value(t, strm_value_int(ptr[1]), 2)
	testing.expect_value(t, strm_value_int(ptr[2]), 3)
}

@(test)
test_exec_array_empty :: proc(t: ^testing.T) {
	// []
	node := node_array_new()

	ret: Strm_Value
	result := exec_expr(nil, nil, node, &ret)

	testing.expect_value(t, result, Exec_Result.Ok)
	testing.expect(t, strm_array_p(ret), "Expected array value")

	ary := Strm_Array(ret)
	testing.expect_value(t, strm_ary_len(ary), 0)
}

// ============================================================================
// Let Statement Tests
// ============================================================================

@(test)
test_exec_let :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	// x = 42
	node := node_let_new("x", node_int_new(42))

	ret: Strm_Value
	result := exec_expr(nil, state, node, &ret)

	testing.expect_value(t, result, Exec_Result.Ok)

	// Check variable was defined
	val, found := strm_var_get(state, "x")
	testing.expect(t, found, "Expected variable x to be defined")
	testing.expect_value(t, strm_value_int(val), 42)
}

// ============================================================================
// Lambda Tests
// ============================================================================

@(test)
test_exec_lambda :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	// Create lambda: {|x| x + 1}
	body := node_op_new("+", node_ident_new("x"), node_int_new(1))
	args := node_args_new()
	node_args_add(args, "x")
	node := node_lambda_new(args, body)

	ret: Strm_Value
	result := exec_expr(nil, state, node, &ret)

	testing.expect_value(t, result, Exec_Result.Ok)
	testing.expect(t, strm_lambda_p(ret), "Expected lambda value")
}

@(test)
test_strm_lambda_new :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	body := node_int_new(42)
	lambda := strm_lambda_new(body, state)
	defer strm_lambda_destroy(lambda)

	testing.expect(t, lambda != nil, "Expected lambda to be created")
	testing.expect_value(t, lambda.type, Ptr_Type.Lambda)
	testing.expect(t, lambda.body == body, "Expected body to match")
	testing.expect(t, lambda.state != nil, "Expected state to be captured")
}

// ============================================================================
// Genfunc Tests
// ============================================================================

@(test)
test_strm_genfunc_new :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	name := strm_str_intern("myFunc")
	gf := strm_genfunc_new(state, name)
	defer free(gf)

	testing.expect(t, gf != nil, "Expected genfunc to be created")
	testing.expect_value(t, gf.type, Ptr_Type.Genfunc)
	testing.expect(t, gf.state == state, "Expected state to match")
	testing.expect(t, strm_str_eq(gf.id, name), "Expected id to match")
}

// ============================================================================
// Pattern Matching Tests
// ============================================================================

@(test)
test_pattern_placeholder :: proc(t: ^testing.T) {
	testing.expect(t, pattern_placeholder_p("_"), "Expected _ to be placeholder")
	testing.expect(t, !pattern_placeholder_p("x"), "Expected x to not be placeholder")
	testing.expect(t, !pattern_placeholder_p("_x"), "Expected _x to not be placeholder")
}

@(test)
test_pmatch_ident :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	// Pattern match: x = 42
	pat := node_ident_new("x")
	val := strm_int_value(42)

	matched := pmatch(nil, state, pat, val)
	testing.expect(t, matched, "Expected identifier pattern to match")

	// Check variable was bound
	v, found := strm_var_get(state, "x")
	testing.expect(t, found, "Expected x to be bound")
	testing.expect_value(t, strm_value_int(v), 42)
}

@(test)
test_pmatch_placeholder :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	// Pattern match: _ = 42 (should match without binding)
	pat := node_ident_new("_")
	val := strm_int_value(42)

	matched := pmatch(nil, state, pat, val)
	testing.expect(t, matched, "Expected placeholder to match")

	// Check variable was NOT bound
	_, found := strm_var_get(state, "_")
	testing.expect(t, !found, "Expected _ to not be bound")
}

@(test)
test_pmatch_int :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	// Pattern match: 42 = 42 (should match)
	pat := node_int_new(42)
	val := strm_int_value(42)
	testing.expect(t, pmatch(nil, state, pat, val), "Expected 42 to match 42")

	// Pattern match: 42 = 43 (should not match)
	val2 := strm_int_value(43)
	testing.expect(t, !pmatch(nil, state, pat, val2), "Expected 42 to not match 43")
}

@(test)
test_pmatch_string :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	// Pattern match: "hello" = "hello" (should match)
	pat := node_string_new("hello")
	val := strm_str_value(strm_str_new("hello"))
	testing.expect(t, pmatch(nil, state, pat, val), "Expected strings to match")

	// Pattern match: "hello" = "world" (should not match)
	val2 := strm_str_value(strm_str_new("world"))
	testing.expect(t, !pmatch(nil, state, pat, val2), "Expected strings to not match")
}

@(test)
test_pmatch_nil :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	// Pattern match: nil = nil (should match)
	pat := node_nil_new()
	val := strm_nil_value()
	testing.expect(t, pmatch(nil, state, pat, val), "Expected nil to match nil")

	// Pattern match: nil = 42 (should not match)
	val2 := strm_int_value(42)
	testing.expect(t, !pmatch(nil, state, pat, val2), "Expected nil to not match int")
}

// ============================================================================
// Nodes Evaluation Tests
// ============================================================================

@(test)
test_exec_nodes :: proc(t: ^testing.T) {
	state := strm_state_new()
	defer strm_state_destroy(state)

	// x = 1; y = 2; y (returns last value)
	node := node_nodes_new()
	node_nodes_add(node, node_let_new("x", node_int_new(1)))
	node_nodes_add(node, node_let_new("y", node_int_new(2)))
	node_nodes_add(node, node_ident_new("y"))

	ret: Strm_Value
	result := exec_expr(nil, state, node, &ret)

	testing.expect_value(t, result, Exec_Result.Ok)
	testing.expect_value(t, strm_value_int(ret), 2)

	// Check both variables are set
	val_x, _ := strm_var_get(state, "x")
	testing.expect_value(t, strm_value_int(val_x), 1)
	val_y, _ := strm_var_get(state, "y")
	testing.expect_value(t, strm_value_int(val_y), 2)
}
