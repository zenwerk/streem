// =============================================================================
// ストリームランタイム
// =============================================================================
//
// このファイルはStreemの中核となるストリーム処理システムを実装しています。
// Streemではデータがストリームを通じてパイプライン形式で流れます。
//
// ストリームの種類:
//   - Producer（プロデューサー）: データを生成する（stdin, seq, 配列など）
//   - Filter（フィルター）: データを変換する（map, filter, ラムダなど）
//   - Consumer（コンシューマー）: データを消費する（stdout, ファイル書き込みなど）
//
// パイプライン例:
//   seq(1, 10) | map{|x| x * 2} | stdout
//   ^Producer   ^Filter          ^Consumer
//
// 参照: src/core.c, src/strm.h (オリジナルC実装)
//
// =============================================================================
package streem

import "core:fmt"
import "core:thread"

// -----------------------------------------------------------------------------
// 戻り値コード（state.odinで定義）
// -----------------------------------------------------------------------------
// STRM_OK :: 0   // 成功
// STRM_NG :: 1   // 失敗

// -----------------------------------------------------------------------------
// ストリームモード
// -----------------------------------------------------------------------------

// Stream_Mode: ストリームの動作モードを表す列挙型
// ストリームのライフサイクルと役割を定義する
Stream_Mode :: enum {
	Producer, // プロデューサー: データを生成する（seq, stdin, ファイル読み込みなど）
	Filter,   // フィルター: データを変換する（map, filter, ラムダなど）
	Consumer, // コンシューマー: データを消費する（stdout, ファイル書き込みなど）
	Dying,    // 終了中: クローズ処理が開始されている
	Killed,   // 終了済み: 完全にクローズされた
}

// -----------------------------------------------------------------------------
// ストリームフラグ
// -----------------------------------------------------------------------------

// Stream_Flags: ストリームの状態フラグのビットセット
Stream_Flags :: bit_set[Stream_Flag]

// Stream_Flag: 個々のフラグを表す列挙型
Stream_Flag :: enum {
	Started,  // ストリームが開始された
	Closed,   // ストリームがクローズされた
}

// -----------------------------------------------------------------------------
// コールバック関数型
// -----------------------------------------------------------------------------

// Stream_Start_Func: ストリーム開始/データ処理コールバック
// データがストリームに到着したときに呼び出される
// 引数:
//   - strm: 処理対象のストリーム
//   - data: 処理するデータ
// 戻り値: STRM_OK（成功）または STRM_NG（失敗）
Stream_Start_Func :: #type proc(strm: ^Strm_Stream, data: Strm_Value) -> int

// Stream_Close_Func: ストリームクローズコールバック
// ストリームがクローズされるときに呼び出される
// リソースのクリーンアップに使用
Stream_Close_Func :: #type proc(strm: ^Strm_Stream, data: Strm_Value) -> int

// -----------------------------------------------------------------------------
// ストリーム構造体
// -----------------------------------------------------------------------------

// Strm_Stream: ストリームを表す主要な構造体
// パイプラインの各ノードを表現し、上流から下流へデータを流す
//
// 参照: src/strm.h strm_stream
Strm_Stream :: struct {
	type:       Ptr_Type,              // 型タグ（必ず先頭に配置）- 値システムでストリームを識別
	mode:       Stream_Mode,           // 動作モード（Producer/Filter/Consumer/Dying/Killed）
	flags:      Stream_Flags,          // 状態フラグ
	start_func: Stream_Start_Func,     // データ処理コールバック
	close_func: Stream_Close_Func,     // クローズコールバック
	data:       rawptr,                // ユーザーデータポインタ（各ストリーム固有のデータ）
	dst:        ^Strm_Stream,          // 主要な下流接続
	rest:       [dynamic]^Strm_Stream, // 追加の下流接続（分岐用）
	queue:      ^Strm_Queue,           // ストリーム固有のタスクキュー
	refcnt:     int,                   // 参照カウント（上流からの接続数）
	excl:       int,                   // 排他フラグ（0=利用可能、1=使用中）スレッドセーフ用
	exc:        ^Node_Error,           // 現在の例外（エラー情報）
}

