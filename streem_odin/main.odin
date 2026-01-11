// =============================================================================
// Streem - ストリームベース並行スクリプト言語 (Odin移植版)
// =============================================================================
//
// このファイルはStreemインタプリタのメインエントリーポイントです。
// Streemは松本行弘(Matz)氏が作成したストリームベースの並行スクリプト言語で、
// シェルパイプラインに似たプログラミングモデルを採用しています。
//
// 主な機能:
//   - ファイルからのスクリプト実行
//   - インラインコード実行 (-e オプション)
//   - 構文チェック (-c オプション)
//   - AST表示 (-v オプション)
//   - 対話的REPL
//
// =============================================================================
package streem

import "core:fmt"
import "core:os"
import "core:strings"
import "core:bufio"
import "core:io"
import "core:flags"

// -----------------------------------------------------------------------------
// コマンドライン引数の定義
// -----------------------------------------------------------------------------

// Options: CLIオプションを定義する構造体
// core:flags パッケージを使用して、コマンドライン引数を自動的にパースする
Options :: struct {
	// -e オプション: インラインコードを直接実行する
	input_string:      string `args:"name=e" usage:"Execute inline code"`,
	// -c オプション: 構文チェックのみを行い、実行はしない
	syntax_check_only: bool `args:"name=c" usage:"Syntax check only"`,
	// -v オプション: 詳細モード（ASTをダンプ表示する）
	verbose:           bool `args:"name=v" usage:"Verbose mode (dump AST)"`,
	// 位置引数: 実行するスクリプトファイルのパス
	input_file:        string `args:"pos=0" usage:"Input file to execute"`,
}

// -----------------------------------------------------------------------------
// メインエントリーポイント
// -----------------------------------------------------------------------------

// main: プログラムのエントリーポイント
// コマンドライン引数をパースし、適切な実行モードを選択する
main :: proc() {
	opt: Options
	// Unix形式のオプション解析（-e, -c, -v など）
	style: flags.Parsing_Style = .Unix
	flags.parse_or_exit(&opt, os.args, style)

	// 実行モードの決定（優先順位に従って分岐）
	if opt.syntax_check_only {
		// 構文チェックモード: パースのみ行い、実行はしない
		if opt.input_file != "" {
			syntax_check_file(opt.input_file)
		} else if opt.input_string != "" {
			syntax_check_string(opt.input_string)
		} else {
			fmt.eprintln("Error: No input specified for syntax check")
			os.exit(1)
		}
	} else if opt.input_string != "" {
		// インラインコード実行モード: -e で指定されたコードを実行
		run_string(opt.input_string, opt.verbose)
	} else if opt.input_file != "" {
		// ファイル実行モード: 指定されたファイルを読み込んで実行
		run_file(opt.input_file, opt.verbose)
	} else {
		// REPLモード: 引数がない場合は対話的REPLを起動
		run_repl(opt.verbose)
	}
}

// -----------------------------------------------------------------------------
// ソースコード実行関連
// -----------------------------------------------------------------------------

// run_file: ファイルからStreemスクリプトを読み込んで実行する
// 引数:
//   - filename: 実行するスクリプトファイルのパス
//   - verbose: trueの場合、ASTをダンプ表示する
run_file :: proc(filename: string, verbose: bool) {
	// ファイル全体をメモリに読み込む
	data, ok := os.read_entire_file(filename)
	if !ok {
		fmt.eprintfln("Error: Cannot read file: %s", filename)
		os.exit(1)
	}
	defer delete(data)  // 関数終了時にメモリを解放

	source := string(data)
	run_source(source, filename, verbose)
}

// run_string: 文字列からStreemコードを実行する
// -e オプションで指定されたインラインコードの実行に使用
// 引数:
//   - source: 実行するStreemソースコード
//   - verbose: trueの場合、ASTをダンプ表示する
run_string :: proc(source: string, verbose: bool) {
	run_source(source, "<input>", verbose)
}

