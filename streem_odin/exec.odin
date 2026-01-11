// =============================================================================
// AST評価器（インタプリタ）
// =============================================================================
//
// このファイルはStreemのAST（抽象構文木）を評価（実行）するインタプリタです。
// パーサーが生成したASTを再帰的に走査し、各ノードを評価して結果を返します。
//
// 主な機能:
//   - リテラル評価（数値、文字列、真偽値など）
//   - 式評価（演算子、条件分岐、配列など）
//   - 文評価（変数束縛、emit、return など）
//   - 関数呼び出し（ラムダ、組み込み関数、パターンマッチング）
//   - 名前空間とインポート
//
// 参照: src/exec.c (オリジナルC実装)
//
// =============================================================================
package streem

import "core:fmt"

// -----------------------------------------------------------------------------
// 実行結果
// -----------------------------------------------------------------------------

// Exec_Result: 式の評価結果を表す列挙型
// 制御フローの管理に使用
Exec_Result :: enum {
	Ok,     // 正常終了
	Error,  // エラー発生
	Return, // return文による早期リターン
	Skip,   // skip文による現在の値のスキップ
}

// =============================================================================
// ラムダ構造体（クロージャ）
// =============================================================================
//
// クロージャはラムダ式とその定義時の環境（スコープ）を保持します。
// これにより、ラムダは定義時の変数にアクセスできます。
//
// 例:
//   let x = 10
//   let f = {|y| x + y}  // f は x = 10 を捕捉
//   f(5)  // => 15
//
// =============================================================================

// Strm_Lambda: ラムダクロージャ構造体
Strm_Lambda :: struct {
	type:  Ptr_Type,     // 型タグ（必ず先頭に配置）- Ptr_Type.Lambda
	body:  ^Node,        // ラムダ本体のASTノード（Lambda または PLambda）
	state: ^Strm_State,  // 捕捉されたスコープ（クロージャ環境）
}

// strm_lambda_new: 新しいラムダクロージャを作成する
// 引数:
//   - body: ラムダのASTノード
//   - state: 捕捉するスコープ（定義時の環境）
// 戻り値:
//   - 新しいラムダクロージャへのポインタ
strm_lambda_new :: proc(body: ^Node, state: ^Strm_State) -> ^Strm_Lambda {
	lambda := new(Strm_Lambda)
	lambda.type = .Lambda
	lambda.body = body
	// クロージャ捕捉のためにスコープをコピー
	// これにより、元のスコープが変更されても影響を受けない
	lambda.state = new(Strm_State)
	lambda.state^ = state^
	return lambda
}

// strm_lambda_destroy: ラムダクロージャを破棄する
strm_lambda_destroy :: proc(lambda: ^Strm_Lambda) {
	if lambda == nil {
		return
	}
	if lambda.state != nil {
		free(lambda.state)
	}
	free(lambda)
}

// =============================================================================
// ジェネリック関数参照構造体
// =============================================================================
//
// ジェネリック関数は、名前による関数参照を表します。
// 実際の関数は呼び出し時に名前で検索されます。
// これにより、同じ名前で異なる引数型に対応する関数を呼び出せます。
//
// =============================================================================

// Strm_Genfunc: ジェネリック関数参照構造体
Strm_Genfunc :: struct {
	type:  Ptr_Type,    // 型タグ（必ず先頭に配置）- Ptr_Type.Genfunc
	state: ^Strm_State, // 関数検索用のスコープ
	id:    Strm_String, // 関数名
}

// strm_genfunc_new: 新しいジェネリック関数参照を作成する
strm_genfunc_new :: proc(state: ^Strm_State, id: Strm_String) -> ^Strm_Genfunc {
	gf := new(Strm_Genfunc)
	gf.type = .Genfunc
	gf.state = state
	gf.id = id
	return gf
}

// =============================================================================
// メイン評価エントリーポイント
// =============================================================================
//
// exec_expr はASTの再帰的評価の中心となる関数です。
// ノードの種類に応じて適切な評価関数にディスパッチします。
//
// =============================================================================

// exec_expr: ASTノードを評価する
// これがインタプリタの中核関数で、全ての式と文を評価する
//
// 引数:
//   - strm: 現在のストリームコンテキスト（nil可、例外処理に使用）
//   - state: 現在のスコープ（変数環境）
//   - node: 評価するASTノード
//   - ret: 評価結果を格納するポインタ
// 戻り値:
//   - Exec_Result: 評価結果（Ok, Error, Return, Skip）
exec_expr :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	// nilノードはnilを返す
	if node == nil {
		ret^ = strm_nil_value()
		return .Ok
	}

	// ノードの種類に応じてディスパッチ
	switch node.type {
	// ===== リテラル =====
	// 即値を返す。スコープに依存しない。
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

	// ===== 式 =====
	// 評価により値を生成する
	case .Ident:
		// 識別子: 変数の値を検索して返す
		return exec_ident(strm, state, node, ret)
	case .Op:
		// 演算子: 二項/単項演算を実行
		return exec_op(strm, state, node, ret)
	case .If:
		// 条件分岐: if-then-else
		return exec_if(strm, state, node, ret)
	case .Array:
		// 配列リテラル: [1, 2, 3]
		return exec_array(strm, state, node, ret)

	// ===== 文 =====
	// 副作用を持つ操作
	case .Let:
		// 変数束縛: let x = expr
		return exec_let(strm, state, node, ret)
	case .Emit:
		// ストリーム送出: emit value
		return exec_emit(strm, state, node, ret)
	case .Skip:
		// スキップ: 現在の値をスキップ
		if strm != nil {
			strm_set_exc(strm, .Skip, strm_nil_value())
		}
		return .Skip
	case .Return:
		// リターン: return value
		return exec_return(strm, state, node, ret)
	case .Nodes:
		// ノードリスト: 複数の文を順次実行
		return exec_nodes(strm, state, node, ret)

	// ===== 関数 =====
	case .Lambda, .PLambda:
		// ラムダ式: {|x| x + 1} または パターンラムダ
		return exec_lambda(strm, state, node, ret)
	case .Call:
		// 名前による関数呼び出し: func(args)
		return exec_call(strm, state, node, ret)
	case .Fcall:
		// 式による関数呼び出し: (expr)(args)
		return exec_fcall(strm, state, node, ret)
	case .Genfunc:
		// ジェネリック関数参照
		return exec_genfunc(state, node, ret)

	// ===== 名前空間 =====
	case .Ns:
		// 名前空間定義: namespace Foo { ... }
		return exec_ns(strm, state, node, ret)
	case .Import:
		// インポート: import Foo
		return exec_import(state, node, ret)

	// ===== パターンマッチングノード =====
	// これらは直接評価されず、lambda_call 内で処理される
	case .Args, .Pair, .Splat, .PArray, .PStruct, .PSplat:
		ret^ = strm_nil_value()
		return .Error
	}

	// 未知のノード種類
	ret^ = strm_nil_value()
	return .Error
}

