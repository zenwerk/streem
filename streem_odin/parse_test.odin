package streem

import "core:testing"

// ============================================================================
// Parser Tests
// ============================================================================

@(test)
test_parse_integer :: proc(t: ^testing.T) {
	node, ok := parse_string("42")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")

	if node != nil {
		// Should be wrapped in Nodes
		testing.expect_value(t, node.type, Node_Type.Nodes)
		if node.type == .Nodes {
			nodes := &node.data.(Node_Nodes)
			testing.expect_value(t, len(nodes.nodes), 1)
			if len(nodes.nodes) > 0 {
				first := nodes.nodes[0]
				testing.expect_value(t, first.type, Node_Type.Int)
				if first.type == .Int {
					data := &first.data.(Node_Int)
					testing.expect_value(t, data.value, i64(42))
				}
			}
		}
	}
}

@(test)
test_parse_float :: proc(t: ^testing.T) {
	node, ok := parse_string("3.14")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")
}

@(test)
test_parse_string_literal :: proc(t: ^testing.T) {
	node, ok := parse_string("\"hello\"")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")
}

@(test)
test_parse_identifier :: proc(t: ^testing.T) {
	node, ok := parse_string("foo")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")
}

@(test)
test_parse_binary_op_add :: proc(t: ^testing.T) {
	node, ok := parse_string("1 + 2")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")

	if node != nil && node.type == .Nodes {
		nodes := &node.data.(Node_Nodes)
		if len(nodes.nodes) > 0 {
			first := nodes.nodes[0]
			testing.expect_value(t, first.type, Node_Type.Op)
			if first.type == .Op {
				data := &first.data.(Node_Op)
				testing.expect_value(t, data.op, "+")
				testing.expect(t, data.lhs != nil, "Expected left operand")
				testing.expect(t, data.rhs != nil, "Expected right operand")
			}
		}
	}
}

@(test)
test_parse_binary_op_mul :: proc(t: ^testing.T) {
	node, ok := parse_string("2 * 3")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")
}

@(test)
test_parse_precedence :: proc(t: ^testing.T) {
	// 1 + 2 * 3 should parse as 1 + (2 * 3)
	node, ok := parse_string("1 + 2 * 3")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")

	if node != nil && node.type == .Nodes {
		nodes := &node.data.(Node_Nodes)
		if len(nodes.nodes) > 0 {
			first := nodes.nodes[0]
			testing.expect_value(t, first.type, Node_Type.Op)
			if first.type == .Op {
				data := &first.data.(Node_Op)
				testing.expect_value(t, data.op, "+")
				// RHS should be a multiply
				if data.rhs != nil && data.rhs.type == .Op {
					rhs_data := &data.rhs.data.(Node_Op)
					testing.expect_value(t, rhs_data.op, "*")
				}
			}
		}
	}
}

@(test)
test_parse_unary_minus :: proc(t: ^testing.T) {
	node, ok := parse_string("-42")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")

	if node != nil && node.type == .Nodes {
		nodes := &node.data.(Node_Nodes)
		if len(nodes.nodes) > 0 {
			first := nodes.nodes[0]
			testing.expect_value(t, first.type, Node_Type.Op)
			if first.type == .Op {
				data := &first.data.(Node_Op)
				testing.expect_value(t, data.op, "-")
				testing.expect(t, data.lhs == nil, "Expected nil lhs for unary")
				testing.expect(t, data.rhs != nil, "Expected rhs")
			}
		}
	}
}

@(test)
test_parse_let :: proc(t: ^testing.T) {
	node, ok := parse_string("x = 1")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")

	if node != nil && node.type == .Nodes {
		nodes := &node.data.(Node_Nodes)
		if len(nodes.nodes) > 0 {
			first := nodes.nodes[0]
			testing.expect_value(t, first.type, Node_Type.Let)
			if first.type == .Let {
				data := &first.data.(Node_Let)
				testing.expect_value(t, data.lhs, "x")
			}
		}
	}
}

@(test)
test_parse_function_call :: proc(t: ^testing.T) {
	node, ok := parse_string("foo(1, 2)")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")

	if node != nil && node.type == .Nodes {
		nodes := &node.data.(Node_Nodes)
		if len(nodes.nodes) > 0 {
			first := nodes.nodes[0]
			testing.expect_value(t, first.type, Node_Type.Call)
			if first.type == .Call {
				data := &first.data.(Node_Call)
				testing.expect_value(t, data.name, "foo")
			}
		}
	}
}

@(test)
test_parse_array :: proc(t: ^testing.T) {
	node, ok := parse_string("[1, 2, 3]")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")

	if node != nil && node.type == .Nodes {
		nodes := &node.data.(Node_Nodes)
		if len(nodes.nodes) > 0 {
			first := nodes.nodes[0]
			testing.expect_value(t, first.type, Node_Type.Array)
			if first.type == .Array {
				data := &first.data.(Node_Array)
				testing.expect_value(t, len(data.elements), 3)
			}
		}
	}
}

@(test)
test_parse_empty_array :: proc(t: ^testing.T) {
	node, ok := parse_string("[]")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")
}

@(test)
test_parse_block :: proc(t: ^testing.T) {
	node, ok := parse_string("{ 1 }")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")
}

