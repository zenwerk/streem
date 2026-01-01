package streem

import "core:fmt"

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
// Lambda structure (closure)
// ============================================================================

// Lambda closure structure
Strm_Lambda :: struct {
	type:  Ptr_Type,     // MUST be first field - Ptr_Type.Lambda
	body:  ^Node,        // Lambda or PLambda node
	state: ^Strm_State,  // captured scope
}

// Create a new lambda closure
strm_lambda_new :: proc(body: ^Node, state: ^Strm_State) -> ^Strm_Lambda {
	lambda := new(Strm_Lambda)
	lambda.type = .Lambda
	lambda.body = body
	// Copy the state for closure capture
	lambda.state = new(Strm_State)
	lambda.state^ = state^
	return lambda
}

// Destroy lambda
strm_lambda_destroy :: proc(lambda: ^Strm_Lambda) {
	if lambda == nil {
		return
	}
	if lambda.state != nil {
		free(lambda.state)
	}
	free(lambda)
}

// ============================================================================
// Generic function reference structure
// ============================================================================

// Generic function structure
Strm_Genfunc :: struct {
	type:  Ptr_Type,    // MUST be first field - Ptr_Type.Genfunc
	state: ^Strm_State, // scope for lookup
	id:    Strm_String, // function name
}

// Create a new genfunc
strm_genfunc_new :: proc(state: ^Strm_State, id: Strm_String) -> ^Strm_Genfunc {
	gf := new(Strm_Genfunc)
	gf.type = .Genfunc
	gf.state = state
	gf.id = id
	return gf
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
		if strm != nil {
			strm_set_exc(strm, .Skip, strm_nil_value())
		}
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
	data := &node.data.(Node_Str)
	str := strm_str_new(data.value)
	ret^ = strm_str_value(str)
	return .Ok
}

exec_bool :: proc(node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Bool)
	ret^ = strm_bool_value(data.value)
	return .Ok
}

exec_time :: proc(node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Time)
	// Create time value
	// For now, store as a foreign value (time implementation needed in Phase 14)
	time_val := strm_time_new(data.sec, data.usec, data.utc_offset)
	ret^ = time_val
	return .Ok
}

// Create time value (stub - full implementation in Phase 14)
strm_time_new :: proc(sec: i64, usec: i64, utc_offset: int) -> Strm_Value {
	// Simple implementation: store as float (seconds since epoch)
	// TODO: Implement proper time type
	return strm_float_value(f64(sec) + f64(usec) / 1_000_000.0)
}

// Check if value is time
strm_time_p :: proc(v: Strm_Value) -> bool {
	// TODO: Implement proper time type check
	return false
}

// ============================================================================
// Expression evaluation
// ============================================================================

exec_ident :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Ident)
	val, found := strm_var_get(state, data.name)
	if !found {
		// Variable not found
		if strm != nil {
			strm_raise(strm, "failed to reference variable")
		}
		ret^ = strm_nil_value()
		return .Error
	}
	ret^ = val
	return .Ok
}