// =============================================================================
// リテラル評価
// =============================================================================
//
// リテラル値（数値、文字列、真偽値など）をStrm_Valueに変換する
// これらは最も単純な評価で、スコープに依存しない
//
// =============================================================================

// exec_int: 整数リテラルを評価
// 例: 42, -10
exec_int :: proc(node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Int)
	ret^ = strm_int_value(i32(data.value))
	return .Ok
}

// exec_float: 浮動小数点リテラルを評価
// 例: 3.14, -0.5
exec_float :: proc(node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Float)
	ret^ = strm_float_value(data.value)
	return .Ok
}

// exec_string: 文字列リテラルを評価
// 例: "hello", "world"
exec_string :: proc(node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Str)
	str := strm_str_new(data.value)
	ret^ = strm_str_value(str)
	return .Ok
}

// exec_bool: 真偽値リテラルを評価
// 例: true, false
exec_bool :: proc(node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Bool)
	ret^ = strm_bool_value(data.value)
	return .Ok
}

// exec_time: 時刻リテラルを評価
// 例: 2024-01-01T00:00:00Z
exec_time :: proc(node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Time)
	// 時刻値を作成
	// 現在は簡易実装（Phase 14で完全実装予定）
	time_val := strm_time_new(data.sec, data.usec, data.utc_offset)
	ret^ = time_val
	return .Ok
}

// strm_time_new: 時刻値を作成する（スタブ実装）
// 現在は浮動小数点数（エポックからの秒数）として保存
// TODO: Phase 14で適切な時刻型を実装
strm_time_new :: proc(sec: i64, usec: i64, utc_offset: int) -> Strm_Value {
	return strm_float_value(f64(sec) + f64(usec) / 1_000_000.0)
}

// strm_time_p: 値が時刻型かどうかをチェック
// TODO: 適切な時刻型チェックを実装
strm_time_p :: proc(v: Strm_Value) -> bool {
	return false
}

// =============================================================================
// 式評価
// =============================================================================
//
// 式を評価して値を生成する関数群
// 識別子、演算子、条件分岐、配列などを処理
//
// =============================================================================

// exec_ident: 識別子（変数参照）を評価
// スコープチェーンを遡って変数を検索し、その値を返す
// 例: x, my_var
exec_ident :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Ident)
	val, found := strm_var_get(state, data.name)
	if !found {
		// 変数が見つからない
		if strm != nil {
			strm_raise(strm, "failed to reference variable")
		}
		ret^ = strm_nil_value()
		return .Error
	}
	ret^ = val
	return .Ok
}

// exec_op: 演算子を評価
// 二項演算子（+, -, *, /, |, など）または単項演算子（!, -）を処理
// 演算子は関数として登録されており、名前で検索して呼び出す
//
// 例: a + b, -x, a | b (パイプ)
exec_op :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Op)

	// オペランドを評価
	args: [2]Strm_Value
	argc := 0

	// lhsがnilの場合は単項演算子
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

	// 登録された演算子関数にディスパッチ
	// 例: "+" → strm_op_add, "|" → strm_op_pipe
	op_name := strm_str_intern(data.op)
	return exec_call_internal(strm, state, op_name, args[:argc], ret)
}

// exec_if: 条件分岐を評価
// if cond then_expr [else else_expr]
// Streemでは if は式であり、値を返す
exec_if :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_If)

	// 条件式を評価
	cond_val: Strm_Value
	result := exec_expr(strm, state, data.cond, &cond_val)
	if result != .Ok {
		return result
	}

	// 真偽値チェック
	// nil と false は偽、それ以外は真
	is_true := true
	if strm_nil_p(cond_val) {
		is_true = false
	} else if strm_bool_p(cond_val) {
		is_true = strm_value_bool(cond_val)
	}

	// 条件に応じて適切な分岐を評価
	if is_true {
		return exec_expr(strm, state, data.then_, ret)
	} else if data.opt_else != nil {
		return exec_expr(strm, state, data.opt_else, ret)
	}

	// else節がなく条件が偽の場合は nil
	ret^ = strm_nil_value()
	return .Ok
}

