package streem

// ============================================================================
// I/Oストリーム (I/O Streams)
// ============================================================================
// ファイルや標準入出力に対する読み書きを行うストリームを提供する。
// Streemにおいて、stdin/stdoutはパイプラインの入口・出口として機能する。
//
// 参照: src/io.c
//
// 概要:
//   - IOオブジェクト: ファイルディスクリプタをラップする構造体
//   - 読み取りストリーム: 行単位で入力を読み取るProducerストリーム
//   - 書き込みストリーム: データを出力するConsumerストリーム
//
// 使用例（Streemコード）:
//   stdin | stdout              # 標準入力を標準出力にそのまま出力
//   stdin | {|x| x.upcase} | stdout   # 大文字に変換して出力
//   file("input.txt") | stdout  # ファイルを読み取って出力
//
// 実装メモ:
//   core:bufio を使用して行単位のバッファリング読み取りを実現。
//   これにより効率的な行指向の入力処理が可能。

import "core:bufio"
import "core:io"
import "core:os"

// ============================================================================
// IOモードフラグ (IO Mode Flags)
// ============================================================================
// IOオブジェクトの動作モードを示すフラグ。

// IO_Mode - IOの動作モード列挙型
IO_Mode :: enum {
	Read,    // 読み取りモード
	Write,   // 書き込みモード
	Flush,   // フラッシュモード（書き込み直後にバッファをフラッシュ）
	Reading, // 読み取り中フラグ（ストリームが作成済み）
}

// IO_Modes - モードフラグのビットセット
// 複数のモードを組み合わせて指定可能
IO_Modes :: bit_set[IO_Mode]

// 定義済みモード定数
STRM_IO_READ :: IO_Modes{.Read}    // 読み取り専用
STRM_IO_WRITE :: IO_Modes{.Write}  // 書き込み専用
STRM_IO_FLUSH :: IO_Modes{.Flush}  // フラッシュ有効

// ============================================================================
// IO構造体 (IO Structure)
// ============================================================================
// ファイルディスクリプタとストリームキャッシュを保持する。
// 参照: src/strm.h strm_io

// Strm_IO - IOオブジェクト
// ファイル/標準入出力を表現する構造体。
// 一つのIOオブジェクトから読み取り/書き込みストリームを生成できる。
Strm_IO :: struct {
	type:         Ptr_Type,       // 型タグ（先頭に配置必須）: Ptr_Type.IO
	fd:           os.Handle,      // ファイルディスクリプタ
	mode:         IO_Modes,       // 動作モード
	read_stream:  ^Strm_Stream,   // 読み取りストリーム（キャッシュ）
	write_stream: ^Strm_Stream,   // 書き込みストリーム（キャッシュ）
}

// ============================================================================
// IOオブジェクトの作成 (IO Creation)
// ============================================================================

// ----------------------------------------------------------------------------
// strm_io_new - 新しいIOオブジェクトを作成
// ----------------------------------------------------------------------------
// ファイルディスクリプタをラップしたIOオブジェクトを生成する。
//
// 引数:
//   fd   - ファイルディスクリプタ（os.stdin, os.stdout, または os.open() の結果）
//   mode - IOモード（STRM_IO_READ, STRM_IO_WRITE など）
//
// 戻り値:
//   IOオブジェクトを保持するStrm_Value
//
// 参照: src/io.c strm_io_new
strm_io_new :: proc(fd: os.Handle, mode: IO_Modes) -> Strm_Value {
	io := new(Strm_IO)
	io.type = .IO
	io.fd = fd
	io.mode = mode
	io.read_stream = nil   // 遅延初期化（最初のアクセス時に作成）
	io.write_stream = nil  // 遅延初期化
	return strm_ptr_value(rawptr(io))
}

// ----------------------------------------------------------------------------
// strm_value_io - Strm_ValueからIOオブジェクトを取得
// ----------------------------------------------------------------------------
// 値がIOオブジェクトであれば、そのポインタを返す。
//
// 引数:
//   v - 検査する値
//
// 戻り値:
//   IOオブジェクトのポインタ、またはnil（IOでない場合）
strm_value_io :: proc(v: Strm_Value) -> ^Strm_IO {
	if !strm_io_p(v) {
		return nil
	}
	return strm_value_ptr(v, Strm_IO)
}

// ============================================================================
// 読み取りストリーム (Read Stream)
// ============================================================================
// core:bufio を使用した行単位の読み取りを実現する。
// Producerストリームとして動作し、各行をパイプラインに送出する。

// Read_Data - 読み取りストリームの内部データ
// bufio.Scannerを使用して効率的な行読み取りを行う。
Read_Data :: struct {
	fd:           os.Handle,       // ファイルディスクリプタ
	io_obj:       ^Strm_IO,        // 親IOオブジェクトへの参照
	scanner:      bufio.Scanner,   // 行単位スキャナ
	stream:       io.Stream,       // 低レベルI/Oストリーム
}

