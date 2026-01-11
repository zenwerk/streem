package streem

// =============================================================================
// イテレータ/ストリーム関数モジュール (Iterator/Stream Functions Module)
// =============================================================================
//
// 参照元: src/iter.c
//
// このモジュールは、Streem言語のストリーム処理を行うビルトイン関数を提供します。
// 関数は大きく3つのカテゴリに分類されます:
//
// 【プロデューサー (Producer)】
//   データを生成してストリームに流す起点となる関数
//   例: seq, repeat, cycle
//
// 【フィルター/トランスフォーマー (Filter/Transformer)】
//   入力データを加工・選別して出力する中間処理関数
//   例: map, filter, each, flatmap, take, drop, slice, consec, uniq
//
// 【アグリゲーター (Aggregator)】
//   複数の入力を集約して1つの結果を出力する関数
//   例: count, reduce, min, max
//
// ストリームの基本構造:
//   Producer → Filter → Filter → ... → Consumer
//   (データ生成) (加工)   (加工)        (出力/消費)
//
// 各ビルトイン関数は以下のシグネチャを持ちます:
//   proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int
// =============================================================================

// =============================================================================
// Seq - 数列プロデューサー (Number Sequence Producer)
// =============================================================================

// -----------------------------------------------------------------------------
// Seq_Data - シーケンス生成用の内部状態
// -----------------------------------------------------------------------------
// seq 関数が生成するストリームの状態を保持する構造体です。
//
// フィールド:
//   n     - 現在の値（次に emit される値）
//   end_  - 終了値（この値を超えたら終了、-1は無限）
//   inc   - 増分（各ステップで加算される値）
// -----------------------------------------------------------------------------
Seq_Data :: struct {
	n:    f64,
	end_: f64,
	inc:  f64,
}

// -----------------------------------------------------------------------------
// gen_seq - シーケンス値を1つ生成する内部コールバック
// -----------------------------------------------------------------------------
// ストリームのタスクとして呼び出され、次の値を emit します。
// end_ に達したらストリームをクローズします。
//
// 動作:
//   1. 終了条件をチェック（n > end_ なら終了）
//   2. 現在の値 n を emit
//   3. n に inc を加算
//   4. 自身を次のコールバックとして登録（継続）
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// exec_seq - 数列を生成するストリームを作成
// -----------------------------------------------------------------------------
// 連続した数値のシーケンスを生成するプロデューサーストリームを返します。
//
// Streem言語での使用例:
//   seq(5)           # => 1, 2, 3, 4, 5
//   seq(2, 5)        # => 2, 3, 4, 5
//   seq(1, 2, 10)    # => 1, 3, 5, 7, 9  （増分2で1から10未満まで）
//   seq(10) | take(3)  # => 1, 2, 3
//
// 引数パターン:
//   seq(end)              - 1 から end まで（増分1）
//   seq(start, end)       - start から end まで（増分1）
//   seq(start, inc, end)  - start から end まで（増分 inc）
//
// パラメータ:
//   argc - 1, 2, または 3
//   args - 数値の配列
//
// 戻り値:
//   プロデューサーストリーム
// -----------------------------------------------------------------------------
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

// =============================================================================
// Repeat - 値繰り返しプロデューサー (Value Repeat Producer)
// =============================================================================

// -----------------------------------------------------------------------------
// Repeat_Data - 繰り返し生成用の内部状態
// -----------------------------------------------------------------------------
// repeat 関数が生成するストリームの状態を保持する構造体です。
//
// フィールド:
//   v     - 繰り返し出力する値
//   count - 残り繰り返し回数（-1は無限）
// -----------------------------------------------------------------------------
Repeat_Data :: struct {
	v:     Strm_Value,
	count: int,
}

// -----------------------------------------------------------------------------
// gen_repeat - 値を1つ emit する内部コールバック
// -----------------------------------------------------------------------------
// 繰り返しカウントをデクリメントしながら値を emit します。
// カウントが0になったらストリームをクローズします。
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// fin_repeat - ストリーム終了時のクリーンアップ
// -----------------------------------------------------------------------------
// 確保したメモリを解放します。
// -----------------------------------------------------------------------------
@(private = "file")
fin_repeat :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	free(strm.data)
	return STRM_OK
}