// exec_array: 配列リテラルを評価
// [1, 2, 3] または [a: 1, b: 2]（ヘッダー付き構造体風配列）
// スプラット展開（*arr）にも対応
exec_array :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Array)

	// 第1パス: 全要素を評価し、スプラットをチェック
	values: [dynamic]Strm_Value
	defer delete(values)

	has_splat := false

	for elem in data.elements {
		if elem.type == .Splat {
			// スプラット展開: *arr
			has_splat = true
			splat_data := &elem.data.(Node_Splat)
			val: Strm_Value
			result := exec_expr(strm, state, splat_data.expr, &val)
			if result != .Ok {
				return result
			}
			// スプラットの対象は配列でなければならない
			if !strm_array_p(val) {
				if strm != nil {
					strm_raise(strm, "splat requires array")
				}
				return .Error
			}
			// スプラットを展開（配列の要素を個別に追加）
			ary := Strm_Array(val)
			ary_ptr := strm_ary_ptr(ary)
			for i in 0 ..< strm_ary_len(ary) {
				append(&values, ary_ptr[i])
			}
		} else {
			// 通常の要素
			val: Strm_Value
			result := exec_expr(strm, state, elem, &val)
			if result != .Ok {
				return result
			}
			append(&values, val)
		}
	}

	// ヘッダーとスプラットの競合をチェック
	// 構造体風配列とスプラットは互換性がない
	if has_splat && len(data.headers) > 0 {
		if strm != nil {
			strm_raise(strm, "label(s) and splat(s) in an array")
		}
		return .Error
	}

	// 配列を作成
	ary := strm_ary_new(values[:])

	// ヘッダー（フィールド名）を設定
	// 例: [name: "Alice", age: 30]
	if len(data.headers) > 0 {
		header_values := make([]Strm_Value, len(data.headers))
		defer delete(header_values)
		for h, i in data.headers {
			header_values[i] = strm_str_value(strm_str_intern(h))
		}
		headers_ary := strm_ary_new(header_values)
		strm_ary_set_headers(ary, headers_ary)
	}

	// 名前空間（型）を設定
	// 例: Point[x: 1, y: 2]
	if data.ns != "" {
		ns := strm_ns_get(strm_str_intern(data.ns))
		if ns != nil {
			// プリミティブ型はインスタンス化できない
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

// =============================================================================
// 文評価
// =============================================================================
//
// 副作用を持つ文を評価する関数群
// 変数束縛、emit、return、複合文などを処理
//
// =============================================================================

// exec_let: 変数束縛を評価
// let name = expr
// 右辺を評価し、結果を変数に束縛する
exec_let :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Let)

	// 右辺を評価
	val: Strm_Value
	result := exec_expr(strm, state, data.rhs, &val)
	if result != .Ok {
		if strm != nil {
			strm_raise(strm, "failed to assign")
		}
		return result
	}

	// 変数に代入
	// strm_str_intern でシンボル化して効率的な検索を可能に
	name := strm_str_intern(data.lhs)
	strm_var_set(state, name, val)

	// let式の値は代入された値
	ret^ = val
	return .Ok
}

// exec_emit: emit文を評価
// emit value
// フィルター内で下流ストリームに値を送出する
// 配列を渡すと複数の値を個別に送出
exec_emit :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Emit)

	if data.value == nil {
		// 値なしのemit
		if strm != nil {
			strm_emit(strm, strm_nil_value(), nil)
		}
		ret^ = strm_nil_value()
		return .Ok
	}

	// 配列の場合は複数の値を個別に送出
	// emit [1, 2, 3] は emit 1; emit 2; emit 3 と同等
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

	// 単一値のemit
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

// exec_return: return文を評価
// return value
// 関数から早期リターンする
// 複数値を返す場合は配列として返される
exec_return :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Return)

	if data.value == nil {
		// 値なしのreturn
		ret^ = strm_nil_value()
	} else if data.value.type == .Array {
		// 複数の戻り値 → 配列として返す
		arr := &data.value.data.(Node_Array)
		if len(arr.elements) == 0 {
			ret^ = strm_nil_value()
		} else if len(arr.elements) == 1 {
			// 単一要素の場合はアンラップ
			result := exec_expr(strm, state, arr.elements[0], ret)
			if result != .Ok {
				return result
			}
		} else {
			// 複数要素の場合は配列を作成
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
		// 単一値のreturn
		result := exec_expr(strm, state, data.value, ret)
		if result != .Ok {
			return result
		}
	}

	// return例外を設定
	// 呼び出し元でキャッチして処理される
	if strm != nil {
		strm_set_exc(strm, .Return, ret^)
	}

	return .Return
}

// exec_nodes: ノードリスト（複合文）を評価
// { stmt1; stmt2; ... }
// 各文を順次評価し、最後の文の値を返す
exec_nodes :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Nodes)

	last_val := strm_nil_value()
	for n in data.nodes {
		result := exec_expr(strm, state, n, &last_val)
		if result != .Ok {
			// エラー発生位置を設定（デバッグ用）
			if strm != nil && strm.exc != nil {
				strm.exc.fname = n.fname
				strm.exc.lineno = n.lineno
			}
			ret^ = last_val
			return result
		}
	}

	// 複合文の値は最後の式の値
	ret^ = last_val
	return .Ok
}

// ============================================================================
// 関数処理 (Function handling)
// ============================================================================
// ラムダ式（クロージャ）、関数呼び出し、ジェネリック関数の評価を行う。
// Streemでは関数は第一級オブジェクトとして扱われ、変数に代入したり
// パイプラインを通じて受け渡すことができる。

// ----------------------------------------------------------------------------
// exec_lambda - ラムダ式（クロージャ）の評価
// ----------------------------------------------------------------------------
// ラムダ式ノードを評価し、クロージャ値を生成する。
// Streemのラムダ式は `{|args| body}` 形式で記述される。
//
// 引数:
//   strm  - 実行中のストリーム（nil可）
//   state - 現在のスコープ（クロージャの親環境となる）
//   node  - ラムダ式ノード（.Lambda または .PLambda）
//   ret   - 結果値の格納先
//
// 戻り値:
//   .Ok    - 成功
//   .Error - 失敗
//
// 例:
//   {|x| x * 2}           # 引数xを2倍にするラムダ
//   {|x, y| x + y}        # 2引数ラムダ
//   { puts("hello") }     # 引数なしブロック（即座に実行）
exec_lambda :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	// パターンマッチングラムダ（PLambda）は別途処理
	// PLambdaは複数のパターンを持ち、引数に応じて異なる処理を行う
	if node.type == .PLambda {
		// パターンマッチング用クロージャを生成
		lambda := strm_lambda_new(node, state)
		ret^ = strm_ptr_value(lambda)
		return .Ok
	}

	data := &node.data.(Node_Lambda)

	// 引数なしブロックの場合は即座に実行
	// if文やwhile文のボディなど、制御構造のブロックに対応
	// 例: if (cond) { stmts } のブロック部分
	if data.is_block && data.args == nil {
		// 現在のスコープでボディを直接実行
		if data.body != nil {
			return exec_expr(strm, state, data.body, ret)
		}
		ret^ = strm_nil_value()
		return .Ok
	}

	// 引数を持つラムダまたは非ブロックの場合はクロージャ値を生成
	// クロージャは現在のスコープ（state）を親環境として捕捉する
	lambda := strm_lambda_new(node, state)
	ret^ = strm_ptr_value(lambda)
	return .Ok
}