// ----------------------------------------------------------------------------
// read_cb - 読み取りコールバック
// ----------------------------------------------------------------------------
// bufio.Scannerを使用して次の行を読み取り、パイプラインに送出する。
// 行が存在する限り自身を再スケジュールし、継続的に読み取りを行う。
//
// 処理フロー:
//   1. スキャナで次の行を取得
//   2. 行があれば文字列に変換してemit
//   3. 次の読み取りのためにread_cbを再スケジュール
//   4. EOF またはエラーでストリームをクローズ
//
// 引数:
//   strm - 読み取りストリーム
//   data - コールバックデータ（未使用）
//
// 戻り値:
//   STRM_OK
@(private = "file")
read_cb :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	rd := cast(^Read_Data)strm.data

	// 次の行をスキャン
	if bufio.scanner_scan(&rd.scanner) {
		line := bufio.scanner_text(&rd.scanner)
		// スキャナはバッファを再利用するため、行をコピーする必要がある
		s := strm_str_new(line)
		// 行を送出し、次の読み取りをスケジュール
		strm_emit(strm, strm_str_value(s), read_cb)
		return STRM_OK
	}

	// エラーチェック
	if rd.scanner._err != nil {
		// I/Oエラー発生
		strm_stream_close(strm)
		return STRM_OK
	}

	// EOF到達：ストリームを正常終了
	strm_stream_close(strm)
	return STRM_OK
}

// ----------------------------------------------------------------------------
// stdio_read - 読み取り開始コールバック
// ----------------------------------------------------------------------------
// 読み取りストリームの開始時に呼ばれる。
// 実際の処理はread_cbに委譲する。
//
// 引数:
//   strm - 読み取りストリーム
//   data - コールバックデータ（未使用）
//
// 戻り値:
//   STRM_OK
@(private = "file")
stdio_read :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	return read_cb(strm, strm_nil_value())
}

// ----------------------------------------------------------------------------
// read_close - 読み取りストリームのクローズ
// ----------------------------------------------------------------------------
// スキャナの破棄とファイルディスクリプタのクローズを行う。
// 標準入力（stdin）の場合はファイルディスクリプタをクローズしない。
//
// 引数:
//   strm - クローズするストリーム
//   data - コールバックデータ（未使用）
//
// 戻り値:
//   STRM_OK
@(private = "file")
read_close :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	rd := cast(^Read_Data)strm.data
	if rd != nil {
		// スキャナのリソースを解放
		bufio.scanner_destroy(&rd.scanner)
		// 標準入力以外の場合のみファイルをクローズ
		if rd.fd != os.stdin {
			os.close(rd.fd)
		}
		free(rd)
	}
	return STRM_OK
}

// ----------------------------------------------------------------------------
// strm_readio - IOオブジェクトから読み取りストリームを作成
// ----------------------------------------------------------------------------
// IOオブジェクトに対応する読み取りProducerストリームを生成する。
// 既にストリームが存在する場合はキャッシュを返す（遅延初期化）。
//
// 引数:
//   io - 読み取り元のIOオブジェクト
//
// 戻り値:
//   読み取りストリーム
@(private = "file")
strm_readio :: proc(io: ^Strm_IO) -> ^Strm_Stream {
	// キャッシュがあればそれを返す
	if io.read_stream != nil {
		return io.read_stream
	}

	// bufio.Scannerを使用した読み取りデータを作成
	rd := new(Read_Data)
	rd.fd = io.fd
	rd.io_obj = io
	rd.stream = os.stream_from_handle(io.fd)
	bufio.scanner_init(&rd.scanner, rd.stream)

	// 読み取り中フラグを設定
	io.mode += {.Reading}

	// Producerストリームを作成してキャッシュ
	io.read_stream = strm_stream_new(.Producer, stdio_read, read_close, rawptr(rd))
	return io.read_stream
}

// ============================================================================
// 書き込みストリーム (Write Stream)
// ============================================================================
// データをファイルディスクリプタに書き込むConsumerストリーム。
// パイプラインの終端として、受け取ったデータを出力する。

// Write_Data - 書き込みストリームの内部データ
Write_Data :: struct {
	fd: os.Handle,   // 出力先ファイルディスクリプタ
	io: ^Strm_IO,    // 親IOオブジェクトへの参照
}

// ----------------------------------------------------------------------------
// write_cb - 書き込みコールバック
// ----------------------------------------------------------------------------
// 受け取ったデータを文字列に変換し、ファイルディスクリプタに書き込む。
// 各データの後に改行を追加する（行指向出力）。
//
// 引数:
//   strm - 書き込みストリーム
//   data - 書き込むデータ
//
// 戻り値:
//   STRM_OK
@(private = "file")
write_cb :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Write_Data)strm.data

	// データを文字列に変換
	s := strm_to_str(data)

	// ファイルディスクリプタに書き込み（改行付き）
	os.write_string(d.fd, s)
	os.write_string(d.fd, "\n")

	// フラッシュモードが有効な場合はバッファをフラッシュ
	if .Flush in d.io.mode {
		// 注: 適切なフラッシュにはos.syncが必要
		// 現在は未実装
	}

	return STRM_OK
}

