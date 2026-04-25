macro package json4cj.jsonmacro

import std.ast.*

/*
* Macro for custom json deserialization
* @param attr_Tk the serializer class name
* @param input_Tk the target var
* @return token the expanded token representation
*/
public macro JsonDeserialize(attr_Tk: Tokens, input_Tk: Tokens): Tokens {
    var decl = TokenVerifier.verifyVarDecl(input_Tk, Const.JSON_DESERIALIZE_MACRO_NAME)
    
    assertParentContext("JsonSerialize")
    setItem("prop", decl.identifier.value)
    setItem("serializer", attr_Tk.toString())
    
    return input_Tk
}