// run_source: Streemソースコードを実行するコア関数
// パース、AST生成、実行、イベントループの全工程を担当する
// 引数:
//   - source: Streemソースコード文字列
//   - filename: エラーメッセージ表示用のファイル名
//   - verbose: trueの場合、ASTをダンプ表示する
run_source :: proc(source: string, filename: string, verbose: bool) {
	// 名前空間システムの初期化
	// グローバル変数や組み込み関数を管理するための基盤
	strm_ns_init()
	defer strm_ns_cleanup()

	// レキサー（字句解析器）の初期化
	// ソースコードをトークン列に変換する
	lex: Lex
	lex_init(&lex, source, filename)

	// パース（構文解析）
	// トークン列からAST（抽象構文木）を生成する
	ast, ok := parse_program_from_lex(&lex)
	if !ok {
		fmt.eprintln("Error: Parse failed")
		os.exit(1)
	}
	defer node_free(ast)  // 関数終了時にASTを解放

	// 詳細モードの場合、ASTをダンプ表示
	if verbose {
		fmt.println("=== AST ===")
		dump_ast(ast, 0)
		fmt.println("===========")
	}

	// グローバル状態（スコープ）の作成
	// 変数束縛や関数定義を保持する
	state := strm_state_new()
	defer strm_state_destroy(state)

	// 組み込み関数の初期化
	// stdin, stdout, seq, map, filter などを登録
	init_builtins(state)

	// ASTを実行
	// exec_expr は再帰的にASTを走査し、各ノードを評価する
	result: Strm_Value
	exec_result := exec_expr(nil, state, ast, &result)

	if exec_result == .Error {
		fmt.eprintln("Error: Execution failed")
		os.exit(1)
	}

	// イベントループの実行
	// ストリーム処理のタスクキューを処理し、全てのストリームが
	// 完了するまで待機する
	strm_loop()

	// ワーカースレッドのクリーンアップ
	worker_cleanup()
}

// -----------------------------------------------------------------------------
// 構文チェック関連
// -----------------------------------------------------------------------------

// syntax_check_file: ファイルの構文をチェックする
// 引数:
//   - filename: チェックするスクリプトファイルのパス
syntax_check_file :: proc(filename: string) {
	data, ok := os.read_entire_file(filename)
	if !ok {
		fmt.eprintfln("Error: Cannot read file: %s", filename)
		os.exit(1)
	}
	defer delete(data)

	source := string(data)
	syntax_check(source, filename)
}

// syntax_check_string: 文字列の構文をチェックする
// -e オプションと -c オプションを組み合わせた場合に使用
// 引数:
//   - source: チェックするStreemソースコード
syntax_check_string :: proc(source: string) {
	syntax_check(source, "<input>")
}

// syntax_check: 構文チェックのコア関数
// パースのみを行い、実行はしない。構文エラーがあれば報告する
// 引数:
//   - source: チェックするソースコード
//   - filename: エラーメッセージ表示用のファイル名
syntax_check :: proc(source: string, filename: string) {
	// レキサーの初期化
	lex: Lex
	lex_init(&lex, source, filename)

	// パースを試行
	ast, ok := parse_program_from_lex(&lex)
	if !ok {
		fmt.eprintfln("Syntax error in %s", filename)
		os.exit(1)
	}

	// パース成功時はASTを解放して成功メッセージを表示
	node_free(ast)
	fmt.printfln("Syntax OK: %s", filename)
}

// -----------------------------------------------------------------------------
// ASTダンプ（デバッグ用）
// -----------------------------------------------------------------------------