// -----------------------------------------------------------------------------
// exec_repeat - 値を繰り返すストリームを作成
// -----------------------------------------------------------------------------
// 同じ値を指定回数（または無限に）繰り返すプロデューサーストリームを返します。
//
// Streem言語での使用例:
//   repeat("hello", 3)   # => "hello", "hello", "hello"
//   repeat(0) | take(5)  # => 0, 0, 0, 0, 0 （無限から5つ取得）
//   repeat([1,2], 2)     # => [1,2], [1,2]
//
// 引数パターン:
//   repeat(value)        - value を無限に繰り返す
//   repeat(value, count) - value を count 回繰り返す
//
// パラメータ:
//   argc - 1 または 2
//   args - [繰り返す値, (繰り返し回数)]
//
// 戻り値:
//   プロデューサーストリーム
//
// エラー:
//   count が0以下の場合はエラー
// -----------------------------------------------------------------------------
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

// =============================================================================
// Map - 要素変換フィルター (Element Transformation Filter)
// =============================================================================

// -----------------------------------------------------------------------------
// Map_Data - map/filter/each 共通の内部状態
// -----------------------------------------------------------------------------
// 変換関数を保持する構造体です。
// map, filter, each, flatmap で共通して使用されます。
//
// フィールド:
//   func_ - 各要素に適用する関数
// -----------------------------------------------------------------------------
Map_Data :: struct {
	func_: Strm_Value,
}

// -----------------------------------------------------------------------------
// iter_map - 各要素を変換する内部コールバック
// -----------------------------------------------------------------------------
// 入力された各要素に対して func_ を呼び出し、
// その結果を下流に emit します。
//
// 動作:
//   1. 入力データ data を引数として func_ を呼び出す
//   2. 関数の戻り値を emit
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// exec_map - 要素を変換するフィルターストリームを作成
// -----------------------------------------------------------------------------
// 各要素に関数を適用し、結果を出力するフィルターストリームを返します。
//
// Streem言語での使用例:
//   seq(5) | map{|x| x * 2}        # => 2, 4, 6, 8, 10
//   ["a", "b"] | map{|s| s.upper}  # => "A", "B"
//   seq(3) | map{|x| [x, x*x]}     # => [1,1], [2,4], [3,9]
//
// パラメータ:
//   argc - 必ず1
//   args - [変換関数]
//
// 戻り値:
//   フィルターストリーム
// -----------------------------------------------------------------------------
exec_map :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 {
		return STRM_NG
	}

	d := new(Map_Data)
	d.func_ = args[0]

	ret^ = strm_stream_value(strm_stream_new(.Filter, iter_map, nil, rawptr(d)))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// ary_map - 配列版の map
// -----------------------------------------------------------------------------
// 配列の各要素に関数を適用し、新しい配列を返します。
// ストリームではなく、配列を直接変換します。
//
// Streem言語での使用例:
//   [1, 2, 3].map{|x| x * 2}  # => [2, 4, 6]
//
// パラメータ:
//   argc - 必ず2
//   args - [配列, 変換関数]
//
// 戻り値:
//   変換後の配列
// -----------------------------------------------------------------------------
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

// =============================================================================
// Filter - 要素選別フィルター (Element Selection Filter)
// =============================================================================

// -----------------------------------------------------------------------------
// iter_filter - 条件に合う要素のみを通す内部コールバック
// -----------------------------------------------------------------------------
// 入力された各要素に対して述語関数を呼び出し、
// true を返した要素のみを下流に emit します。
//
// 動作:
//   1. 入力データ data を引数として func_ を呼び出す
//   2. 結果が true なら data を emit、false なら何もしない
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// exec_filter - 要素を選別するフィルターストリームを作成
// -----------------------------------------------------------------------------
// 述語関数が true を返す要素のみを通すフィルターストリームを返します。
//
// Streem言語での使用例:
//   seq(10) | filter{|x| x % 2 == 0}  # => 2, 4, 6, 8, 10 （偶数のみ）
//   seq(10) | filter{|x| x > 5}       # => 6, 7, 8, 9, 10
//   ["a", "bb", "ccc"] | filter{|s| s.length > 1}  # => "bb", "ccc"
//
// パラメータ:
//   argc - 必ず1
//   args - [述語関数（真偽値を返す関数）]
//
// 戻り値:
//   フィルターストリーム
// -----------------------------------------------------------------------------
exec_filter :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 {
		return STRM_NG
	}

	d := new(Map_Data)
	d.func_ = args[0]

	ret^ = strm_stream_value(strm_stream_new(.Filter, iter_filter, nil, rawptr(d)))
	return STRM_OK
}

// =============================================================================
// Each - 副作用実行フィルター (Side-Effect Execution Filter)
// =============================================================================

