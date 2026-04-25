macro package json4cj.jsonmacro

import std.ast.*

/*
 * Macro for controlling which fields are included in JSON serialization output.
 * This is the json4cj equivalent of Jackson's @JsonInclude(Include.NON_NULL).
 *
 * Usage:
 *   @JsonInclude[ALWAYS]      - always include all fields (default)
 *   @JsonInclude[NON_NULL]    - skip Option fields that are None
 *   @JsonInclude[NON_EMPTY]   - skip None, empty String, empty collections
 *
 * Example:
 *   @JsonSerialize
 *   @JsonInclude[NON_NULL]
 *   class User {
 *       var name: String = ""
 *       var bio: Option<String> = None  // None -> "bio" key not emitted
 *   }
 */
public macro JsonInclude(attr_Tk: Tokens, input_Tk: Tokens): Tokens {
    assertParentContext(Const.JSON_SERIALIZE_MACRO_NAME)
    let value = parseIncludeModeAttr(attr_Tk)
    setItem(Const.KEY_INCLUDE_MODE, value)
    return input_Tk
}

func parseIncludeModeAttr(attr_Tk: Tokens): String {
    if (attr_Tk.size == 0) {
        return "ALWAYS"
    }
    var token = attr_Tk[0]
    let value = token.value
    if (value == "ALWAYS" || value == "NON_NULL" || value == "NON_EMPTY") {
        return value
    } else {
        throw MacroParameterException("JsonInclude requires ALWAYS, NON_NULL, or NON_EMPTY, find '${value}' instead")
    }
}
