package streem

import "core:testing"

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

@(test)
test_node_parray :: proc(t: ^testing.T) {
	// Test pattern array creation
	parray := node_parray_new()
	defer node_free(parray)

	testing.expect_value(t, parray.type, Node_Type.PArray)

	// Add patterns
	node_parray_add(parray, node_ident_new("x"))
	node_parray_add(parray, node_ident_new("y"))

	data := &parray.data.(Node_PArray)
	testing.expect_value(t, len(data.patterns), 2)
}

@(test)
test_node_pstruct :: proc(t: ^testing.T) {
	// Test pattern struct creation
	pstruct := node_pstruct_new()
	defer node_free(pstruct)

	testing.expect_value(t, pstruct.type, Node_Type.PStruct)

	// Add labeled patterns (key:pattern pairs)
	node_pstruct_add(pstruct, node_pair_new("name", node_ident_new("n")))
	node_pstruct_add(pstruct, node_pair_new("age", node_ident_new("a")))

	data := &pstruct.data.(Node_PStruct)
	testing.expect_value(t, len(data.patterns), 2)
}

@(test)
test_node_pattern_new :: proc(t: ^testing.T) {
	// Test generic pattern creation with PArray
	parray := node_pattern_new(.PArray)
	defer node_free(parray)
	testing.expect_value(t, parray.type, Node_Type.PArray)

	// Test generic pattern creation with PStruct
	pstruct := node_pattern_new(.PStruct)
	defer node_free(pstruct)
	testing.expect_value(t, pstruct.type, Node_Type.PStruct)

	// Test default (should be PArray)
	default_pat := node_pattern_new()
	defer node_free(default_pat)
	testing.expect_value(t, default_pat.type, Node_Type.PArray)
}

@(test)
test_node_pattern_add :: proc(t: ^testing.T) {
	// Test adding to PArray
	parray := node_pattern_new(.PArray)
	defer node_free(parray)

	node_pattern_add(parray, node_ident_new("a"))
	node_pattern_add(parray, node_ident_new("b"))

	data := &parray.data.(Node_PArray)
	testing.expect_value(t, len(data.patterns), 2)

	// Test adding to PStruct
	pstruct := node_pattern_new(.PStruct)
	defer node_free(pstruct)

	node_pattern_add(pstruct, node_pair_new("x", node_ident_new("x")))

	data2 := &pstruct.data.(Node_PStruct)
	testing.expect_value(t, len(data2.patterns), 1)
}

@(test)
test_node_psplat :: proc(t: ^testing.T) {
	// Test pattern splat [head, *mid, tail]
	head := node_parray_new()
	node_parray_add(head, node_ident_new("a"))

	mid := node_ident_new("rest")

	tail := node_parray_new()
	node_parray_add(tail, node_ident_new("z"))

	psplat := node_psplat_new(head, mid, tail)
	defer node_free(psplat)

	testing.expect_value(t, psplat.type, Node_Type.PSplat)

	data := &psplat.data.(Node_PSplat)
	testing.expect(t, data.head != nil, "Expected head")
	testing.expect(t, data.mid != nil, "Expected mid")
	testing.expect(t, data.tail != nil, "Expected tail")
}

@(test)
test_node_plambda :: proc(t: ^testing.T) {
	// Test pattern lambda creation
	pat := node_parray_new()
	node_parray_add(pat, node_ident_new("x"))

	plambda := node_plambda_new(pat, nil)
	defer node_free(plambda)

	testing.expect_value(t, plambda.type, Node_Type.PLambda)

	// Test setting body
	body := node_int_new(42)
	node_plambda_body(plambda, body)

	data := &plambda.data.(Node_PLambda)
	testing.expect(t, data.body != nil, "Expected body")
	testing.expect_value(t, data.body.type, Node_Type.Int)
}

@(test)
test_node_plambda_chain :: proc(t: ^testing.T) {
	// Test pattern lambda chaining (multiple case clauses)
	pat1 := node_parray_new()
	node_parray_add(pat1, node_ident_new("x"))
	plambda1 := node_plambda_new(pat1, nil)
	node_plambda_body(plambda1, node_int_new(1))

	pat2 := node_parray_new()
	node_parray_add(pat2, node_ident_new("y"))
	plambda2 := node_plambda_new(pat2, nil)
	node_plambda_body(plambda2, node_int_new(2))

	// Chain them
	node_plambda_add(plambda1, plambda2)
	defer node_free(plambda1)

	// Verify chain
	data1 := &plambda1.data.(Node_PLambda)
	testing.expect(t, data1.next_ != nil, "Expected next plambda")
	testing.expect_value(t, data1.next_.type, Node_Type.PLambda)
}
