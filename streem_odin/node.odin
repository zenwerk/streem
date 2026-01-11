package streem

// ============================================================================
// AST（抽象構文木）ノード定義 (AST Node Definitions)
// ============================================================================
// Streem言語のパーサーが生成する抽象構文木のノード構造を定義する。
// 各ノードはソースコードの構文要素を表現し、インタプリタがこれを評価する。
//
// 参照: src/node.h
//
// ASTの概要:
//   パーサーがソースコードを解析し、AST（抽象構文木）を構築する。
//   インタプリタ（exec.odin）がこのASTを走査して実行する。
//
// ノードカテゴリ:
//   - リテラル: Int, Float, Str, Bool, Nil, Time
//   - コレクション: Array, Nodes, Args, Pair
//   - 式: Ident, Op, If, Lambda, Call, Fcall, Genfunc
//   - 文: Let, Emit, Skip, Return
//   - トップレベル: Ns, Import
//   - パターンマッチング: PArray, PStruct, PSplat, PLambda
//
// 例（Streemコード → AST）:
//   x = 1 + 2
//   → Let { lhs: "x", rhs: Op { op: "+", lhs: Int(1), rhs: Int(2) } }

import "core:strings"

// ============================================================================
// ノード型列挙 (Node Type Enumeration)
// ============================================================================

// Node_Type - ASTノードの種類を示す列挙型
// 各ノードはこの型でタグ付けされ、データ共用体の解釈方法を決定する。
Node_Type :: enum {
	// --- リテラル (Literals) ---
	Int,   // 整数リテラル: 42, -100
	Float, // 浮動小数点リテラル: 3.14, 1e-10
	Time,  // 時刻リテラル
	Str,   // 文字列リテラル: "hello", 'world'
	Nil,   // nil値
	Bool,  // 真偽値リテラル: true, false

	// --- コレクションと引数 (Collections and Arguments) ---
	Args,  // 関数の仮引数名リスト: |x, y, z|
	Pair,  // キー:値ペア（ラベル付き引数用）: name: "Alice"
	Array, // 配列リテラル（オプションでheaders付き）: [1, 2, 3]
	Nodes, // 文/式のリスト（複合文）

	// --- スプラット (Splat) ---
	Splat, // スプラット式: *expr （配列展開）

	// --- 式 (Expressions) ---
	Ident,   // 識別子参照: x, foo
	Op,      // 二項/単項演算: +, -, *, /, |, ==, etc.
	If,      // 条件式: if (cond) then else
	Lambda,  // ラムダ/関数定義: {|x| x * 2}
	Call,    // 関数呼び出し（名前指定）: func(args)
	Fcall,   // 間接関数呼び出し: func_expr(args)
	Genfunc, // ジェネリック関数参照: &fname

	// --- 文 (Statements) ---
	Let,    // 変数束縛: x = expr
	Emit,   // emit文（ストリームへの送出）: emit value
	Skip,   // skip文（次の入力へスキップ）
	Return, // return文: return value

	// --- トップレベル (Top-level) ---
	Ns,     // 名前空間/クラス定義: namespace Name { ... }
	Import, // import文: import ModuleName

	// --- パターンマッチング (Pattern Matching) ---
	PArray,  // パターン配列: [a, b, c]
	PStruct, // パターン構造体: {name: n, age: a}
	PSplat,  // スプラット付きパターン: [head, *mid, tail]
	PLambda, // パターンラムダ（case節）: |pattern| body
}

// ============================================================================
// 位置情報 (Position Information)
// ============================================================================

// Node_Pos - ソースコード上の位置情報
// エラー報告時に使用される。
Node_Pos :: struct {
	fname:  string, // ファイル名（またはREPL等の識別子）
	lineno: int,    // 行番号
}

// ============================================================================
// ノード構造体 (Node Structure)
// ============================================================================

// Node - ASTノードの基本構造体
// 全てのノード型はこの構造体で表現される。
// typeフィールドでノードの種類を判別し、dataフィールドから具体的なデータを取得する。
Node :: struct {
	type:      Node_Type, // ノードの種類
	using pos: Node_Pos,  // 位置情報（usingで直接アクセス可能）
	data:      Node_Data, // ノード固有のデータ（共用体）
}