// -----------------------------------------------------------------------------
// 例外（エラー）関連
// -----------------------------------------------------------------------------

// Exception_Type: 例外の種類
Exception_Type :: enum {
	None,    // 例外なし
	Runtime, // ランタイムエラー
	Return,  // return文による戻り
	Skip,    // skip文によるスキップ
}

// Node_Error: エラー/例外情報を保持する構造体
Node_Error :: struct {
	type:   Exception_Type, // 例外の種類
	arg:    Strm_Value,     // エラーメッセージまたは戻り値
	fname:  string,         // ファイル名（エラー発生位置）
	lineno: int,            // 行番号（エラー発生位置）
}

// =============================================================================
// ストリームの作成と破棄
// =============================================================================
//
// ストリームのライフサイクル:
//   1. strm_stream_new: 作成
//   2. strm_stream_connect: 接続（パイプライン構築）
//   3. データ処理（start_func が繰り返し呼ばれる）
//   4. strm_stream_close: クローズ（参照カウントが0になったら）
//   5. strm_stream_destroy: 破棄（リソース解放）
//
// =============================================================================

// strm_stream_new: 新しいストリームを作成する
// 引数:
//   - mode: ストリームの動作モード（Producer/Filter/Consumer）
//   - start_func: データ処理コールバック
//   - close_func: クローズ時のクリーンアップコールバック
//   - data: ストリーム固有のユーザーデータ
// 戻り値:
//   - 新しく作成されたストリームへのポインタ
strm_stream_new :: proc(mode: Stream_Mode, start_func: Stream_Start_Func, close_func: Stream_Close_Func, data: rawptr) -> ^Strm_Stream {
	strm := new(Strm_Stream)
	strm.type = .Stream    // 値システム用の型タグ
	strm.mode = mode
	strm.flags = {}
	strm.start_func = start_func
	strm.close_func = close_func
	strm.data = data
	strm.dst = nil
	strm.rest = make([dynamic]^Strm_Stream)
	strm.queue = strm_queue_new()  // ストリーム固有のタスクキュー
	strm.refcnt = 0                // 初期状態では参照なし
	strm.excl = 0                  // 利用可能状態
	strm.exc = nil

	// グローバルストリームカウントをインクリメント
	// イベントループの終了判定に使用
	strm_stream_count_inc()

	return strm
}

// stream_close_cb: strm_stream_close のタスクコールバックラッパー
// Task_Func のシグネチャに合わせるために必要
// （strm_stream_close は引数が異なる）
stream_close_cb :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	strm_stream_close(strm)
	return STRM_OK
}

// strm_stream_close: ストリームをクローズし、下流に伝播する
// 参照カウントを使用した遅延クローズを実装
//
// 処理フロー:
//   1. 参照カウントをデクリメント
//   2. カウントが0になったら実際にクローズ
//   3. close_func を呼び出してリソースをクリーンアップ
//   4. 下流ストリームにクローズを伝播
//
// 参照: src/core.c strm_stream_close
strm_stream_close :: proc(strm: ^Strm_Stream) {
	if strm == nil {
		return
	}

	mode := strm.mode
	// 既にクローズ済み
	if mode == .Killed {
		return
	}

	// 参照カウントをデクリメント
	// 複数の上流から接続されている場合、全てがクローズするまで待つ
	atomic_dec(&strm.refcnt)
	if strm.refcnt > 0 {
		return
	}

	// アトミックにモードをKilledに変更
	// 他のスレッドとの競合を防ぐ
	if !atomic_cas(&strm.mode, mode, Stream_Mode.Killed) {
		return
	}

	// クローズコールバックを呼び出し
	if strm.close_func != nil {
		if strm.close_func(strm, strm_nil_value()) == STRM_NG {
			return
		}
	} else {
		// クローズコールバックがない場合、データを直接解放
		if strm.data != nil {
			free(strm.data)
			strm.data = nil
		}
	}

	// 下流ストリームにクローズを伝播
	// これにより、パイプライン全体が順次クローズされる
	if strm.dst != nil {
		strm_task_push(strm.dst, stream_close_cb, strm_nil_value())
	}

	for dst in strm.rest {
		strm_task_push(dst, stream_close_cb, strm_nil_value())
	}

	// 追加接続配列を解放
	if len(strm.rest) > 0 {
		delete(strm.rest)
	}

	// グローバルストリームカウントをデクリメント
	strm_stream_count_dec()
}

