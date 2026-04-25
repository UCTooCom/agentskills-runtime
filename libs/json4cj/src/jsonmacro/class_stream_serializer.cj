macro package json4cj.jsonmacro

import std.ast.*
import std.collection.ArrayList

/*
 * Generates stream-based serialization code using stdx.encoding.json.stream API.
 *
 * Output: extend Clazz <: JsonSerializable {
 *     public func toJson(w: JsonWriter): Unit { ... }
 * }
 *
 * === Two-path strategy: writeValue<T>() vs JsonValue bridge ===
 *
 * Path 1 — Direct (preferred, zero-copy):
 *   w.writeName("key").writeValue<T>(this.field)
 *   Requires: T <: JsonSerializable (stdx constraint)
 *   Works for: Int64, String, Bool, Float64, ArrayList<Int64>, etc.
 *
 * Path 2 — JsonValue bridge (fallback):
 *   w.writeName("key").jsonValue(this.field.toJsonValue().toString())
 *   Requires: T <: JsonValueSerializable<T> (json4cj constraint, much looser)
 *   Used when: writeValue<T>() fails due to cjc 1.0.1 constraint propagation
 *
 * === Why JsonValue bridge is needed ===
 *
 * cjc 1.0.1 cannot propagate generic constraints through extend declarations.
 * Although stdx has: extend<T> HashSet<T> <: JsonSerializable where T <: JsonSerializable
 * and:            extend Int64 <: JsonSerializable
 * The compiler fails with: 'Class-HashSet<Int64>' is not a subtype of 'Interface-JsonSerializable'
 *
 * This is verified by direct hand-written tests — see TROUBLESHOOTING.md 5.2.
 * ArrayList<T> is NOT affected by this bug.
 *
 * === Type name note ===
 *
 * Generated code uses SHORT names (JsonSerializable, JsonWriter) not fully-qualified
 * names (stdx.encoding.json.stream.JsonSerializable) because cjc macro quote()
 * treats dotted names as chained member access, not type references.
 * Users must `import stdx.encoding.json.stream.*` in their source files.
 * See TROUBLESHOOTING.md 5.3.
 */
class ClassStreamSerializer {
    private var globalConfig: ClassConfig

    public init(globalConfig: ClassConfig) {
        this.globalConfig = globalConfig
    }

    /*
     * Generates the extend block for JsonSerializable.
     */
    public func makeStreamToJsonExtend(classIdent: Token, fieldConfigs: ArrayList<FieldConfig>, isGeneric: Bool, typeParams: Tokens): Tokens {
        let bodyCode = composeStreamToJsonBody(fieldConfigs)
        
        // For generic classes: extend<T> ClassName<T> <: JsonSerializable where T <: JsonValueSerializable<T>
        // Cangjie requires type params on the extend keyword: extend<T>, not just extend ClassName<T>
        var extendDecl = Tokens()
        if (isGeneric && typeParams.size > 0) {
            let typeParamList = buildTypeParamList(typeParams)
            let whereClause = buildWhereClause(typeParams)
            extendDecl = quote(extend<$typeParamList> $classIdent<$typeParamList> <: JsonSerializable $whereClause)
        } else {
            extendDecl = quote(extend $classIdent <: JsonSerializable)
        }
        
        return quote(
            $extendDecl {
                public func toJson(w: JsonWriter): Unit {
                    w.startObject()
                    $bodyCode
                    w.endObject()
                }
            }
        )
    }

    /*
     * Build where clause for generic methods
     */
    private func buildWhereClause(typeParams: Tokens): Tokens {
        if (typeParams.size > 0) {
            return quote(where $(buildConstraints(typeParams)))
        }
        return Tokens()
    }
    