// Node_Data - ノードデータの共用体
// ノードの種類に応じて異なるデータ構造を保持する。
// Odinの共用体により型安全なアクセスが可能。
Node_Data :: union {
	Node_Int,     // 整数
	Node_Float,   // 浮動小数点
	Node_Time,    // 時刻
	Node_Str,     // 文字列
	Node_Bool,    // 真偽値
	Node_Args,    // 引数リスト
	Node_Pair,    // ペア
	Node_Array,   // 配列
	Node_Nodes,   // ノードリスト
	Node_Splat,   // スプラット
	Node_Ident,   // 識別子
	Node_Op,      // 演算
	Node_If,      // 条件
	Node_Lambda,  // ラムダ
	Node_Call,    // 関数呼び出し
	Node_Fcall,   // 間接呼び出し
	Node_Genfunc, // ジェネリック関数
	Node_Let,     // 変数束縛
	Node_Emit,    // emit
	Node_Return,  // return
	Node_Ns,      // 名前空間
	Node_Import,  // import
	Node_PArray,  // パターン配列
	Node_PStruct, // パターン構造体
	Node_PSplat,  // パターンスプラット
	Node_PLambda, // パターンラムダ
}

// ============================================================================
// リテラルノード (Literal Nodes)
// ============================================================================

// Node_Int - 整数リテラル
// 例: 42, -100, 0xFF
Node_Int :: struct {
	value: i64, // 整数値
}

// Node_Float - 浮動小数点リテラル
// 例: 3.14, 1.0e-10
Node_Float :: struct {
	value: f64, // 浮動小数点値
}

// Node_Time - 時刻リテラル
// Unix時刻ベースの時刻表現
Node_Time :: struct {
	sec:        i64, // 秒（Unix時刻）
	usec:       i64, // マイクロ秒
	utc_offset: int, // UTCからのオフセット（秒）
}

// Node_Str - 文字列リテラル
// 例: "hello", 'world'
Node_Str :: struct {
	value: string, // 文字列値
}

// Node_Bool - 真偽値リテラル
// 例: true, false
Node_Bool :: struct {
	value: bool, // 真偽値
}

// ============================================================================
// コレクションノード (Collection Nodes)
// ============================================================================

// Node_Args - 関数の仮引数名リスト
// ラムダ式や関数定義で使用される。
// 例: {|x, y, z| body} の x, y, z 部分
Node_Args :: struct {
	names: [dynamic]string, // 引数名の動的配列
}

// Node_Pair - キー:値ペア
// ラベル付き引数や構造体フィールドで使用される。
// 例: name: "Alice", age: 30
Node_Pair :: struct {
	key:   string, // キー名
	value: ^Node,  // 値のノード
}

// Node_Array - 配列リテラル
// オプションでheadersを持ち、構造体的な配列も表現できる。
// 例: [1, 2, 3], {name: "Alice", age: 30}
Node_Array :: struct {
	elements: [dynamic]^Node,  // 要素のノード
	headers:  [dynamic]string, // フィールド名（オプション、構造体用）
	ns:       string,          // 名前空間名（オプション）
}

// Node_Nodes - ノードのリスト（複合文）
// 複数の文や式を順次実行する場合に使用。
// 例: { stmt1; stmt2; stmt3 }
Node_Nodes :: struct {
	nodes: [dynamic]^Node, // ノードの動的配列
}

// ============================================================================
// パターンマッチングノード (Pattern Matching Nodes)
// ============================================================================

// Node_PArray - パターン配列
// case式での配列パターンマッチングに使用。
// 例: [a, b, c] のパターン部分
Node_PArray :: struct {
	patterns: [dynamic]^Node, // パターン要素
}

// Node_PStruct - パターン構造体
// ラベル付きパターンマッチングに使用。
// Node_Pairを要素として含む。
// 例: {name: n, age: a} のパターン部分
Node_PStruct :: struct {
	patterns: [dynamic]^Node, // パターン要素（Node_Pair）
}

// Node_Splat - スプラット式
// 配列を展開して個別の要素として扱う。
// 例: *args（配列argsの展開）
Node_Splat :: struct {
	expr: ^Node, // 展開する式
}

