package streem

import "core:fmt"
import "core:os"
import "core:strings"
import "core:bufio"
import "core:io"
import "core:flags"

// CLI options structure
Options :: struct {
	input_string:      string `args:"name=e" usage:"Execute inline code"`,
	syntax_check_only: bool `args:"name=c" usage:"Syntax check only"`,
	verbose:           bool `args:"name=v" usage:"Verbose mode (dump AST)"`,
	input_file:        string `args:"pos=0" usage:"Input file to execute"`,
}

// Main entry point
main :: proc() {
	opt: Options
	style: flags.Parsing_Style = .Unix
	flags.parse_or_exit(&opt, os.args, style)

	// Determine what to run
	if opt.syntax_check_only {
		if opt.input_file != "" {
			syntax_check_file(opt.input_file)
		} else if opt.input_string != "" {
			syntax_check_string(opt.input_string)
		} else {
			fmt.eprintln("Error: No input specified for syntax check")
			os.exit(1)
		}
	} else if opt.input_string != "" {
		run_string(opt.input_string, opt.verbose)
	} else if opt.input_file != "" {
		run_file(opt.input_file, opt.verbose)
	} else {
		// No input specified - start REPL
		run_repl(opt.verbose)
	}
}

// Run a streem file
run_file :: proc(filename: string, verbose: bool) {
	// Read file contents
	data, ok := os.read_entire_file(filename)
	if !ok {
		fmt.eprintfln("Error: Cannot read file: %s", filename)
		os.exit(1)
	}
	defer delete(data)

	source := string(data)
	run_source(source, filename, verbose)
}

// Run streem code from string
run_string :: proc(source: string, verbose: bool) {
	run_source(source, "<input>", verbose)
}

// Run streem source code
run_source :: proc(source: string, filename: string, verbose: bool) {
	// Initialize
	strm_ns_init()
	defer strm_ns_cleanup()

	// Create lexer
	lex: Lex
	lex_init(&lex, source, filename)

	// Parse
	ast, ok := parse_program_from_lex(&lex)
	if !ok {
		fmt.eprintln("Error: Parse failed")
		os.exit(1)
	}
	defer node_free(ast)

	if verbose {
		// Dump AST
		fmt.println("=== AST ===")
		dump_ast(ast, 0)
		fmt.println("===========")
	}

	// Create global state
	state := strm_state_new()
	defer strm_state_destroy(state)

	// Initialize built-ins
	init_builtins(state)

	// Execute
	result: Strm_Value
	exec_result := exec_expr(nil, state, ast, &result)

	if exec_result == .Error {
		fmt.eprintln("Error: Execution failed")
		os.exit(1)
	}

	// Run event loop
	strm_loop()

	// Cleanup workers
	worker_cleanup()
}

// Syntax check a file
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

// Syntax check a string
syntax_check_string :: proc(source: string) {
	syntax_check(source, "<input>")
}

// Perform syntax check
syntax_check :: proc(source: string, filename: string) {
	lex: Lex
	lex_init(&lex, source, filename)

	ast, ok := parse_program_from_lex(&lex)
	if !ok {
		fmt.eprintfln("Syntax error in %s", filename)
		os.exit(1)
	}

	node_free(ast)
	fmt.printfln("Syntax OK: %s", filename)
}