// strm_stream_destroy: ストリームを即座に破棄する
// 下流への伝播なしで、全リソースを解放する
// 主にエラー時や強制終了時に使用
strm_stream_destroy :: proc(strm: ^Strm_Stream) {
	if strm == nil {
		return
	}

	// ユーザーデータを解放（close_funcで処理されていない場合）
	if strm.data != nil {
		free(strm.data)
		strm.data = nil
	}

	// 追加接続配列を解放
	delete(strm.rest)

	// タスクキューと保留中のタスクを全て破棄
	strm_task_queue_destroy(strm.queue)

	// 例外情報を解放
	if strm.exc != nil {
		free(strm.exc)
		strm.exc = nil
	}

	// ストリーム構造体自体を解放
	free(strm)
}

// =============================================================================
// ストリーム接続
// =============================================================================
//
// パイプ演算子（|）によるストリームの接続を実装
// src | dst の形式で、データが src から dst へ流れる
//
// 接続ルール:
//   - Producer/Filter は下流に接続可能
//   - Filter/Consumer は上流に接続可能
//   - Consumer からの接続は不可
//   - Producer への接続は不可
//
// =============================================================================

// strm_stream_connect: 2つのストリームを接続する（src | dst）
// 引数:
//   - src: 上流ストリーム（データの発信元）
//   - dst: 下流ストリーム（データの送信先）
// 戻り値:
//   - STRM_OK: 成功
//   - STRM_NG: 失敗
strm_stream_connect :: proc(src: ^Strm_Stream, dst: ^Strm_Stream) -> int {
	if src == nil || dst == nil {
		return STRM_NG
	}

	// モードの検証
	// Consumer からは出力できない、Producer への入力はできない
	assert(src.mode != .Consumer, "cannot connect from consumer")
	assert(dst.mode != .Producer, "cannot connect to producer")

	// 下流接続を設定
	// dst が最初の接続なら dst フィールドに、それ以降は rest 配列に追加
	if src.dst == nil {
		src.dst = dst
	} else {
		append(&src.rest, dst)
	}

	// 下流の参照カウントをアトミックにインクリメント
	// これにより、全ての上流がクローズするまで下流は存続する
	atomic_inc(&dst.refcnt)

	// ソースがプロデューサーの場合、ワーカーを初期化して開始
	// フィルターやコンシューマーは上流からのデータ到着を待つ
	if src.mode == .Producer {
		worker_init()
		strm_task_push(src, src.start_func, strm_nil_value())
	}

	return STRM_OK
}

// value_to_src_stream: 値をソースストリームに変換する
// パイプの左側（データ発信元）で使用
//
// 変換ルール:
//   - Stream: そのまま返す
//   - IO: 読み取りストリームに変換
//   - Lambda: フィルターストリームに変換
//   - Array: プロデューサーストリームに変換
//
// @(private = "file"): このファイル内でのみ使用可能
@(private = "file")
value_to_src_stream :: proc(strm: ^Strm_Stream, val: Strm_Value) -> Strm_Value {
	// 既にストリームの場合はそのまま
	if strm_stream_p(val) {
		return val
	}

	// IO → 読み取りストリーム
	if strm_io_p(val) {
		io_strm := strm_io_stream(val, STRM_IO_READ)
		if io_strm != nil {
			return strm_stream_value(io_strm)
		}
		return val
	}

	// Lambda → フィルターストリーム
	// ラムダ式は各データに対して適用される
	if strm_lambda_p(val) {
		lambda := strm_value_ptr(val, Strm_Lambda)
		new_strm := strm_stream_new(.Filter, blk_exec, nil, rawptr(lambda))
		return strm_stream_value(new_strm)
	}

	// Array → プロデューサーストリーム
	// 配列の各要素を順に出力する
	if strm_array_p(val) {
		arrd := new(Array_Data)
		arrd.arr = Strm_Array(val)
		arrd.n = 0
		new_strm := strm_stream_new(.Producer, arr_exec, nil, rawptr(arrd))
		return strm_stream_value(new_strm)
	}

	return val
}

