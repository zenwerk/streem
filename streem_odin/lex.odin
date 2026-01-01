#+feature dynamic-literals
package streem

import "core:unicode/utf8"
import "core:strconv"
import "core:strings"

// Lexer structure
Lex :: struct {
	using pos: Pos,
	input:     string,
	fname:     string, // source file name
}

// Initialize lexer with input string
lex_init :: proc(lex: ^Lex, input: string, fname: string = "<input>") {
	lex.input = input
	lex.fname = fname
	lex.pos = Pos{offset = 0, line = 1, column = 1}
}

// Peek next character without consuming
lex_peek :: proc(lex: ^Lex) -> rune {
	if lex.offset >= len(lex.input) {
		return utf8.RUNE_EOF
	}
	r, _ := utf8.decode_rune_in_string(lex.input[lex.offset:])
	return r
}

// Peek character at offset N ahead (0 = current)
lex_peek_n :: proc(lex: ^Lex, n: int) -> rune {
	offset := lex.offset
	for i := 0; i < n; i += 1 {
		if offset >= len(lex.input) {
			return utf8.RUNE_EOF
		}
		_, size := utf8.decode_rune_in_string(lex.input[offset:])
		offset += size
	}
	if offset >= len(lex.input) {
		return utf8.RUNE_EOF
	}
	r, _ := utf8.decode_rune_in_string(lex.input[offset:])
	return r
}

// Consume and return next character
lex_advance :: proc(lex: ^Lex) -> rune {
	r := lex_peek(lex)
	if r != utf8.RUNE_ERROR && r != utf8.RUNE_EOF {
		size := utf8.rune_size(r)
		lex.offset += size
		if r == '\n' {
			lex.line += 1
			lex.column = 1
		} else {
			lex.column += 1
		}
	}
	return r
}

// Create token with current position
lex_create_token :: proc(lex: ^Lex, t: Token_Type, lexeme: string) -> Token {
	return Token{pos = lex.pos, type = t, lexeme = lexeme, consumed = false}
}

// Check if character is valid for identifier start (unicode-aware)
is_ident_start :: proc(r: rune) -> bool {
	if r >= 'a' && r <= 'z' {
		return true
	}
	if r >= 'A' && r <= 'Z' {
		return true
	}
	if r == '_' {
		return true
	}
	// UTF-8 multibyte characters (for unicode identifiers)
	if r >= 0x80 {
		return true
	}
	return false
}

// Check if character is valid for identifier continuation
is_ident_char :: proc(r: rune) -> bool {
	if is_ident_start(r) {
		return true
	}
	if r >= '0' && r <= '9' {
		return true
	}
	return false
}

// Check if character is a decimal digit
is_digit :: proc(r: rune) -> bool {
	return r >= '0' && r <= '9'
}

// Check if character is a hex digit
is_hex_digit :: proc(r: rune) -> bool {
	return (r >= '0' && r <= '9') || (r >= 'a' && r <= 'f') || (r >= 'A' && r <= 'F')
}

// Check if character is an octal digit
is_octal_digit :: proc(r: rune) -> bool {
	return r >= '0' && r <= '7'
}

// Keyword lookup table
@(private = "file")
keywords := map[string]Token_Type {
	"if"        = .Kw_If,
	"else"      = .Kw_Else,
	"case"      = .Kw_Case,
	"emit"      = .Kw_Emit,
	"skip"      = .Kw_Skip,
	"return"    = .Kw_Return,
	"namespace" = .Kw_Namespace,
	"class"     = .Kw_Class,
	"import"    = .Kw_Import,
	"def"       = .Kw_Def,
	"method"    = .Kw_Method,
	"new"       = .Kw_New,
	"nil"       = .Kw_Nil,
	"true"      = .Kw_True,
	"false"     = .Kw_False,
}

// Scan identifier or keyword
lex_scan_identifier :: proc(lex: ^Lex, start_offset: int) -> Token {
	for is_ident_char(lex_peek(lex)) {
		lex_advance(lex)
	}
	lexeme := lex.input[start_offset:lex.offset]

	// Check for label (identifier followed by colon, but not ::)
	if lex_peek(lex) == ':' && lex_peek_n(lex, 1) != ':' {
		lex_advance(lex) // consume ':'
		return lex_create_token(lex, .Label, lexeme)
	}

	// Check if it's a keyword
	if kw, ok := keywords[lexeme]; ok {
		return lex_create_token(lex, kw, lexeme)
	}

	return lex_create_token(lex, .Ident, lexeme)
}