// Dump AST for debugging
dump_ast :: proc(node: ^Node, indent: int) {
	if node == nil {
		print_indent(indent)
		fmt.println("nil")
		return
	}

	print_indent(indent)

	#partial switch node.type {
	case .Int:
		data := &node.data.(Node_Int)
		fmt.printfln("Int(%d)", data.value)

	case .Float:
		data := &node.data.(Node_Float)
		fmt.printfln("Float(%f)", data.value)

	case .Str:
		data := &node.data.(Node_Str)
		fmt.printfln("Str(\"%s\")", data.value)

	case .Bool:
		data := &node.data.(Node_Bool)
		fmt.printfln("Bool(%v)", data.value)

	case .Nil:
		fmt.println("Nil")

	case .Ident:
		data := &node.data.(Node_Ident)
		fmt.printfln("Ident(%s)", data.name)

	case .Op:
		data := &node.data.(Node_Op)
		fmt.printfln("Op(%s)", data.op)
		dump_ast(data.lhs, indent + 2)
		dump_ast(data.rhs, indent + 2)

	case .If:
		data := &node.data.(Node_If)
		fmt.println("If")
		print_indent(indent + 2)
		fmt.println("cond:")
		dump_ast(data.cond, indent + 4)
		print_indent(indent + 2)
		fmt.println("then:")
		dump_ast(data.then_, indent + 4)
		if data.opt_else != nil {
			print_indent(indent + 2)
			fmt.println("else:")
			dump_ast(data.opt_else, indent + 4)
		}

	case .Lambda:
		data := &node.data.(Node_Lambda)
		fmt.printfln("Lambda(block=%v)", data.is_block)
		if data.args != nil {
			print_indent(indent + 2)
			fmt.println("args:")
			dump_ast(data.args, indent + 4)
		}
		print_indent(indent + 2)
		fmt.println("body:")
		dump_ast(data.body, indent + 4)

	case .Call:
		data := &node.data.(Node_Call)
		fmt.printfln("Call(%s)", data.name)
		if data.args != nil {
			dump_ast(data.args, indent + 2)
		}

	case .Fcall:
		data := &node.data.(Node_Fcall)
		fmt.println("Fcall")
		print_indent(indent + 2)
		fmt.println("func:")
		dump_ast(data.func_, indent + 4)
		if data.args != nil {
			print_indent(indent + 2)
			fmt.println("args:")
			dump_ast(data.args, indent + 4)
		}

	case .Let:
		data := &node.data.(Node_Let)
		fmt.printfln("Let(%s)", data.lhs)
		dump_ast(data.rhs, indent + 2)

	case .Emit:
		data := &node.data.(Node_Emit)
		fmt.println("Emit")
		dump_ast(data.value, indent + 2)

	case .Skip:
		fmt.println("Skip")

	case .Return:
		data := &node.data.(Node_Return)
		fmt.println("Return")
		dump_ast(data.value, indent + 2)

	case .Nodes:
		data := &node.data.(Node_Nodes)
		fmt.printfln("Nodes(%d)", len(data.nodes))
		for n in data.nodes {
			dump_ast(n, indent + 2)
		}

	case .Array:
		data := &node.data.(Node_Array)
		fmt.printfln("Array(%d)", len(data.elements))
		for elem in data.elements {
			dump_ast(elem, indent + 2)
		}

	case .Args:
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
		data := &node.data.(Node_Ns)
		fmt.printfln("Namespace(%s)", data.name)
		dump_ast(data.body, indent + 2)

	case .Import:
		data := &node.data.(Node_Import)
		fmt.printfln("Import(%s)", data.name)

	case:
		fmt.printfln("<%v>", node.type)
	}
}

@(private = "file")
print_indent :: proc(n: int) {
	for _ in 0 ..< n {
		fmt.print(" ")
	}
}

// Initialize built-in functions
init_builtins :: proc(state: ^Strm_State) {
	// Initialize all built-in functions (Phase 14)
	strm_init(state)
}

// ============================================================================
// REPL (Read-Eval-Print Loop)
// ============================================================================