// ============================================================================
// 式ノード (Expression Nodes)
// ============================================================================

// Node_Ident - 識別子参照
// 変数や関数名への参照。
// 例: x, foo, myFunction
Node_Ident :: struct {
	name: string, // 識別子名
}

// Node_Op - 二項/単項演算
// 算術演算、比較演算、論理演算、パイプ演算など。
// 例: +, -, *, /, |, ==, !=, <, >, &&, ||
Node_Op :: struct {
	op:  string, // 演算子
	lhs: ^Node,  // 左辺（単項前置演算の場合はnil）
	rhs: ^Node,  // 右辺
}

// Node_If - 条件式
// if-then-else構文。
// 例: if (cond) { then_body } else { else_body }
Node_If :: struct {
	cond:     ^Node, // 条件式
	then_:    ^Node, // 真の場合のボディ
	opt_else: ^Node, // 偽の場合のボディ（nilでelse無し）
}

// Node_Lambda - ラムダ/関数定義
// クロージャを表現する。
// 例: {|x| x * 2}, {|x, y| x + y}
Node_Lambda :: struct {
	args:     ^Node, // 引数リスト（Node_Args）またはnil
	body:     ^Node, // 関数ボディ
	is_block: bool,  // true: {stmts}形式, false: -> expr形式
}

// Node_Call - 関数呼び出し（名前指定）
// 名前で関数を呼び出す。
// 例: puts("hello"), map({|x| x * 2})
Node_Call :: struct {
	name: string, // 関数名
	args: ^Node,  // 引数（Node_Array）またはnil
}

// Node_Fcall - 間接関数呼び出し
// 式を評価して得られた関数を呼び出す。
// 例: f(1, 2), callbacks[0]("arg")
Node_Fcall :: struct {
	func_: ^Node, // 関数を返す式
	args:  ^Node, // 引数（Node_Array）またはnil
}

// Node_Genfunc - ジェネリック関数参照
// &演算子で関数への参照を取得。
// 例: &length, &to_s
Node_Genfunc :: struct {
	name: string, // 関数名
}

// ============================================================================
// 文ノード (Statement Nodes)
// ============================================================================

// Node_Let - 変数束縛（let文）
// 変数に値を束縛する。
// 例: x = 42, name = "Alice"
Node_Let :: struct {
	lhs: string, // 変数名
	rhs: ^Node,  // 値を計算する式
}

// Node_Emit - emit文
// ストリームに値を送出する。
// 例: emit x, emit transform(value)
Node_Emit :: struct {
	value: ^Node, // 送出する値の式
}

// Node_Return - return文
// 関数から値を返す。
// 例: return x, return（値なし）
Node_Return :: struct {
	value: ^Node, // 返す値の式（nilで値なしreturn）
}

// ============================================================================
// トップレベルノード (Top-level Nodes)
// ============================================================================

// Node_Ns - 名前空間/クラス定義
// モジュールやクラスを定義する。
// 例: namespace MyModule { def foo() { ... } }
Node_Ns :: struct {
	name: string, // 名前空間名
	body: ^Node,  // 名前空間のボディ
}

// Node_Import - import文
// 名前空間をインポートする。
// 例: import MyModule
Node_Import :: struct {
	name: string, // インポートする名前空間名
}

// ============================================================================
// パターンマッチング構造 (Pattern Matching Structures)
// ============================================================================

// Node_PSplat - スプラット付きパターン
// 配列を head, *mid, tail に分解するパターン。
// 例: [first, *rest], [head, *middle, tail]
Node_PSplat :: struct {
	head: ^Node, // 先頭パターン（PArray）
	mid:  ^Node, // 中間パターン（残り要素を束縛）
	tail: ^Node, // 末尾パターン（PArray）
}

// Node_PLambda - パターンラムダ（case節）
// パターンマッチングによる分岐を行うラムダ。
// 複数のcase節はnext_でチェーンされる。
// 例: {|0| "zero" |n if n > 0| "positive" |_| "negative"}
Node_PLambda :: struct {
	pat:   ^Node, // マッチングパターン
	cond:  ^Node, // ガード条件（オプション）
	body:  ^Node, // パターンがマッチした場合のボディ
	next_: ^Node, // 次のパターンラムダ（チェーン）
}