// -----------------------------------------------------------------------------
// iter_each - 各要素に関数を適用する内部コールバック（emit なし）
// -----------------------------------------------------------------------------
// 入力された各要素に対して関数を呼び出しますが、
// 結果は emit せず、データは消費されます。
// 主に副作用（ログ出力など）のために使用します。
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// exec_each - 各要素に関数を適用するフィルターストリームを作成
// -----------------------------------------------------------------------------
// 各要素に関数を適用しますが、データを下流に流しません。
// 副作用（出力、ログなど）を実行するために使用します。
//
// Streem言語での使用例:
//   seq(5) | each{|x| puts(x)}  # 1, 2, 3, 4, 5 を出力（ストリーム終端）
//
// パラメータ:
//   argc - 必ず1
//   args - [適用する関数]
//
// 戻り値:
//   フィルターストリーム（コンシューマーとして動作）
//
// 注意:
//   each は下流にデータを emit しないため、パイプラインの終端として
//   使用されます。データを変換しつつ流したい場合は map を使用してください。
// -----------------------------------------------------------------------------
exec_each :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 {
		return STRM_NG
	}

	d := new(Map_Data)
	d.func_ = args[0]

	ret^ = strm_stream_value(strm_stream_new(.Filter, iter_each, nil, rawptr(d)))
	return STRM_OK
}

// =============================================================================
// Count - 要素カウントアグリゲーター (Element Count Aggregator)
// =============================================================================

// -----------------------------------------------------------------------------
// Count_Data - カウント用の内部状態
// -----------------------------------------------------------------------------
// 要素数をカウントするための構造体です。
//
// フィールド:
//   count - これまでに受け取った要素の数
// -----------------------------------------------------------------------------
Count_Data :: struct {
	count: int,
}

// -----------------------------------------------------------------------------
// iter_count - 各要素を数える内部コールバック
// -----------------------------------------------------------------------------
// 要素が来るたびにカウントをインクリメントします。
// 要素自体は下流に流しません。
// -----------------------------------------------------------------------------
@(private = "file")
iter_count :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Count_Data)strm.data
	d.count += 1
	return STRM_OK
}

// -----------------------------------------------------------------------------
// count_finish - ストリーム終了時にカウントを emit
// -----------------------------------------------------------------------------
// 上流のストリームが終了したら、累積したカウント値を emit します。
// -----------------------------------------------------------------------------
@(private = "file")
count_finish :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Count_Data)strm.data
	strm_emit(strm, strm_int_value(i32(d.count)), nil)
	free(d)
	return STRM_OK
}

// -----------------------------------------------------------------------------
// exec_count - 要素数をカウントするフィルターストリームを作成
// -----------------------------------------------------------------------------
// ストリームの全要素を数え、終了時に合計数を出力します。
//
// Streem言語での使用例:
//   seq(10) | count()                      # => 10
//   seq(100) | filter{|x| x % 2 == 0} | count()  # => 50
//   fread("file.txt") | count()            # => 行数
//
// パラメータ:
//   argc - 0（引数なし）
//
// 戻り値:
//   フィルターストリーム（終了時に整数を1つ emit）
// -----------------------------------------------------------------------------
exec_count :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	d := new(Count_Data)
	d.count = 0

	ret^ = strm_stream_value(strm_stream_new(.Filter, iter_count, count_finish, rawptr(d)))
	return STRM_OK
}

// =============================================================================
// Reduce - 集約アグリゲーター (Reduction Aggregator)
// =============================================================================

// -----------------------------------------------------------------------------
// Reduce_Data - リダクション用の内部状態
// -----------------------------------------------------------------------------
// reduce 関数の状態を保持する構造体です。
//
// フィールド:
//   init  - アキュムレータが初期化済みかどうか
//   acc   - アキュムレータ（累積値）
//   func_ - リダクション関数 (acc, elem) -> new_acc
// -----------------------------------------------------------------------------
Reduce_Data :: struct {
	init:  bool,
	acc:   Strm_Value,
	func_: Strm_Value,
}

// -----------------------------------------------------------------------------
// iter_reduce - 各要素を累積する内部コールバック
// -----------------------------------------------------------------------------
// 各要素に対して func_(acc, data) を呼び出し、
// 結果を新しい acc として保持します。
//
// 動作:
//   1. 最初の要素の場合、それをアキュムレータとして初期化
//   2. 2番目以降は func_(acc, data) を呼び出してアキュムレータを更新
// -----------------------------------------------------------------------------
@(private = "file")
iter_reduce :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Reduce_Data)strm.data

	// 最初の要素がアキュムレータになる
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

// -----------------------------------------------------------------------------
// reduce_finish - ストリーム終了時に累積結果を emit
// -----------------------------------------------------------------------------
// 上流のストリームが終了したら、最終的なアキュムレータ値を emit します。
// -----------------------------------------------------------------------------
@(private = "file")
reduce_finish :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Reduce_Data)strm.data
	if !d.init {
		return STRM_NG
	}
	strm_emit(strm, d.acc, nil)
	return STRM_OK
}

