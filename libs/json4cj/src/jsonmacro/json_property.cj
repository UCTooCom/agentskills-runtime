macro package json4cj.jsonmacro

import std.ast.*

/*
 * Macro for custom json property name mapping
 * @param attr_Tk the given name for mapping
 * @param input_Tk the target var
 * @return token the expanded token representation
 */
public macro JsonProperty(attr_Tk: Tokens, input_Tk: Tokens): Tokens {
    var decl = TokenVerifier.verifyVarDecl(input_Tk, Const.JSON_PROPERTY_MACRO_NAME)

    assertParentContext(Const.JSON_SERIALIZE_MACRO_NAME)
    setItem(Const.KEY_PROP_ORIGINAL_NAME, decl.identifier.value)
    setItem(Const.KEY_PROP_MAPPED_NAME, checkVarNameAttr(attr_Tk))

    return input_Tk
}

func checkVarNameAttr(attr_Tk: Tokens): String {
    var token = attr_Tk[0]
    if (token.kind == STRING_LITERAL) {
        return token.value
    } else {
        throw MacroParameterException(
            "JsonProperty requires a string parameter at position 0, find ${token.kind} instead")
    }
}
