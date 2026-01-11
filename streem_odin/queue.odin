// =============================================================================
// タスクキューとワーカースレッドプール
// =============================================================================
//
// このファイルはStreemのマルチスレッド実行基盤を実装しています。
// Streemではストリーム処理が並行に実行され、複数のワーカースレッドが
// タスクキューからタスクを取り出して処理します。
//
// アーキテクチャ:
//   - 2つのグローバルキュー: プロデューサー用とコンシューマー/フィルター用
//   - 各ストリームは独自のタスクキューを持つ
//   - ワーカースレッドはセマフォで待機し、タスク追加時に起床
//   - アトミック操作により排他制御を実現
//
// 参照: src/queue.c, src/atomic.h, src/core.c (オリジナルC実装)
//
// =============================================================================
package streem

import "core:container/queue"
import "core:sync"
import "core:thread"
import "core:os"
import "core:strconv"

// -----------------------------------------------------------------------------
// タスク関連の型定義
// -----------------------------------------------------------------------------

// Task_Func: タスクコールバック関数の型
// ストリーム処理の各ステップ（データ生成、変換、消費）を表す
// 引数:
//   - strm: 処理対象のストリーム
//   - data: タスクに渡されるデータ（ストリームを流れる値）
// 戻り値:
//   - STRM_OK (0): 成功
//   - STRM_NG (-1): エラー
Task_Func :: #type proc(strm: ^Strm_Stream, data: Strm_Value) -> int

// Strm_Task: タスク構造体
// ストリームで実行される個々の処理単位を表す
Strm_Task :: struct {
	func_: Task_Func,   // 実行する関数
	data:  Strm_Value,  // 関数に渡すデータ
}

// Strm_Queue: スレッドセーフなFIFOキュー
// core:container/queue をミューテックスでラップして排他制御を提供
// 複数のワーカースレッドから同時にアクセスされるため必要
Strm_Queue :: struct {
	data:  queue.Queue(rawptr),  // 内部キュー（汎用ポインタを格納）
	mutex: sync.Mutex,           // 排他制御用ミューテックス
}

// =============================================================================
// グローバルワーカー状態
// =============================================================================
//
// Streemのランタイムは以下のグローバル状態を管理します:
//   - prod_queue: プロデューサータスク用キュー（データ生成側）
//   - work_queue: コンシューマー/フィルタータスク用キュー（データ処理側）
//   - workers: ワーカースレッドの配列
//   - task_sema: タスク待機用セマフォ
//
// タスクの優先順位:
//   work_queue (コンシューマー) > prod_queue (プロデューサー)
//   これにより、データが滞留せずに処理されることを保証
//
// =============================================================================

// Strm_Worker: ワーカースレッド構造体
// 各ワーカーは独立したスレッドでタスクを処理する
Strm_Worker :: struct {
	th: ^thread.Thread,  // OSスレッドへのポインタ
}

// prod_queue: プロデューサー用グローバルキュー
// データを生成するストリーム（stdin, seq など）のタスクを保持
// @(private = "file"): このファイル内でのみアクセス可能
@(private = "file")
prod_queue: ^Strm_Queue = nil

// work_queue: コンシューマー/フィルター用グローバルキュー
// データを処理・消費するストリーム（map, filter, stdout など）のタスクを保持
@(private = "file")
work_queue: ^Strm_Queue = nil

// task_sema: タスク待機用セマフォ
// ワーカースレッドはこのセマフォで待機し、タスク追加時にシグナルを受け取る
// これによりビジーウェイトを回避し、CPU効率を向上
@(private = "file")
task_sema: sync.Sema

// workers: ワーカースレッドの動的配列
// プログラム起動時に worker_max 個のスレッドが作成される
@(private = "file")
workers: [dynamic]Strm_Worker

// worker_max: ワーカースレッドの最大数
// 環境変数 STRM_WORKER_MAX または CPU数から決定
@(private = "file")
worker_max: int = 0

// stream_count: アクティブなストリームの数（アトミック変数）
// 全てのストリームが終了したかを判定するために使用
// アトミック操作で更新され、スレッドセーフ
@(private = "file")
stream_count: int = 0

// strm_event_loop_started: イベントループが開始されたかのフラグ
// true: ワーカースレッドが起動済み
// 外部からアクセス可能（他のモジュールがループ状態を確認するため）
strm_event_loop_started: bool = false

// workers_should_stop: ワーカー停止シグナルフラグ
// true: ワーカースレッドは処理を終了して終了すべき
// worker_cleanup() で設定される
@(private = "file")
workers_should_stop: bool = false

// =============================================================================
// タスク操作
// =============================================================================