// ----------------------------------------------------------------------------
// exec_call - 名前による関数呼び出しの評価
// ----------------------------------------------------------------------------
// 関数名を指定した呼び出しを評価する。
// 名前空間のメソッド検索を経て、適切な関数を呼び出す。
//
// 引数:
//   strm  - 実行中のストリーム（nil可）
//   state - 現在のスコープ
//   node  - 関数呼び出しノード（.Call）
//   ret   - 結果値の格納先
//
// 戻り値:
//   .Ok    - 成功
//   .Error - 失敗
//
// 例:
//   puts("hello")          # 名前付き関数呼び出し
//   map({|x| x * 2})       # ラムダを引数とする呼び出し
//   sum(*args)             # splat展開を含む呼び出し
exec_call :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Call)

	// 引数を評価して収集
	args: [dynamic]Strm_Value
	defer delete(args)

	has_splat := false  // splat演算子（*）の有無

	if data.args != nil && data.args.type == .Array {
		arr := &data.args.data.(Node_Array)

		// splat演算子の存在をチェック
		// splat: 配列を展開して個別の引数として渡す（例: func(*ary)）
		for elem in arr.elements {
			if elem.type == .Splat {
				has_splat = true
				break
			}
		}

		if has_splat {
			// splat有り: 配列全体を評価してから展開
			// 配列式として評価し、結果を個別の引数に分解
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
			// splat無し: 各引数を順次評価
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

	// 関数名を内部化して呼び出しをディスパッチ
	name := strm_str_intern(data.name)
	return exec_call_internal(strm, state, name, args[:], ret)
}

// ----------------------------------------------------------------------------
// exec_fcall - 関数式による呼び出しの評価
// ----------------------------------------------------------------------------
// 関数式（変数、配列要素など）を評価し、その結果を関数として呼び出す。
// exec_callとの違い: 関数名ではなく式を評価して関数値を取得する点。
//
// 引数:
//   strm  - 実行中のストリーム（nil可）
//   state - 現在のスコープ
//   node  - 関数呼び出しノード（.Fcall）
//   ret   - 結果値の格納先
//
// 戻り値:
//   .Ok    - 成功
//   .Error - 失敗
//
// 例:
//   f(1, 2)                # 変数fが関数を保持している場合
//   callbacks[0]("arg")    # 配列から取得した関数の呼び出し
//   (get_func())(args)     # 関数を返す関数の結果を呼び出し
exec_fcall :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Fcall)

	// 関数式を評価して関数値を取得
	func_val: Strm_Value
	result := exec_expr(strm, state, data.func_, &func_val)
	if result != .Ok {
		return result
	}

	// 引数を評価して収集
	args: [dynamic]Strm_Value
	defer delete(args)

	has_splat := false  // splat演算子の有無

	if data.args != nil && data.args.type == .Array {
		arr := &data.args.data.(Node_Array)

		// splat演算子の存在をチェック
		for elem in arr.elements {
			if elem.type == .Splat {
				has_splat = true
				break
			}
		}

		if has_splat {
			// splat有り: 配列全体を評価してから展開
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
			// splat無し: 各引数を順次評価
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

	// 関数値の型に応じてディスパッチ
	return strm_funcall(strm, state, func_val, args[:], ret)
}

// ----------------------------------------------------------------------------
// exec_genfunc - ジェネリック関数参照の評価
// ----------------------------------------------------------------------------
// ジェネリック関数（名前空間を跨いで多態的に振る舞う関数）の参照を生成する。
// ジェネリック関数は呼び出し時に第一引数の型に応じて適切な実装を選択する。
//
// 引数:
//   state - 現在のスコープ（関数の定義元となる）
//   node  - ジェネリック関数ノード（.Genfunc）
//   ret   - 結果値の格納先
//
// 戻り値:
//   .Ok    - 成功
//   .Error - 失敗
//
// 例:
//   &length     # 配列/文字列の長さを取得するジェネリック関数参照
exec_genfunc :: proc(state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Genfunc)

	// ジェネリック関数参照を生成
	// idは関数名、stateは検索開始点として使用される
	id := strm_str_intern(data.name)
	gf := strm_genfunc_new(state, id)
	ret^ = strm_ptr_value(gf)
	return .Ok
}

// ============================================================================
// 内部関数呼び出しヘルパー (Internal function call helper)
// ============================================================================
// 名前空間のメソッド検索と関数呼び出しの内部実装。
// 多態的なメソッドディスパッチを実現するための中核機能。

// ----------------------------------------------------------------------------
// exec_call_internal - 名前空間を考慮した関数呼び出し
// ----------------------------------------------------------------------------
// 関数名と引数から適切な関数を検索し呼び出す。
// 検索順序:
//   1. 第一引数の名前空間内のメソッド（メソッド呼び出しの実現）
//   2. 配列のフィールドアクセス（構造体的な使い方）
//   3. 現在のスコープ内の変数
//
// この検索順序により、オブジェクト指向的なメソッド呼び出しが可能になる。
// 例: length([1, 2, 3]) → Array名前空間のlengthメソッドが呼ばれる
//
// 引数:
//   strm  - 実行中のストリーム（エラー報告用、nil可）
//   state - 現在のスコープ
//   name  - 関数名（内部化済み文字列）
//   args  - 引数の配列
//   ret   - 結果値の格納先
//
// 戻り値:
//   .Ok    - 成功
//   .Error - 関数が見つからない場合
exec_call_internal :: proc(strm: ^Strm_Stream, state: ^Strm_State, name: Strm_String, args: []Strm_Value, ret: ^Strm_Value) -> Exec_Result {
	// 第一引数の名前空間でメソッドを検索（オブジェクト指向的ディスパッチ）
	// 例: length(str) → String名前空間のlengthを呼び出し
	if len(args) > 0 {
		ns := strm_value_ns(args[0])
		if ns != nil {
			m, found := strm_var_get(ns, name)
			if found {
				return strm_funcall(strm, state, m, args, ret)
			}

			// 配列の場合、フィールド名によるアクセスを試行
			// 例: person.name → headers付き配列のフィールドアクセス
			if strm_array_p(args[0]) {
				ary := Strm_Array(args[0])
				result, ok := ary_get(strm, ary, len(args) - 1, args[1:], name, ret)
				if ok {
					return result
				}
			}
		}
	}

	// 現在のスコープで関数を検索
	m, found := strm_var_get(state, name)
	if found {
		return strm_funcall(strm, state, m, args, ret)
	}

	// 関数が見つからない場合はエラー
	if strm != nil {
		strm_raise(strm, "function not found")
	}
	return .Error
}

