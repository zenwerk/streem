package streem

// Built-in iterator/stream functions
// Reference: src/iter.c

// ============================================================================
// Seq - Number sequence producer
// ============================================================================

Seq_Data :: struct {
	n:    f64,
	end_: f64,
	inc:  f64,
}

// Generate sequence
@(private = "file")
gen_seq :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Seq_Data)strm.data

	if d.end_ > 0 && d.n > d.end_ {
		strm_stream_close(strm)
		return STRM_OK
	}

	strm_emit(strm, strm_float_value(d.n), gen_seq)
	d.n += d.inc
	return STRM_OK
}

// seq(end) - 1 to end
// seq(start, end) - start to end
// seq(start, inc, end) - start to end by inc
exec_seq :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	start: f64 = 1
	end_: f64 = -1
	inc: f64 = 1

	switch argc {
	case 1:
		if !strm_number_p(args[0]) {
			return STRM_NG
		}
		end_ = strm_value_float(args[0])
	case 2:
		if !strm_number_p(args[0]) || !strm_number_p(args[1]) {
			return STRM_NG
		}
		start = strm_value_float(args[0])
		end_ = strm_value_float(args[1])
	case 3:
		if !strm_number_p(args[0]) || !strm_number_p(args[1]) || !strm_number_p(args[2]) {
			return STRM_NG
		}
		start = strm_value_float(args[0])
		inc = strm_value_float(args[1])
		end_ = strm_value_float(args[2])
	case:
		return STRM_NG
	}

	d := new(Seq_Data)
	d.n = start
	d.inc = inc
	d.end_ = end_

	ret^ = strm_stream_value(strm_stream_new(.Producer, gen_seq, nil, rawptr(d)))
	return STRM_OK
}

// ============================================================================
// Repeat - Repeat value producer
// ============================================================================

Repeat_Data :: struct {
	v:     Strm_Value,
	count: int,
}

@(private = "file")
gen_repeat :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Repeat_Data)strm.data

	d.count -= 1
	if d.count == 0 {
		strm_emit(strm, d.v, nil)
		strm_stream_close(strm)
	} else {
		strm_emit(strm, d.v, gen_repeat)
	}
	return STRM_OK
}

@(private = "file")
fin_repeat :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	free(strm.data)
	return STRM_OK
}

// repeat(value) - repeat infinitely
// repeat(value, count) - repeat count times
exec_repeat :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc < 1 || argc > 2 {
		return STRM_NG
	}

	v := args[0]
	n := -1

	if argc == 2 {
		if !strm_int_p(args[1]) {
			return STRM_NG
		}
		n = int(strm_value_int(args[1]))
		if n <= 0 {
			strm_raise(strm, "invalid count number")
			return STRM_NG
		}
	}

	d := new(Repeat_Data)
	d.v = v
	d.count = n

	ret^ = strm_stream_value(strm_stream_new(.Producer, gen_repeat, fin_repeat, rawptr(d)))
	return STRM_OK
}

// ============================================================================
// Map - Transform elements
// ============================================================================

Map_Data :: struct {
	func_: Strm_Value,
}

@(private = "file")
iter_map :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Map_Data)strm.data
	val: Strm_Value

	args := []Strm_Value{data}
	if strm_funcall(strm, nil, d.func_, args, &val) != .Ok {
		return STRM_NG
	}

	strm_emit(strm, val, nil)
	return STRM_OK
}

// map(func) - transform each element
exec_map :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 {
		return STRM_NG
	}

	d := new(Map_Data)
	d.func_ = args[0]

	ret^ = strm_stream_value(strm_stream_new(.Filter, iter_map, nil, rawptr(d)))
	return STRM_OK
}

// Array version of map
ary_map :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	if !strm_array_p(args[0]) {
		return STRM_NG
	}

	ary := Strm_Array(args[0])
	func_ := args[1]

	len := int(strm_ary_len(ary))
	ptr := strm_ary_ptr(ary)

	result := make([]Strm_Value, len)
	defer delete(result)

	for i in 0 ..< len {
		a := []Strm_Value{ptr[i]}
		if strm_funcall(strm, nil, func_, a, &result[i]) != .Ok {
			return STRM_NG
		}
	}

	ret^ = strm_ary_value(strm_ary_new(result))
	return STRM_OK
}