// strm_task_new: 新しいタスクを作成する
// 引数:
//   - func_: タスクとして実行する関数
//   - data: 関数に渡すデータ
// 戻り値:
//   - 新しく作成されたタスクへのポインタ
strm_task_new :: proc(func_: Task_Func, data: Strm_Value) -> ^Strm_Task {
	task := new(Strm_Task)
	task.func_ = func_
	task.data = data
	return task
}

// strm_task_destroy: タスクを破棄する
// タスク実行後にメモリを解放する
strm_task_destroy :: proc(task: ^Strm_Task) {
	if task != nil {
		free(task)
	}
}

// strm_task_push: ストリームにタスクをプッシュする
// タスクを作成し、ストリームのキューに追加する便利関数
//
// 処理フロー:
//   1. タスクを作成
//   2. ストリームのローカルキューに追加
//   3. ストリームをグローバルキューに追加
//   4. ワーカーにシグナルを送信
//
// 引数:
//   - strm: タスクを追加するストリーム
//   - func_: 実行する関数
//   - data: 関数に渡すデータ
strm_task_push :: proc(strm: ^Strm_Stream, func_: Task_Func, data: Strm_Value) {
	if strm == nil {
		return
	}
	// 終了中または強制終了されたストリームには追加しない
	if strm.mode == .Killed || strm.mode == .Dying {
		return
	}

	task := strm_task_new(func_, data)
	strm_task_add(strm, task)
}

// strm_task_add: タスクをストリームのキューに追加し、グローバルキューにも登録
// これがタスクスケジューリングの中核となる関数
//
// 2段階キュー構造:
//   1. ストリーム固有のキュー: そのストリームの保留タスクを保持
//   2. グローバルキュー: 処理待ちのストリームを保持
//
// ワーカーはグローバルキューからストリームを取得し、
// そのストリームのローカルキューから全タスクを処理する
strm_task_add :: proc(strm: ^Strm_Stream, task: ^Strm_Task) {
	if strm == nil || strm.queue == nil {
		return
	}

	// ストリーム固有のキューにタスクを追加
	strm_queue_add(strm.queue, task)

	// ストリームのモードに応じて適切なグローバルキューに追加
	// プロデューサー: データ生成（stdin, seq など）
	// それ以外: データ処理（map, filter, stdout など）
	if strm.mode == .Producer {
		strm_queue_add(prod_queue, strm)
	} else {
		strm_queue_add(work_queue, strm)
	}

	// 待機中のワーカースレッドにタスクが利用可能になったことを通知
	sync.sema_post(&task_sema)
}

// =============================================================================
// キュー操作
// =============================================================================
//
// 基本的なFIFO（First-In-First-Out）キュー操作を提供
// 全ての操作はミューテックスで保護され、スレッドセーフ
//
// =============================================================================

// strm_queue_new: 新しいキューを作成する
// 戻り値:
//   - 初期化されたキューへのポインタ
strm_queue_new :: proc() -> ^Strm_Queue {
	q := new(Strm_Queue)
	queue.init(&q.data)
	return q
}

// strm_queue_destroy: キューを破棄する
// キュー構造体のみを解放し、格納されている値は解放しない
// （値は別の場所で管理されている: ストリームまたはタスク）
//
// 注意: グローバルキューの破棄に使用
// タスクキューには strm_task_queue_destroy を使用すること
strm_queue_destroy :: proc(q: ^Strm_Queue) {
	if q == nil {
		return
	}
	queue.destroy(&q.data)
	free(q)
}

// strm_task_queue_destroy: タスクキューを破棄する
// ストリーム固有のタスクキュー用。残っているタスクも解放する
//
// 使用場面:
//   - ストリームのクローズ時
//   - エラーによるストリームの強制終了時
strm_task_queue_destroy :: proc(q: ^Strm_Queue) {
	if q == nil {
		return
	}

	// 残っているタスクを全て解放
	// ストリームが途中で終了した場合、未処理タスクが残っている可能性がある
	for queue.len(q.data) > 0 {
		val := queue.pop_front(&q.data)
		if val != nil {
			strm_task_destroy(cast(^Strm_Task)val)
		}
	}

	queue.destroy(&q.data)
	free(q)
}

// strm_queue_add: キューの末尾に要素を追加する（エンキュー）
// スレッドセーフ: ミューテックスで保護
// 引数:
//   - q: 対象のキュー
//   - val: 追加する値（rawptr型）
strm_queue_add :: proc(q: ^Strm_Queue, val: rawptr) {
	if q == nil {
		return
	}

	// クリティカルセクション開始
	sync.mutex_lock(&q.mutex)
	defer sync.mutex_unlock(&q.mutex)  // 関数終了時に自動的にアンロック

	queue.push_back(&q.data, val)
}