// value_to_dst_stream: 値を宛先ストリームに変換する
// パイプの右側（データ送信先）で使用
//
// 変換ルール:
//   - Stream: そのまま返す
//   - IO: 書き込みストリームに変換
//   - Lambda: フィルターストリームに変換
//   - Cfunc: フィルターストリームに変換
//
// @(private = "file"): このファイル内でのみ使用可能
@(private = "file")
value_to_dst_stream :: proc(strm: ^Strm_Stream, val: Strm_Value) -> Strm_Value {
	// 既にストリームの場合はそのまま
	if strm_stream_p(val) {
		return val
	}

	// IO → 書き込みストリーム
	if strm_io_p(val) {
		io_strm := strm_io_stream(val, STRM_IO_WRITE)
		if io_strm != nil {
			return strm_stream_value(io_strm)
		}
		return val
	}

	// Lambda → フィルターストリーム
	if strm_lambda_p(val) {
		lambda := strm_value_ptr(val, Strm_Lambda)
		new_strm := strm_stream_new(.Filter, blk_exec, nil, rawptr(lambda))
		return strm_stream_value(new_strm)
	}

	// Cfunc（C関数）→ フィルターストリーム
	// 組み込み関数をフィルターとして使用
	if strm_cfunc_p(val) {
		func_ := strm_value_cfunc(val)
		new_strm := strm_stream_new(.Filter, cfunc_exec, cfunc_closer, rawptr(func_))
		return strm_stream_value(new_strm)
	}

	return val
}

// strm_connect: 高レベルパイプ演算子（|）の実装
// 必要に応じてIO/Lambda/Arrayをストリームに変換し、接続する
//
// 例:
//   [1, 2, 3] | {|x| x * 2} | stdout
//   ^配列       ^ラムダ        ^IO
//   ↓変換後
//   Producer | Filter | Consumer
//
// 参照: src/exec.c strm_connect
strm_connect :: proc(strm: ^Strm_Stream, src_val: Strm_Value, dst_val: Strm_Value, ret: ^Strm_Value) -> int {
	// ソース値をストリームに変換
	src := value_to_src_stream(strm, src_val)

	// 宛先値をストリームに変換
	dst := value_to_dst_stream(strm, dst_val)

	// 両方がストリームであることを確認
	if strm_stream_p(src) && strm_stream_p(dst) {
		lstrm := strm_value_ptr(src, Strm_Stream)
		rstrm := strm_value_ptr(dst, Strm_Stream)

		// 接続の妥当性を検証
		if lstrm == nil || rstrm == nil ||
		   lstrm.mode == .Consumer ||
		   rstrm.mode == .Producer {
			strm_raise(strm, "stream error")
			return STRM_NG
		}

		// 実際に接続
		strm_stream_connect(lstrm, rstrm)
		ret^ = dst
		return STRM_OK
	}

	return STRM_NG
}

// strm_stream_value: ストリームポインタからStrm_Valueを作成する
// ストリームを値システムで扱えるように変換
strm_stream_value :: proc(strm: ^Strm_Stream) -> Strm_Value {
	return strm_ptr_value(rawptr(strm))
}

// strm_value_stream: Strm_Valueからストリームを取り出す
// 値がストリームでない場合は nil を返す
strm_value_stream :: proc(v: Strm_Value) -> ^Strm_Stream {
	if !strm_stream_p(v) {
		return nil
	}
	return strm_value_ptr(v, Strm_Stream)
}

// =============================================================================
// データ送出（Emission）
// =============================================================================
//
// ストリーム間のデータ転送を担当
// 上流ストリームが strm_emit を呼び出すと、データが下流に送られる
//
// 参照: src/core.c strm_emit
//
// =============================================================================