// dump_ast: AST（抽象構文木）を人間が読める形式で出力する
// -v オプションが指定された場合に呼び出される
// 引数:
//   - node: 出力するASTノード
//   - indent: 現在のインデントレベル（ネストの深さを表現）
dump_ast :: proc(node: ^Node, indent: int) {
	// nilノードの処理
	if node == nil {
		print_indent(indent)
		fmt.println("nil")
		return
	}

	print_indent(indent)

	// ノードタイプに応じて適切な形式で出力
	// #partial switch: 全てのケースを網羅しなくてもコンパイルエラーにならない
	#partial switch node.type {
	case .Int:
		// 整数リテラル
		data := &node.data.(Node_Int)
		fmt.printfln("Int(%d)", data.value)

	case .Float:
		// 浮動小数点リテラル
		data := &node.data.(Node_Float)
		fmt.printfln("Float(%f)", data.value)

	case .Str:
		// 文字列リテラル
		data := &node.data.(Node_Str)
		fmt.printfln("Str(\"%s\")", data.value)

	case .Bool:
		// 真偽値リテラル
		data := &node.data.(Node_Bool)
		fmt.printfln("Bool(%v)", data.value)

	case .Nil:
		// nil値
		fmt.println("Nil")

	case .Ident:
		// 識別子（変数名、関数名など）
		data := &node.data.(Node_Ident)
		fmt.printfln("Ident(%s)", data.name)

	case .Op:
		// 二項演算子（+, -, *, /, |, などを含む）
		// Streemでは | がパイプ演算子として重要な役割を持つ
		data := &node.data.(Node_Op)
		fmt.printfln("Op(%s)", data.op)
		dump_ast(data.lhs, indent + 2)  // 左オペランド
		dump_ast(data.rhs, indent + 2)  // 右オペランド

	case .If:
		// if式（Streemではifは式であり値を返す）
		data := &node.data.(Node_If)
		fmt.println("If")
		print_indent(indent + 2)
		fmt.println("cond:")
		dump_ast(data.cond, indent + 4)   // 条件式
		print_indent(indent + 2)
		fmt.println("then:")
		dump_ast(data.then_, indent + 4)  // then節
		if data.opt_else != nil {
			print_indent(indent + 2)
			fmt.println("else:")
			dump_ast(data.opt_else, indent + 4)  // else節（オプション）
		}

	case .Lambda:
		// ラムダ式（無名関数）
		// is_block: ブロック形式 {|x| ...} かどうか
		data := &node.data.(Node_Lambda)
		fmt.printfln("Lambda(block=%v)", data.is_block)
		if data.args != nil {
			print_indent(indent + 2)
			fmt.println("args:")
			dump_ast(data.args, indent + 4)  // 引数リスト
		}
		print_indent(indent + 2)
		fmt.println("body:")
		dump_ast(data.body, indent + 4)  // 関数本体

	case .Call:
		// 名前付き関数呼び出し（例: print("hello")）
		data := &node.data.(Node_Call)
		fmt.printfln("Call(%s)", data.name)
		if data.args != nil {
			dump_ast(data.args, indent + 2)  // 引数
		}

	case .Fcall:
		// 式からの関数呼び出し（例: (get_func())()）
		// 関数オブジェクトが式で得られる場合に使用
		data := &node.data.(Node_Fcall)
		fmt.println("Fcall")
		print_indent(indent + 2)
		fmt.println("func:")
		dump_ast(data.func_, indent + 4)  // 関数を返す式
		if data.args != nil {
			print_indent(indent + 2)
			fmt.println("args:")
			dump_ast(data.args, indent + 4)  // 引数
		}

	case .Let:
		// 変数束縛（let文）
		data := &node.data.(Node_Let)
		fmt.printfln("Let(%s)", data.lhs)  // 変数名
		dump_ast(data.rhs, indent + 2)     // 束縛する値

	case .Emit:
		// ストリームへの値の送出
		// フィルター内で下流に値を送る
		data := &node.data.(Node_Emit)
		fmt.println("Emit")
		dump_ast(data.value, indent + 2)

	case .Skip:
		// 現在の値をスキップ（フィルター内で使用）
		fmt.println("Skip")

	case .Return:
		// 関数からの戻り
		data := &node.data.(Node_Return)
		fmt.println("Return")
		dump_ast(data.value, indent + 2)

	case .Nodes:
		// 複数のノードのリスト（プログラム本体や複文など）
		data := &node.data.(Node_Nodes)
		fmt.printfln("Nodes(%d)", len(data.nodes))
		for n in data.nodes {
			dump_ast(n, indent + 2)
		}

	case .Array:
		// 配列リテラル
		data := &node.data.(Node_Array)
		fmt.printfln("Array(%d)", len(data.elements))
		for elem in data.elements {
			dump_ast(elem, indent + 2)
		}

	case .Args:
		// 引数定義リスト（ラムダ式の引数など）
		data := &node.data.(Node_Args)
		fmt.print("Args(")
		for i := 0; i < len(data.names); i += 1 {
			if i > 0 {
				fmt.print(", ")
			}
			fmt.print(data.names[i])
		}
		fmt.println(")")

	case .Ns:
		// 名前空間定義
		data := &node.data.(Node_Ns)
		fmt.printfln("Namespace(%s)", data.name)
		dump_ast(data.body, indent + 2)

	case .Import:
		// インポート文
		data := &node.data.(Node_Import)
		fmt.printfln("Import(%s)", data.name)

	case:
		// 未知のノードタイプ（フォールバック）
		fmt.printfln("<%v>", node.type)
	}
}