// ============================================================================
// Filter - Filter elements
// ============================================================================

@(private = "file")
iter_filter :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Map_Data)strm.data
	val: Strm_Value

	args := []Strm_Value{data}
	if strm_funcall(strm, nil, d.func_, args, &val) != .Ok {
		return STRM_NG
	}

	if strm_value_bool(val) {
		strm_emit(strm, data, nil)
	}
	return STRM_OK
}

// filter(func) - filter elements by predicate
exec_filter :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 {
		return STRM_NG
	}

	d := new(Map_Data)
	d.func_ = args[0]

	ret^ = strm_stream_value(strm_stream_new(.Filter, iter_filter, nil, rawptr(d)))
	return STRM_OK
}

// ============================================================================
// Each - Apply function without emitting
// ============================================================================

@(private = "file")
iter_each :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Map_Data)strm.data
	val: Strm_Value

	args := []Strm_Value{data}
	if strm_funcall(strm, nil, d.func_, args, &val) != .Ok {
		return STRM_NG
	}
	return STRM_OK
}

// each(func) - apply function to each element (no emit)
exec_each :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 {
		return STRM_NG
	}

	d := new(Map_Data)
	d.func_ = args[0]

	ret^ = strm_stream_value(strm_stream_new(.Filter, iter_each, nil, rawptr(d)))
	return STRM_OK
}

// ============================================================================
// Count - Count elements
// ============================================================================

Count_Data :: struct {
	count: int,
}

@(private = "file")
iter_count :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Count_Data)strm.data
	d.count += 1
	return STRM_OK
}

@(private = "file")
count_finish :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Count_Data)strm.data
	strm_emit(strm, strm_int_value(i32(d.count)), nil)
	free(d)
	return STRM_OK
}

// count() - count elements
exec_count :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	d := new(Count_Data)
	d.count = 0

	ret^ = strm_stream_value(strm_stream_new(.Filter, iter_count, count_finish, rawptr(d)))
	return STRM_OK
}

// ============================================================================
// Reduce - Reduce elements to single value
// ============================================================================

Reduce_Data :: struct {
	init:  bool,
	acc:   Strm_Value,
	func_: Strm_Value,
}

@(private = "file")
iter_reduce :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Reduce_Data)strm.data

	// First element becomes accumulator
	if !d.init {
		d.init = true
		d.acc = data
		return STRM_OK
	}

	args := []Strm_Value{d.acc, data}
	val: Strm_Value
	if strm_funcall(strm, nil, d.func_, args, &val) != .Ok {
		return STRM_NG
	}
	d.acc = val
	return STRM_OK
}

@(private = "file")
reduce_finish :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Reduce_Data)strm.data
	if !d.init {
		return STRM_NG
	}
	strm_emit(strm, d.acc, nil)
	return STRM_OK
}

// reduce(func) - reduce without initial value
// reduce(init, func) - reduce with initial value
exec_reduce :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc < 1 || argc > 2 {
		return STRM_NG
	}

	d := new(Reduce_Data)

	if argc == 2 {
		d.init = true
		d.acc = args[0]
		d.func_ = args[1]
	} else {
		d.init = false
		d.acc = strm_nil_value()
		d.func_ = args[0]
	}

	ret^ = strm_stream_value(strm_stream_new(.Filter, iter_reduce, reduce_finish, rawptr(d)))
	return STRM_OK
}

// ============================================================================
// Take - Take first n elements
// ============================================================================

Take_Data :: struct {
	n: int,
}

@(private = "file")
iter_take :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Take_Data)strm.data

	strm_emit(strm, data, nil)
	d.n -= 1
	if d.n == 0 {
		strm_stream_close(strm)
	}
	return STRM_OK
}

// take(n) - take first n elements
exec_take :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_int_p(args[0]) {
		return STRM_NG
	}

	n := int(strm_value_int(args[0]))
	if n < 0 {
		strm_raise(strm, "negative iteration")
		return STRM_NG
	}

	d := new(Take_Data)
	d.n = n

	ret^ = strm_stream_value(strm_stream_new(.Filter, iter_take, nil, rawptr(d)))
	return STRM_OK
}

