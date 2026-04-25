macro package json4cj.jsonmacro

import std.ast.*

/*
 * Macro that ignores the decorated var when doing json serialization/deserialization
 * @param input_Tk the target var
 * @return token the expanded token representation
 */
public macro JsonIgnore(input_Tk: Tokens): Tokens {
    var decl = TokenVerifier.verifyVarDecl(input_Tk, Const.JSON_IGNORE_MACRO_NAME)

    assertParentContext(Const.JSON_SERIALIZE_MACRO_NAME)
    setItem(Const.KEY_IGNORED_PROP, decl.identifier.value)

    return input_Tk
}