// strm_emit: 下流ストリームにデータを送出する
// これがStreemのデータフローの中核
//
// 引数:
//   - strm: データを送出するストリーム
//   - data: 送出するデータ
//   - cb: 継続コールバック（プロデューサーが次のデータを生成するために使用）
//
// 動作:
//   1. 下流ストリームにデータを送る（タスクとしてキューに追加）
//   2. 下流が終了していないかチェック
//   3. 全下流が終了していたら自身も終了開始
//   4. 継続コールバックがあれば、次のデータ生成をスケジュール
strm_emit :: proc(strm: ^Strm_Stream, data: Strm_Value, cb: Stream_Start_Func) {
	if strm == nil {
		return
	}

	// 終了中のストリームからは送出しない
	if strm.mode == .Dying {
		return
	}

	// nil以外のデータのみ送出
	if !strm_nil_p(data) {
		// 主要な下流にデータを送出
		if strm.dst != nil {
			strm_task_push(strm.dst, strm.dst.start_func, data)
			// 下流が終了していたら接続を切る
			if strm.dst.mode == .Killed {
				strm.dst = nil
			}
		}

		// 追加の下流接続にもデータを送出（分岐の場合）
		for dst in strm.rest {
			strm_task_push(dst, dst.start_func, data)
		}

		// 終了判定: 全ての下流が終了/消滅している場合
		if strm.dst == nil {
			closed := true
			for dst in strm.rest {
				if dst.mode != .Killed {
					closed = false
					break
				}
			}
			if closed {
				// 送り先がなくなったので自身も終了開始
				strm.mode = .Dying
				return
			}
		}
	}

	// 他のスレッドに実行機会を与える
	// これにより公平なスケジューリングを実現
	thread.yield()

	// 継続コールバックが指定されていれば、自身にタスクを追加
	// これにより、プロデューサーは再帰的にデータを生成し続けられる
	// 例: seq(1, 10) は各数を出力後、次の数の生成をスケジュール
	if cb != nil {
		strm_task_push(strm, cb, strm_nil_value())
	}
}

// strm_io_emit: IOコールバック付きのデータ送出
// 将来的には epoll/kqueue を使用したIO対応の送出を実装予定
// 現在は通常の strm_emit にフォールバック
strm_io_emit :: proc(strm: ^Strm_Stream, data: Strm_Value, fd: int, cb: Stream_Start_Func) {
	// TODO: Phase 13 - epoll/kqueue を使用したIO対応の送出を実装
	strm_emit(strm, data, cb)
}

// =============================================================================
// 例外処理
// =============================================================================
//
// Streemの例外処理機構
// ストリーム処理中のエラーや制御フロー（return, skip）を管理
//
// 参照: src/exec.c
//
// =============================================================================

// strm_raise: ランタイムエラーを発生させる
// エラーメッセージを指定して例外を設定
// 引数:
//   - strm: 例外を発生させるストリーム
//   - msg: エラーメッセージ
strm_raise :: proc(strm: ^Strm_Stream, msg: string) {
	if strm == nil {
		return
	}

	strm_set_exc(strm, .Runtime, strm_str_value(strm_str_new(msg)))
}

// strm_set_exc: 例外を設定する
// 例外の種類と引数を指定して設定
// 引数:
//   - strm: 例外を設定するストリーム
//   - type: 例外の種類（Runtime, Return, Skip）
//   - arg: 例外の引数（エラーメッセージや戻り値）
// 戻り値:
//   - 作成された例外構造体へのポインタ
strm_set_exc :: proc(strm: ^Strm_Stream, type: Exception_Type, arg: Strm_Value) -> ^Node_Error {
	if strm == nil {
		return nil
	}

	// 既存の例外をクリア
	strm_clear_exc(strm)

	// 新しい例外を作成
	exc := new(Node_Error)
	exc.type = type
	exc.arg = arg
	exc.fname = ""   // ファイル名（後で設定可能）
	exc.lineno = 0   // 行番号（後で設定可能）
	strm.exc = exc

	return exc
}

// strm_clear_exc: 例外をクリアする
// ストリームに設定されている例外を解放
strm_clear_exc :: proc(strm: ^Strm_Stream) {
	if strm == nil || strm.exc == nil {
		return
	}
	free(strm.exc)
	strm.exc = nil
}