// Scan number literal (int or float, decimal/hex/octal) or time literal
lex_scan_number :: proc(lex: ^Lex, start_offset: int) -> Token {
	// Check for hex (0x) or octal (0o)
	if lex.input[start_offset] == '0' && lex.offset - start_offset == 1 {
		r := lex_peek(lex)
		if r == 'x' || r == 'X' {
			lex_advance(lex) // consume 'x'
			for is_hex_digit(lex_peek(lex)) {
				lex_advance(lex)
			}
			return lex_create_token(lex, .Lit_Int, lex.input[start_offset:lex.offset])
		}
		if r == 'o' || r == 'O' {
			lex_advance(lex) // consume 'o'
			for is_octal_digit(lex_peek(lex)) {
				lex_advance(lex)
			}
			return lex_create_token(lex, .Lit_Int, lex.input[start_offset:lex.offset])
		}
	}

	// Scan integer part
	for is_digit(lex_peek(lex)) {
		lex_advance(lex)
	}

	// Check for time literal pattern: YYYY.MM.DD...
	// Time literals have 4 digits followed by '.' and more digits (not float pattern)
	digits_count := lex.offset - start_offset
	if digits_count == 4 && lex_peek(lex) == '.' && is_digit(lex_peek_n(lex, 1)) {
		// Could be time literal - check if it matches date pattern
		// Save position to potentially rollback
		saved_offset := lex.offset
		saved_pos := lex.pos

		lex_advance(lex) // consume '.'

		// Scan month (1-2 digits)
		month_start := lex.offset
		for is_digit(lex_peek(lex)) {
			lex_advance(lex)
		}
		month_digits := lex.offset - month_start

		// Check for another '.' (day part)
		if month_digits >= 1 && month_digits <= 2 && lex_peek(lex) == '.' && is_digit(lex_peek_n(lex, 1)) {
			lex_advance(lex) // consume '.'

			// Scan day (1-2 digits)
			for is_digit(lex_peek(lex)) {
				lex_advance(lex)
			}

			// This is a time literal - scan rest of time pattern
			return lex_scan_time(lex, start_offset)
		}

		// Not a time literal, rollback and treat as float
		lex.offset = saved_offset
		lex.pos = saved_pos
	}

	// Check for decimal point (but not '..' range or method call)
	is_float := false
	if lex_peek(lex) == '.' && is_digit(lex_peek_n(lex, 1)) {
		is_float = true
		lex_advance(lex) // consume '.'
		for is_digit(lex_peek(lex)) {
			lex_advance(lex)
		}
	}

	lexeme := lex.input[start_offset:lex.offset]
	if is_float {
		return lex_create_token(lex, .Lit_Float, lexeme)
	}
	return lex_create_token(lex, .Lit_Int, lexeme)
}

// Scan string literal with escape sequences
lex_scan_string :: proc(lex: ^Lex, start_offset: int) -> Token {
	// Opening quote already consumed
	for {
		r := lex_peek(lex)
		if r == utf8.RUNE_EOF {
			return lex_create_token(lex, .Error, "unterminated string")
		}
		if r == '"' {
			lex_advance(lex) // consume closing quote
			break
		}
		if r == '\\' {
			lex_advance(lex) // consume backslash
			// Consume escaped character
			if lex_peek(lex) != utf8.RUNE_EOF {
				lex_advance(lex)
			}
		} else {
			lex_advance(lex)
		}
	}

	// Check if this is a label ("string":)
	if lex_peek(lex) == ':' && lex_peek_n(lex, 1) != ':' {
		lex_advance(lex) // consume ':'
		// Return label with the string content (without quotes and colon)
		return lex_create_token(lex, .Label, lex.input[start_offset + 1:lex.offset - 2])
	}

	// Return string content without quotes
	lexeme := lex.input[start_offset + 1:lex.offset - 1]
	return lex_create_token(lex, .Lit_String, lexeme)
}

// Scan symbol literal (:identifier)
lex_scan_symbol :: proc(lex: ^Lex, start_offset: int) -> Token {
	// Colon already consumed
	if !is_ident_start(lex_peek(lex)) {
		// Just a colon, not a symbol
		return lex_create_token(lex, .Colon, ":")
	}

	for is_ident_char(lex_peek(lex)) {
		lex_advance(lex)
	}

	return lex_create_token(lex, .Lit_Symbol, lex.input[start_offset:lex.offset])
}