// Run interactive REPL
run_repl :: proc(verbose: bool) {
	fmt.println("Streem REPL (Odin port)")
	fmt.println("Type 'exit' or Ctrl+D to quit")
	fmt.println()

	// Initialize namespace system
	strm_ns_init()
	defer strm_ns_cleanup()

	// Create persistent global state for REPL session
	state := strm_state_new()
	defer strm_state_destroy(state)

	// Initialize built-ins
	init_builtins(state)

	// Input buffer for line continuation
	input_buffer: strings.Builder
	strings.builder_init(&input_buffer)
	defer strings.builder_destroy(&input_buffer)

	continuation := false

	// Create buffered reader for stdin
	stdin_stream := os.stream_from_handle(os.stdin)
	reader: bufio.Reader
	bufio.reader_init(&reader, stdin_stream)
	defer bufio.reader_destroy(&reader)

	for {
		// Print prompt
		if continuation {
			fmt.print("... ")
		} else {
			fmt.print("streem> ")
		}

		// Read line
		line, err := bufio.reader_read_string(&reader, '\n')
		if err != nil {
			// EOF or error
			if strings.builder_len(input_buffer) > 0 {
				fmt.println()
				fmt.eprintln("Error: Incomplete input")
			} else {
				fmt.println()
			}
			break
		}

		// Remove trailing newline
		line = strings.trim_right(line, "\r\n")

		// Check for exit command
		if !continuation && (line == "exit" || line == "quit") {
			break
		}

		// Check for empty line
		if !continuation && strings.trim_space(line) == "" {
			continue
		}

		// Append to input buffer
		if strings.builder_len(input_buffer) > 0 {
			strings.write_string(&input_buffer, "\n")
		}
		strings.write_string(&input_buffer, line)

		// Try to parse the accumulated input
		source := strings.to_string(input_buffer)
		complete, result := try_parse_and_eval(state, source, verbose)

		if complete {
			// Successfully parsed and evaluated (or error)
			if result != "" {
				fmt.println(result)
			}
			// Clear buffer for next input
			strings.builder_reset(&input_buffer)
			continuation = false

			// Run any pending stream tasks
			strm_loop()
			worker_cleanup()
		} else {
			// Incomplete input - continue reading
			continuation = true
		}
	}

	fmt.println("Goodbye!")
}

// Try to parse and evaluate input
// Returns (complete, result) where complete indicates if input was complete
try_parse_and_eval :: proc(state: ^Strm_State, source: string, verbose: bool) -> (complete: bool, result: string) {
	// Create lexer
	lex: Lex
	lex_init(&lex, source, "<repl>")

	// Try parsing
	p := parser_new()
	defer parser_destroy(p)
	parser_reset(p)

	// Feed tokens to parser
	for {
		token := lex_scan_token(&lex)
		parse_result := parser_push_token(p, token)

		switch parse_result {
		case .Done:
			// Successfully parsed
			ast := p.root
			if ast == nil {
				return true, ""
			}
			// NOTE: Don't free AST in REPL mode because lambdas hold references to AST nodes.
			// This causes a small memory leak per REPL input, but it's acceptable for interactive use.
			// The memory will be reclaimed when the process exits.

			if verbose {
				// Dump AST
				fmt.println("=== AST ===")
				dump_ast(ast, 0)
				fmt.println("===========")
			}

			// Execute
			ret: Strm_Value
			exec_result := exec_expr(nil, state, ast, &ret)

			if exec_result == .Error {
				return true, "Error: Execution failed"
			}

			// Format result (skip nil for cleaner output)
			if !strm_nil_p(ret) {
				return true, strm_to_str(ret)
			}
			return true, ""

		case .Error:
			// Check if it's a real error or just incomplete
			if p.error_msg != "" {
				// Check for common "unexpected EOF" patterns that indicate incomplete input
				if is_incomplete_error(p.error_msg) {
					return false, ""
				}
				return true, fmt.tprintf("Parse error: %s", p.error_msg)
			}
			return true, "Parse error"

		case .Ok, .Need_Token:
			if token.type == .Eof {
				// Reached EOF but parser still needs more - incomplete input
				return false, ""
			}
			continue
		}
	}
}

// Check if parse error indicates incomplete input
@(private = "file")
is_incomplete_error :: proc(msg: string) -> bool {
	// Common patterns for incomplete input
	incomplete_patterns := []string{
		"unexpected end",
		"Expected '}'",
		"Expected ')'",
		"Expected ']'",
	}

	for pattern in incomplete_patterns {
		if strings.contains(msg, pattern) {
			return true
		}
	}
	return false
}