// -----------------------------------------------------------------------------
// exec_reduce - 要素を集約するフィルターストリームを作成
// -----------------------------------------------------------------------------
// ストリームの全要素を1つの値に畳み込みます（fold操作）。
//
// Streem言語での使用例:
//   seq(5) | reduce{|a, b| a + b}        # => 15 (1+2+3+4+5)
//   seq(5) | reduce(0){|a, b| a + b}     # => 15 (初期値0から開始)
//   seq(5) | reduce(1){|a, b| a * b}     # => 120 (1*1*2*3*4*5)
//   ["a", "b", "c"] | reduce{|a, b| a + b}  # => "abc"
//
// 引数パターン:
//   reduce(func)        - 最初の要素を初期値として使用
//   reduce(init, func)  - init を初期値として使用
//
// パラメータ:
//   argc - 1 または 2
//   args - [(初期値,) リダクション関数]
//
// 戻り値:
//   フィルターストリーム（終了時に累積結果を1つ emit）
//
// 注意:
//   初期値なしで空のストリームを reduce するとエラーになります。
// -----------------------------------------------------------------------------
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

// =============================================================================
// Take - 先頭N個取得フィルター (Take First N Elements Filter)
// =============================================================================

// -----------------------------------------------------------------------------
// Take_Data - take/drop 共通の内部状態
// -----------------------------------------------------------------------------
// 残りカウントを保持する構造体です。
//
// フィールド:
//   n - 残り要素数（take では emit する残り数、drop では skip する残り数）
// -----------------------------------------------------------------------------
Take_Data :: struct {
	n: int,
}

// -----------------------------------------------------------------------------
// iter_take - 最初のn個を通す内部コールバック
// -----------------------------------------------------------------------------
// 要素を emit し、カウントをデクリメントします。
// カウントが0になったらストリームをクローズして上流を停止させます。
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// exec_take - 最初のn個を取得するフィルターストリームを作成
// -----------------------------------------------------------------------------
// ストリームの最初の n 個の要素のみを通し、残りは無視します。
// n 個取得したら上流ストリームを停止させます。
//
// Streem言語での使用例:
//   seq(100) | take(5)   # => 1, 2, 3, 4, 5
//   repeat(0) | take(3)  # => 0, 0, 0 （無限ストリームを制限）
//
// パラメータ:
//   argc - 必ず1
//   args - [取得する要素数 n（整数）]
//
// 戻り値:
//   フィルターストリーム
//
// エラー:
//   n が負の場合はエラー
// -----------------------------------------------------------------------------
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

// =============================================================================
// Drop - 先頭N個スキップフィルター (Drop First N Elements Filter)
// =============================================================================

// -----------------------------------------------------------------------------
// iter_drop - 最初のn個をスキップする内部コールバック
// -----------------------------------------------------------------------------
// カウントが0より大きい間は要素をスキップし、
// 0になったら以降の要素を emit します。
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// exec_drop - 最初のn個をスキップするフィルターストリームを作成
// -----------------------------------------------------------------------------
// ストリームの最初の n 個の要素をスキップし、残りを通します。
//
// Streem言語での使用例:
//   seq(10) | drop(5)   # => 6, 7, 8, 9, 10
//   seq(10) | drop(3) | take(2)  # => 4, 5
//
// パラメータ:
//   argc - 必ず1
//   args - [スキップする要素数 n（整数）]
//
// 戻り値:
//   フィルターストリーム
//
// エラー:
//   n が負の場合はエラー
// -----------------------------------------------------------------------------
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

// =============================================================================
// Min/Max - 最小/最大値検索アグリゲーター (Minimum/Maximum Finder)
// =============================================================================

// -----------------------------------------------------------------------------
// MinMax_Data - min/max 共通の内部状態
// -----------------------------------------------------------------------------
// 最小値または最大値を追跡するための構造体です。
//
// フィールド:
//   start  - 最初の要素かどうか（初期化フラグ）
//   is_min - true なら最小値、false なら最大値を探す
//   data   - 現在の最小/最大の元データ
//   num    - 現在の最小/最大の数値（比較用）
//   func_  - 比較用のキー関数（オプション）
// -----------------------------------------------------------------------------
MinMax_Data :: struct {
	start: bool,
	is_min: bool,
	data: Strm_Value,
	num: f64,
	func_: Strm_Value,
}