exec_op :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Op)

	// Evaluate operands
	args: [2]Strm_Value
	argc := 0

	// Unary operator if lhs is nil
	if data.lhs != nil {
		result := exec_expr(strm, state, data.lhs, &args[argc])
		if result != .Ok {
			return result
		}
		argc += 1
	}

	if data.rhs != nil {
		result := exec_expr(strm, state, data.rhs, &args[argc])
		if result != .Ok {
			return result
		}
		argc += 1
	}

	// Dispatch to registered operator function
	op_name := strm_str_intern(data.op)
	return exec_call_internal(strm, state, op_name, args[:argc], ret)
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
	data := &node.data.(Node_Array)

	// First pass: evaluate all elements and check for splats
	values: [dynamic]Strm_Value
	defer delete(values)

	has_splat := false

	for elem in data.elements {
		if elem.type == .Splat {
			has_splat = true
			splat_data := &elem.data.(Node_Splat)
			val: Strm_Value
			result := exec_expr(strm, state, splat_data.expr, &val)
			if result != .Ok {
				return result
			}
			if !strm_array_p(val) {
				if strm != nil {
					strm_raise(strm, "splat requires array")
				}
				return .Error
			}
			// Expand splat
			ary := Strm_Array(val)
			ary_ptr := strm_ary_ptr(ary)
			for i in 0 ..< strm_ary_len(ary) {
				append(&values, ary_ptr[i])
			}
		} else {
			val: Strm_Value
			result := exec_expr(strm, state, elem, &val)
			if result != .Ok {
				return result
			}
			append(&values, val)
		}
	}

	// Check for headers with splat conflict
	if has_splat && len(data.headers) > 0 {
		if strm != nil {
			strm_raise(strm, "label(s) and splat(s) in an array")
		}
		return .Error
	}

	// Create array
	ary := strm_ary_new(values[:])

	// Set headers if present
	if len(data.headers) > 0 {
		header_values := make([]Strm_Value, len(data.headers))
		defer delete(header_values)
		for h, i in data.headers {
			header_values[i] = strm_str_value(strm_str_intern(h))
		}
		headers_ary := strm_ary_new(header_values)
		strm_ary_set_headers(ary, headers_ary)
	}

	// Set namespace if present
	if data.ns != "" {
		ns := strm_ns_get(strm_str_intern(data.ns))
		if ns != nil {
			// Check if namespace allows instance creation
			if .Udef not_in ns.flags {
				if strm != nil {
					strm_raise(strm, "instantiating primitive class")
				}
				return .Error
			}
			strm_ary_set_ns(ary, ns)
		}
	}

	ret^ = strm_ary_value(ary)
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
		if strm != nil {
			strm_raise(strm, "failed to assign")
		}
		return result
	}

	// Assign to variable
	name := strm_str_intern(data.lhs)
	strm_var_set(state, name, val)

	ret^ = val
	return .Ok
}

exec_emit :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Emit)

	if data.value == nil {
		// emit without value
		if strm != nil {
			strm_emit(strm, strm_nil_value(), nil)
		}
		ret^ = strm_nil_value()
		return .Ok
	}

	// Handle array of values (emit multiple)
	if data.value.type == .Array {
		arr := &data.value.data.(Node_Array)
		for elem in arr.elements {
			val: Strm_Value
			result := exec_expr(strm, state, elem, &val)
			if result != .Ok {
				return result
			}
			if strm != nil {
				strm_emit(strm, val, nil)
			}
		}
		ret^ = strm_nil_value()
		return .Ok
	}

	// Single value emit
	val: Strm_Value
	result := exec_expr(strm, state, data.value, &val)
	if result != .Ok {
		return result
	}

	if strm != nil {
		strm_emit(strm, val, nil)
	}

	ret^ = val
	return .Ok
}

exec_return :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Return)

	if data.value == nil {
		ret^ = strm_nil_value()
	} else if data.value.type == .Array {
		// Multiple return values -> create array
		arr := &data.value.data.(Node_Array)
		if len(arr.elements) == 0 {
			ret^ = strm_nil_value()
		} else if len(arr.elements) == 1 {
			result := exec_expr(strm, state, arr.elements[0], ret)
			if result != .Ok {
				return result
			}
		} else {
			values := make([]Strm_Value, len(arr.elements))
			defer delete(values)
			for elem, i in arr.elements {
				result := exec_expr(strm, state, elem, &values[i])
				if result != .Ok {
					return result
				}
			}
			ary := strm_ary_new(values)
			ret^ = strm_ary_value(ary)
		}
	} else {
		result := exec_expr(strm, state, data.value, ret)
		if result != .Ok {
			return result
		}
	}

	// Set return exception
	if strm != nil {
		strm_set_exc(strm, .Return, ret^)
	}

	return .Return
}