// strm_queue_get: キューの先頭から要素を取り出す（デキュー）
// スレッドセーフ: ミューテックスで保護
// 引数:
//   - q: 対象のキュー
// 戻り値:
//   - 取り出した値、キューが空の場合は nil
strm_queue_get :: proc(q: ^Strm_Queue) -> rawptr {
	if q == nil {
		return nil
	}

	// クリティカルセクション開始
	sync.mutex_lock(&q.mutex)
	defer sync.mutex_unlock(&q.mutex)

	// キューが空の場合は nil を返す
	if queue.len(q.data) == 0 {
		return nil
	}

	return queue.pop_front(&q.data)
}

// strm_queue_empty_p: キューが空かどうかを確認する
// 注意: この関数はスレッドセーフではない（ミューテックスを取得しない）
// 引数:
//   - q: 対象のキュー
// 戻り値:
//   - true: キューが空または nil
//   - false: キューに要素がある
strm_queue_empty_p :: proc(q: ^Strm_Queue) -> bool {
	if q == nil {
		return true
	}
	return queue.len(q.data) == 0
}

// =============================================================================
// ストリームカウント管理（アトミック操作）
// =============================================================================
//
// アクティブなストリームの数を追跡し、全てのストリームが完了したかを判定
// アトミック操作を使用してスレッドセーフに更新
//
// =============================================================================

// strm_stream_count_inc: ストリームカウントをインクリメント
// 新しいストリームが作成されたときに呼び出される
strm_stream_count_inc :: proc() {
	atomic_inc(&stream_count)
}

// strm_stream_count_dec: ストリームカウントをデクリメント
// ストリームがクローズされたときに呼び出される
// カウントが0になると、イベントループが終了条件を満たす
strm_stream_count_dec :: proc() {
	atomic_dec(&stream_count)
}

// strm_stream_count_get: 現在のストリームカウントを取得
// イベントループの終了判定に使用
// 戻り値:
//   - 現在アクティブなストリームの数
strm_stream_count_get :: proc() -> int {
	return atomic_load(&stream_count)
}

// =============================================================================
// ワーカースレッドプール
// =============================================================================
//
// Streemの並行処理エンジン。複数のワーカースレッドがタスクキューから
// タスクを取り出して並行に処理する。
//
// 参照: src/core.c (オリジナルC実装)
//
// =============================================================================

// worker_count: ワーカースレッドの数を決定する
// 環境変数 STRM_WORKER_MAX が設定されていればその値を使用、
// 設定されていなければデフォルト値（4）を使用
//
// 戻り値:
//   - ワーカースレッドの数
worker_count :: proc() -> int {
	// 環境変数から読み取りを試行
	env_val, ok := os.lookup_env("STRM_WORKER_MAX")
	if ok {
		n, parse_ok := strconv.parse_int(env_val)
		if parse_ok && n > 0 {
			return n
		}
	}

	// デフォルトは4ワーカー
	// 注: プラットフォーム固有のCPU検出も可能だが、4は妥当なデフォルト値
	return 4
}

// task_exec: 単一のタスクを実行する
// ワーカースレッドから呼び出され、タスクの関数を実行する
//
// 処理フロー:
//   1. タスクから関数とデータを取り出す
//   2. タスク構造体を解放
//   3. 関数を実行
//   4. エラー時はストリームを終了状態に遷移
//   5. Dying状態のストリームをクローズ
//
// @(private = "file"): このファイル内でのみアクセス可能
@(private = "file")
task_exec :: proc(strm: ^Strm_Stream, task: ^Strm_Task) {
	// タスクから情報を取り出し、すぐに解放
	// （関数実行中にタスク構造体は不要）
	func_ := task.func_
	data := task.data

	free(task)

	// 強制終了されたストリームは処理しない
	if strm.mode == .Killed {
		return
	}

	// タスク関数を実行
	if func_ != nil {
		result := func_(strm, data)
		if result != STRM_OK {
			// エラー発生 - エラー情報を出力
			if strm.exc != nil {
				strm_eprint(strm)
			}
			// クリーンアップをトリガーするためにDying状態に遷移
			if strm.mode != .Killed {
				strm.mode = .Dying
			}
		}
	}

	// Dying状態のストリームをクローズ
	if strm.mode == .Dying {
		strm_stream_close(strm)
	}
}