// ============================================================================
// ノードコンストラクタ (Node Constructors)
// ============================================================================
// ASTノードを生成するためのファクトリ関数群。
// パーサーがこれらの関数を使用してASTを構築する。

// ----------------------------------------------------------------------------
// node_new - 汎用ノードコンストラクタ
// ----------------------------------------------------------------------------
// 指定された型とNode_Typeでノードを生成する。
// 他のコンストラクタから内部的に使用される。
//
// 引数:
//   $T     - ノードデータの型（コンパイル時）
//   type   - ノードタイプ
//   fname  - ソースファイル名
//   lineno - 行番号
//
// 戻り値:
//   生成されたノード
node_new :: proc($T: typeid, type: Node_Type, fname: string = "", lineno: int = 0) -> ^Node {
	n := new(Node)
	n.type = type
	n.fname = fname
	n.lineno = lineno
	n.data = T{}
	return n
}

// ----------------------------------------------------------------------------
// node_int_new - 整数リテラルノードを生成
// ----------------------------------------------------------------------------
// 例: 42 → Node { type: .Int, data: Node_Int { value: 42 } }
node_int_new :: proc(value: i64, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Int, .Int, fname, lineno)
	(&n.data.(Node_Int)).value = value
	return n
}

// ----------------------------------------------------------------------------
// node_float_new - 浮動小数点リテラルノードを生成
// ----------------------------------------------------------------------------
// 例: 3.14 → Node { type: .Float, data: Node_Float { value: 3.14 } }
node_float_new :: proc(value: f64, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Float, .Float, fname, lineno)
	(&n.data.(Node_Float)).value = value
	return n
}

// ----------------------------------------------------------------------------
// node_time_new - 時刻リテラルノードを生成
// ----------------------------------------------------------------------------
node_time_new :: proc(sec: i64, usec: i64, utc_offset: int, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Time, .Time, fname, lineno)
	t := &n.data.(Node_Time)
	t.sec = sec
	t.usec = usec
	t.utc_offset = utc_offset
	return n
}

// ----------------------------------------------------------------------------
// node_string_new - 文字列リテラルノードを生成
// ----------------------------------------------------------------------------
// 文字列はクローンされる（REPLモードでのダングリング参照を防ぐため）。
// 例: "hello" → Node { type: .Str, data: Node_Str { value: "hello" } }
node_string_new :: proc(value: string, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Str, .Str, fname, lineno)
	// 文字列をクローン（ダングリング参照防止、REPLモードで重要）
	(&n.data.(Node_Str)).value = strings.clone(value)
	return n
}

// ----------------------------------------------------------------------------
// node_bool_new - 真偽値リテラルノードを生成
// ----------------------------------------------------------------------------
// 例: true → Node { type: .Bool, data: Node_Bool { value: true } }
node_bool_new :: proc(value: bool, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Bool, .Bool, fname, lineno)
	(&n.data.(Node_Bool)).value = value
	return n
}

// ----------------------------------------------------------------------------
// node_nil_new - nilリテラルノードを生成
// ----------------------------------------------------------------------------
// nilはデータを持たないため、dataフィールドは初期化しない。
node_nil_new :: proc(fname: string = "", lineno: int = 0) -> ^Node {
	n := new(Node)
	n.type = .Nil
	n.fname = fname
	n.lineno = lineno
	return n
}

// ----------------------------------------------------------------------------
// node_ident_new - 識別子ノードを生成
// ----------------------------------------------------------------------------
// 例: x → Node { type: .Ident, data: Node_Ident { name: "x" } }
node_ident_new :: proc(name: string, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Ident, .Ident, fname, lineno)
	// 文字列をクローン（ダングリング参照防止）
	(&n.data.(Node_Ident)).name = strings.clone(name)
	return n
}

// ----------------------------------------------------------------------------
// node_op_new - 演算ノードを生成
// ----------------------------------------------------------------------------
// 二項演算と単項演算の両方に使用。
// 単項前置演算の場合はlhsがnil。
// 例: 1 + 2 → Node { type: .Op, data: Node_Op { op: "+", lhs: Int(1), rhs: Int(2) } }
node_op_new :: proc(op: string, lhs: ^Node, rhs: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Op, .Op, fname, lineno)
	o := &n.data.(Node_Op)
	// 演算子文字列をクローン
	o.op = strings.clone(op)
	o.lhs = lhs
	o.rhs = rhs
	return n
}