exec_nodes :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Nodes)

	last_val := strm_nil_value()
	for n in data.nodes {
		result := exec_expr(strm, state, n, &last_val)
		if result != .Ok {
			// Set error location
			if strm != nil && strm.exc != nil {
				strm.exc.fname = n.fname
				strm.exc.lineno = n.lineno
			}
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
	// Handle PLambda (pattern matching lambda) separately
	if node.type == .PLambda {
		// Create lambda closure for pattern matching
		lambda := strm_lambda_new(node, state)
		ret^ = strm_ptr_value(lambda)
		return .Ok
	}

	data := &node.data.(Node_Lambda)

	// Block without params: execute immediately
	// This handles cases like: if (cond) { stmts }
	if data.is_block && data.args == nil {
		// Execute the body directly in the current scope
		if data.body != nil {
			return exec_expr(strm, state, data.body, ret)
		}
		ret^ = strm_nil_value()
		return .Ok
	}

	// Create lambda closure value (for actual lambdas with params or non-blocks)
	lambda := strm_lambda_new(node, state)
	ret^ = strm_ptr_value(lambda)
	return .Ok
}

exec_call :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Call)

	// Evaluate arguments
	args: [dynamic]Strm_Value
	defer delete(args)

	has_splat := false

	if data.args != nil && data.args.type == .Array {
		arr := &data.args.data.(Node_Array)

		// Check for splat
		for elem in arr.elements {
			if elem.type == .Splat {
				has_splat = true
				break
			}
		}

		if has_splat {
			// Handle splat: evaluate as array and use result
			aary: Strm_Value
			result := exec_array(strm, state, data.args, &aary)
			if result != .Ok {
				return result
			}
			ary := Strm_Array(aary)
			ptr := strm_ary_ptr(ary)
			for i in 0 ..< strm_ary_len(ary) {
				append(&args, ptr[i])
			}
		} else {
			for elem in arr.elements {
				val: Strm_Value
				result := exec_expr(strm, state, elem, &val)
				if result != .Ok {
					return result
				}
				append(&args, val)
			}
		}
	}

	// Dispatch function call by name
	name := strm_str_intern(data.name)
	return exec_call_internal(strm, state, name, args[:], ret)
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

	has_splat := false

	if data.args != nil && data.args.type == .Array {
		arr := &data.args.data.(Node_Array)

		for elem in arr.elements {
			if elem.type == .Splat {
				has_splat = true
				break
			}
		}

		if has_splat {
			aary: Strm_Value
			result2 := exec_array(strm, state, data.args, &aary)
			if result2 != .Ok {
				return result2
			}
			ary := Strm_Array(aary)
			ptr := strm_ary_ptr(ary)
			for i in 0 ..< strm_ary_len(ary) {
				append(&args, ptr[i])
			}
		} else {
			for elem in arr.elements {
				val: Strm_Value
				result2 := exec_expr(strm, state, elem, &val)
				if result2 != .Ok {
					return result2
				}
				append(&args, val)
			}
		}
	}

	return strm_funcall(strm, state, func_val, args[:], ret)
}

exec_genfunc :: proc(state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Genfunc)

	// Create genfunc reference
	id := strm_str_intern(data.name)
	gf := strm_genfunc_new(state, id)
	ret^ = strm_ptr_value(gf)
	return .Ok
}

// ============================================================================
// Internal function call helper
// ============================================================================

