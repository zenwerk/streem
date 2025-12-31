package streem

import "core:testing"

// ============================================================================
// Token Utility Tests
// ============================================================================

@(test)
test_token_is_keyword :: proc(t: ^testing.T) {
	testing.expect(t, token_is_keyword(.Kw_If), "if should be keyword")
	testing.expect(t, token_is_keyword(.Kw_Def), "def should be keyword")
	testing.expect(t, !token_is_keyword(.Ident), "Ident should not be keyword")
	testing.expect(t, !token_is_keyword(.Op_Plus), "Op_Plus should not be keyword")
}

@(test)
test_token_is_binary_op :: proc(t: ^testing.T) {
	testing.expect(t, token_is_binary_op(.Op_Plus), "+ should be binary op")
	testing.expect(t, token_is_binary_op(.Op_Eq), "== should be binary op")
	testing.expect(t, !token_is_binary_op(.Kw_If), "if should not be binary op")
}

@(test)
test_token_is_unary_op :: proc(t: ^testing.T) {
	testing.expect(t, token_is_unary_op(.Op_Minus), "- should be unary op")
	testing.expect(t, token_is_unary_op(.Op_Not), "! should be unary op")
	testing.expect(t, token_is_unary_op(.Op_Tilde), "~ should be unary op")
	testing.expect(t, !token_is_unary_op(.Op_Plus), "+ should not be unary op")
}

@(test)
test_token_is_literal :: proc(t: ^testing.T) {
	testing.expect(t, token_is_literal(.Lit_Int), "Lit_Int should be literal")
	testing.expect(t, token_is_literal(.Lit_String), "Lit_String should be literal")
	testing.expect(t, token_is_literal(.Kw_Nil), "nil should be literal")
	testing.expect(t, token_is_literal(.Kw_True), "true should be literal")
	testing.expect(t, !token_is_literal(.Ident), "Ident should not be literal")
}