// strm_eprint: 例外を標準エラーに出力する
// エラー情報をユーザーに表示
//
// 出力フォーマット:
//   ファイル名:行番号: エラーメッセージ
//
// 参照: src/exec.c strm_eprint
strm_eprint :: proc(strm: ^Strm_Stream) {
	if strm == nil || strm.exc == nil {
		return
	}

	exc := strm.exc

	// skip例外は表示しない（制御フロー用のため）
	if exc.type == .Skip {
		return
	}

	// ファイル名と行番号がある場合は表示
	if exc.fname != "" {
		fmt.eprintf("%s:%d:", exc.fname, exc.lineno)
	}

	// エラーメッセージを出力
	msg := strm_to_str(exc.arg)
	fmt.eprintln(msg)

	// 出力後に例外をクリア
	strm_clear_exc(strm)
}

// =============================================================================
// エラー伝播
// =============================================================================
//
// エラー発生時に下流ストリームに通知し、パイプライン全体を停止させる
//
// 参照: src/core.c
//
// =============================================================================

// strm_propagate_error: 下流ストリームにエラーを伝播する
// エラーが発生した場合、下流ストリームに停止を通知する必要がある
//
// 処理フロー:
//   1. 現在のストリームにエラーを設定・出力
//   2. ストリームをDying状態に変更
//   3. 下流ストリームにクローズを伝播
strm_propagate_error :: proc(strm: ^Strm_Stream, msg: string) {
	if strm == nil {
		return
	}

	// 現在のストリームにエラーを設定して出力
	strm_raise(strm, msg)
	strm_eprint(strm)

	// Dying状態に変更（これ以上データを処理しない）
	strm.mode = .Dying

	// 下流ストリームにクローズを伝播してクリーンアップをトリガー
	if strm.dst != nil {
		strm_task_push(strm.dst, stream_close_cb, strm_nil_value())
	}
	for dst in strm.rest {
		strm_task_push(dst, stream_close_cb, strm_nil_value())
	}
}

// =============================================================================
// ストリームキャンセル
// =============================================================================
//
// ストリームの強制終了機能
// 通常のクローズとは異なり、即座にストリームを停止させる
//
// 参照: src/core.c
//
// =============================================================================

// strm_cancel: ストリームとその下流全てをキャンセルする
// 強制的なキャンセルで、即座にストリームをKilled状態にする
//
// 使用場面:
//   - エラーからの回復
//   - タイムアウト
//   - ユーザーによる中断
strm_cancel :: proc(strm: ^Strm_Stream) {
	if strm == nil {
		return
	}

	// 既にキャンセル済みまたは終了済み
	if strm.mode == .Killed || strm.mode == .Dying {
		return
	}

	// まずDying状態に変更
	strm.mode = .Dying

	// 下流ストリームを再帰的にキャンセル
	if strm.dst != nil {
		strm_cancel(strm.dst)
	}
	for dst in strm.rest {
		strm_cancel(dst)
	}

	// このストリームをクローズ
	strm_stream_close(strm)
}

// strm_cancel_upstream: 上流に停止を通知する
// コンシューマーが早期に停止したい場合に使用（例: take(n)）
//
// 動作:
//   自身をDying状態に変更することで、上流からの新しいデータを
//   受け付けないことを示す。上流は下流がDyingであることを検出し、
//   データ生成を停止する。
strm_cancel_upstream :: proc(strm: ^Strm_Stream) {
	if strm == nil {
		return
	}

	// Dying状態に変更して、これ以上データを受け取らないことを示す
	strm.mode = .Dying
}

// =============================================================================
// ストリーム実行ヘルパー
// =============================================================================
//
// 値からストリームへの変換時に使用される実行関数群
// 配列、ラムダ、C関数をストリームとして動作させる
//
// 参照: src/exec.c
//
// =============================================================================

// Array_Data: 配列→プロデューサー変換用のデータ構造
// 配列の各要素を順に出力するプロデューサーストリームで使用
Array_Data :: struct {
	n:   int,         // 現在のインデックス（次に出力する要素の位置）
	arr: Strm_Array,  // 元の配列
}