// Call function by name with namespace method lookup
exec_call_internal :: proc(strm: ^Strm_Stream, state: ^Strm_State, name: Strm_String, args: []Strm_Value, ret: ^Strm_Value) -> Exec_Result {
	// First, try to find method in first argument's namespace
	if len(args) > 0 {
		ns := strm_value_ns(args[0])
		if ns != nil {
			m, found := strm_var_get(ns, name)
			if found {
				return strm_funcall(strm, state, m, args, ret)
			}

			// For arrays, try field access by name
			if strm_array_p(args[0]) {
				ary := Strm_Array(args[0])
				result, ok := ary_get(strm, ary, len(args) - 1, args[1:], name, ret)
				if ok {
					return result
				}
			}
		}
	}

	// Then try to find in current scope
	m, found := strm_var_get(state, name)
	if found {
		return strm_funcall(strm, state, m, args, ret)
	}

	if strm != nil {
		strm_raise(strm, "function not found")
	}
	return .Error
}

// ============================================================================
// Array access helper
// ============================================================================

// Get element from array by index or field name
ary_get :: proc(strm: ^Strm_Stream, ary: Strm_Array, argc: int, argv: []Strm_Value, name: Strm_String, ret: ^Strm_Value) -> (Exec_Result, bool) {
	if argc == 0 && u64(name) != 0 {
		// Field access by name
		headers := strm_ary_headers(ary)
		if u64(headers) != 0 {
			headers_ptr := strm_ary_ptr(headers)
			ary_ptr := strm_ary_ptr(ary)
			for i in 0 ..< strm_ary_len(headers) {
				h := headers_ptr[i]
				if strm_string_p(h) && strm_str_eq(Strm_String(h), name) {
					if i < strm_ary_len(ary) {
						ret^ = ary_ptr[i]
						return .Ok, true
					}
				}
			}
		}
		return .Error, false
	}

	if argc == 1 && u64(name) == 0 {
		idx := argv[0]
		if strm_number_p(idx) {
			i := strm_value_int(idx)
			val, ok := strm_ary_get(ary, i)
			if ok {
				ret^ = val
				return .Ok, true
			}
		} else if strm_string_p(idx) {
			// String index for struct-like array
			headers := strm_ary_headers(ary)
			if u64(headers) != 0 {
				headers_ptr := strm_ary_ptr(headers)
				ary_ptr := strm_ary_ptr(ary)
				for i in 0 ..< strm_ary_len(headers) {
					h := headers_ptr[i]
					if strm_str_eq(Strm_String(h), Strm_String(idx)) {
						if i < strm_ary_len(ary) {
							ret^ = ary_ptr[i]
							return .Ok, true
						}
					}
				}
			}
		}
	}

	return .Error, false
}

// ============================================================================
// Function call dispatch
// ============================================================================

// Dispatch function call by type
strm_funcall :: proc(strm: ^Strm_Stream, state: ^Strm_State, func_val: Strm_Value, args: []Strm_Value, ret: ^Strm_Value) -> Exec_Result {
	// Check function type
	if strm_cfunc_p(func_val) {
		// C function call
		cfunc := strm_value_cfunc(func_val)
		if cfunc != nil {
			result := cfunc(strm, len(args), args, ret)
			if result == STRM_OK {
				return .Ok
			}
			return .Error
		}
		return .Error
	}

	// Array access
	if strm_array_p(func_val) {
		ary := Strm_Array(func_val)
		result, ok := ary_get(strm, ary, len(args), args, STRM_STR_NULL, ret)
		if ok {
			return result
		}
		return .Error
	}

	// Lambda or genfunc call
	tag := strm_value_tag(func_val)
	if tag == .Ptr {
		ptr := strm_value_rawptr(func_val)
		if ptr != nil {
			ptr_type := (cast(^Ptr_Type)ptr)^
			#partial switch ptr_type {
			case .Lambda:
				lambda := cast(^Strm_Lambda)ptr
				return lambda_call(strm, lambda.state, lambda.body, args, ret)
			case .Genfunc:
				gf := cast(^Strm_Genfunc)ptr
				return exec_call_internal(strm, gf.state, gf.id, args, ret)
			}
		}
	}

	if strm != nil {
		strm_raise(strm, "not a function")
	}
	return .Error
}

// ============================================================================
// Lambda call
// ============================================================================