// print_indent: 指定された数のスペースを出力する
// ASTダンプのインデント表示に使用
// @(private = "file"): このファイル内でのみ使用可能
@(private = "file")
print_indent :: proc(n: int) {
	for _ in 0 ..< n {
		fmt.print(" ")
	}
}

// -----------------------------------------------------------------------------
// 組み込み関数の初期化
// -----------------------------------------------------------------------------

// init_builtins: 全ての組み込み関数を初期化する
// 以下のような関数をグローバルスコープに登録:
//   - I/O: stdin, stdout, stderr
//   - ストリーム操作: seq, map, filter, reduce, take, drop など
//   - 出力: print, println
//   - その他のユーティリティ関数
// 引数:
//   - state: 関数を登録するグローバル状態
init_builtins :: proc(state: ^Strm_State) {
	strm_init(state)
}

// =============================================================================
// REPL (Read-Eval-Print Loop) - 対話的実行環境
// =============================================================================
//
// REPLはユーザーからの入力を読み込み、評価し、結果を表示する対話的環境です。
// 複数行にまたがる入力（継続行）にも対応しています。
//
// =============================================================================

// run_repl: 対話的REPLを起動する
// 引数なしでプログラムを起動した場合に呼び出される
// 引数:
//   - verbose: trueの場合、各入力のASTをダンプ表示する
run_repl :: proc(verbose: bool) {
	// 起動メッセージの表示
	fmt.println("Streem REPL (Odin port)")
	fmt.println("Type 'exit' or Ctrl+D to quit")
	fmt.println()

	// 名前空間システムの初期化
	strm_ns_init()
	defer strm_ns_cleanup()

	// REPLセッション用の永続的なグローバル状態を作成
	// REPLでは変数定義などが次の入力に引き継がれる必要がある
	state := strm_state_new()
	defer strm_state_destroy(state)

	// 組み込み関数の初期化
	init_builtins(state)

	// 入力バッファ（複数行入力の継続に使用）
	// 例: { で始まり } で終わる複数行のブロック
	input_buffer: strings.Builder
	strings.builder_init(&input_buffer)
	defer strings.builder_destroy(&input_buffer)

	// 継続行フラグ: 前の入力が不完全だった場合にtrue
	continuation := false

	// 標準入力用のバッファ付きリーダーを作成
	// バッファリングにより効率的な行読み込みが可能
	stdin_stream := os.stream_from_handle(os.stdin)
	reader: bufio.Reader
	bufio.reader_init(&reader, stdin_stream)
	defer bufio.reader_destroy(&reader)

	// メインREPLループ
	for {
		// プロンプトの表示
		// 継続行の場合は "... "、通常は "streem> "
		if continuation {
			fmt.print("... ")
		} else {
			fmt.print("streem> ")
		}

		// 1行読み込み
		line, err := bufio.reader_read_string(&reader, '\n')
		if err != nil {
			// EOF (Ctrl+D) またはエラー
			if strings.builder_len(input_buffer) > 0 {
				// 不完全な入力がある状態でEOF
				fmt.println()
				fmt.eprintln("Error: Incomplete input")
			} else {
				fmt.println()
			}
			break
		}

		// 末尾の改行文字を削除
		line = strings.trim_right(line, "\r\n")

		// 終了コマンドのチェック（継続行でない場合のみ）
		if !continuation && (line == "exit" || line == "quit") {
			break
		}

		// 空行のチェック（継続行でない場合のみスキップ）
		if !continuation && strings.trim_space(line) == "" {
			continue
		}

		// 入力バッファに追加
		// 継続行の場合は改行を挟んで追加
		if strings.builder_len(input_buffer) > 0 {
			strings.write_string(&input_buffer, "\n")
		}
		strings.write_string(&input_buffer, line)

		// 蓄積された入力をパース・評価を試行
		source := strings.to_string(input_buffer)
		complete, result := try_parse_and_eval(state, source, verbose)

		if complete {
			// パース・評価が完了（成功またはエラー）
			if result != "" {
				fmt.println(result)
			}
			// 次の入力のためにバッファをクリア
			strings.builder_reset(&input_buffer)
			continuation = false

			// 保留中のストリームタスクを実行
			// パイプライン処理などが完了するまで待機
			strm_loop()
			worker_cleanup()
		} else {
			// 入力が不完全 - 継続行として次の入力を待つ
			continuation = true
		}
	}

	fmt.println("Goodbye!")
}