// -----------------------------------------------------------------------------
// iter_minmax - 各要素を比較して最小/最大を更新する内部コールバック
// -----------------------------------------------------------------------------
// 各要素を受け取り、現在の最小/最大値と比較して更新します。
// オプションのキー関数がある場合、それを適用した結果で比較します。
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// minmax_finish - ストリーム終了時に最小/最大値を emit
// -----------------------------------------------------------------------------
// 上流のストリームが終了したら、見つかった最小/最大値を emit します。
// -----------------------------------------------------------------------------
@(private = "file")
minmax_finish :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^MinMax_Data)strm.data
	strm_emit(strm, d.data, nil)
	return STRM_OK
}

// -----------------------------------------------------------------------------
// exec_minmax - 最小/最大値を検索するフィルターストリームを作成（内部）
// -----------------------------------------------------------------------------
// min と max で共通のロジックを実装します。
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// exec_min - 最小値を検索するフィルターストリームを作成
// -----------------------------------------------------------------------------
// ストリームの全要素の中から最小値を見つけて出力します。
//
// Streem言語での使用例:
//   seq(10) | min()                    # => 1
//   [3, 1, 4, 1, 5] | min()            # => 1
//   ["abc", "xy", "hello"] | min{|s| s.length}  # => "xy" (長さで比較)
//
// 引数パターン:
//   min()      - 要素自体で比較
//   min(func)  - func の戻り値で比較（元の要素を返す）
//
// パラメータ:
//   argc - 0 または 1
//   args - [(キー関数)]
//
// 戻り値:
//   フィルターストリーム（終了時に最小値を1つ emit）
// -----------------------------------------------------------------------------
exec_min :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	return exec_minmax(strm, argc, args, ret, true)
}

// -----------------------------------------------------------------------------
// exec_max - 最大値を検索するフィルターストリームを作成
// -----------------------------------------------------------------------------
// ストリームの全要素の中から最大値を見つけて出力します。
//
// Streem言語での使用例:
//   seq(10) | max()                    # => 10
//   [3, 1, 4, 1, 5] | max()            # => 5
//   ["abc", "xy", "hello"] | max{|s| s.length}  # => "hello" (長さで比較)
//
// 引数パターン:
//   max()      - 要素自体で比較
//   max(func)  - func の戻り値で比較（元の要素を返す）
//
// パラメータ:
//   argc - 0 または 1
//   args - [(キー関数)]
//
// 戻り値:
//   フィルターストリーム（終了時に最大値を1つ emit）
// -----------------------------------------------------------------------------
exec_max :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	return exec_minmax(strm, argc, args, ret, false)
}

// =============================================================================
// Flatmap - 変換＆平坦化フィルター (Transform and Flatten Filter)
// =============================================================================

// -----------------------------------------------------------------------------
// iter_flatmap - 各要素を変換して平坦化する内部コールバック
// -----------------------------------------------------------------------------
// 各要素に関数を適用し、結果が配列なら展開して個別に emit します。
// 配列でなければそのまま emit します。
//
// 動作:
//   1. 入力データ data を引数として func_ を呼び出す
//   2. 結果が配列なら、各要素を個別に emit
//   3. 配列でなければ、そのまま emit
// -----------------------------------------------------------------------------
@(private = "file")
iter_flatmap :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Map_Data)strm.data
	val: Strm_Value

	args := []Strm_Value{data}
	if strm_funcall(strm, nil, d.func_, args, &val) != .Ok {
		return STRM_NG
	}

	// 結果が配列なら、各要素を個別に emit
	if strm_array_p(val) {
		ary := Strm_Array(val)
		ptr := strm_ary_ptr(ary)
		for i in 0 ..< strm_ary_len(ary) {
			strm_emit(strm, ptr[i], nil)
		}
	} else {
		// 配列以外はそのまま emit
		strm_emit(strm, val, nil)
	}
	return STRM_OK
}

// -----------------------------------------------------------------------------
// exec_flatmap - 変換＆平坦化フィルターストリームを作成
// -----------------------------------------------------------------------------
// 各要素に関数を適用し、結果の配列を展開して個別の要素として出力します。
// map + flatten の組み合わせです。
//
// Streem言語での使用例:
//   seq(3) | flatmap{|x| [x, x*x]}  # => 1, 1, 2, 4, 3, 9
//   [[1,2], [3,4]] | flatmap{|a| a}  # => 1, 2, 3, 4 （ネストを解除）
//   seq(3) | flatmap{|x| x}         # => 1, 2, 3 （配列以外はそのまま）
//
// パラメータ:
//   argc - 必ず1
//   args - [変換関数]
//
// 戻り値:
//   フィルターストリーム
// -----------------------------------------------------------------------------
exec_flatmap :: proc(strm: ^Strm_Stream, argc: int, args: []Strm_Value, ret: ^Strm_Value) -> int {
	if argc != 1 {
		return STRM_NG
	}

	d := new(Map_Data)
	d.func_ = args[0]

	ret^ = strm_stream_value(strm_stream_new(.Filter, iter_flatmap, nil, rawptr(d)))
	return STRM_OK
}