// ----------------------------------------------------------------------------
// write_close - 書き込みストリームのクローズ
// ----------------------------------------------------------------------------
// ファイルディスクリプタのクローズを行う。
// 標準出力/標準エラー出力の場合はクローズしない。
//
// 引数:
//   strm - クローズするストリーム
//   data - コールバックデータ（未使用）
//
// 戻り値:
//   STRM_OK
@(private = "file")
write_close :: proc(strm: ^Strm_Stream, data: Strm_Value) -> int {
	d := cast(^Write_Data)strm.data
	if d != nil {
		// 標準出力/標準エラー以外の場合のみファイルをクローズ
		if d.fd != os.stdout && d.fd != os.stderr {
			os.close(d.fd)
		}
		free(d)
	}
	return STRM_OK
}

// ----------------------------------------------------------------------------
// strm_writeio - IOオブジェクトから書き込みストリームを作成
// ----------------------------------------------------------------------------
// IOオブジェクトに対応する書き込みConsumerストリームを生成する。
// 既にストリームが存在する場合はキャッシュを返す。
//
// 引数:
//   io - 書き込み先のIOオブジェクト
//
// 戻り値:
//   書き込みストリーム
@(private = "file")
strm_writeio :: proc(io: ^Strm_IO) -> ^Strm_Stream {
	// キャッシュがあればそれを返す
	if io.write_stream != nil {
		return io.write_stream
	}

	// 書き込みデータを作成
	d := new(Write_Data)
	d.fd = io.fd
	d.io = io

	// Consumerストリームを作成してキャッシュ
	io.write_stream = strm_stream_new(.Consumer, write_cb, write_close, rawptr(d))
	return io.write_stream
}

// ============================================================================
// IOストリームインターフェース (IO Stream Interface)
// ============================================================================
// IOオブジェクトからストリームを取得するための統一インターフェース。

// ----------------------------------------------------------------------------
// strm_io_stream - IOからストリームを取得
// ----------------------------------------------------------------------------
// 指定されたモードに応じて、読み取りまたは書き込みストリームを返す。
// パイプライン接続時に内部的に呼ばれる。
//
// 引数:
//   iov  - IOオブジェクトを保持するStrm_Value
//   mode - 要求するモード（.Read または .Write）
//
// 戻り値:
//   対応するストリーム、またはnil（IOでない場合やモード不一致）
//
// 参照: src/io.c strm_io_stream
strm_io_stream :: proc(iov: Strm_Value, mode: IO_Modes) -> ^Strm_Stream {
	if !strm_io_p(iov) {
		return nil
	}

	io := strm_value_io(iov)
	if io == nil {
		return nil
	}

	// モードに応じてストリームを取得
	if .Read in mode {
		return strm_readio(io)
	} else if .Write in mode {
		return strm_writeio(io)
	}

	return nil
}

// ============================================================================
// ファイル操作 (File Operations)
// ============================================================================
// ファイルを開いてIOオブジェクトを作成するユーティリティ関数。

// ----------------------------------------------------------------------------
// strm_fread - ファイルを読み取りモードで開く
// ----------------------------------------------------------------------------
// 指定されたパスのファイルを読み取り専用で開き、IOオブジェクトを返す。
//
// 引数:
//   path - ファイルパス
//
// 戻り値:
//   IOオブジェクトを保持するStrm_Value
//   失敗時はnil値
//
// 例:
//   io := strm_fread("input.txt")
strm_fread :: proc(path: string) -> Strm_Value {
	fd, err := os.open(path, os.O_RDONLY)
	if err != nil {
		return strm_nil_value()
	}
	return strm_io_new(fd, STRM_IO_READ)
}

// ----------------------------------------------------------------------------
// strm_fwrite - ファイルを書き込みモードで開く
// ----------------------------------------------------------------------------
// 指定されたパスのファイルを書き込み用に開く（上書きモード）。
// ファイルが存在しない場合は新規作成、存在する場合は内容を切り詰める。
//
// 引数:
//   path - ファイルパス
//
// 戻り値:
//   IOオブジェクトを保持するStrm_Value
//   失敗時はnil値
//
// 例:
//   io := strm_fwrite("output.txt")
strm_fwrite :: proc(path: string) -> Strm_Value {
	// O_WRONLY: 書き込み専用
	// O_CREATE: ファイルがなければ作成
	// O_TRUNC:  既存ファイルの内容を切り詰め
	// 0o644:    パーミッション（オーナー読み書き、その他読み取り）
	fd, err := os.open(path, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, 0o644)
	if err != nil {
		return strm_nil_value()
	}
	return strm_io_new(fd, STRM_IO_WRITE)
}