// Scan time literal (YYYY.MM.DD or YYYY.MM.DDThh:mm:ss with optional timezone)
// Called after date part (YYYY.MM.DD) has already been scanned
lex_scan_time :: proc(lex: ^Lex, start_offset: int) -> Token {
	// Date part (YYYY.MM.DD) already scanned by lex_scan_number
	// Now check for optional time part (Thh:mm:ss[.fraction][timezone])

	// Check for time part (T followed by time)
	if lex_peek(lex) == 'T' {
		lex_advance(lex) // consume 'T'

		// Scan hours
		for is_digit(lex_peek(lex)) {
			lex_advance(lex)
		}

		// Scan :mm
		if lex_peek(lex) == ':' {
			lex_advance(lex)
			for is_digit(lex_peek(lex)) {
				lex_advance(lex)
			}
		}

		// Scan optional :ss
		if lex_peek(lex) == ':' {
			lex_advance(lex)
			for is_digit(lex_peek(lex)) {
				lex_advance(lex)
			}
		}

		// Scan optional .fraction
		if lex_peek(lex) == '.' {
			lex_advance(lex)
			for is_digit(lex_peek(lex)) {
				lex_advance(lex)
			}
		}

		// Check for timezone
		r := lex_peek(lex)
		if r == 'Z' {
			lex_advance(lex)
		} else if r == '+' || r == '-' {
			lex_advance(lex)
			// Scan timezone offset hh or hh:mm
			for is_digit(lex_peek(lex)) {
				lex_advance(lex)
			}
			if lex_peek(lex) == ':' {
				lex_advance(lex)
				for is_digit(lex_peek(lex)) {
					lex_advance(lex)
				}
			}
		}
	}

	return lex_create_token(lex, .Lit_Time, lex.input[start_offset:lex.offset])
}

// Skip TRAIL (optional whitespace/comment/newline after operators)
// This allows operators to span lines
lex_skip_trail :: proc(lex: ^Lex) {
	for {
		r := lex_peek(lex)
		switch r {
		case ' ', '\t', '\n':
			lex_advance(lex)
		case '#':
			// Skip comment until newline
			for lex_peek(lex) != '\n' && lex_peek(lex) != utf8.RUNE_EOF {
				lex_advance(lex)
			}
			if lex_peek(lex) == '\n' {
				lex_advance(lex)
			}
		case:
			return
		}
	}
}