// Evaluate lambda body with arguments
lambda_call :: proc(strm: ^Strm_Stream, closure_state: ^Strm_State, lambda_node: ^Node, args: []Strm_Value, ret: ^Strm_Value) -> Exec_Result {
	if lambda_node == nil {
		return .Error
	}

	// Create new scope with closure as parent
	local := strm_state_new(closure_state)
	defer strm_state_destroy(local)

	if lambda_node.type == .Lambda {
		data := &lambda_node.data.(Node_Lambda)

		// Bind arguments
		if data.args != nil {
			if data.args.type == .Args {
				arg_names := &data.args.data.(Node_Args)
				if len(arg_names.names) != len(args) {
					if strm != nil {
						strm_raise(strm, "wrong number of arguments")
						if strm.exc != nil {
							strm.exc.fname = lambda_node.fname
							strm.exc.lineno = lambda_node.lineno
						}
					}
					return .Error
				}
				for i := 0; i < len(arg_names.names); i += 1 {
					name := strm_str_intern(arg_names.names[i])
					strm_var_set(local, name, args[i])
				}
			} else if data.args.type == .Ident {
				// Single identifier arg
				if len(args) != 1 {
					if strm != nil {
						strm_raise(strm, "wrong number of arguments")
					}
					return .Error
				}
				arg_ident := &data.args.data.(Node_Ident)
				name := strm_str_intern(arg_ident.name)
				strm_var_set(local, name, args[0])
			}
		} else if len(args) > 0 {
			// No args expected but args provided
			if strm != nil {
				strm_raise(strm, "wrong number of arguments")
			}
			return .Error
		}

		// Evaluate body
		result := exec_expr(strm, local, data.body, ret)

		// Handle return exception
		if result == .Return && strm != nil && strm.exc != nil {
			if strm.exc.type == .Return {
				ret^ = strm.exc.arg
				strm_clear_exc(strm)
				return .Ok
			}
		}

		return result
	}

	// Pattern lambda - try matching patterns
	if lambda_node.type == .PLambda {
		return plambda_call(strm, local, lambda_node, args, ret)
	}

	ret^ = strm_nil_value()
	return .Error
}

// Pattern lambda call
plambda_call :: proc(strm: ^Strm_Stream, state: ^Strm_State, plambda_node: ^Node, args: []Strm_Value, ret: ^Strm_Value) -> Exec_Result {
	plmbd := plambda_node
	nexec := 0

	for plmbd != nil && plmbd.type == .PLambda {
		data := &plmbd.data.(Node_PLambda)

		// Clear state env for each pattern attempt
		clear(&state.env)

		// Try to match pattern
		if pattern_match(strm, state, data.pat, len(args), args) {
			// Check condition if present
			if data.cond != nil {
				cond: Strm_Value
				result := exec_expr(strm, state, data.cond, &cond)
				if result == .Ok && strm_value_bool(cond) {
					nexec += 1
					result = exec_expr(strm, state, data.body, ret)

					// Handle return exception
					if result == .Return && strm != nil && strm.exc != nil && strm.exc.type == .Return {
						ret^ = strm.exc.arg
						strm_clear_exc(strm)
						return .Ok
					}
					return result
				}
			} else {
				nexec += 1
				result := exec_expr(strm, state, data.body, ret)

				if result == .Return && strm != nil && strm.exc != nil && strm.exc.type == .Return {
					ret^ = strm.exc.arg
					strm_clear_exc(strm)
					return .Ok
				}
				return result
			}
		}

		plmbd = data.next_
	}

	if nexec == 0 {
		if strm != nil {
			strm_raise(strm, "match failure")
		}
		return .Error
	}

	return .Ok
}

// ============================================================================
// Pattern matching
// ============================================================================

// Check if identifier is placeholder (_)
pattern_placeholder_p :: proc(name: string) -> bool {
	return name == "_"
}

