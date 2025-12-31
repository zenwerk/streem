package streem

// AST evaluator
// Reference: src/exec.c

// Execution result
Exec_Result :: enum {
	Ok,
	Error,
	Return,
	Skip,
}

// ============================================================================
// Main evaluation entry point
// ============================================================================

// Evaluate an expression node
exec_expr :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	if node == nil {
		ret^ = strm_nil_value()
		return .Ok
	}

	switch node.type {
	// Literals
	case .Int:
		return exec_int(node, ret)
	case .Float:
		return exec_float(node, ret)
	case .Str:
		return exec_string(node, ret)
	case .Bool:
		return exec_bool(node, ret)
	case .Nil:
		ret^ = strm_nil_value()
		return .Ok
	case .Time:
		return exec_time(node, ret)

	// Expressions
	case .Ident:
		return exec_ident(strm, state, node, ret)
	case .Op:
		return exec_op(strm, state, node, ret)
	case .If:
		return exec_if(strm, state, node, ret)
	case .Array:
		return exec_array(strm, state, node, ret)

	// Statements
	case .Let:
		return exec_let(strm, state, node, ret)
	case .Emit:
		return exec_emit(strm, state, node, ret)
	case .Skip:
		return .Skip
	case .Return:
		return exec_return(strm, state, node, ret)
	case .Nodes:
		return exec_nodes(strm, state, node, ret)

	// Functions
	case .Lambda, .PLambda:
		return exec_lambda(strm, state, node, ret)
	case .Call:
		return exec_call(strm, state, node, ret)
	case .Fcall:
		return exec_fcall(strm, state, node, ret)
	case .Genfunc:
		return exec_genfunc(state, node, ret)

	// Namespace
	case .Ns:
		return exec_ns(strm, state, node, ret)
	case .Import:
		return exec_import(state, node, ret)

	// Pattern matching nodes (handled in lambda_call)
	case .Args, .Pair, .Splat, .PArray, .PStruct, .PSplat:
		ret^ = strm_nil_value()
		return .Error
	}

	ret^ = strm_nil_value()
	return .Error
}

// ============================================================================
// Literal evaluation
// ============================================================================

exec_int :: proc(node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Int)
	ret^ = strm_int_value(i32(data.value))
	return .Ok
}

exec_float :: proc(node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Float)
	ret^ = strm_float_value(data.value)
	return .Ok
}

exec_string :: proc(node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	// TODO: Create string value from node data
	ret^ = strm_nil_value()
	return .Ok
}

exec_bool :: proc(node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Bool)
	ret^ = strm_bool_value(data.value)
	return .Ok
}

exec_time :: proc(node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	// TODO: Create time value from node data
	ret^ = strm_nil_value()
	return .Ok
}

// ============================================================================
// Expression evaluation
// ============================================================================

exec_ident :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Ident)
	val, found := strm_var_get(state, data.name)
	if !found {
		// Variable not found
		ret^ = strm_nil_value()
		return .Error
	}
	ret^ = val
	return .Ok
}

exec_op :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Op)

	// Evaluate operands
	lhs_val: Strm_Value
	rhs_val: Strm_Value

	// Unary operator if lhs is nil
	if data.lhs != nil {
		result := exec_expr(strm, state, data.lhs, &lhs_val)
		if result != .Ok {
			return result
		}
	}

	result := exec_expr(strm, state, data.rhs, &rhs_val)
	if result != .Ok {
		return result
	}

	// TODO: Dispatch to registered operator function
	// For now, implement basic arithmetic

	ret^ = strm_nil_value()
	return .Ok
}

exec_if :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_If)

	// Evaluate condition
	cond_val: Strm_Value
	result := exec_expr(strm, state, data.cond, &cond_val)
	if result != .Ok {
		return result
	}

	// Check truthiness
	is_true := true
	if strm_nil_p(cond_val) {
		is_true = false
	} else if strm_bool_p(cond_val) {
		is_true = strm_value_bool(cond_val)
	}

	if is_true {
		return exec_expr(strm, state, data.then_, ret)
	} else if data.opt_else != nil {
		return exec_expr(strm, state, data.opt_else, ret)
	}

	ret^ = strm_nil_value()
	return .Ok
}

exec_array :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	// TODO: Build array value with splat support
	ret^ = strm_nil_value()
	return .Ok
}

// ============================================================================
// Statement evaluation
// ============================================================================

exec_let :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Let)

	// Evaluate right-hand side
	val: Strm_Value
	result := exec_expr(strm, state, data.rhs, &val)
	if result != .Ok {
		return result
	}

	// Assign to variable
	strm_var_set(state, data.lhs, val)

	ret^ = val
	return .Ok
}

exec_emit :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Emit)

	// Evaluate value to emit
	val: Strm_Value
	result := exec_expr(strm, state, data.value, &val)
	if result != .Ok {
		return result
	}

	// Emit to downstream
	if strm != nil {
		strm_emit(strm, val, nil)
	}

	ret^ = val
	return .Ok
}

exec_return :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Return)

	if data.value != nil {
		result := exec_expr(strm, state, data.value, ret)
		if result != .Ok {
			return result
		}
	} else {
		ret^ = strm_nil_value()
	}

	return .Return
}