// -----------------------------------------------------------------------------
// ary_flatmap - 配列版の flatmap
// -----------------------------------------------------------------------------
// 配列の各要素に関数を適用し、結果を平坦化した新しい配列を返します。
//
// Streem言語での使用例:
//   [1, 2, 3].flatmap{|x| [x, x*x]}  # => [1, 1, 2, 4, 3, 9]
//
// パラメータ:
//   argc - 必ず2
//   args - [配列, 変換関数]
//
// 戻り値:
//   平坦化された配列
// -----------------------------------------------------------------------------
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
		// 結果が配列なら、各要素を追加
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

// =============================================================================
// Cycle - 配列循環プロデューサー (Array Cycle Producer)
// =============================================================================

// -----------------------------------------------------------------------------
// Cycle_Data - 循環生成用の内部状態
// -----------------------------------------------------------------------------
// cycle 関数が生成するストリームの状態を保持する構造体です。
//
// フィールド:
//   ary    - 循環する配列
//   idx    - 現在のインデックス（配列内の位置）
//   count  - 繰り返し回数（-1は無限）
//   cycles - これまでに完了した周回数
// -----------------------------------------------------------------------------
Cycle_Data :: struct {
	ary:    Strm_Array,
	idx:    int,
	count:  int, // -1 は無限
	cycles: int, // 現在の周回数
}

// -----------------------------------------------------------------------------
// gen_cycle - 配列要素を1つ emit する内部コールバック
// -----------------------------------------------------------------------------
// 配列の次の要素を emit し、末尾に達したら先頭に戻ります。
// 指定された周回数に達したらストリームをクローズします。
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// exec_cycle - 配列を循環するストリームを作成
// -----------------------------------------------------------------------------
// 配列の要素を順番に出力し、末尾に達したら先頭に戻ります。
// 指定された回数だけ繰り返すか、無限に繰り返します。
//
// Streem言語での使用例:
//   cycle([1, 2, 3], 2)         # => 1, 2, 3, 1, 2, 3
//   cycle(["a", "b"]) | take(5) # => "a", "b", "a", "b", "a"
//   cycle([1]) | take(3)        # => 1, 1, 1
//
// 引数パターン:
//   cycle(array)        - array を無限に繰り返す
//   cycle(array, count) - array を count 回繰り返す
//
// パラメータ:
//   argc - 1 または 2
//   args - [配列, (繰り返し回数)]
//
// 戻り値:
//   プロデューサーストリーム
//
// エラー:
//   - 第1引数が配列でない場合はエラー
//   - count が0以下の場合はエラー
// -----------------------------------------------------------------------------
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

// =============================================================================
// Slice - N要素グループ化フィルター (Group into N-element Arrays Filter)
// =============================================================================

// -----------------------------------------------------------------------------
// Slice_Data - スライス用の内部状態
// -----------------------------------------------------------------------------
// slice 関数の状態を保持する構造体です。
//
// フィールド:
//   n      - グループサイズ
//   buffer - 現在蓄積中の要素
// -----------------------------------------------------------------------------
Slice_Data :: struct {
	n:      int,
	buffer: [dynamic]Strm_Value,
}

// -----------------------------------------------------------------------------
// iter_slice - 要素をバッファリングしてグループ化する内部コールバック
// -----------------------------------------------------------------------------
// 要素をバッファに追加し、n個たまったら配列として emit します。
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// slice_finish - ストリーム終了時に残りの要素を emit
// -----------------------------------------------------------------------------
// バッファに残っている要素があれば、最後のグループとして emit します。
// （n個未満でも出力される）
// -----------------------------------------------------------------------------
@(private = "file")
slice_finish :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Slice_Data)strm.data

	// 残っている要素があれば emit
	if len(d.buffer) > 0 {
		ary := strm_ary_new(d.buffer[:])
		strm_emit(strm, strm_ary_value(ary), nil)
	}

	delete(d.buffer)
	free(d)
	return STRM_OK
}

// -----------------------------------------------------------------------------
// exec_slice - N要素ずつグループ化するフィルターストリームを作成
// -----------------------------------------------------------------------------
// 入力要素を n 個ずつまとめて配列として出力します。
// 最後のグループは n 個未満になることがあります。
//
// Streem言語での使用例:
//   seq(10) | slice(3)  # => [1,2,3], [4,5,6], [7,8,9], [10]
//   seq(6) | slice(2)   # => [1,2], [3,4], [5,6]
//   seq(5) | slice(10)  # => [1,2,3,4,5]
//
// パラメータ:
//   argc - 必ず1
//   args - [グループサイズ n（整数）]
//
// 戻り値:
//   フィルターストリーム（配列を emit）
//
// エラー:
//   n が0以下の場合はエラー
// -----------------------------------------------------------------------------
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