// Match value against pattern
pmatch :: proc(strm: ^Strm_Stream, state: ^Strm_State, pat: ^Node, val: Strm_Value) -> bool {
	if pat == nil {
		return true
	}

	#partial switch pat.type {
	case .Ident:
		data := &pat.data.(Node_Ident)
		if pattern_placeholder_p(data.name) {
			return true // Placeholder matches anything
		}
		// Bind variable
		name := strm_str_intern(data.name)
		return strm_var_match(state, name, val) == STRM_OK

	case .Str:
		if strm_string_p(val) {
			data := &pat.data.(Node_Str)
			pat_str := strm_str_new(data.value)
			return strm_str_eq(Strm_String(val), pat_str)
		}
		return false

	case .Int:
		data := &pat.data.(Node_Int)
		if strm_int_p(val) {
			return i64(strm_value_int(val)) == data.value
		}
		if strm_float_p(val) {
			return strm_value_float(val) == f64(data.value)
		}
		return false

	case .Float:
		data := &pat.data.(Node_Float)
		if strm_number_p(val) {
			return strm_value_float(val) == data.value
		}
		return false

	case .Nil:
		return strm_nil_p(val)

	case .Bool:
		data := &pat.data.(Node_Bool)
		if strm_bool_p(val) {
			return strm_value_bool(val) == data.value
		}
		return false

	case .Ns:
		// Pattern with namespace type check
		data := &pat.data.(Node_Ns)
		ns_name := strm_str_intern(data.name)
		s1 := strm_ns_get(ns_name)
		s2 := strm_value_ns(val)
		if s1 != s2 {
			return false
		}
		return pmatch(strm, state, data.body, val)

	case .PArray:
		if strm_array_p(val) {
			ary := Strm_Array(val)
			return pattern_match(strm, state, pat, int(strm_ary_len(ary)), strm_ary_slice(ary))
		}
		return false

	case .PSplat:
		if strm_array_p(val) {
			ary := Strm_Array(val)
			return pattern_match(strm, state, pat, int(strm_ary_len(ary)), strm_ary_slice(ary))
		}
		return false

	case .PStruct:
		if !strm_array_p(val) {
			return false
		}
		return pmatch_struct(strm, state, pat, val)

	case:
		return false
	}
}

// Match struct pattern
pmatch_struct :: proc(strm: ^Strm_Stream, state: ^Strm_State, pat: ^Node, val: Strm_Value) -> bool {
	pstruct := &pat.data.(Node_PStruct)
	ary := Strm_Array(val)

	headers := strm_ary_headers(ary)
	if u64(headers) == 0 {
		return false // Struct pattern requires headers
	}

	if i32(len(pstruct.patterns)) > strm_ary_len(ary) {
		return false
	}

	headers_ptr := strm_ary_ptr(headers)
	ary_ptr := strm_ary_ptr(ary)

	for p in pstruct.patterns {
		if p.type != .Pair {
			continue
		}
		pair := &p.data.(Node_Pair)
		key := strm_str_intern(pair.key)

		found := false
		for j in 0 ..< strm_ary_len(headers) {
			h := headers_ptr[j]
			if strm_string_p(h) && strm_str_eq(Strm_String(h), key) {
				if !pmatch(strm, state, pair.value, ary_ptr[j]) {
					return false
				}
				found = true
				break
			}
		}
		if !found {
			return false
		}
	}

	return true
}