// ----------------------------------------------------------------------------
// node_if_new - 条件式ノードを生成
// ----------------------------------------------------------------------------
// if-then-else構文を表現。
// opt_elseがnilの場合はelse節なし。
node_if_new :: proc(cond: ^Node, then_: ^Node, opt_else: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_If, .If, fname, lineno)
	i := &n.data.(Node_If)
	i.cond = cond
	i.then_ = then_
	i.opt_else = opt_else
	return n
}

// ----------------------------------------------------------------------------
// node_lambda_new - ラムダノードを生成
// ----------------------------------------------------------------------------
// クロージャ/関数定義を表現。
// is_blockはfalse（-> expr形式）。
// 例: {|x| x * 2}
node_lambda_new :: proc(args: ^Node, body: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Lambda, .Lambda, fname, lineno)
	l := &n.data.(Node_Lambda)
	l.args = args
	l.body = body
	l.is_block = false
	return n
}

// ----------------------------------------------------------------------------
// node_block_new - ブロックノードを生成
// ----------------------------------------------------------------------------
// 引数なしのブロック（{stmts}形式）を表現。
// is_blockはtrue。
// 例: { puts("hello"); puts("world") }
node_block_new :: proc(body: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Lambda, .Lambda, fname, lineno)
	l := &n.data.(Node_Lambda)
	l.args = nil
	l.body = body
	l.is_block = true
	return n
}

// ----------------------------------------------------------------------------
// node_call_new - 関数呼び出しノードを生成
// ----------------------------------------------------------------------------
// 名前で関数を呼び出す。
// 例: puts("hello") → Node { type: .Call, data: Node_Call { name: "puts", args: ... } }
node_call_new :: proc(name: string, args: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Call, .Call, fname, lineno)
	c := &n.data.(Node_Call)
	// 関数名をクローン
	c.name = strings.clone(name)
	c.args = args
	return n
}

// ----------------------------------------------------------------------------
// node_fcall_new - 間接関数呼び出しノードを生成
// ----------------------------------------------------------------------------
// 式を評価して得られた関数を呼び出す。
// 例: f(1, 2), arr[0](x)
node_fcall_new :: proc(func_: ^Node, args: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Fcall, .Fcall, fname, lineno)
	f := &n.data.(Node_Fcall)
	f.func_ = func_
	f.args = args
	return n
}

// ----------------------------------------------------------------------------
// node_genfunc_new - ジェネリック関数参照ノードを生成
// ----------------------------------------------------------------------------
// &演算子による関数参照。
// 例: &length → Node { type: .Genfunc, data: Node_Genfunc { name: "length" } }
node_genfunc_new :: proc(name: string, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Genfunc, .Genfunc, fname, lineno)
	// 関数名をクローン
	(&n.data.(Node_Genfunc)).name = strings.clone(name)
	return n
}

// ----------------------------------------------------------------------------
// node_let_new - 変数束縛ノードを生成
// ----------------------------------------------------------------------------
// 変数への代入を表現。
// 例: x = 42 → Node { type: .Let, data: Node_Let { lhs: "x", rhs: Int(42) } }
node_let_new :: proc(lhs: string, rhs: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Let, .Let, fname, lineno)
	l := &n.data.(Node_Let)
	// 変数名をクローン
	l.lhs = strings.clone(lhs)
	l.rhs = rhs
	return n
}

// ----------------------------------------------------------------------------
// node_emit_new - emit文ノードを生成
// ----------------------------------------------------------------------------
// ストリームへの値送出を表現。
// 例: emit x → Node { type: .Emit, data: Node_Emit { value: Ident("x") } }
node_emit_new :: proc(value: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Emit, .Emit, fname, lineno)
	(&n.data.(Node_Emit)).value = value
	return n
}