// =============================================================================
// Consec - スライディングウィンドウフィルター (Sliding Window Filter)
// =============================================================================

// -----------------------------------------------------------------------------
// Consec_Data - スライディングウィンドウ用の内部状態
// -----------------------------------------------------------------------------
// consec 関数の状態を保持する構造体です。
//
// フィールド:
//   n      - ウィンドウサイズ
//   buffer - 現在のウィンドウ内の要素
//   full   - ウィンドウが n 個で満たされたかどうか
// -----------------------------------------------------------------------------
Consec_Data :: struct {
	n:      int,
	buffer: [dynamic]Strm_Value,
	full:   bool,
}

// -----------------------------------------------------------------------------
// iter_consec - スライディングウィンドウを emit する内部コールバック
// -----------------------------------------------------------------------------
// 新しい要素をウィンドウに追加し、ウィンドウが n 個になったら emit します。
// emit 後、最も古い要素を削除してウィンドウをスライドさせます。
// -----------------------------------------------------------------------------
@(private = "file")
iter_consec :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Consec_Data)strm.data

	append(&d.buffer, data)

	if len(d.buffer) >= d.n {
		d.full = true
	}

	if d.full {
		// ウィンドウを emit
		ary := strm_ary_new(d.buffer[:])
		strm_emit(strm, strm_ary_value(ary), nil)
		// ウィンドウをスライド - 最初の要素を削除
		ordered_remove(&d.buffer, 0)
	}
	return STRM_OK
}

// -----------------------------------------------------------------------------
// consec_finish - ストリーム終了時のクリーンアップ
// -----------------------------------------------------------------------------
// バッファを解放します。
// 注意: slice と異なり、最後の不完全なウィンドウは emit しません。
// -----------------------------------------------------------------------------
@(private = "file")
consec_finish :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Consec_Data)strm.data
	delete(d.buffer)
	free(d)
	return STRM_OK
}

// -----------------------------------------------------------------------------
// exec_consec - スライディングウィンドウフィルターストリームを作成
// -----------------------------------------------------------------------------
// 連続する n 個の要素をウィンドウとして出力します。
// 新しい要素が来るたびにウィンドウが1つスライドします。
//
// slice との違い:
//   - slice: 要素を n 個ずつの重複しないグループに分割
//   - consec: 1要素ずつスライドする重複するウィンドウを生成
//
// Streem言語での使用例:
//   seq(5) | consec(3)   # => [1,2,3], [2,3,4], [3,4,5]
//   seq(5) | consec(2)   # => [1,2], [2,3], [3,4], [4,5]
//   seq(3) | consec(5)   # => （何も出力されない - 要素数が足りない）
//
// パラメータ:
//   argc - 必ず1
//   args - [ウィンドウサイズ n（整数）]
//
// 戻り値:
//   フィルターストリーム（配列を emit）
//
// エラー:
//   n が0以下の場合はエラー
// -----------------------------------------------------------------------------
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

// =============================================================================
// Uniq - 連続重複削除フィルター (Remove Consecutive Duplicates Filter)
// =============================================================================

// -----------------------------------------------------------------------------
// Uniq_Data - 重複削除用の内部状態
// -----------------------------------------------------------------------------
// uniq 関数の状態を保持する構造体です。
//
// フィールド:
//   first - 最初の要素かどうか
//   prev  - 前回のキー値（比較用）
//   func_ - キー関数（オプション）
// -----------------------------------------------------------------------------
Uniq_Data :: struct {
	first: bool,
	prev:  Strm_Value,
	func_: Strm_Value, // オプションのキー関数
}

// -----------------------------------------------------------------------------
// iter_uniq - 連続する重複を除去する内部コールバック
// -----------------------------------------------------------------------------
// 前回の要素（のキー）と異なる場合のみ emit します。
// 同じ値が連続している場合、最初の1つだけが通過します。
// -----------------------------------------------------------------------------
@(private = "file")
iter_uniq :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Uniq_Data)strm.data

	key := data
	// キー関数があれば適用
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

	// 前回のキーと比較
	if !strm_value_eq(key, d.prev) {
		d.prev = key
		strm_emit(strm, data, nil)
	}
	return STRM_OK
}