// task_loop: ワーカースレッドのメイン関数
// 各ワーカースレッドはこの関数を実行し、タスクを処理し続ける
//
// 動作:
//   1. セマフォでタスクを待機（CPU効率のため、ビジーウェイトではない）
//   2. グローバルキューからストリームを取得（work_queue優先）
//   3. ストリームの排他アクセスを取得
//   4. ストリームの全タスクを処理
//   5. 排他アクセスを解放
//   6. 1に戻る
//
// 終了条件:
//   - workers_should_stop が true
//   - 全てのストリームが完了（stream_count == 0）
@(private = "file")
task_loop :: proc(t: ^thread.Thread) {
	for {
		// 停止フラグをチェック
		if workers_should_stop {
			break
		}

		// 全ストリームが完了したかチェック
		if strm_stream_count_get() == 0 {
			break
		}

		// タスクが利用可能になるまで待機
		// sema_wait はタスクがポストされるかシャットダウンで起こされるまでブロック
		sync.sema_wait(&task_sema)

		// 起床後に再度停止条件をチェック
		if workers_should_stop {
			break
		}

		// まずwork_queue（コンシューマー/フィルター）を試し、
		// なければprod_queue（プロデューサー）を試す
		// これによりデータが滞留せずに処理される
		strm := cast(^Strm_Stream)strm_queue_get(work_queue)
		if strm == nil {
			strm = cast(^Strm_Stream)strm_queue_get(prod_queue)
		}

		if strm != nil {
			// このストリームへの排他アクセスを取得
			// CAS（Compare-And-Swap）でアトミックに0→1に変更
			// 他のワーカーが既に処理中なら失敗
			if atomic_cas(&strm.excl, 0, 1) {
				// ストリームのキューにある全タスクを処理
				for {
					task := cast(^Strm_Task)strm_queue_get(strm.queue)
					if task == nil {
						break
					}
					task_exec(strm, task)
				}
				// 排他アクセスを解放（1→0に戻す）
				atomic_cas(&strm.excl, 1, 0)
			}
		}
	}
}

// worker_init: ワーカースレッドを初期化する
// 最初のストリーム接続時に遅延初期化される
//
// 初期化内容:
//   1. グローバルキューの作成
//   2. ワーカースレッドの生成と起動
worker_init :: proc() {
	// 既に初期化済み？
	if len(workers) > 0 {
		return
	}

	// イベントループ開始フラグを設定
	strm_event_loop_started = true
	workers_should_stop = false

	// グローバルキューがまだなければ初期化
	if prod_queue == nil {
		prod_queue = strm_queue_new()
	}
	if work_queue == nil {
		work_queue = strm_queue_new()
	}

	// TODO: IOループの初期化（Phase 13で実装予定）
	// strm_init_io_loop()

	// ワーカー数を決定
	worker_max = worker_count()

	// ワーカースレッドを作成して起動
	workers = make([dynamic]Strm_Worker, worker_max)
	for i in 0 ..< worker_max {
		workers[i].th = thread.create(task_loop)
		if workers[i].th != nil {
			thread.start(workers[i].th)
		}
	}
}

// worker_cleanup: ワーカースレッドをクリーンアップする
// プログラム終了時や全ストリーム完了後に呼び出される
//
// 処理フロー:
//   1. 停止シグナルを設定
//   2. 全ワーカーを起床（停止フラグを確認させる）
//   3. 全ワーカーの終了を待機（join）
//   4. リソースを解放
worker_cleanup :: proc() {
	// ワーカーに停止を通知
	workers_should_stop = true

	// 待機中の全ワーカーを起床して停止フラグを確認させる
	for _ in 0 ..< worker_max {
		sync.sema_post(&task_sema)
	}

	// 全ワーカーの終了を待機
	for &w in workers {
		if w.th != nil {
			thread.join(w.th)     // スレッドの終了を待機
			thread.destroy(w.th)  // スレッドリソースを解放
			w.th = nil
		}
	}

	// ワーカー配列を解放
	delete(workers)

	// グローバルキューを解放
	strm_queue_destroy(prod_queue)
	strm_queue_destroy(work_queue)
	prod_queue = nil
	work_queue = nil

	strm_event_loop_started = false
}

// strm_loop: メインイベントループ
// 全てのストリームが完了するまで待機する
//
// これがStreemプログラムの実行エンジン。
// パイプラインで接続された全ストリームの処理が完了するまでブロックする。
//
// 戻り値:
//   - STRM_OK: 正常終了
strm_loop :: proc() -> int {
	// ストリームがなければ何もしない
	if strm_stream_count_get() == 0 {
		return STRM_OK
	}

	// ワーカーがまだ初期化されていなければ初期化
	worker_init()

	// 全ストリームが完了するまで待機
	// thread.yield() で他のスレッドに実行機会を与えながらポーリング
	for {
		thread.yield()
		if strm_stream_count_get() == 0 {
			break
		}
	}

	return STRM_OK
}