// Scan next token
lex_scan_token :: proc(lex: ^Lex) -> Token {
	for {
		// Skip whitespace (but not newline - it's significant)
		for lex_peek(lex) == ' ' || lex_peek(lex) == '\t' {
			lex_advance(lex)
		}

		start_offset := lex.offset
		start_pos := lex.pos
		r := lex_advance(lex)

		switch r {
		case utf8.RUNE_EOF:
			return Token{pos = start_pos, type = .Eof, lexeme = "", consumed = false}

		case '\n':
			return Token{pos = start_pos, type = .Newline, lexeme = "\n", consumed = false}

		case '#':
			// Comment until end of line, then return newline token
			for lex_peek(lex) != '\n' && lex_peek(lex) != utf8.RUNE_EOF {
				lex_advance(lex)
			}
			if lex_peek(lex) == '\n' {
				lex_advance(lex)
			}
			return Token{pos = start_pos, type = .Newline, lexeme = "\n", consumed = false}

		case '+':
			lex_skip_trail(lex)
			return Token{pos = start_pos, type = .Op_Plus, lexeme = "+", consumed = false}

		case '-':
			// Check for -> (lambda)
			if lex_peek(lex) == '>' {
				lex_advance(lex)
				lex_skip_trail(lex)
				return Token{pos = start_pos, type = .Op_Lambda, lexeme = "->", consumed = false}
			}
			lex_skip_trail(lex)
			return Token{pos = start_pos, type = .Op_Minus, lexeme = "-", consumed = false}

		case '*':
			lex_skip_trail(lex)
			return Token{pos = start_pos, type = .Op_Mult, lexeme = "*", consumed = false}

		case '/':
			lex_skip_trail(lex)
			return Token{pos = start_pos, type = .Op_Div, lexeme = "/", consumed = false}

		case '%':
			lex_skip_trail(lex)
			return Token{pos = start_pos, type = .Op_Mod, lexeme = "%", consumed = false}

		case '=':
			// Check for == or =>
			if lex_peek(lex) == '=' {
				lex_advance(lex)
				lex_skip_trail(lex)
				return Token{pos = start_pos, type = .Op_Eq, lexeme = "==", consumed = false}
			}
			if lex_peek(lex) == '>' {
				lex_advance(lex)
				lex_skip_trail(lex)
				return Token{pos = start_pos, type = .Op_Rasgn, lexeme = "=>", consumed = false}
			}
			lex_skip_trail(lex)
			return Token{pos = start_pos, type = .Op_Assign, lexeme = "=", consumed = false}

		case '!':
			// Check for !=
			if lex_peek(lex) == '=' {
				lex_advance(lex)
				lex_skip_trail(lex)
				return Token{pos = start_pos, type = .Op_Neq, lexeme = "!=", consumed = false}
			}
			return Token{pos = start_pos, type = .Op_Not, lexeme = "!", consumed = false}

		case '<':
			// Check for <= or <-
			if lex_peek(lex) == '=' {
				lex_advance(lex)
				lex_skip_trail(lex)
				return Token{pos = start_pos, type = .Op_Le, lexeme = "<=", consumed = false}
			}
			if lex_peek(lex) == '-' {
				lex_advance(lex)
				lex_skip_trail(lex)
				return Token{pos = start_pos, type = .Op_Lasgn, lexeme = "<-", consumed = false}
			}
			lex_skip_trail(lex)
			return Token{pos = start_pos, type = .Op_Lt, lexeme = "<", consumed = false}

		case '>':
			// Check for >=
			if lex_peek(lex) == '=' {
				lex_advance(lex)
				lex_skip_trail(lex)
				return Token{pos = start_pos, type = .Op_Ge, lexeme = ">=", consumed = false}
			}
			lex_skip_trail(lex)
			return Token{pos = start_pos, type = .Op_Gt, lexeme = ">", consumed = false}

		case '&':
			// Check for &&
			if lex_peek(lex) == '&' {
				lex_advance(lex)
				lex_skip_trail(lex)
				return Token{pos = start_pos, type = .Op_And, lexeme = "&&", consumed = false}
			}
			lex_skip_trail(lex)
			return Token{pos = start_pos, type = .Op_Amper, lexeme = "&", consumed = false}

		case '|':
			// Check for ||
			// Note: | with TRAIL is handled specially
			if lex_peek(lex) == '|' {
				lex_advance(lex)
				lex_skip_trail(lex)
				return Token{pos = start_pos, type = .Op_Or, lexeme = "||", consumed = false}
			}
			lex_skip_trail(lex)
			return Token{pos = start_pos, type = .Op_Bar, lexeme = "|", consumed = false}

		case '~':
			return Token{pos = start_pos, type = .Op_Tilde, lexeme = "~", consumed = false}

		case ':':
			// Check for :: or :symbol
			if lex_peek(lex) == ':' {
				lex_advance(lex)
				lex_skip_trail(lex)
				return Token{pos = start_pos, type = .Op_Colon2, lexeme = "::", consumed = false}
			}
			// Try to scan symbol
			return lex_scan_symbol(lex, start_offset)

		case '(':
			lex_skip_trail(lex)
			return Token{pos = start_pos, type = .Left_Paren, lexeme = "(", consumed = false}

		case ')':
			// Check for )-> or )->{
			// Skip optional spaces
			saved_offset := lex.offset
			saved_pos := lex.pos
			spaces := 0
			for lex_peek(lex) == ' ' {
				lex_advance(lex)
				spaces += 1
			}
			if lex_peek(lex) == '-' && lex_peek_n(lex, 1) == '>' {
				lex_advance(lex) // consume '-'
				lex_advance(lex) // consume '>'
				// Check for )->{
				for lex_peek(lex) == ' ' {
					lex_advance(lex)
				}
				if lex_peek(lex) == '{' {
					lex_advance(lex)
					lex_skip_trail(lex)
					return Token{pos = start_pos, type = .Op_Lambda3, lexeme = ")->{", consumed = false}
				}
				lex_skip_trail(lex)
				return Token{pos = start_pos, type = .Op_Lambda2, lexeme = ")->", consumed = false}
			}
			// Restore position if not a lambda
			lex.offset = saved_offset
			lex.pos = saved_pos
			return Token{pos = start_pos, type = .Right_Paren, lexeme = ")", consumed = false}

		case '[':
			lex_skip_trail(lex)
			return Token{pos = start_pos, type = .Left_Bracket, lexeme = "[", consumed = false}

		case ']':
			return Token{pos = start_pos, type = .Right_Bracket, lexeme = "]", consumed = false}

		case '{':
			lex_skip_trail(lex)
			return Token{pos = start_pos, type = .Left_Brace, lexeme = "{", consumed = false}

		case '}':
			return Token{pos = start_pos, type = .Right_Brace, lexeme = "}", consumed = false}

		case ',':
			lex_skip_trail(lex)
			return Token{pos = start_pos, type = .Comma, lexeme = ",", consumed = false}

		case ';':
			lex_skip_trail(lex)
			return Token{pos = start_pos, type = .Semicolon, lexeme = ";", consumed = false}

		case '.':
			lex_skip_trail(lex)
			return Token{pos = start_pos, type = .Dot, lexeme = ".", consumed = false}

		case '@':
			return Token{pos = start_pos, type = .At, lexeme = "@", consumed = false}

		case '"':
			return lex_scan_string(lex, start_offset)

		case '0' ..= '9':
			// Could be number or time literal
			// Time format starts with YYYY. where YYYY is 4 digits
			// We'll scan as number and check for time pattern
			return lex_scan_number(lex, start_offset)

		case:
			// Identifier or unicode character
			if is_ident_start(r) {
				return lex_scan_identifier(lex, start_offset)
			}

			// Error - unexpected character
			lexeme := lex.input[start_offset:lex.offset]
			return Token{pos = start_pos, type = .Error, lexeme = lexeme, consumed = false}
		}
	}
}