exec_nodes :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Nodes)

	last_val := strm_nil_value()
	for n in data.nodes {
		result := exec_expr(strm, state, n, &last_val)
		if result != .Ok {
			ret^ = last_val
			return result
		}
	}

	ret^ = last_val
	return .Ok
}

// ============================================================================
// Function handling
// ============================================================================

exec_lambda :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	// Create lambda closure value
	// TODO: Store lambda node and closure state
	ret^ = strm_ptr_value(node)
	return .Ok
}

exec_call :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Call)

	// Look up function
	func_val, found := strm_var_get(state, data.name)
	if !found {
		ret^ = strm_nil_value()
		return .Error
	}

	// Evaluate arguments
	args: [dynamic]Strm_Value
	defer delete(args)

	if data.args != nil && data.args.type == .Array {
		arr := &data.args.data.(Node_Array)
		for elem in arr.elements {
			val: Strm_Value
			result := exec_expr(strm, state, elem, &val)
			if result != .Ok {
				return result
			}
			append(&args, val)
		}
	}

	// Dispatch function call
	return strm_funcall(strm, state, func_val, args[:], ret)
}

exec_fcall :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Fcall)

	// Evaluate function expression
	func_val: Strm_Value
	result := exec_expr(strm, state, data.func_, &func_val)
	if result != .Ok {
		return result
	}

	// Evaluate arguments
	args: [dynamic]Strm_Value
	defer delete(args)

	if data.args != nil && data.args.type == .Array {
		arr := &data.args.data.(Node_Array)
		for elem in arr.elements {
			val: Strm_Value
			result = exec_expr(strm, state, elem, &val)
			if result != .Ok {
				return result
			}
			append(&args, val)
		}
	}

	return strm_funcall(strm, state, func_val, args[:], ret)
}

exec_genfunc :: proc(state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Genfunc)

	// Look up function and return as value
	func_val, found := strm_var_get(state, data.name)
	if !found {
		ret^ = strm_nil_value()
		return .Error
	}

	ret^ = func_val
	return .Ok
}

// ============================================================================
// Function call dispatch
// ============================================================================

// Dispatch function call by type
strm_funcall :: proc(strm: ^Strm_Stream, state: ^Strm_State, func_val: Strm_Value, args: []Strm_Value, ret: ^Strm_Value) -> Exec_Result {
	// Check function type
	if strm_cfunc_p(func_val) {
		// C function call
		// TODO: Implement cfunc calling
		ret^ = strm_nil_value()
		return .Ok
	}

	// Lambda call
	tag := strm_value_tag(func_val)
	if tag == .Ptr {
		// Assume it's a lambda node
		lambda_node := strm_value_ptr(func_val, Node)
		if lambda_node != nil && (lambda_node.type == .Lambda || lambda_node.type == .PLambda) {
			return lambda_call(strm, state, lambda_node, args, ret)
		}
	}

	ret^ = strm_nil_value()
	return .Error
}

// Evaluate lambda body with arguments
lambda_call :: proc(strm: ^Strm_Stream, state: ^Strm_State, lambda_node: ^Node, args: []Strm_Value, ret: ^Strm_Value) -> Exec_Result {
	// Create new scope
	local := strm_state_new(state)
	defer strm_state_destroy(local)

	if lambda_node.type == .Lambda {
		data := &lambda_node.data.(Node_Lambda)

		// Bind arguments
		if data.args != nil && data.args.type == .Args {
			arg_names := &data.args.data.(Node_Args)
			for i := 0; i < len(arg_names.names); i += 1 {
				name := arg_names.names[i]
				if i < len(args) {
					strm_var_def(local, name, args[i])
				} else {
					strm_var_def(local, name, strm_nil_value())
				}
			}
		}

		// Evaluate body
		return exec_expr(strm, local, data.body, ret)
	}

	// Pattern lambda - try matching patterns
	if lambda_node.type == .PLambda {
		// TODO: Implement pattern matching
		ret^ = strm_nil_value()
		return .Error
	}

	ret^ = strm_nil_value()
	return .Error
}

// ============================================================================
// Pattern matching (stubs for Phase 11)
// ============================================================================

// Match value against pattern
pmatch :: proc(strm: ^Strm_Stream, state: ^Strm_State, pat: ^Node, val: Strm_Value) -> bool {
	// TODO: Implement pattern matching
	return false
}

// Match array of arguments against pattern
pattern_match :: proc(strm: ^Strm_Stream, state: ^Strm_State, npat: ^Node, argc: int, argv: []Strm_Value) -> bool {
	// TODO: Implement argument pattern matching
	return false
}

// ============================================================================
// Namespace/Import evaluation
// ============================================================================

exec_ns :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Ns)

	// Create namespace
	ns := strm_ns_create(state, strm_str_intern(data.name))

	// Evaluate body in namespace scope
	result := exec_expr(strm, ns, data.body, ret)
	if result != .Ok {
		return result
	}

	ret^ = strm_nil_value()
	return .Ok
}

exec_import :: proc(state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Import)

	// Look up namespace
	ns := strm_ns_get(strm_str_intern(data.name))
	if ns == nil {
		ret^ = strm_nil_value()
		return .Error
	}

	// Copy bindings to current state
	strm_env_copy(state, ns)

	ret^ = strm_nil_value()
	return .Ok
}
