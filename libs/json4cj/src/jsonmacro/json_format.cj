macro package json4cj.jsonmacro

import std.ast.*

/*
 * Macro for custom DateTime format in JSON serialization/deserialization.
 * This is the json4cj equivalent of Jackson's @JsonFormat(pattern = "yyyy-MM-dd").
 *
 * Usage:
 *   @JsonSerialize
 *   class Event {
 *       @JsonFormat["yyyy-MM-dd"]
 *       var date: DateTime = DateTime.now()
 *
 *       @JsonFormat["yyyy/MM/dd HH:mm:ss"]
 *       var startTime: DateTime = DateTime.now()
 *   }
 *
 * Serialization: uses DateTime.format(pattern) instead of toString()
 * Deserialization: uses DateTime.parse(str, pattern) instead of parse(str)
 */
public macro JsonFormat(attr_Tk: Tokens, input_Tk: Tokens): Tokens {
    var decl = TokenVerifier.verifyVarDecl(input_Tk, Const.JSON_FORMAT_MACRO_NAME)
    assertParentContext(Const.JSON_SERIALIZE_MACRO_NAME)
    let pattern = checkFormatAttr(attr_Tk)
    setItem(Const.KEY_FORMAT_PROP, decl.identifier.value)
    setItem(Const.KEY_FORMAT_PATTERN, pattern)
    return input_Tk
}

func checkFormatAttr(attr_Tk: Tokens): String {
    if (attr_Tk.size == 0) {
        throw MacroParameterException("JsonFormat requires a format pattern string parameter")
    }
    var token = attr_Tk[0]
    if (token.kind == STRING_LITERAL) {
        return token.value
    } else {
        throw MacroParameterException(
            "JsonFormat requires a string parameter for the format pattern, find ${token.kind} instead")
    }
}