// ============================================================================
// Drop - Drop first n elements
// ============================================================================

@(private = "file")
iter_drop :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Take_Data)strm.data

	if d.n > 0 {
		d.n -= 1
		return STRM_OK
	}
	strm_emit(strm, data, nil)
	return STRM_OK
}

// drop(n) - drop first n elements
exec_drop :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_int_p(args[0]) {
		return STRM_NG
	}

	n := int(strm_value_int(args[0]))
	if n < 0 {
		strm_raise(strm, "negative iteration")
		return STRM_NG
	}

	d := new(Take_Data)
	d.n = n

	ret^ = strm_stream_value(strm_stream_new(.Filter, iter_drop, nil, rawptr(d)))
	return STRM_OK
}

// ============================================================================
// Min/Max - Find minimum/maximum
// ============================================================================

MinMax_Data :: struct {
	start: bool,
	is_min: bool,
	data: Strm_Value,
	num: f64,
	func_: Strm_Value,
}

@(private = "file")
iter_minmax :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^MinMax_Data)strm.data
	e: Strm_Value

	if !strm_nil_p(d.func_) {
		args := []Strm_Value{data}
		if strm_funcall(strm, nil, d.func_, args, &e) != .Ok {
			return STRM_NG
		}
	} else {
		e = data
	}

	num := strm_value_float(e)

	if d.start {
		d.start = false
		d.num = num
		d.data = data
	} else if d.is_min {
		if d.num > num {
			d.num = num
			d.data = data
		}
	} else {
		if d.num < num {
			d.num = num
			d.data = data
		}
	}
	return STRM_OK
}

@(private = "file")
minmax_finish :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^MinMax_Data)strm.data
	strm_emit(strm, d.data, nil)
	return STRM_OK
}

@(private = "file")
exec_minmax :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value, is_min: bool) -> int {
	func_ := strm_nil_value()

	if argc > 0 {
		func_ = args[0]
	}

	d := new(MinMax_Data)
	d.start = true
	d.is_min = is_min
	d.num = 0
	d.data = strm_nil_value()
	d.func_ = func_

	ret^ = strm_stream_value(strm_stream_new(.Filter, iter_minmax, minmax_finish, rawptr(d)))
	return STRM_OK
}

// min(func?) - find minimum
exec_min :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	return exec_minmax(strm, argc, args, ret, true)
}

// max(func?) - find maximum
exec_max :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	return exec_minmax(strm, argc, args, ret, false)
}

// ============================================================================
// Flatmap - Transform and flatten elements
// ============================================================================

@(private = "file")
iter_flatmap :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Map_Data)strm.data
	val: Strm_Value

	args := []Strm_Value{data}
	if strm_funcall(strm, nil, d.func_, args, &val) != .Ok {
		return STRM_NG
	}

	// If result is an array, emit each element
	if strm_array_p(val) {
		ary := Strm_Array(val)
		ptr := strm_ary_ptr(ary)
		for i in 0 ..< strm_ary_len(ary) {
			strm_emit(strm, ptr[i], nil)
		}
	} else {
		// Non-array results are emitted as-is
		strm_emit(strm, val, nil)
	}
	return STRM_OK
}

// flatmap(func) - transform each element and flatten arrays
exec_flatmap :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 {
		return STRM_NG
	}

	d := new(Map_Data)
	d.func_ = args[0]

	ret^ = strm_stream_value(strm_stream_new(.Filter, iter_flatmap, nil, rawptr(d)))
	return STRM_OK
}

// Array version of flatmap
ary_flatmap :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 2 {
		return STRM_NG
	}

	if !strm_array_p(args[0]) {
		return STRM_NG
	}

	ary := Strm_Array(args[0])
	func_ := args[1]

	len := int(strm_ary_len(ary))
	ptr := strm_ary_ptr(ary)

	result: [dynamic]Strm_Value
	defer delete(result)

	for i in 0 ..< len {
		a := []Strm_Value{ptr[i]}
		val: Strm_Value
		if strm_funcall(strm, nil, func_, a, &val) != .Ok {
			return STRM_NG
		}
		// If result is an array, append each element
		if strm_array_p(val) {
			sub_ary := Strm_Array(val)
			sub_ptr := strm_ary_ptr(sub_ary)
			for j in 0 ..< strm_ary_len(sub_ary) {
				append(&result, sub_ptr[j])
			}
		} else {
			append(&result, val)
		}
	}

	ret^ = strm_ary_value(strm_ary_new(result[:]))
	return STRM_OK
}

