macro package json4cj.jsonmacro

import std.ast.*

/*
 * Macro for enabling constructor-based JSON deserialization.
 * When applied, the deserializer generates code that calls the class constructor
 * with all field values, rather than using setter injection on a default instance.
 * This enables support for `let` (immutable) fields.
 *
 * This is the json4cj equivalent of Jackson's @JsonCreator on a constructor.
 *
 * Usage:
 *   @JsonSerialize
 *   @JsonCreator
 *   class User {
 *       let name: String    // let fields supported via constructor deserialization
 *       let age: Int64
 *
 *       public init(name: String, age: Int64) {
 *           this.name = name
 *           this.age = age
 *       }
 *   }
 *
 * Note: The class must have a constructor whose parameters match the class fields
 * in both name and order. The generated fromJsonValue() will call this constructor.
 */
public macro JsonCreator(input_Tk: Tokens): Tokens {
    assertParentContext(Const.JSON_SERIALIZE_MACRO_NAME)
    setItem(Const.KEY_USE_CREATOR, "true")
    return input_Tk
}