// ============================================================================
// 配列アクセスヘルパー (Array access helper)
// ============================================================================
// 配列要素へのアクセス（インデックス、フィールド名）を処理する。
// Streemでは配列はheadersを持つことができ、構造体的に使用できる。

// ----------------------------------------------------------------------------
// ary_get - 配列要素の取得
// ----------------------------------------------------------------------------
// インデックスまたはフィールド名で配列要素を取得する。
//
// 引数:
//   strm - 実行中のストリーム（nil可）
//   ary  - 対象の配列
//   argc - 追加引数の数
//   argv - 追加引数（インデックスなど）
//   name - フィールド名（フィールドアクセスの場合）
//   ret  - 結果値の格納先
//
// 戻り値:
//   (Exec_Result, bool) - 結果と成功フラグ
//   成功時: (.Ok, true)
//   失敗時: (.Error, false)
//
// アクセスパターン:
//   1. フィールドアクセス: name指定、argc=0 → headers照合
//   2. インデックスアクセス: 数値引数、argc=1 → 位置指定
//   3. キーアクセス: 文字列引数、argc=1 → headers照合
//
// 例:
//   person.name      → フィールドアクセス
//   arr[0]           → インデックスアクセス
//   arr["name"]      → キーアクセス
ary_get :: proc(strm: ^Strm_Stream, ary: Strm_Array, argc: int, argv: []Strm_Value, name: Strm_String, ret: ^Strm_Value) -> (Exec_Result, bool) {
	// フィールド名によるアクセス（person.nameのような形式）
	if argc == 0 && u64(name) != 0 {
		headers := strm_ary_headers(ary)
		if u64(headers) != 0 {
			headers_ptr := strm_ary_ptr(headers)
			ary_ptr := strm_ary_ptr(ary)
			// headersから一致するフィールド名を検索
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

	// インデックスまたはキーによるアクセス（arr[0]やarr["key"]の形式）
	if argc == 1 && u64(name) == 0 {
		idx := argv[0]
		if strm_number_p(idx) {
			// 数値インデックスによるアクセス
			i := strm_value_int(idx)
			val, ok := strm_ary_get(ary, i)
			if ok {
				ret^ = val
				return .Ok, true
			}
		} else if strm_string_p(idx) {
			// 文字列キーによるアクセス（構造体的配列）
			headers := strm_ary_headers(ary)
			if u64(headers) != 0 {
				headers_ptr := strm_ary_ptr(headers)
				ary_ptr := strm_ary_ptr(ary)
				// headersから一致するキーを検索
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
// 関数呼び出しディスパッチ (Function call dispatch)
// ============================================================================
// 関数値の型に応じて適切な呼び出し方法を選択する。
// C関数、ラムダ、ジェネリック関数、配列アクセスに対応。

// ----------------------------------------------------------------------------
// strm_funcall - 関数値の呼び出し
// ----------------------------------------------------------------------------
// 関数値の型を判別し、適切な方法で呼び出す。
// 対応する関数型:
//   - Cfunc: C言語で実装された組み込み関数
//   - Array: 配列のインデックスアクセス（関数的呼び出し）
//   - Lambda: ユーザー定義クロージャ
//   - Genfunc: ジェネリック関数参照
//
// 引数:
//   strm     - 実行中のストリーム（エラー報告用、nil可）
//   state    - 現在のスコープ
//   func_val - 関数値
//   args     - 引数の配列
//   ret      - 結果値の格納先
//
// 戻り値:
//   .Ok    - 成功
//   .Error - 失敗（関数でない値、または実行エラー）
strm_funcall :: proc(strm: ^Strm_Stream, state: ^Strm_State, func_val: Strm_Value, args: []Strm_Value, ret: ^Strm_Value) -> Exec_Result {
	// C関数（組み込み関数）の呼び出し
	if strm_cfunc_p(func_val) {
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

	// 配列の関数的アクセス: arr(0) は arr[0] と同等
	if strm_array_p(func_val) {
		ary := Strm_Array(func_val)
		result, ok := ary_get(strm, ary, len(args), args, STRM_STR_NULL, ret)
		if ok {
			return result
		}
		return .Error
	}

	// ポインタ型の関数値（Lambda, Genfunc）
	tag := strm_value_tag(func_val)
	if tag == .Ptr {
		ptr := strm_value_rawptr(func_val)
		if ptr != nil {
			// ポインタの先頭にある型タグで種別を判定
			ptr_type := (cast(^Ptr_Type)ptr)^
			#partial switch ptr_type {
			case .Lambda:
				// ラムダ（クロージャ）の呼び出し
				lambda := cast(^Strm_Lambda)ptr
				return lambda_call(strm, lambda.state, lambda.body, args, ret)
			case .Genfunc:
				// ジェネリック関数の呼び出し
				// 登録されたスコープから名前で関数を検索
				gf := cast(^Strm_Genfunc)ptr
				return exec_call_internal(strm, gf.state, gf.id, args, ret)
			}
		}
	}

	// 関数として呼び出せない値
	if strm != nil {
		strm_raise(strm, "not a function")
	}
	return .Error
}

// ============================================================================
// ラムダ呼び出し (Lambda call)
// ============================================================================
// クロージャの実行処理。引数のバインドとボディの評価を行う。

// ----------------------------------------------------------------------------
// lambda_call - ラムダ（クロージャ）の実行
// ----------------------------------------------------------------------------
// ラムダのボディを、引数をバインドした新しいスコープで実行する。
// クロージャの親環境（closure_state）がレキシカルスコープを提供する。
//
// 実行フロー:
//   1. クロージャの親環境を継承した新しいローカルスコープを作成
//   2. 仮引数に実引数をバインド
//   3. ボディを評価
//   4. return文があればその値を返す
//
// 引数:
//   strm          - 実行中のストリーム（エラー報告用、nil可）
//   closure_state - クロージャの親環境（レキシカルスコープ）
//   lambda_node   - ラムダ式のASTノード
//   args          - 実引数の配列
//   ret           - 結果値の格納先
//
// 戻り値:
//   .Ok     - 成功
//   .Error  - 失敗（引数の数が一致しない等）
//   .Return - return文による早期脱出（呼び出し元で処理）
lambda_call :: proc(strm: ^Strm_Stream, closure_state: ^Strm_State, lambda_node: ^Node, args: []Strm_Value, ret: ^Strm_Value) -> Exec_Result {
	if lambda_node == nil {
		return .Error
	}

	// クロージャの親環境を継承した新しいローカルスコープを作成
	// これによりレキシカルスコープが実現される
	local := strm_state_new(closure_state)
	defer strm_state_destroy(local)

	if lambda_node.type == .Lambda {
		data := &lambda_node.data.(Node_Lambda)

		// 引数のバインド処理
		if data.args != nil {
			if data.args.type == .Args {
				// 複数引数: {|x, y, z| body}
				arg_names := &data.args.data.(Node_Args)
				// 引数の数をチェック
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
				// 各引数を名前にバインド
				for i := 0; i < len(arg_names.names); i += 1 {
					name := strm_str_intern(arg_names.names[i])
					strm_var_set(local, name, args[i])
				}
			} else if data.args.type == .Ident {
				// 単一引数: {|x| body} の省略形
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
			// 引数なしラムダに引数が渡された場合はエラー
			if strm != nil {
				strm_raise(strm, "wrong number of arguments")
			}
			return .Error
		}

		// ボディを評価
		result := exec_expr(strm, local, data.body, ret)

		// return文の処理
		// return文は例外として伝播するため、ここでキャッチして正常終了に変換
		if result == .Return && strm != nil && strm.exc != nil {
			if strm.exc.type == .Return {
				ret^ = strm.exc.arg
				strm_clear_exc(strm)
				return .Ok
			}
		}

		return result
	}

	// パターンマッチングラムダの場合は専用処理へ
	if lambda_node.type == .PLambda {
		return plambda_call(strm, local, lambda_node, args, ret)
	}

	ret^ = strm_nil_value()
	return .Error
}

// ----------------------------------------------------------------------------
// plambda_call - パターンマッチングラムダの実行
// ----------------------------------------------------------------------------
// 複数のパターン節を持つラムダを実行する。
// 引数に対して各パターンを順に試行し、マッチしたパターンのボディを実行。
// Erlangの関数節やOCamlのmatch式に類似した機能。
//
// パターン節の構造:
//   pattern [if condition] -> body
//
// 実行フロー:
//   1. 各パターン節を順に評価
//   2. パターンがマッチし、条件（あれば）が真なら、ボディを実行
//   3. マッチしなければ次の節を試行
//   4. どの節もマッチしなければ「match failure」エラー
//
// 引数:
//   strm         - 実行中のストリーム（エラー報告用、nil可）
//   state        - ローカルスコープ（パターン変数がバインドされる）
//   plambda_node - パターンラムダのASTノード
//   args         - 実引数の配列
//   ret          - 結果値の格納先
//
// 戻り値:
//   .Ok    - 成功（パターンがマッチし、ボディを実行）
//   .Error - 失敗（マッチするパターンなし）
//
// 例:
//   {|0| "zero" |n if n > 0| "positive" |_| "negative"}
plambda_call :: proc(strm: ^Strm_Stream, state: ^Strm_State, plambda_node: ^Node, args: []Strm_Value, ret: ^Strm_Value) -> Exec_Result {
	plmbd := plambda_node
	nexec := 0  // 実行されたパターン節の数

	// 各パターン節を順に試行
	for plmbd != nil && plmbd.type == .PLambda {
		data := &plmbd.data.(Node_PLambda)

		// 各パターン試行の前に環境をクリア
		// これにより前のパターンでバインドされた変数が残らない
		clear(&state.env)

		// パターンマッチングを試行
		if pattern_match(strm, state, data.pat, len(args), args) {
			// ガード条件があれば評価
			if data.cond != nil {
				cond: Strm_Value
				result := exec_expr(strm, state, data.cond, &cond)
				if result == .Ok && strm_value_bool(cond) {
					// ガード条件も満たした：ボディを実行
					nexec += 1
					result = exec_expr(strm, state, data.body, ret)

					// return文の処理
					if result == .Return && strm != nil && strm.exc != nil && strm.exc.type == .Return {
						ret^ = strm.exc.arg
						strm_clear_exc(strm)
						return .Ok
					}
					return result
				}
				// ガード条件が偽：次のパターンを試行
			} else {
				// ガード条件なし：パターンマッチのみでボディを実行
				nexec += 1
				result := exec_expr(strm, state, data.body, ret)

				// return文の処理
				if result == .Return && strm != nil && strm.exc != nil && strm.exc.type == .Return {
					ret^ = strm.exc.arg
					strm_clear_exc(strm)
					return .Ok
				}
				return result
			}
		}

		// 次のパターン節へ
		plmbd = data.next_
	}

	// どのパターンもマッチしなかった場合
	if nexec == 0 {
		if strm != nil {
			strm_raise(strm, "match failure")
		}
		return .Error
	}

	return .Ok
}

// ============================================================================
// パターンマッチング (Pattern matching)
// ============================================================================
// 値とパターンの照合を行う。
// パターンマッチングは関数型プログラミングの中核機能の一つであり、
// 値の分解と条件分岐を簡潔に記述できる。
//
// サポートするパターン:
//   - 識別子: 変数へのバインド（_はプレースホルダー）
//   - リテラル: 数値、文字列、真偽値、nilとの一致
//   - 名前空間: 型チェック付きパターン
//   - 配列: 要素ごとのパターンマッチ
//   - スプラット: 残り要素の収集
//   - 構造体: フィールド名によるマッチ

// ----------------------------------------------------------------------------
// pattern_placeholder_p - プレースホルダーチェック
// ----------------------------------------------------------------------------
// 識別子がプレースホルダー（_）かどうかを判定する。
// プレースホルダーは任意の値にマッチし、バインドを行わない。
pattern_placeholder_p :: proc(name: string) -> bool {
	return name == "_"
}

// ----------------------------------------------------------------------------
// pmatch - 単一値のパターンマッチング
// ----------------------------------------------------------------------------
// パターンと値を照合し、変数のバインドを行う。
//
// 引数:
//   strm  - 実行中のストリーム（nil可）
//   state - スコープ（変数バインド先）
//   pat   - パターンノード
//   val   - マッチ対象の値
//
// 戻り値:
//   true  - マッチ成功
//   false - マッチ失敗
pmatch :: proc(strm: ^Strm_Stream, state: ^Strm_State, pat: ^Node, val: Strm_Value) -> bool {
	if pat == nil {
		return true
	}

	#partial switch pat.type {
	case .Ident:
		// 識別子パターン: 変数バインドまたはプレースホルダー
		data := &pat.data.(Node_Ident)
		if pattern_placeholder_p(data.name) {
			return true // プレースホルダーは任意の値にマッチ
		}
		// 変数にバインド（既存の同名変数との一致チェックを含む）
		name := strm_str_intern(data.name)
		return strm_var_match(state, name, val) == STRM_OK

	case .Str:
		// 文字列リテラルパターン: 完全一致
		if strm_string_p(val) {
			data := &pat.data.(Node_Str)
			pat_str := strm_str_new(data.value)
			return strm_str_eq(Strm_String(val), pat_str)
		}
		return false

	case .Int:
		// 整数リテラルパターン: 数値一致（浮動小数点も対応）
		data := &pat.data.(Node_Int)
		if strm_int_p(val) {
			return i64(strm_value_int(val)) == data.value
		}
		if strm_float_p(val) {
			return strm_value_float(val) == f64(data.value)
		}
		return false

	case .Float:
		// 浮動小数点リテラルパターン
		data := &pat.data.(Node_Float)
		if strm_number_p(val) {
			return strm_value_float(val) == data.value
		}
		return false

	case .Nil:
		// nilパターン
		return strm_nil_p(val)

	case .Bool:
		// 真偽値リテラルパターン
		data := &pat.data.(Node_Bool)
		if strm_bool_p(val) {
			return strm_value_bool(val) == data.value
		}
		return false

	case .Ns:
		// 名前空間パターン: 型チェック付きマッチ
		// 例: Array::[x, y] → 配列であることを確認してからパターンマッチ
		data := &pat.data.(Node_Ns)
		ns_name := strm_str_intern(data.name)
		s1 := strm_ns_get(ns_name)
		s2 := strm_value_ns(val)
		if s1 != s2 {
			return false
		}
		// 内部パターンとの再帰的マッチ
		return pmatch(strm, state, data.body, val)

	case .PArray:
		// 配列パターン: 要素ごとのマッチ
		if strm_array_p(val) {
			ary := Strm_Array(val)
			return pattern_match(strm, state, pat, int(strm_ary_len(ary)), strm_ary_slice(ary))
		}
		return false

	case .PSplat:
		// スプラットパターン: 残り要素の収集
		if strm_array_p(val) {
			ary := Strm_Array(val)
			return pattern_match(strm, state, pat, int(strm_ary_len(ary)), strm_ary_slice(ary))
		}
		return false

	case .PStruct:
		// 構造体パターン: フィールド名によるマッチ
		if !strm_array_p(val) {
			return false
		}
		return pmatch_struct(strm, state, pat, val)

	case:
		return false
	}
}

// ----------------------------------------------------------------------------
// pmatch_struct - 構造体パターンのマッチング
// ----------------------------------------------------------------------------
// 構造体（ヘッダー付き配列）に対するパターンマッチを行う。
// フィールド名をキーとしてパターンを照合する。
//
// 引数:
//   strm  - 実行中のストリーム（nil可）
//   state - スコープ（変数バインド先）
//   pat   - 構造体パターンノード
//   val   - マッチ対象の値（ヘッダー付き配列）
//
// 戻り値:
//   true  - マッチ成功
//   false - マッチ失敗
//
// 例:
//   {name: n, age: a}   → 構造体からnameとageを抽出
pmatch_struct :: proc(strm: ^Strm_Stream, state: ^Strm_State, pat: ^Node, val: Strm_Value) -> bool {
	pstruct := &pat.data.(Node_PStruct)
	ary := Strm_Array(val)

	// 構造体パターンにはヘッダーが必要
	headers := strm_ary_headers(ary)
	if u64(headers) == 0 {
		return false
	}

	// パターンのフィールド数が配列の要素数を超えないことを確認
	if i32(len(pstruct.patterns)) > strm_ary_len(ary) {
		return false
	}

	headers_ptr := strm_ary_ptr(headers)
	ary_ptr := strm_ary_ptr(ary)

	// 各フィールドパターンについて照合
	for p in pstruct.patterns {
		if p.type != .Pair {
			continue
		}
		pair := &p.data.(Node_Pair)
		key := strm_str_intern(pair.key)

		// ヘッダーからフィールドを検索
		found := false
		for j in 0 ..< strm_ary_len(headers) {
			h := headers_ptr[j]
			if strm_string_p(h) && strm_str_eq(Strm_String(h), key) {
				// フィールドが見つかった：値パターンと照合
				if !pmatch(strm, state, pair.value, ary_ptr[j]) {
					return false
				}
				found = true
				break
			}
		}
		// 指定されたフィールドが見つからなければ失敗
		if !found {
			return false
		}
	}

	return true
}

// ----------------------------------------------------------------------------
// pattern_match - 引数配列のパターンマッチング
// ----------------------------------------------------------------------------
// 複数の引数に対するパターンマッチを行う。
// 配列パターン（PArray）とスプラットパターン（PSplat）を処理。
//
// 引数:
//   strm  - 実行中のストリーム（nil可）
//   state - スコープ（変数バインド先）
//   npat  - パターンノード
//   argc  - 引数の数
//   argv  - 引数の配列
//
// 戻り値:
//   true  - マッチ成功
//   false - マッチ失敗
//
// スプラットパターンの例:
//   [head, *rest]        → 先頭要素と残りを分離
//   [first, *mid, last]  → 先頭と末尾を分離、中間を収集
//   [a, b, *_]           → 先頭2要素を取得、残りは無視
pattern_match :: proc(strm: ^Strm_Stream, state: ^Strm_State, npat: ^Node, argc: int, argv: []Strm_Value) -> bool {
	if npat == nil {
		return true // デフォルトケース（else節）
	}

	// PSplatパターン: 頭部、中間（残り）、尾部に分割
	// 例: [a, *rest, z] → head=[a], mid=rest, tail=[z]
	if npat.type == .PSplat {
		psp := &npat.data.(Node_PSplat)

		// 頭部パターンの長さを取得
		head_len := 0
		if psp.head != nil && psp.head.type == .PArray {
			head_data := &psp.head.data.(Node_PArray)
			head_len = len(head_data.patterns)
		}

		// 尾部パターンの長さを取得
		tail_len := 0
		if psp.tail != nil && psp.tail.type == .PArray {
			tail_data := &psp.tail.data.(Node_PArray)
			tail_len = len(tail_data.patterns)
		}

		// 引数の数が頭部+尾部より少なければ失敗
		if argc < head_len + tail_len {
			return false
		}

		// 頭部のマッチング
		if psp.head != nil {
			if !pattern_match(strm, state, psp.head, head_len, argv[:head_len]) {
				return false
			}
		}

		// 中間部（残り要素）のマッチング
		rest_start := head_len
		rest_end := argc - tail_len
		rest_values := argv[rest_start:rest_end]
		rest_ary := strm_ary_new(rest_values)

		if !pmatch(strm, state, psp.mid, strm_ary_value(rest_ary)) {
			return false
		}

		// 尾部のマッチング
		if psp.tail != nil {
			if !pattern_match(strm, state, psp.tail, tail_len, argv[argc - tail_len:]) {
				return false
			}
		}

		return true
	}

	// PArrayパターン: 要素ごとのマッチ（スプラット含む可能性あり）
	if npat.type == .PArray {
		parray := &npat.data.(Node_PArray)

		// パターン内のスプラット位置を検索
		splat_idx := -1
		for i := 0; i < len(parray.patterns); i += 1 {
			if parray.patterns[i] != nil && parray.patterns[i].type == .Splat {
				splat_idx = i
				break
			}
		}

		if splat_idx >= 0 {
			// スプラット有り: 可変長マッチ
			head_len := splat_idx                              // スプラット前の要素数
			tail_len := len(parray.patterns) - splat_idx - 1   // スプラット後の要素数

			// 最低限必要な引数数をチェック
			if argc < head_len + tail_len {
				return false
			}

			// 頭部パターンのマッチング
			for i := 0; i < head_len; i += 1 {
				if !pmatch(strm, state, parray.patterns[i], argv[i]) {
					return false
				}
			}

			// スプラット部分（残り要素を配列として収集）のマッチング
			rest_start := head_len
			rest_end := argc - tail_len
			rest_values := argv[rest_start:rest_end]
			rest_ary := strm_ary_new(rest_values)
			splat_node := parray.patterns[splat_idx]
			splat_data := &splat_node.data.(Node_Splat)
			if !pmatch(strm, state, splat_data.expr, strm_ary_value(rest_ary)) {
				return false
			}

			// 尾部パターンのマッチング
			for i := 0; i < tail_len; i += 1 {
				if !pmatch(strm, state, parray.patterns[splat_idx + 1 + i], argv[argc - tail_len + i]) {
					return false
				}
			}

			return true
		} else {
			// スプラット無し: 固定長マッチ（要素数が一致する必要あり）
			if len(parray.patterns) != argc {
				return false
			}
			// 各要素を順にマッチング
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
// 名前空間/インポート評価 (Namespace/Import evaluation)
// ============================================================================
// 名前空間の定義とインポートを処理する。
// 名前空間はモジュールシステムの基盤となり、コードの構造化と
// 名前の衝突回避を実現する。

// ----------------------------------------------------------------------------
// exec_ns - 名前空間定義の評価
// ----------------------------------------------------------------------------
// 新しい名前空間を作成し、その中でボディを評価する。
//
// 引数:
//   strm  - 実行中のストリーム（エラー報告用、nil可）
//   state - 親スコープ
//   node  - 名前空間定義ノード（.Ns）
//   ret   - 結果値の格納先
//
// 戻り値:
//   .Ok    - 成功
//   .Error - 失敗（名前空間が既に存在する等）
//
// 例:
//   namespace MyModule {
//     def hello() { puts("Hello") }
//   }
exec_ns :: proc(strm: ^Strm_Stream, state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Ns)

	// 名前空間を作成
	name := strm_str_intern(data.name)
	ns := strm_ns_create(state, name)

	if ns == nil {
		// 作成失敗：既存の名前空間との衝突をチェック
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

	// ユーザー定義名前空間フラグを設定
	// これにより組み込み名前空間と区別される
	ns.flags += {.Udef}

	// 名前空間のスコープ内でボディを評価
	// ボディ内で定義された変数・関数は名前空間に属する
	if data.body != nil {
		result := exec_expr(strm, ns, data.body, ret)
		if result != .Ok {
			return result
		}
	}

	ret^ = strm_nil_value()
	return .Ok
}

// ----------------------------------------------------------------------------
// exec_import - インポート文の評価
// ----------------------------------------------------------------------------
// 指定された名前空間の内容を現在のスコープにインポートする。
// インポートにより、名前空間接頭辞なしで関数や変数を使用できる。
//
// 引数:
//   state - 現在のスコープ（インポート先）
//   node  - インポートノード（.Import）
//   ret   - 結果値の格納先
//
// 戻り値:
//   .Ok    - 成功
//   .Error - 失敗（名前空間が見つからない）
//
// 例:
//   import MyModule   # MyModule内の定義を現在のスコープで使用可能に
exec_import :: proc(state: ^Strm_State, node: ^Node, ret: ^Strm_Value) -> Exec_Result {
	data := &node.data.(Node_Import)

	// 名前空間を検索
	name := strm_str_intern(data.name)
	ns := strm_ns_get(name)
	if ns == nil {
		ret^ = strm_nil_value()
		return .Error
	}

	// 名前空間の全バインディングを現在のスコープにコピー
	result := strm_env_copy(state, ns)
	if result != STRM_OK {
		return .Error
	}

	ret^ = strm_nil_value()
	return .Ok
}