// ============================================================================
// Cycle - Cycle through array
// ============================================================================

Cycle_Data :: struct {
	ary:    Strm_Array,
	idx:    int,
	count:  int, // -1 for infinite
	cycles: int, // current cycle count
}

@(private = "file")
gen_cycle :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Cycle_Data)strm.data
	ary_len := int(strm_ary_len(d.ary))

	if ary_len == 0 {
		strm_stream_close(strm)
		return STRM_OK
	}

	ptr := strm_ary_ptr(d.ary)
	strm_emit(strm, ptr[d.idx], gen_cycle)

	d.idx += 1
	if d.idx >= ary_len {
		d.idx = 0
		d.cycles += 1
		if d.count > 0 && d.cycles >= d.count {
			strm_stream_close(strm)
		}
	}
	return STRM_OK
}

// cycle(array) - cycle infinitely
// cycle(array, count) - cycle count times
exec_cycle :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc < 1 || argc > 2 {
		return STRM_NG
	}

	if !strm_array_p(args[0]) {
		strm_raise(strm, "cycle requires an array")
		return STRM_NG
	}

	count := -1
	if argc == 2 {
		if !strm_int_p(args[1]) {
			return STRM_NG
		}
		count = int(strm_value_int(args[1]))
		if count <= 0 {
			strm_raise(strm, "invalid count number")
			return STRM_NG
		}
	}

	d := new(Cycle_Data)
	d.ary = Strm_Array(args[0])
	d.idx = 0
	d.count = count
	d.cycles = 0

	ret^ = strm_stream_value(strm_stream_new(.Producer, gen_cycle, nil, rawptr(d)))
	return STRM_OK
}

// ============================================================================
// Slice - Group into n-element arrays
// ============================================================================

Slice_Data :: struct {
	n:      int,
	buffer: [dynamic]Strm_Value,
}

@(private = "file")
iter_slice :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Slice_Data)strm.data

	append(&d.buffer, data)

	if len(d.buffer) >= d.n {
		ary := strm_ary_new(d.buffer[:])
		strm_emit(strm, strm_ary_value(ary), nil)
		clear(&d.buffer)
	}
	return STRM_OK
}

@(private = "file")
slice_finish :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Slice_Data)strm.data

	// Emit remaining elements if any
	if len(d.buffer) > 0 {
		ary := strm_ary_new(d.buffer[:])
		strm_emit(strm, strm_ary_value(ary), nil)
	}

	delete(d.buffer)
	free(d)
	return STRM_OK
}

// slice(n) - group into n-element arrays
exec_slice :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_int_p(args[0]) {
		return STRM_NG
	}

	n := int(strm_value_int(args[0]))
	if n <= 0 {
		strm_raise(strm, "invalid slice size")
		return STRM_NG
	}

	d := new(Slice_Data)
	d.n = n
	d.buffer = make([dynamic]Strm_Value)

	ret^ = strm_stream_value(strm_stream_new(.Filter, iter_slice, slice_finish, rawptr(d)))
	return STRM_OK
}

// ============================================================================
// Consec - Sliding window of n elements
// ============================================================================

Consec_Data :: struct {
	n:      int,
	buffer: [dynamic]Strm_Value,
	full:   bool,
}

@(private = "file")
iter_consec :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Consec_Data)strm.data

	append(&d.buffer, data)

	if len(d.buffer) >= d.n {
		d.full = true
	}

	if d.full {
		// Emit the window
		ary := strm_ary_new(d.buffer[:])
		strm_emit(strm, strm_ary_value(ary), nil)
		// Slide the window - remove first element
		ordered_remove(&d.buffer, 0)
	}
	return STRM_OK
}