// -----------------------------------------------------------------------------
// uniq_finish - ストリーム終了時のクリーンアップ
// -----------------------------------------------------------------------------
@(private = "file")
uniq_finish :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Uniq_Data)strm.data
	free(d)
	return STRM_OK
}

// -----------------------------------------------------------------------------
// exec_uniq - 連続重複を削除するフィルターストリームを作成
// -----------------------------------------------------------------------------
// 連続して同じ値が来た場合、最初の1つだけを通過させます。
// UNIXの uniq コマンドと同様の動作です。
//
// 注意: ソートされていないデータでは、離れた位置にある重複は残ります。
// 全ての重複を削除するには、先にソートする必要があります。
//
// Streem言語での使用例:
//   [1, 1, 2, 2, 2, 3, 1] | uniq()  # => 1, 2, 3, 1 （連続重複のみ削除）
//   [1, 2, 3, 2, 1] | uniq()       # => 1, 2, 3, 2, 1 （連続していないので全て通過）
//   ["ab", "abc", "xy"] | uniq{|s| s.length}  # => "ab", "xy" （長さで比較）
//
// 引数パターン:
//   uniq()      - 要素自体で比較
//   uniq(func)  - func の戻り値で比較（元の要素を通す）
//
// パラメータ:
//   argc - 0 または 1
//   args - [(キー関数)]
//
// 戻り値:
//   フィルターストリーム
// -----------------------------------------------------------------------------
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

// =============================================================================
// 初期化 (Initialization)
// =============================================================================

// -----------------------------------------------------------------------------
// strm_iter_init - イテレータ/ストリーム関数の初期化
// -----------------------------------------------------------------------------
// Streem言語のグローバルスコープに、全てのイテレータ関数を登録します。
//
// 登録される関数:
//
// 【プロデューサー (データ生成)】
//   seq     - 数列を生成
//   repeat  - 値を繰り返す
//   cycle   - 配列を循環
//
// 【トランスフォーマー (データ変換)】
//   each    - 各要素に関数を適用（emit なし）
//   map     - 各要素を変換
//   filter  - 条件に合う要素のみ通す
//   flatmap - 変換して平坦化
//
// 【アグリゲーター (データ集約)】
//   count   - 要素数をカウント
//   min     - 最小値を検索
//   max     - 最大値を検索
//   reduce  - 要素を1つに集約
//
// 【ウィンドウ操作】
//   take    - 最初の n 個を取得
//   drop    - 最初の n 個をスキップ
//   slice   - n 個ずつグループ化
//   consec  - スライディングウィンドウ
//   uniq    - 連続重複を削除
//
// 【配列メソッド】
//   array.map     - 配列版 map
//   array.flatmap - 配列版 flatmap
// -----------------------------------------------------------------------------
strm_iter_init :: proc(state: ^Strm_State) {
	// プロデューサー
	strm_var_def(state, strm_str_intern("seq"), strm_cfunc_value(exec_seq))
	strm_var_def(state, strm_str_intern("repeat"), strm_cfunc_value(exec_repeat))
	strm_var_def(state, strm_str_intern("cycle"), strm_cfunc_value(exec_cycle))

	// トランスフォーマー
	strm_var_def(state, strm_str_intern("each"), strm_cfunc_value(exec_each))
	strm_var_def(state, strm_str_intern("map"), strm_cfunc_value(exec_map))
	strm_var_def(state, strm_str_intern("filter"), strm_cfunc_value(exec_filter))
	strm_var_def(state, strm_str_intern("flatmap"), strm_cfunc_value(exec_flatmap))

	// アグリゲーター
	strm_var_def(state, strm_str_intern("count"), strm_cfunc_value(exec_count))
	strm_var_def(state, strm_str_intern("min"), strm_cfunc_value(exec_min))
	strm_var_def(state, strm_str_intern("max"), strm_cfunc_value(exec_max))
	strm_var_def(state, strm_str_intern("reduce"), strm_cfunc_value(exec_reduce))

	// ウィンドウ操作
	strm_var_def(state, strm_str_intern("take"), strm_cfunc_value(exec_take))
	strm_var_def(state, strm_str_intern("drop"), strm_cfunc_value(exec_drop))
	strm_var_def(state, strm_str_intern("slice"), strm_cfunc_value(exec_slice))
	strm_var_def(state, strm_str_intern("consec"), strm_cfunc_value(exec_consec))
	strm_var_def(state, strm_str_intern("uniq"), strm_cfunc_value(exec_uniq))

	// 配列メソッド
	strm_var_def(strm_ns_array, strm_str_intern("map"), strm_cfunc_value(ary_map))
	strm_var_def(strm_ns_array, strm_str_intern("flatmap"), strm_cfunc_value(ary_flatmap))
}