// ----------------------------------------------------------------------------
// node_skip_new - skip文ノードを生成
// ----------------------------------------------------------------------------
// 次の入力へスキップすることを表現。
// データを持たない。
node_skip_new :: proc(fname: string = "", lineno: int = 0) -> ^Node {
	n := new(Node)
	n.type = .Skip
	n.fname = fname
	n.lineno = lineno
	return n
}

// ----------------------------------------------------------------------------
// node_return_new - return文ノードを生成
// ----------------------------------------------------------------------------
// 関数からの戻りを表現。
// valueがnilの場合は値なしreturn。
node_return_new :: proc(value: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Return, .Return, fname, lineno)
	(&n.data.(Node_Return)).value = value
	return n
}

// ----------------------------------------------------------------------------
// node_ns_new - 名前空間ノードを生成
// ----------------------------------------------------------------------------
// 名前空間/モジュール定義を表現。
// 例: namespace MyModule { ... }
node_ns_new :: proc(name: string, body: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Ns, .Ns, fname, lineno)
	ns := &n.data.(Node_Ns)
	// 名前空間名をクローン
	ns.name = strings.clone(name)
	ns.body = body
	return n
}

// ----------------------------------------------------------------------------
// node_import_new - import文ノードを生成
// ----------------------------------------------------------------------------
// 名前空間のインポートを表現。
// 例: import MyModule
node_import_new :: proc(name: string, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Import, .Import, fname, lineno)
	// 名前空間名をクローン
	(&n.data.(Node_Import)).name = strings.clone(name)
	return n
}

// ----------------------------------------------------------------------------
// node_splat_new - スプラット式ノードを生成
// ----------------------------------------------------------------------------
// 配列展開を表現。
// 例: *args → Node { type: .Splat, data: Node_Splat { expr: Ident("args") } }
node_splat_new :: proc(expr: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Splat, .Splat, fname, lineno)
	(&n.data.(Node_Splat)).expr = expr
	return n
}

// ----------------------------------------------------------------------------
// node_psplat_new - パターンスプラットノードを生成
// ----------------------------------------------------------------------------
// スプラット付きパターンを表現。
// 例: [head, *mid, tail] のパターン
node_psplat_new :: proc(head: ^Node, mid: ^Node, tail: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_PSplat, .PSplat, fname, lineno)
	p := &n.data.(Node_PSplat)
	p.head = head
	p.mid = mid
	p.tail = tail
	return n
}

// ----------------------------------------------------------------------------
// node_plambda_new - パターンラムダノードを生成
// ----------------------------------------------------------------------------
// パターンマッチング節を表現。
// bodyとnext_は後から設定される。
node_plambda_new :: proc(pat: ^Node, cond: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_PLambda, .PLambda, fname, lineno)
	p := &n.data.(Node_PLambda)
	p.pat = pat
	p.cond = cond
	p.body = nil   // 後で設定
	p.next_ = nil  // 後で設定（チェーン用）
	return n
}

// ============================================================================
// 配列/ノードリストヘルパー (Array/Nodes Helpers)
// ============================================================================
// 動的にノードを追加するためのヘルパー関数群。

// ----------------------------------------------------------------------------
// node_array_new - 配列ノードを生成
// ----------------------------------------------------------------------------
// 空の配列ノードを生成。要素はnode_array_addで追加。
node_array_new :: proc(fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Array, .Array, fname, lineno)
	return n
}

// ----------------------------------------------------------------------------
// node_array_add - 配列ノードに要素を追加
// ----------------------------------------------------------------------------
// 配列に新しい要素を追加する。
node_array_add :: proc(arr: ^Node, elem: ^Node) {
	if arr == nil || arr.type != .Array {
		return
	}
	a := &arr.data.(Node_Array)
	append(&a.elements, elem)
}

// ----------------------------------------------------------------------------
// node_nodes_new - ノードリストを生成
// ----------------------------------------------------------------------------
// 複合文を表現する空のノードリストを生成。
node_nodes_new :: proc(fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Nodes, .Nodes, fname, lineno)
	return n
}

// ----------------------------------------------------------------------------
// node_nodes_add - ノードリストにノードを追加
// ----------------------------------------------------------------------------
// ノードリストに新しいノード（文/式）を追加する。
node_nodes_add :: proc(nodes: ^Node, node: ^Node) {
	if nodes == nil || nodes.type != .Nodes {
		return
	}
	ns := &nodes.data.(Node_Nodes)
	append(&ns.nodes, node)
}

