macro package json4cj.jsonmacro

import std.ast.*
import std.collection.ArrayList

class ClassJsonSerializer <: ClassProcessor {
    public init(classConfig: ClassConfig) {
        super(classConfig)
    }

    /*
     * Makes toJsonValue() and toJson() functions of target class
     * using FieldConfig list for field categorization.
     */
    public func makeToJsonFunc(fieldConfigs: ArrayList<FieldConfig>, isGeneric: Bool, typeParams: Tokens): Tokens {
        // Methods inside a generic class don't need where clause
        // The class-level where clause already constrains the type parameters
        return quote(
            public func toJsonValue(): JsonObject {
                var map: HashMap<String, JsonValue> = HashMap()
                $(composeMapFromConfigs(fieldConfigs))
                return JsonObject(map)
            }

            public func toJson(): String {
                this.toJsonValue().toString()
            }
        )
    }

    /*
     * Build where clause for generic methods: where T <: JsonValueSerializable<T>
     */
    private func buildWhereClause(typeParams: Tokens): Tokens {
        // Use quote to generate: where T <: JsonValueSerializable<T>, U <: JsonValueSerializable<U>
        if (typeParams.size > 0) {
            return quote(where $(buildConstraints(typeParams)))
        }
        return Tokens()
    }
    
    private func buildConstraints(typeParams: Tokens): Tokens {
        var constraints = Tokens()
        var first = true
        // Iterate through the tokens - typeParams contains identifiers like T, U, V
        for (i in 0..typeParams.size) {
            let tk = typeParams[i]
            if (tk.kind == TokenKind.IDENTIFIER) {
                if (!first) {
                    constraints = constraints + Token(TokenKind.COMMA, ",")
                }
                constraints = constraints + quote($tk <: JsonValueSerializable<$tk>)
                first = false
            }
        }
        return constraints
    }

    /*
     * Legacy entry point: builds FieldConfig internally from VarDecl list.
     * Kept for backward compatibility during refactoring.
     * NOTE: Not currently used - all callers use the FieldConfig version.
     */
    public func makeToJsonFuncFromVarDecl(var_Tk_List: ArrayList<VarDecl>, isGeneric: Bool, typeParams: Tokens): Tokens {
        let builder = FieldConfigBuilder(globalConfig)
        let fieldConfigs = builder.build(var_Tk_List)
        return makeToJsonFunc(fieldConfigs, isGeneric, typeParams)
    }

    private func composeMapFromConfigs(fieldConfigs: ArrayList<FieldConfig>): Tokens {
        var fieldMapToken = Tokens()
        for (fc in fieldConfigs) {
            fieldMapToken = fieldMapToken + addFieldToMapFromConfig(fc)
        }
        return fieldMapToken
    }

    private func addFieldToMapFromConfig(fc: FieldConfig): Tokens {
        // Handle NON_EMPTY special cases first (only when annotation is present)
        if (let Some(IncludeMode.NON_EMPTY) <- fc.includeMode) {
            if (isCollectionType(fc.typeName)) {
                return addCollectionPropNonEmpty(fc)
            } else if (fc.typeName == "String") {
                return addStringPropNonEmpty(fc)
            }
        }
        // When includeMode == None or ALWAYS: use standard category-based dispatch
        // Default: ALWAYS mode (include all fields) — library default

        // Category-based dispatch
        match (fc.category) {
            case CUSTOM_ADAPTER => addCustomProp(fc)
            case FORMAT_DATETIME => addFormatProp(fc)
            case OPTION => addOptionProp(fc)
            case GENERIC_CONTAINER => addProp(fc)
            case PRIMITIVE => addProp(fc)
        }
    }

    private func isCollectionType(typeName: String): Bool {
        return typeName == "ArrayList" || typeName == "HashSet" || typeName == "HashMap"
    }

    private func addCustomProp(fc: FieldConfig): Tokens {
        let key = fc.jsonName
        let serializer_Tk = Token(TokenKind.IDENTIFIER, fc.adapterName.getOrThrow())
        return quote(
            map.add($key, $serializer_Tk(this.$(fc.identifier)).toJsonValue())
        )
    }

    private func addFormatProp(fc: FieldConfig): Tokens {
        let key = fc.jsonName
        let pattern = fc.formatPattern.getOrThrow()
        return quote(
            map.add($key, JsonString(this.$(fc.identifier).format($pattern)))
        )
    }

    private func addOptionProp(fc: FieldConfig): Tokens {
        let key = fc.jsonName
        if (let Some(IncludeMode.NON_NULL) <- fc.includeMode || let Some(IncludeMode.NON_EMPTY) <- fc.includeMode) {
            // Annotation present → skip nulls (hardcoded)
            return quote(
                if (let Some(v) <- this.$(fc.identifier)) {
                    map.add($key, v.toJsonValue())
                }
            )
        } else {
            // None or ALWAYS mode → include even if null (default behavior)
            return quote(
                if (let Some(v) <- this.$(fc.identifier)) {
                    map.add($key, v.toJsonValue())
                } else {
                    map.add($key, JsonNull())
                }
            )
        }
    }

    private func addCollectionPropNonEmpty(fc: FieldConfig): Tokens {
        let key = fc.jsonName
        return quote(
            if(!this.$(fc.identifier).isEmpty()) {
                map.add($key, this.$(fc.identifier).toJsonValue())
            }
        )
    }

    private func addStringPropNonEmpty(fc: FieldConfig): Tokens {
        let key = fc.jsonName
        return quote(
            if (this.$(fc.identifier).size > 0) {
                map.add($key, this.$(fc.identifier).toJsonValue())
            }
        )
    }

    private func addProp(fc: FieldConfig): Tokens {
        let key = fc.jsonName
        return quote(
            map.add($key, this.$(fc.identifier).toJsonValue())
        )
    }
}