@(test)
test_parse_if :: proc(t: ^testing.T) {
	node, ok := parse_string("if (x) 1 else 2")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")

	if node != nil && node.type == .Nodes {
		nodes := &node.data.(Node_Nodes)
		if len(nodes.nodes) > 0 {
			first := nodes.nodes[0]
			testing.expect_value(t, first.type, Node_Type.If)
		}
	}
}

@(test)
test_parse_def :: proc(t: ^testing.T) {
	node, ok := parse_string("def add(a, b) { a + b }")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")

	if node != nil && node.type == .Nodes {
		nodes := &node.data.(Node_Nodes)
		if len(nodes.nodes) > 0 {
			first := nodes.nodes[0]
			testing.expect_value(t, first.type, Node_Type.Let)
			if first.type == .Let {
				data := &first.data.(Node_Let)
				testing.expect_value(t, data.lhs, "add")
			}
		}
	}
}

@(test)
test_parse_skip :: proc(t: ^testing.T) {
	node, ok := parse_string("skip")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")

	if node != nil && node.type == .Nodes {
		nodes := &node.data.(Node_Nodes)
		if len(nodes.nodes) > 0 {
			first := nodes.nodes[0]
			testing.expect_value(t, first.type, Node_Type.Skip)
		}
	}
}

@(test)
test_parse_emit :: proc(t: ^testing.T) {
	node, ok := parse_string("emit 42")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")

	if node != nil && node.type == .Nodes {
		nodes := &node.data.(Node_Nodes)
		if len(nodes.nodes) > 0 {
			first := nodes.nodes[0]
			testing.expect_value(t, first.type, Node_Type.Emit)
		}
	}
}

@(test)
test_parse_return :: proc(t: ^testing.T) {
	node, ok := parse_string("return 42")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")

	if node != nil && node.type == .Nodes {
		nodes := &node.data.(Node_Nodes)
		if len(nodes.nodes) > 0 {
			first := nodes.nodes[0]
			testing.expect_value(t, first.type, Node_Type.Return)
		}
	}
}

@(test)
test_parse_nil :: proc(t: ^testing.T) {
	node, ok := parse_string("nil")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")

	if node != nil && node.type == .Nodes {
		nodes := &node.data.(Node_Nodes)
		if len(nodes.nodes) > 0 {
			first := nodes.nodes[0]
			testing.expect_value(t, first.type, Node_Type.Nil)
		}
	}
}

@(test)
test_parse_true_false :: proc(t: ^testing.T) {
	node, ok := parse_string("true")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")

	node2, ok2 := parse_string("false")
	defer node_free(node2)

	testing.expect(t, ok2, "Expected successful parse")
}

@(test)
test_parse_pipe :: proc(t: ^testing.T) {
	node, ok := parse_string("a | b")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")

	if node != nil && node.type == .Nodes {
		nodes := &node.data.(Node_Nodes)
		if len(nodes.nodes) > 0 {
			first := nodes.nodes[0]
			testing.expect_value(t, first.type, Node_Type.Op)
			if first.type == .Op {
				data := &first.data.(Node_Op)
				testing.expect_value(t, data.op, "|")
			}
		}
	}
}

@(test)
test_parse_multi_stmt :: proc(t: ^testing.T) {
	node, ok := parse_string("x = 1\ny = 2")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")

	if node != nil && node.type == .Nodes {
		nodes := &node.data.(Node_Nodes)
		testing.expect_value(t, len(nodes.nodes), 2)
	}
}

@(test)
test_parse_namespace :: proc(t: ^testing.T) {
	node, ok := parse_string("namespace Foo { x = 1 }")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")

	if node != nil && node.type == .Nodes {
		nodes := &node.data.(Node_Nodes)
		if len(nodes.nodes) > 0 {
			first := nodes.nodes[0]
			testing.expect_value(t, first.type, Node_Type.Ns)
			if first.type == .Ns {
				data := &first.data.(Node_Ns)
				testing.expect_value(t, data.name, "Foo")
			}
		}
	}
}

@(test)
test_parse_import :: proc(t: ^testing.T) {
	node, ok := parse_string("import Foo")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")

	if node != nil && node.type == .Nodes {
		nodes := &node.data.(Node_Nodes)
		if len(nodes.nodes) > 0 {
			first := nodes.nodes[0]
			testing.expect_value(t, first.type, Node_Type.Import)
			if first.type == .Import {
				data := &first.data.(Node_Import)
				testing.expect_value(t, data.name, "Foo")
			}
		}
	}
}

@(test)
test_parse_genfunc :: proc(t: ^testing.T) {
	node, ok := parse_string("&foo")
	defer node_free(node)

	testing.expect(t, ok, "Expected successful parse")
	testing.expect(t, node != nil, "Expected non-nil AST")

	if node != nil && node.type == .Nodes {
		nodes := &node.data.(Node_Nodes)
		if len(nodes.nodes) > 0 {
			first := nodes.nodes[0]
			testing.expect_value(t, first.type, Node_Type.Genfunc)
			if first.type == .Genfunc {
				data := &first.data.(Node_Genfunc)
				testing.expect_value(t, data.name, "foo")
			}
		}
	}
}
