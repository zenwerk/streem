package streem

import "core:fmt"
import "core:os"
import "core:strings"

// CLI modes
Run_Mode :: enum {
	File,         // execute file
	String,       // execute inline code (-e)
	Syntax_Check, // syntax check only (-c)
	Verbose,      // verbose/AST dump (-v)
}

// Main entry point
main :: proc() {
	args := os.args
	input_string: string
	input_file: string
	verbose := false
	syntax_check_only := false

	// Parse arguments
	i := 1
	for i < len(args) {
		arg := args[i]

		if arg == "-e" {
			// Execute inline code
			i += 1
			if i < len(args) {
				input_string = args[i]
			} else {
				fmt.eprintln("Error: -e requires an argument")
				os.exit(1)
			}
		} else if arg == "-c" {
			// Syntax check only
			syntax_check_only = true
		} else if arg == "-v" {
			// Verbose mode (AST dump)
			verbose = true
		} else if arg == "-h" || arg == "--help" {
			print_usage()
			os.exit(0)
		} else if strings.has_prefix(arg, "-") {
			fmt.eprintfln("Error: Unknown option: %s", arg)
			print_usage()
			os.exit(1)
		} else {
			// Input file
			input_file = arg
		}

		i += 1
	}

	// Determine what to run
	if syntax_check_only {
		if input_file != "" {
			syntax_check_file(input_file)
		} else if input_string != "" {
			syntax_check_string(input_string)
		} else {
			fmt.eprintln("Error: No input specified for syntax check")
			os.exit(1)
		}
	} else if input_string != "" {
		run_string(input_string, verbose)
	} else if input_file != "" {
		run_file(input_file, verbose)
	} else {
		fmt.eprintln("Error: No input specified")
		print_usage()
		os.exit(1)
	}
}

print_usage :: proc() {
	fmt.println("Usage: streem [options] [file]")
	fmt.println()
	fmt.println("Options:")
	fmt.println("  -e CODE    Execute inline code")
	fmt.println("  -c         Syntax check only")
	fmt.println("  -v         Verbose mode (dump AST)")
	fmt.println("  -h, --help Show this help")
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