// arr_exec: 配列プロデューサーの実行関数
// 配列の要素を1つずつ下流に送出する
//
// 動作:
//   1. 現在のインデックスの要素を送出
//   2. インデックスをインクリメント
//   3. 自身を継続コールバックとして登録（次の要素の送出）
//   4. 配列の終端に達したらクローズ
//
// 参照: src/exec.c arr_exec
arr_exec :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	arrd := cast(^Array_Data)strm.data
	ary_len := int(strm_ary_len(arrd.arr))

	// 配列の終端に達したらクローズ
	if arrd.n == ary_len {
		strm_stream_close(strm)
		return STRM_OK
	}

	// 現在の要素を送出し、arr_exec を継続コールバックとして渡す
	// これにより次の要素の送出がスケジュールされる
	ptr := strm_ary_ptr(arrd.arr)
	strm_emit(strm, ptr[arrd.n], arr_exec)
	arrd.n += 1

	return STRM_OK
}

// blk_exec: ラムダ/ブロックの実行関数
// フィルターストリームとして、入力データにラムダを適用し結果を送出
//
// 動作:
//   1. クロージャの環境を親として新しいスコープを作成
//   2. 入力データを引数としてバインド
//   3. ラムダ本体を実行
//   4. 結果を下流に送出
//
// 例:
//   seq(1, 5) | {|x| x * 2}
//   → 各数値に対して blk_exec が呼ばれ、x に値がバインドされ、
//     x * 2 が評価されて結果が送出される
//
// 参照: src/exec.c blk_exec
blk_exec :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	lambda := cast(^Strm_Lambda)strm.data
	if lambda == nil {
		return STRM_NG
	}
	ret := strm_nil_value()

	// クロージャの環境を親として実行用スコープを作成
	// これによりラムダ定義時の変数にアクセス可能
	c := strm_state_new(lambda.state)
	defer strm_state_destroy(c)

	// ラムダの引数情報を取得
	nlmbd := lambda.body
	if nlmbd.type != .Lambda {
		return STRM_NG
	}

	lambda_data := &nlmbd.data.(Node_Lambda)

	// 引数がある場合、入力データをバインド
	if lambda_data.args != nil {
		if lambda_data.args.type == .Args {
			// 引数リスト形式: {|x, y| ...}
			arg_names := &lambda_data.args.data.(Node_Args)
			if len(arg_names.names) == 1 {
				arg_name := strm_str_intern(arg_names.names[0])
				strm_var_set(c, arg_name, data)
			}
		} else if lambda_data.args.type == .Ident {
			// 単一識別子形式: {|x| ...}
			arg_ident := &lambda_data.args.data.(Node_Ident)
			arg_name := strm_str_intern(arg_ident.name)
			strm_var_set(c, arg_name, data)
		}
	}

	// ラムダ本体を実行
	result := exec_expr(strm, c, lambda_data.body, &ret)

	// 例外の処理
	exc := strm.exc
	if exc != nil {
		if exc.type == .Return {
			// return文による戻りは正常な制御フロー
			ret = exc.arg
			strm_clear_exc(strm)
		} else {
			// その他の例外はエラー
			return STRM_NG
		}
	}

	if result != .Ok {
		return STRM_NG
	}

	// 結果を下流に送出
	strm_emit(strm, ret, nil)
	return STRM_OK
}

// cfunc_exec: C関数（組み込み関数）の実行関数
// 組み込み関数をフィルターストリームとして実行
//
// 動作:
//   入力データを引数として組み込み関数を呼び出し、
//   結果を下流に送出
//
// 参照: src/exec.c cfunc_exec
cfunc_exec :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	func_ := cast(Strm_Cfunc)strm.data
	ret: Strm_Value

	// 入力データを引数として関数を呼び出し
	args := []Strm_Value{data}
	if func_(strm, 1, args, &ret) == STRM_OK {
		strm_emit(strm, ret, nil)
		return STRM_OK
	}
	return STRM_NG
}

// cfunc_closer: C関数フィルターのクローズ関数
// 特にクリーンアップは不要（no-op）
//
// 参照: src/exec.c cfunc_closer
cfunc_closer :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	return STRM_OK
}
