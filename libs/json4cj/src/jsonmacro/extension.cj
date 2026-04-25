macro package json4cj.jsonmacro

import std.ast.*
import std.collection.ArrayList

interface TokenExtension {

}

extend TypeNode <: TokenExtension {

    /*
    * Gets the type name
    *
    * @return String the name of the type
    */
    public func getTypeName(): String {
        if (this is RefType) {
            return (this as RefType).getOrThrow().identifier.value
        } else if (this is PrimitiveType) {
            return (this as PrimitiveType).getOrThrow().keyword.value
        } else if (this is PrefixType) {
            throw TypeInferenceException("Option type expressed as '?Type' is currently not supported, please use 'Option<Type>' instead: ${this.toTokens()}")
        } else {
            throw TypeInferenceException("Error when trying to get type name for ${this.toTokens()}")
        }
    }
}

extend VarDecl <: TokenExtension {

    /*
     * Get info from VarDecl
     *
     * @return VarInfo
     */
    public func getVarInfo(): VarInfo {
        let identifier = identifier
        let name = identifier.value
        var typeName: String
        var typeArguments = ArrayList<TypeNode>()

        try {
            typeName = this.declType.getTypeName()
            if (this.declType is RefType) {
                let refType = (this.declType as RefType).getOrThrow()
                typeArguments = refType.typeArguments
            }
        } catch (exp: NoneValueException) {
            throw TypeInferenceException("Field ${name} must be declared with a specific type instead of using an inferred type")
        }
        return VarInfo(identifier, name, typeName, typeArguments)
    }
}

extend ArrayList<TypeNode> <: TokenExtension {
    public func flattenWithComma(): Tokens {
        var res_Tks = quote()
        for (typeNode in this) {
            res_Tks.append(typeNode)
            res_Tks.append(Token(COMMA))
        }

        res_Tks.remove(res_Tks.size - 1)
        return res_Tks
    }
}