// Match array of arguments against pattern
pattern_match :: proc(strm: ^Strm_Stream, state: ^Strm_State, npat: ^Node, argc: int, argv: []Strm_Value) -> bool {
	if npat == nil {
		return true // case else
	}

	// Handle PSplat pattern
	if npat.type == .PSplat {
		psp := &npat.data.(Node_PSplat)

		// Get head and tail lengths
		head_len := 0
		if psp.head != nil && psp.head.type == .PArray {
			head_data := &psp.head.data.(Node_PArray)
			head_len = len(head_data.patterns)
		}

		tail_len := 0
		if psp.tail != nil && psp.tail.type == .PArray {
			tail_data := &psp.tail.data.(Node_PArray)
			tail_len = len(tail_data.patterns)
		}

		if argc < head_len + tail_len {
			return false
		}

		// Match head
		if psp.head != nil {
			if !pattern_match(strm, state, psp.head, head_len, argv[:head_len]) {
				return false
			}
		}

		// Match mid (rest)
		rest_start := head_len
		rest_end := argc - tail_len
		rest_values := argv[rest_start:rest_end]
		rest_ary := strm_ary_new(rest_values)

		if !pmatch(strm, state, psp.mid, strm_ary_value(rest_ary)) {
			return false
		}

		// Match tail
		if psp.tail != nil {
			if !pattern_match(strm, state, psp.tail, tail_len, argv[argc - tail_len:]) {
				return false
			}
		}

		return true
	}

	// Handle PArray pattern
	if npat.type == .PArray {
		parray := &npat.data.(Node_PArray)

		// Check if pattern contains splat
		splat_idx := -1
		for i := 0; i < len(parray.patterns); i += 1 {
			if parray.patterns[i] != nil && parray.patterns[i].type == .Splat {
				splat_idx = i
				break
			}
		}

		if splat_idx >= 0 {
			// Pattern contains splat
			head_len := splat_idx
			tail_len := len(parray.patterns) - splat_idx - 1

			if argc < head_len + tail_len {
				return false
			}

			// Match head patterns
			for i := 0; i < head_len; i += 1 {
				if !pmatch(strm, state, parray.patterns[i], argv[i]) {
					return false
				}
			}

			// Match splat (rest elements)
			rest_start := head_len
			rest_end := argc - tail_len
			rest_values := argv[rest_start:rest_end]
			rest_ary := strm_ary_new(rest_values)
			splat_node := parray.patterns[splat_idx]
			splat_data := &splat_node.data.(Node_Splat)
			if !pmatch(strm, state, splat_data.expr, strm_ary_value(rest_ary)) {
				return false
			}

			// Match tail patterns
			for i := 0; i < tail_len; i += 1 {
				if !pmatch(strm, state, parray.patterns[splat_idx + 1 + i], argv[argc - tail_len + i]) {
					return false
				}
			}

			return true
		} else {
			// No splat - exact length match required
			if len(parray.patterns) != argc {
				return false
			}
			for i := 0; i < argc; i += 1 {
				if !pmatch(strm, state, parray.patterns[i], argv[i]) {
					return false
				}
			}
			return true
		}
	}

	return false
}

// ============================================================================
// Namespace/Import evaluation
// ============================================================================

exec_ns :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Ns)

	// Create namespace
	name := strm_str_intern(data.name)
	ns := strm_ns_create(state, name)

	if ns == nil {
		// Namespace might already exist
		if strm_ns_get(name) != nil {
			if strm != nil {
				strm_raise(strm, "namespace already exists")
			}
		} else {
			if strm != nil {
				strm_raise(strm, "failed to create namespace")
			}
		}
		return .Error
	}

	// Set Udef flag for user-defined namespace
	ns.flags += {.Udef}

	// Evaluate body in namespace scope
	if data.body != nil {
		result := exec_expr(strm, ns, data.body, ret)
		if result != .Ok {
			return result
		}
	}

	ret^ = strm_nil_value()
	return .Ok
}

exec_import :: proc(state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Import)

	// Look up namespace
	name := strm_str_intern(data.name)
	ns := strm_ns_get(name)
	if ns == nil {
		ret^ = strm_nil_value()
		return .Error
	}

	// Copy bindings to current state
	result := strm_env_copy(state, ns)
	if result != STRM_OK {
		return .Error
	}

	ret^ = strm_nil_value()
	return .Ok
}
