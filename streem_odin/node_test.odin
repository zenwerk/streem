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