// ----------------------------------------------------------------------------
// node_args_new - 引数リストノードを生成
// ----------------------------------------------------------------------------
// 関数の仮引数リストを生成。
node_args_new :: proc(fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Args, .Args, fname, lineno)
	return n
}

// ----------------------------------------------------------------------------
// node_args_add - 引数リストに引数名を追加
// ----------------------------------------------------------------------------
// 仮引数名を追加する。
node_args_add :: proc(args: ^Node, name: string) {
	if args == nil || args.type != .Args {
		return
	}
	a := &args.data.(Node_Args)
	// 文字列をクローン（ダングリング参照防止）
	append(&a.names, strings.clone(name))
}

// ----------------------------------------------------------------------------
// node_pair_new - ペアノードを生成
// ----------------------------------------------------------------------------
// key:value形式のペアを生成。
// ラベル付き引数や構造体フィールドで使用。
node_pair_new :: proc(key: string, value: ^Node, fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_Pair, .Pair, fname, lineno)
	p := &n.data.(Node_Pair)
	p.key = key
	p.value = value
	return n
}

// ============================================================================
// パターンマッチングヘルパー (Pattern Matching Helpers)
// ============================================================================
// パターンマッチング用ノードの構築を支援する関数群。

// ----------------------------------------------------------------------------
// node_parray_new - パターン配列ノードを生成
// ----------------------------------------------------------------------------
// case式での配列パターン用。
// 例: [a, b, c] パターン
node_parray_new :: proc(fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_PArray, .PArray, fname, lineno)
	return n
}

// ----------------------------------------------------------------------------
// node_parray_add - パターン配列にパターンを追加
// ----------------------------------------------------------------------------
// パターン配列に新しいパターン要素を追加する。
node_parray_add :: proc(parray: ^Node, pattern: ^Node) {
	if parray == nil || parray.type != .PArray {
		return
	}
	p := &parray.data.(Node_PArray)
	append(&p.patterns, pattern)
}

// ----------------------------------------------------------------------------
// node_pstruct_new - パターン構造体ノードを生成
// ----------------------------------------------------------------------------
// case式でのラベル付きパターン用。
// 例: {name: n, age: a} パターン
node_pstruct_new :: proc(fname: string = "", lineno: int = 0) -> ^Node {
	n := node_new(Node_PStruct, .PStruct, fname, lineno)
	return n
}

// ----------------------------------------------------------------------------
// node_pstruct_add - パターン構造体にパターンを追加
// ----------------------------------------------------------------------------
// パターン構造体に新しいパターン（Node_Pair）を追加する。
node_pstruct_add :: proc(pstruct: ^Node, pattern: ^Node) {
	if pstruct == nil || pstruct.type != .PStruct {
		return
	}
	p := &pstruct.data.(Node_PStruct)
	append(&p.patterns, pattern)
}

// ----------------------------------------------------------------------------
// node_pattern_new - 汎用パターンノード生成
// ----------------------------------------------------------------------------
// C版のnode_pattern_newと同等の動作。
// typeに応じてPArrayまたはPStructを生成する。
//
// 引数:
//   type - パターンの種類（.PArray or .PStruct）
node_pattern_new :: proc(type: Node_Type = .PArray, fname: string = "", lineno: int = 0) -> ^Node {
	#partial switch type {
	case .PArray:
		return node_parray_new(fname, lineno)
	case .PStruct:
		return node_pstruct_new(fname, lineno)
	case:
		// デフォルトはPArray（後方互換性のため）
		return node_parray_new(fname, lineno)
	}
}

// ----------------------------------------------------------------------------
// node_pattern_add - 汎用パターン追加
// ----------------------------------------------------------------------------
// PArrayとPStructの両方に対応したパターン追加。
node_pattern_add :: proc(pattern_node: ^Node, elem: ^Node) {
	if pattern_node == nil {
		return
	}
	#partial switch pattern_node.type {
	case .PArray:
		node_parray_add(pattern_node, elem)
	case .PStruct:
		node_pstruct_add(pattern_node, elem)
	case:
		// その他の型には何もしない
	}
}

