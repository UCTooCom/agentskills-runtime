macro package json4cj.jsonmacro

import std.ast.*

/*
 * Attribute macro for specifying the discriminator value of a polymorphic subclass.
 *
 * Used on subclasses that inherit from a @JsonTypeInfo-annotated base class.
 * If omitted, defaults to the lowercased class name.
 *
 * Usage:
 *   @JsonSerialize
 *   @JsonType["dog"]     // explicit discriminator value
 *   class Dog <: Animal {
 *       var breed: String = ""
 *   }
 *
 * If @JsonType is omitted, the class name is lowercased as the discriminator:
 *   @JsonSerialize
 *   class Cat <: Animal { ... }  // discriminator = "cat"
 */
public macro JsonType(attr_Tk: Tokens, input_Tk: Tokens): Tokens {
    let _ = TokenVerifier.verifyClassDecl(input_Tk, Const.JSON_TYPE_MACRO_NAME)
    assertParentContext(Const.JSON_SERIALIZE_MACRO_NAME)
    let typeValue = parseTypeAttr(attr_Tk)
    setItem(Const.KEY_TYPE_VALUE, typeValue)
    return input_Tk
}

func parseTypeAttr(attr_Tk: Tokens): String {
    if (attr_Tk.size == 0) {
        throw MacroParameterException("JsonType requires a string parameter: @JsonType[\"value\"]")
    }
    let tk = attr_Tk[0]
    if (tk.kind == TokenKind.STRING_LITERAL) {
        return tk.value
    } else {
        throw MacroParameterException(
            "JsonType requires a string parameter, found ${tk.kind} instead")
    }
}