@(private = "file")
consec_finish :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Consec_Data)strm.data
	delete(d.buffer)
	free(d)
	return STRM_OK
}

// consec(n) - sliding window of n elements
exec_consec :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 || !strm_int_p(args[0]) {
		return STRM_NG
	}

	n := int(strm_value_int(args[0]))
	if n <= 0 {
		strm_raise(strm, "invalid window size")
		return STRM_NG
	}

	d := new(Consec_Data)
	d.n = n
	d.buffer = make([dynamic]Strm_Value)
	d.full = false

	ret^ = strm_stream_value(strm_stream_new(.Filter, iter_consec, consec_finish, rawptr(d)))
	return STRM_OK
}

// ============================================================================
// Uniq - Remove consecutive duplicates
// ============================================================================

Uniq_Data :: struct {
	first: bool,
	prev:  Strm_Value,
	func_: Strm_Value, // Optional key function
}

@(private = "file")
iter_uniq :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Uniq_Data)strm.data

	key := data
	// Apply key function if provided
	if !strm_nil_p(d.func_) {
		args := []Strm_Value{data}
		if strm_funcall(strm, nil, d.func_, args, &key) != .Ok {
			return STRM_NG
		}
	}

	if d.first {
		d.first = false
		d.prev = key
		strm_emit(strm, data, nil)
		return STRM_OK
	}

	// Compare with previous key
	if !strm_value_eq(key, d.prev) {
		d.prev = key
		strm_emit(strm, data, nil)
	}
	return STRM_OK
}

@(private = "file")
uniq_finish :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Uniq_Data)strm.data
	free(d)
	return STRM_OK
}

// uniq() - remove consecutive duplicates
// uniq(func) - remove consecutive duplicates by key function
exec_uniq :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc > 1 {
		return STRM_NG
	}

	d := new(Uniq_Data)
	d.first = true
	d.prev = strm_nil_value()
	d.func_ = argc > 0 ? args[0] : strm_nil_value()

	ret^ = strm_stream_value(strm_stream_new(.Filter, iter_uniq, uniq_finish, rawptr(d)))
	return STRM_OK
}

// ============================================================================
// Iterator initialization
// ============================================================================

strm_iter_init :: proc(state: ^Strm_State) {
	// Producers
	strm_var_def(state, strm_str_intern("seq"), strm_cfunc_value(exec_seq))
	strm_var_def(state, strm_str_intern("repeat"), strm_cfunc_value(exec_repeat))
	strm_var_def(state, strm_str_intern("cycle"), strm_cfunc_value(exec_cycle))

	// Transformers
	strm_var_def(state, strm_str_intern("each"), strm_cfunc_value(exec_each))
	strm_var_def(state, strm_str_intern("map"), strm_cfunc_value(exec_map))
	strm_var_def(state, strm_str_intern("filter"), strm_cfunc_value(exec_filter))
	strm_var_def(state, strm_str_intern("flatmap"), strm_cfunc_value(exec_flatmap))

	// Aggregators
	strm_var_def(state, strm_str_intern("count"), strm_cfunc_value(exec_count))
	strm_var_def(state, strm_str_intern("min"), strm_cfunc_value(exec_min))
	strm_var_def(state, strm_str_intern("max"), strm_cfunc_value(exec_max))
	strm_var_def(state, strm_str_intern("reduce"), strm_cfunc_value(exec_reduce))

	// Windowing
	strm_var_def(state, strm_str_intern("take"), strm_cfunc_value(exec_take))
	strm_var_def(state, strm_str_intern("drop"), strm_cfunc_value(exec_drop))
	strm_var_def(state, strm_str_intern("slice"), strm_cfunc_value(exec_slice))
	strm_var_def(state, strm_str_intern("consec"), strm_cfunc_value(exec_consec))
	strm_var_def(state, strm_str_intern("uniq"), strm_cfunc_value(exec_uniq))

	// Array methods
	strm_var_def(strm_ns_array, strm_str_intern("map"), strm_cfunc_value(ary_map))
	strm_var_def(strm_ns_array, strm_str_intern("flatmap"), strm_cfunc_value(ary_flatmap))
}
