macro package json4cj.jsonmacro

import std.ast.*

/*
 * Macro for controlling whether unknown JSON fields are ignored during deserialization.
 * This is the json4cj equivalent of Jackson's @JsonIgnoreProperties(ignoreUnknown = ...).
 *
 * Usage:
 *   @JsonIgnoreUnknown[true]   - ignore unknown fields (default behavior)
 *   @JsonIgnoreUnknown[false]  - strict mode, throw on unknown fields
 *
 * Example:
 *   @JsonSerialize
 *   @JsonIgnoreUnknown[true]
 *   class User {
 *       var name: String = ""
 *   }
 */
public macro JsonIgnoreUnknown(attr_Tk: Tokens, input_Tk: Tokens): Tokens {
    assertParentContext(Const.JSON_SERIALIZE_MACRO_NAME)
    let value = parseBoolAttr(attr_Tk)
    setItem(Const.KEY_IGNORE_UNKNOWN, value)
    return input_Tk
}

func parseBoolAttr(attr_Tk: Tokens): String {
    if (attr_Tk.size == 0) {
        return "true"
    }
    var token = attr_Tk[0]
    if (token.value == "true") {
        return "true"
    } else if (token.value == "false") {
        return "false"
    } else {
        throw MacroParameterException(
            "JsonIgnoreUnknown requires a boolean parameter (true/false), find '${token.value}' instead")
    }
}
