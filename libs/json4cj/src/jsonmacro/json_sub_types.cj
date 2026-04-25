macro package json4cj.jsonmacro

import std.ast.*

/*
 * Attribute macro for registering subtype mappings in polymorphic serialization.
 *
 * This is the json4cj equivalent of Jackson's @JsonSubTypes.
 *
 * Usage (on the base class):
 *   @JsonSerialize
 *   @JsonTypeInfo[tag = "type"]
 *   @JsonSubTypes["dog" => Dog, "cat" => Cat]
 *   open class Animal { ... }
 *
 * The mapping format is: "discriminatorValue" => ClassName
 * Multiple mappings are comma-separated within the brackets.
 *
 * During deserialization, the base class reads the discriminator field
 * and dispatches to the mapped subclass's fromJsonValue().
 *
 * During serialization, each subclass knows its discriminator value
 * via @JsonType["dog"] (or defaults to lowercased class name).
 */
public macro JsonSubTypes(attr_Tk: Tokens, input_Tk: Tokens): Tokens {
    let _ = TokenVerifier.verifyClassDecl(input_Tk, Const.JSON_SUB_TYPES_MACRO_NAME)
    assertParentContext(Const.JSON_SERIALIZE_MACRO_NAME)
    let mappingStr = parseSubTypesAttr(attr_Tk)
    setItem(Const.KEY_SUB_TYPE_MAPPING, mappingStr)
    return input_Tk
}

/*
 * Parse @JsonSubTypes["dog" => Dog, "cat" => Cat] into a serialized mapping string.
 * Output format: "dog=>Dog,cat=>Cat"
 *
 * attr_Tk tokens for "dog" => Dog, "cat" => Cat:
 *   [STRING("dog"), FAT_ARROW, IDENT(Dog), COMMA, STRING("cat"), FAT_ARROW, IDENT(Cat)]
 */
func parseSubTypesAttr(attr_Tk: Tokens): String {
    var mappings = ArrayList<String>()
    var i: Int64 = 0
    while (i < attr_Tk.size) {
        let tk = attr_Tk[i]
        if (tk.kind == TokenKind.STRING_LITERAL) {
            let discValue = tk.value
            // Next tokens should be: => ClassName
            var className = ""
            if (i + 2 < attr_Tk.size) {
                let arrowTk = attr_Tk[i + 1]
                let nameTk = attr_Tk[i + 2]
                if (arrowTk.value == "=>" &&
                    nameTk.kind == TokenKind.IDENTIFIER) {
                    className = nameTk.value
                    i = i + 3
                } else {
                    i = i + 1
                }
            } else {
                i = i + 1
            }
            if (className != "") {
                mappings.add(discValue + "=>" + className)
            }
        } else {
            i = i + 1
        }
    }

    if (mappings.size == 0) {
        throw MacroParameterException("JsonSubTypes requires at least one mapping: \"value\" => ClassName")
    }

    // Join with comma
    var result = ""
    var first = true
    for (m in mappings) {
        if (!first) {
            result = result + ","
        }
        result = result + m
        first = false
    }
    return result
}