// try_parse_and_eval: 入力のパースと評価を試行する
// REPLで入力が完全かどうかを判定し、完全なら評価を行う
//
// 戻り値:
//   - complete: 入力が完全（パース可能）だったかどうか
//   - result: 評価結果の文字列表現（エラーメッセージを含む）
//
// 入力が不完全（例: 開き括弧のみ）の場合、completeはfalseを返し、
// 呼び出し元は継続行を読み込む
try_parse_and_eval :: proc(state: ^Strm_State, source: string, verbose: bool) -> (complete: bool, result: string) {
	// レキサーの初期化
	lex: Lex
	lex_init(&lex, source, "<repl>")

	// パーサーの初期化
	p := parser_new()
	defer parser_destroy(p)
	parser_reset(p)

	// トークンを1つずつパーサーに供給
	// このインクリメンタルなアプローチにより、入力の完全性を判定できる
	for {
		token := lex_scan_token(&lex)
		parse_result := parser_push_token(p, token)

		switch parse_result {
		case .Done:
			// パース成功
			ast := p.root
			if ast == nil {
				return true, ""
			}
			// 注意: REPLモードではASTを解放しない
			// ラムダ式がASTノードへの参照を保持しているため
			// これにより入力ごとに小さなメモリリークが発生するが、
			// 対話的使用では許容範囲内（プロセス終了時に解放される）

			// 詳細モードの場合はASTをダンプ
			if verbose {
				fmt.println("=== AST ===")
				dump_ast(ast, 0)
				fmt.println("===========")
			}

			// ASTを実行
			ret: Strm_Value
			exec_result := exec_expr(nil, state, ast, &ret)

			if exec_result == .Error {
				return true, "Error: Execution failed"
			}

			// 結果をフォーマット（nilはクリーンな出力のためスキップ）
			if !strm_nil_p(ret) {
				return true, strm_to_str(ret)
			}
			return true, ""

		case .Error:
			// エラーが本当のエラーか、単に入力が不完全なだけかを判定
			if p.error_msg != "" {
				// 「予期しないEOF」のようなパターンは不完全な入力を示す
				if is_incomplete_error(p.error_msg) {
					return false, ""
				}
				return true, fmt.tprintf("Parse error: %s", p.error_msg)
			}
			return true, "Parse error"

		case .Ok, .Need_Token:
			if token.type == .Eof {
				// EOFに達したがパーサーはまだトークンを必要としている
				// → 入力が不完全
				return false, ""
			}
			continue
		}
	}
}

// is_incomplete_error: パースエラーが不完全な入力を示しているかを判定する
// 特定のエラーメッセージパターンをチェックし、ユーザーが継続行を
// 入力すべきかどうかを決定する
//
// 引数:
//   - msg: パーサーからのエラーメッセージ
// 戻り値:
//   - true: 入力が不完全（継続行が必要）
//   - false: 本当のパースエラー
//
// @(private = "file"): このファイル内でのみ使用可能
@(private = "file")
is_incomplete_error :: proc(msg: string) -> bool {
	// 不完全な入力を示す一般的なエラーパターン
	// これらのパターンは、閉じ括弧や終端記号が不足していることを示す
	incomplete_patterns := []string{
		"unexpected end",  // 予期しない終端
		"Expected '}'",    // 閉じ中括弧が必要
		"Expected ')'",    // 閉じ丸括弧が必要
		"Expected ']'",    // 閉じ角括弧が必要
	}

	for pattern in incomplete_patterns {
		if strings.contains(msg, pattern) {
			return true
		}
	}
	return false
}