// ----------------------------------------------------------------------------
// node_plambda_body - パターンラムダにボディを設定
// ----------------------------------------------------------------------------
// パターンラムダ構築時にボディを後から設定する。
node_plambda_body :: proc(n: ^Node, body: ^Node) -> ^Node {
	if n == nil || n.type != .PLambda {
		return n
	}
	p := &n.data.(Node_PLambda)
	p.body = body
	return n
}

// ----------------------------------------------------------------------------
// node_plambda_add - パターンラムダチェーンに追加
// ----------------------------------------------------------------------------
// 複数のcase節をチェーンで連結する。
// 新しいパターンラムダをチェーンの末尾に追加する。
node_plambda_add :: proc(n: ^Node, next: ^Node) -> ^Node {
	if n == nil || n.type != .PLambda {
		return n
	}
	// チェーンの末尾を探して追加
	current := n
	for current.type == .PLambda {
		p := &current.data.(Node_PLambda)
		if p.next_ == nil {
			p.next_ = next
			break
		}
		current = p.next_
	}
	return n
}

// ============================================================================
// ノード解放 (Node Deallocation)
// ============================================================================
// ASTノードとその子ノードを再帰的に解放する。

// ----------------------------------------------------------------------------
// node_free - ノードを解放
// ----------------------------------------------------------------------------
// ノードとその子ノードを再帰的に解放する。
// 各ノード型に応じて適切なリソースを解放する。
//
// 引数:
//   n - 解放するノード
node_free :: proc(n: ^Node) {
	if n == nil {
		return
	}

	// ノード型に応じた解放処理
	switch &d in n.data {
	case Node_Int, Node_Float, Node_Time, Node_Str, Node_Bool:
		// プリミティブ型は追加の解放不要

	case Node_Args:
		// 引数名リストを解放
		delete(d.names)

	case Node_Pair:
		// 値ノードを再帰的に解放
		node_free(d.value)

	case Node_Array:
		// 全要素を再帰的に解放
		for elem in d.elements {
			node_free(elem)
		}
		delete(d.elements)
		delete(d.headers)

	case Node_Nodes:
		// 全ノードを再帰的に解放
		for node in d.nodes {
			node_free(node)
		}
		delete(d.nodes)

	case Node_PArray:
		// 全パターンを再帰的に解放
		for pat in d.patterns {
			node_free(pat)
		}
		delete(d.patterns)

	case Node_PStruct:
		// 全パターンを再帰的に解放
		for pat in d.patterns {
			node_free(pat)
		}
		delete(d.patterns)

	case Node_Splat:
		// 式を再帰的に解放
		node_free(d.expr)

	case Node_Ident:
		// 追加の解放不要（文字列はクローンされているが、手動解放は不要）

	case Node_Op:
		// 左辺・右辺を再帰的に解放
		node_free(d.lhs)
		node_free(d.rhs)

	case Node_If:
		// 条件・then・elseを再帰的に解放
		node_free(d.cond)
		node_free(d.then_)
		node_free(d.opt_else)

	case Node_Lambda:
		// 引数・ボディを再帰的に解放
		node_free(d.args)
		node_free(d.body)

	case Node_Call:
		// 引数を再帰的に解放
		node_free(d.args)

	case Node_Fcall:
		// 関数式・引数を再帰的に解放
		node_free(d.func_)
		node_free(d.args)

	case Node_Genfunc:
		// 追加の解放不要

	case Node_Let:
		// 右辺を再帰的に解放
		node_free(d.rhs)

	case Node_Emit:
		// 値を再帰的に解放
		node_free(d.value)

	case Node_Return:
		// 値を再帰的に解放
		node_free(d.value)

	case Node_Ns:
		// ボディを再帰的に解放
		node_free(d.body)

	case Node_Import:
		// 追加の解放不要

	case Node_PSplat:
		// head/mid/tailを再帰的に解放
		node_free(d.head)
		node_free(d.mid)
		node_free(d.tail)

	case Node_PLambda:
		// パターン・条件・ボディ・次のラムダを再帰的に解放
		node_free(d.pat)
		node_free(d.cond)
		node_free(d.body)
		node_free(d.next_)
	}

	// ノード本体を解放
	free(n)
}
