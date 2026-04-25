macro package json4cj.jsonmacro

import std.ast.*

/*
 * Attribute macro for specifying the tagging strategy and discriminator field name
 * in polymorphic (class-inheritance-based) JSON serialization.
 *
 * Aligned with Rust Serde's enum representations:
 * - INTERNAL: {"type":"dog","name":"Buddy"} (default, recommended)
 * - EXTERNAL: {"Dog":{"name":"Buddy"}}
 * - ADJACENT: {"type":"dog","data":{"name":"Buddy"}}
 * - UNTAGGED: {"name":"Buddy"}
 *
 * Usage (on the base class):
 *   // Internal tagging (default)
 *   @JsonTypeInfo[tag = "type"]
 *   
 *   // External tagging
 *   @JsonTypeInfo[EXTERNAL]
 *   
 *   // Adjacent tagging
 *   @JsonTypeInfo[ADJACENT, tag = "type", content = "data"]
 *   
 *   // Untagged
 *   @JsonTypeInfo[UNTAGGED]
 *
 * During deserialization, the base class reads the type field (if present) and dispatches
 * to the correct subclass's fromJsonValue().
 */
public macro JsonTypeInfo(attr_Tk: Tokens, input_Tk: Tokens): Tokens {
    // Support both class and enum declarations
    let _ = TokenVerifier.verifyClassOrEnumDecl(input_Tk, Const.JSON_TYPE_INFO_MACRO_NAME)
    
    assertParentContext(Const.JSON_SERIALIZE_MACRO_NAME)
    
    // Parse strategy and parameters
    let (strategy, tag, content) = parseTypeInfoAttrs(attr_Tk)
    
    // Store in context for ClassConfigBuilder or EnumProcessor (strategy is already a string)
    setItem(Const.KEY_TAGGING_STRATEGY, strategy)
    setItem(Const.KEY_TYPE_INFO_TAG, tag)
    setItem(Const.KEY_CONTENT_FIELD, content)
    
    return input_Tk
}

/*
 * Parse @JsonTypeInfo attributes.
 *
 * Supports:
 * - @JsonTypeInfo[tag = "type"] → ("INTERNAL", "type", "data")
 * - @JsonTypeInfo[EXTERNAL] → ("EXTERNAL", "type", "data")
 * - @JsonTypeInfo[ADJACENT, tag = "type", content = "data"] → ("ADJACENT", "type", "data")
 * - @JsonTypeInfo[UNTAGGED] → ("UNTAGGED", "type", "data")
 */
func parseTypeInfoAttrs(attr_Tk: Tokens): (String, String, String) {
    var strategy = "INTERNAL"  // default
    var tagName = "type"  // default tag field
    var contentName = "data"  // default content field

    var i = 0
    while (i < attr_Tk.size) {
        let tk = attr_Tk[i]

        // Check for strategy enum or named parameters
        if (tk.kind == TokenKind.IDENTIFIER) {
            if (tk.value == "INTERNAL") {
                strategy = "INTERNAL"
            } else if (tk.value == "EXTERNAL") {
                strategy = "EXTERNAL"
            } else if (tk.value == "ADJACENT") {
                strategy = "ADJACENT"
            } else if (tk.value == "UNTAGGED") {
                strategy = "UNTAGGED"
            } else if (tk.value == "tag" && i + 2 < attr_Tk.size) {
                // tag = "...", look ahead for the string value
                let nextTk = attr_Tk[i + 2]
                if (nextTk.kind == TokenKind.STRING_LITERAL) {
                    tagName = nextTk.value
                }
            } else if (tk.value == "content" && i + 2 < attr_Tk.size) {
                // content = "...", look ahead for the string value
                let nextTk = attr_Tk[i + 2]
                if (nextTk.kind == TokenKind.STRING_LITERAL) {
                    contentName = nextTk.value
                }
            }
        }

        i += 1
    }

    return (strategy, tagName, contentName)
}