    private func buildConstraints(typeParams: Tokens): Tokens {
        var constraints = Tokens()
        var first = true
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
     * Build comma-separated type parameter list
     */
    private func buildTypeParamList(typeParams: Tokens): Tokens {
        var result = Tokens()
        var first = true
        for (i in 0..typeParams.size) {
            let tk = typeParams[i]
            if (tk.kind == TokenKind.IDENTIFIER) {
                if (!first) {
                    result = result + Token(TokenKind.COMMA, ",")
                }
                result = result + tk
                first = false
            }
        }
        return result
    }

    private func composeStreamToJsonBody(fieldConfigs: ArrayList<FieldConfig>): Tokens {
        var code = Tokens()
        for (fc in fieldConfigs) {
            code = code + emitFieldWrite(fc)
        }
        return code
    }

    private func emitFieldWrite(fc: FieldConfig): Tokens {
        // Handle NON_EMPTY special cases first (only when annotation is present)
        if (let Some(IncludeMode.NON_EMPTY) <- fc.includeMode) {
            if (isCollectionType(fc.typeName)) {
                return emitCollectionNonEmpty(fc)
            } else if (fc.typeName == "String") {
                return emitStringNonEmpty(fc)
            }
        }
        // When includeMode == None or ALWAYS: use standard category-based dispatch
        // Default: ALWAYS mode (include all fields) — library default

        // Category-based dispatch
        match (fc.category) {
            case CUSTOM_ADAPTER => emitCustomAdapter(fc)
            case FORMAT_DATETIME => emitFormatDateTime(fc)
            case OPTION => emitOption(fc)
            case GENERIC_CONTAINER => emitGenericContainer(fc)
            case PRIMITIVE => emitPrimitive(fc)
        }
    }

    private func isCollectionType(typeName: String): Bool {
        return typeName == "ArrayList" || typeName == "HashSet" || typeName == "HashMap"
    }

    /*
     * Check if a type is directly supported by stdx stream writeValue<T>().
     *
     * cjc 1.0.1 BUG: writeValue<HashSet<Int64>>() fails with
     * "'Class-HashSet<Int64>' is not a subtype of 'Interface-JsonSerializable'"
     * even though stdx has `extend<T> HashSet<T> <: JsonSerializable where T <: JsonSerializable`
     * and `extend Int64 <: JsonSerializable`. The generic constraint is not propagated.
     *
     * ArrayList<T> is NOT affected — writeValue<ArrayList<Int64>>() works fine.
     * Verified by direct hand-written test (testDirectWriteValueArrayList).
     * See TROUBLESHOOTING.md 5.2.
     *
     * Currently only primitives and ArrayList<primitive> are considered "native".
     * This is intentionally conservative — when cjc fixes the constraint propagation,
     * this check can be expanded to include HashSet, HashMap, and user types
     * that implement JsonSerializable.
     */
    private func isStreamNativeType(fc: FieldConfig): Bool {
        let typeName = fc.typeName
        // Primitives are always native
        if (typeName == "String" || typeName == "Int64" || typeName == "Int32" ||
            typeName == "Int16" || typeName == "Int8" || typeName == "UInt64" ||
            typeName == "UInt32" || typeName == "UInt16" || typeName == "UInt8" ||
            typeName == "Float64" || typeName == "Float32" || typeName == "Float16" ||
            typeName == "Bool") {
            return true
        }
        // ArrayList with primitive inner types is native
        if (typeName == "ArrayList" && fc.typeArguments.size > 0) {
            let innerName = getTypeArgumentName(fc.typeArguments[0])
            if (isPrimitiveTypeName(innerName)) {
                return true
            }
        }
        return false
    }

    private func isPrimitiveTypeName(name: String): Bool {
        return name == "String" || name == "Int64" || name == "Int32" ||
            name == "Int16" || name == "Int8" || name == "UInt64" ||
            name == "UInt32" || name == "UInt16" || name == "UInt8" ||
            name == "Float64" || name == "Float32" || name == "Float16" ||
            name == "Bool"
    }

    private func getTypeArgumentName(typeNode: TypeNode): String {
        let tokens = typeNode.toTokens()
        // Flatten tokens to get the type name string
        var name = ""
        for (tk in tokens) {
            name = name + tk.value
        }
        return name
    }

    // PRIMITIVE: use writeValue<T> for native types, JsonValue bridge for user types
    private func emitPrimitive(fc: FieldConfig): Tokens {
        let key = fc.jsonName
        if (isPrimitiveTypeName(fc.typeName)) {
            let typeToken = Token(TokenKind.IDENTIFIER, fc.typeName)
            return quote(
                w.writeName($key).writeValue<$typeToken>(this.$(fc.identifier))
            )
        } else {
            // User-defined type: fallback to JsonValue bridge
            return quote(
                w.writeName($key).jsonValue(this.$(fc.identifier).toJsonValue().toString())
            )
        }
    }

    // GENERIC_CONTAINER: use writeValue<T> if natively supported, else JsonValue bridge
    private func emitGenericContainer(fc: FieldConfig): Tokens {
        let key = fc.jsonName
        if (isStreamNativeType(fc)) {
            var typeToken = Token(TokenKind.IDENTIFIER, fc.typeName)
            var genericType_Tk = fc.typeArguments.flattenWithComma()
            return quote(
                w.writeName($key).writeValue<$typeToken<$genericType_Tk>>(this.$(fc.identifier))
            )
        } else {
            // Fallback to JsonValue bridge for HashSet, HashMap, etc.
            return quote(
                w.writeName($key).jsonValue(this.$(fc.identifier).toJsonValue().toString())
            )
        }
    }

    // OPTION (ALWAYS/None): w.writeName("key"); if (let Some(v) <- this.field) { w.writeValue<Inner>(v) } else { w.writeNullValue() }
    // OPTION (NON_NULL/NON_EMPTY): if (let Some(v) <- this.field) { w.writeName("key").writeValue<Inner>(v) }
    private func emitOption(fc: FieldConfig): Tokens {
        let key = fc.jsonName
        if (fc.typeArguments.size == 0) {
            throw Exception("Option generic type not provided")
        }
        let innerType = fc.typeArguments[0]

        if (let Some(IncludeMode.NON_NULL) <- fc.includeMode || let Some(IncludeMode.NON_EMPTY) <- fc.includeMode) {
            // Annotation present → skip nulls (hardcoded)
            return quote(
                if (let Some(v) <- this.$(fc.identifier)) {
                    w.writeName($key).writeValue<$innerType>(v)
                }
            )
        } else {
            // None or ALWAYS mode → include even if null (default behavior)
            return quote(
                w.writeName($key)
                if (let Some(v) <- this.$(fc.identifier)) {
                    w.writeValue<$innerType>(v)
                } else {
                    w.writeNullValue()
                }
            )
        }
    }

    // FORMAT_DATETIME: w.writeName("key").writeValue<String>(this.field.format(pattern))
    private func emitFormatDateTime(fc: FieldConfig): Tokens {
        let key = fc.jsonName
        let pattern = fc.formatPattern.getOrThrow()
        return quote(
            w.writeName($key).writeValue<String>(this.$(fc.identifier).format($pattern))
        )
    }

    // CUSTOM_ADAPTER: use JsonValue bridge since json4cj adapters have toJsonValue(), not toJson(w)
    private func emitCustomAdapter(fc: FieldConfig): Tokens {
        let key = fc.jsonName
        let adapterToken = Token(TokenKind.IDENTIFIER, fc.adapterName.getOrThrow())
        return quote(
            w.writeName($key).jsonValue($adapterToken(this.$(fc.identifier)).toJsonValue().toString())
        )
    }

    // NON_EMPTY + Collection: if (!this.field.isEmpty()) { ... }
    private func emitCollectionNonEmpty(fc: FieldConfig): Tokens {
        let key = fc.jsonName
        if (isStreamNativeType(fc)) {
            var typeToken = Token(TokenKind.IDENTIFIER, fc.typeName)
            var genericType_Tk = fc.typeArguments.flattenWithComma()
            return quote(
                if(!this.$(fc.identifier).isEmpty()) {
                    w.writeName($key).writeValue<$typeToken<$genericType_Tk>>(this.$(fc.identifier))
                }
            )
        } else {
            return quote(
                if(!this.$(fc.identifier).isEmpty()) {
                    w.writeName($key).jsonValue(this.$(fc.identifier).toJsonValue().toString())
                }
            )
        }
    }

    // NON_EMPTY + String: if (this.field.size > 0) { w.writeName("key").writeValue<String>(this.field) }
    private func emitStringNonEmpty(fc: FieldConfig): Tokens {
        let key = fc.jsonName
        return quote(
            if (this.$(fc.identifier).size > 0) {
                w.writeName($key).writeValue<String>(this.$(fc.identifier))
            }
        )
    }
}
