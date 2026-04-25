macro package json4cj.jsonmacro

import std.ast.*
import std.collection.ArrayList

/*
 * Generates stream-based deserialization code using stdx.encoding.json.stream API.
 *
 * Output: extend Clazz <: JsonDeserializable<Clazz> {
 *     public static func fromJson(r: JsonReader): Clazz { ... }
 * }
 *
 * === Rust-like one-time construction pattern ===
 *
 * All intermediate local variables use Option<FieldT> = None as initial value.
 * This eliminates the need for per-type default values and naturally supports
 * bare type parameters (e.g., T in generic classes).
 *
 *   var _name: Option<String> = None        // not var _name: String = ""
 *   var _data: Option<T> = None             // works for ANY T, no default needed
 *
 * When a field is read from JSON, it's wrapped in Some:
 *   _name = Some(r.readValue<String>())
 *
 * At construction time:
 *   - @JsonCreator: Clazz(_name.getOrThrow(), ...) — one-time construction
 *   - var-based: obj.field = _name.getOrThrow() — setter injection
 *   - If field is missing: getOrThrow() throws clear "required field missing" error
 *
 * Option<T> fields are a special case: they don't get double-wrapped.
 *   var _nickname: Option<String> = None    // stays as Option<String>, not Option<Option<String>>
 *   Missing fields naturally remain None (correct semantic behavior).
 *
 * === Two-path strategy: readValue<T>() vs JsonValue bridge ===
 *
 * Path 1 — Direct (preferred):
 *   _field = Some(r.readValue<T>())
 *   Requires: T <: JsonDeserializable<T> (stdx constraint)
 *   Works for: Int64, String, Bool, Float64, ArrayList<Int64>, etc.
 *
 * Path 2 — JsonValue bridge (fallback):
 *   _field = Some(T.fromJsonValue(JsonValue.fromStr(String.fromUtf8(r.readValueBytes()))))
 *   Used when: readValue<T>() fails due to cjc 1.0.1 constraint propagation
 *   Steps: readValueBytes() → String → JsonValue → T.fromJsonValue()
 *
 * === Key design notes ===
 *
 * 1. var obj (not let obj): struct types are value types; `let obj` makes the
 *    entire object immutable, preventing field assignment. Always use `var obj`.
 *    See TROUBLESHOOTING.md 5.4.
 *
 * 2. Constraint propagation: same issue as serializer — HashSet<T>, HashMap<K,V>
 *    fail readValue<T>() even though stdx provides the extend. See TROUBLESHOOTING.md 5.2.
 */
class ClassStreamDeserializer {
    private var globalConfig: ClassConfig

    public init(globalConfig: ClassConfig) {
        this.globalConfig = globalConfig
    }

    /*
     * Generates the extend block for JsonDeserializable<T>.
     * Includes path tracking for error reporting.
     */
    public func makeStreamFromJsonExtend(classIdent: Token, fieldConfigs: ArrayList<FieldConfig>, isGeneric: Bool, typeParams: Tokens, genericConstraint: ArrayList<GenericConstraint>): Tokens {
        let localVarDecls = composeLocalVarDecls(fieldConfigs)
        let matchCases = composeMatchCases(fieldConfigs)
        let returnCode = composeReturnCode(classIdent, fieldConfigs, isGeneric, typeParams)
        let className = classIdent.value
        let prefix = "JSON deserialization error at '"
        
        // Determine unknown field handling strategy
        var unknownFieldHandler = Tokens()
        if (let Some(false) <- globalConfig.ignoreUnknown) {
            // Annotation explicitly set to false → strict mode (hardcoded throw)
            unknownFieldHandler = quote(
                case _ => throw Exception("JSON deserialization error at '" + _path + "." + _fieldName + "': unknown field")
            )
        } else {
            // None or Some(true) → skip unknown fields silently (lenient mode)
            // Default: lenient mode (ignore unknown fields) — library default
            unknownFieldHandler = quote(
                case _ => r.skip()
            )
        }
        
        // Build full class type and extend declaration for generic classes
        // Cangjie requires type params on the extend keyword: extend<T> ClassName<T> <: Interface where T <: Constraint
        var fullClassType = Tokens()
        var extendDecl = Tokens()
        if (isGeneric && typeParams.size > 0) {
            let typeParamList = buildTypeParamList(typeParams)
            let whereClause = buildWhereClause(typeParams)
            fullClassType = quote($classIdent<$typeParamList>)
            extendDecl = quote(extend<$typeParamList> $classIdent<$typeParamList> <: JsonDeserializable<$classIdent<$typeParamList>> $whereClause)
        } else {
            fullClassType = quote($classIdent)
            extendDecl = quote(extend $classIdent <: JsonDeserializable<$classIdent>)
        }

        return quote(
            $extendDecl {
                public static func fromJson(r: JsonReader): $fullClassType {
                    let _path = "$"
                    r.startObject()
                    $localVarDecls
                    var _fieldName = ""
                    while (let Some(token) <- r.peek()) {
                        if (token == EndObject) {
                            break
                        }
                        _fieldName = r.readName()
                        try {
                            match (_fieldName) {
                                $matchCases
                                $unknownFieldHandler
                            }
                        } catch (e: Exception) {
                            if (e.message.startsWith($prefix)) {
                                throw e
                            }
                            throw Exception($prefix + _path + "." + _fieldName + "': " + e.message)
                        }
                    }
                    r.endObject()
                    $returnCode
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

    /*
     * Declare local variables using Rust-like Option<T> pattern.
     *
     * - Non-Option fields: var _name: Option<String> = None
     *   → Assigned as: _name = Some(parsedValue)
     *   → Used as: _name.getOrThrow() (throws if missing)
     *
     * - Option<T> fields: var _nickname: Option<String> = None
     *   → Assigned as: _nickname = Some(parsedValue) or stays None
     *   → Used as: _nickname (missing field naturally = None, correct semantic)
     *   → No double-wrapping: Option<String>, not Option<Option<String>>
     */
    private func composeLocalVarDecls(fieldConfigs: ArrayList<FieldConfig>): Tokens {
        var code = Tokens()
        for (fc in fieldConfigs) {
            let localVarName = Token(TokenKind.IDENTIFIER, "_" + fc.jsonName)
            if (let FieldCategory.OPTION <- fc.category) {
                // Option<T> fields: use Option<InnerT> = None directly (no double-wrap)
                let typeExpr = buildFullTypeExpr(fc)
                code = code + quote(
                    var $localVarName: $typeExpr = None
                )
            } else {
                // All other fields: wrap in Option<FieldType> = None
                let innerTypeExpr = buildFullTypeExpr(fc)
                code = code + quote(
                    var $localVarName: Option<$innerTypeExpr> = None
                )
            }
        }
        return code
    }

    /*
     * Build the full type expression as Tokens including generic params.
     * e.g., ArrayList<String> or Option<Int64>
     */
    private func buildFullTypeExpr(fc: FieldConfig): Tokens {
        let typeToken = Token(TokenKind.IDENTIFIER, fc.typeName)
        if (fc.typeArguments.size > 0) {
            var genericType_Tk = fc.typeArguments.flattenWithComma()
            return quote($typeToken<$genericType_Tk>)
        }
        return quote($typeToken)
    }

    /*
     * Compose match cases for each field's readName() dispatch.
     */
    private func composeMatchCases(fieldConfigs: ArrayList<FieldConfig>): Tokens {
        var code = Tokens()
        for (fc in fieldConfigs) {
            let key = fc.jsonName
            let localVarName = Token(TokenKind.IDENTIFIER, "_" + fc.jsonName)
            let readExpr = emitFieldRead(fc, localVarName)
            code = code + quote(
                case $key => $readExpr
            )
        }
        return code
    }

    /*
     * Emit the read expression for a single field based on its category.
     */
    private func emitFieldRead(fc: FieldConfig, localVarName: Token): Tokens {
        match (fc.category) {
            case CUSTOM_ADAPTER => emitCustomAdapterRead(fc, localVarName)
            case FORMAT_DATETIME => emitFormatDateTimeRead(fc, localVarName)
            case OPTION => emitOptionRead(fc, localVarName)
            case GENERIC_CONTAINER => emitGenericContainerRead(fc, localVarName)
            case PRIMITIVE => emitPrimitiveRead(fc, localVarName)
        }
    }

    // PRIMITIVE: use readValue<T> for native types, JsonValue bridge for user types
    // Non-Option fields are wrapped in Some(); Option fields assigned directly.
    private func emitPrimitiveRead(fc: FieldConfig, localVarName: Token): Tokens {
        if (isPrimitiveTypeName(fc.typeName)) {
            let typeToken = Token(TokenKind.IDENTIFIER, fc.typeName)
            let readExpr = quote(r.readValue<$typeToken>())
            return wrapAssignment(fc, localVarName, readExpr)
        } else {
            // User-defined type: fallback to JsonValue bridge
            let typeToken = Token(TokenKind.IDENTIFIER, fc.typeName)
            let readExpr = quote($typeToken.fromJsonValue(JsonValue.fromStr(String.fromUtf8(r.readValueBytes()))))
            return wrapAssignment(fc, localVarName, readExpr)
        }
    }

    // GENERIC_CONTAINER: use readValue<T> if natively supported, else JsonValue bridge
    private func emitGenericContainerRead(fc: FieldConfig, localVarName: Token): Tokens {
        if (isStreamNativeType(fc)) {
            let typeToken = Token(TokenKind.IDENTIFIER, fc.typeName)
            var genericType_Tk = fc.typeArguments.flattenWithComma()
            let readExpr = quote(r.readValue<$typeToken<$genericType_Tk>>())
            return wrapAssignment(fc, localVarName, readExpr)
        } else {
            // JsonValue bridge for HashSet, HashMap, etc.
            let typeExpr = buildFullTypeExpr(fc)
            let readExpr = quote($typeExpr.fromJsonValue(JsonValue.fromStr(String.fromUtf8(r.readValueBytes()))))
            return wrapAssignment(fc, localVarName, readExpr)
        }
    }

    // OPTION: read via JsonValue bridge for generic inner types, or readValue for concrete inner types
    // cjc 1.0.1 constraint propagation bug: readValue<Option<T>> fails even with where clause,
    // so we must use the JsonValue bridge when the inner type is a type parameter or user type.
    private func emitOptionRead(fc: FieldConfig, localVarName: Token): Tokens {
        if (fc.typeArguments.size == 0) {
            throw Exception("Option generic type not provided")
        }
        let innerType = fc.typeArguments[0]
        // Check if inner type is a known concrete type that readValue can handle
        let innerTypeName = getTypeArgumentName(innerType)
        if (isPrimitiveTypeName(innerTypeName) || innerTypeName == "ArrayList") {
            // Concrete type: use readValue<Option<InnerType>>()
            return quote($localVarName = r.readValue<Option<$innerType>>())
        } else {
            // Generic or user type: use JsonValue bridge
            // Read bytes → parse as JsonValue → check if null → Some(T.fromJsonValue()) or None
            return quote(
                let _optJsonValue = JsonValue.fromStr(String.fromUtf8(r.readValueBytes()))
                if (_optJsonValue is JsonNull) {
                    $localVarName = None
                } else {
                    $localVarName = Some($innerType.fromJsonValue(_optJsonValue))
                }
            )
        }
    }

    // FORMAT_DATETIME: read as String, then parse
    private func emitFormatDateTimeRead(fc: FieldConfig, localVarName: Token): Tokens {
        let pattern = fc.formatPattern.getOrThrow()
        let typeName = fc.typeName
        if (typeName == "DateTime") {
            let readExpr = quote(DateTime.parse(r.readValue<String>(), $pattern))
            return wrapAssignment(fc, localVarName, readExpr)
        } else {
            // Custom type with format — use JsonValue bridge
            let typeToken = Token(TokenKind.IDENTIFIER, typeName)
            let readExpr = quote($typeToken.fromJsonValue(JsonValue.fromStr(String.fromUtf8(r.readValueBytes()))))
            return wrapAssignment(fc, localVarName, readExpr)
        }
    }

    // CUSTOM_ADAPTER: AdapterType.fromJsonValue(...)
    private func emitCustomAdapterRead(fc: FieldConfig, localVarName: Token): Tokens {
        let adapterToken = Token(TokenKind.IDENTIFIER, fc.adapterName.getOrThrow())
        let readExpr = quote($adapterToken.fromJsonValue(JsonValue.fromStr(String.fromUtf8(r.readValueBytes()))))
        return wrapAssignment(fc, localVarName, readExpr)
    }

    /*
     * Wrap a read expression in Some() for non-Option fields.
     * Option fields are assigned directly (no double-wrap).
     */
    private func wrapAssignment(fc: FieldConfig, localVarName: Token, readExpr: Tokens): Tokens {
        if (let FieldCategory.OPTION <- fc.category) {
            return quote($localVarName = $readExpr)
        } else {
            return quote($localVarName = Some($readExpr))
        }
    }

    /*
     * Compose the return statement for the fromJson function.
     * - @JsonCreator: return Clazz(arg1.getOrThrow(), arg2.getOrThrow(), ...)
     *   → Rust-like one-time construction; getOrThrow() throws if field missing
     * - Normal mode: create obj, set fields via getOrThrow(), return obj
     * - Option fields: used directly (None = missing, correct semantic)
     *
     * NOTE: Uses `var obj` (not `let obj`) because struct types are value types —
     * `let obj` makes the entire object immutable, preventing obj.field = value.
     * For class types both work, but `var obj` is universally safe.
     * See TROUBLESHOOTING.md 5.4.
     */
    private func composeReturnCode(classIdent: Token, fieldConfigs: ArrayList<FieldConfig>, isGeneric: Bool, typeParams: Tokens): Tokens {
        // Build full class type
        var fullClassType = Tokens()
        if (isGeneric && typeParams.size > 0) {
            let typeParamList = buildTypeParamList(typeParams)
            fullClassType = quote($classIdent<$typeParamList>)
        } else {
            fullClassType = quote($classIdent)
        }
        
        if (globalConfig.useCreator) {
            // Constructor call: return Clazz<T>(arg1, arg2, ...)
            // Non-Option fields: _name.getOrThrow() (throws if missing)
            // Option fields: _nickname (directly, None if missing)
            var args = Tokens()
            var first = true
            for (fc in fieldConfigs) {
                if (!first) {
                    args = args + Token(TokenKind.COMMA, ",")
                }
                let localVarName = Token(TokenKind.IDENTIFIER, "_" + fc.jsonName)
                if (let FieldCategory.OPTION <- fc.category) {
                    args = args + quote($localVarName)
                } else {
                    args = args + quote($localVarName.getOrThrow())
                }
                first = false
            }
            return quote(return $fullClassType($args))
        } else {
            // Setter injection: create obj, set fields, return obj
            // Non-Option fields: obj.field = _name.getOrThrow()
            // Option fields: obj.field = _nickname
            var setCode = Tokens()
            for (fc in fieldConfigs) {
                let localVarName = Token(TokenKind.IDENTIFIER, "_" + fc.jsonName)
                if (let FieldCategory.OPTION <- fc.category) {
                    setCode = setCode + quote(
                        obj.$(fc.identifier) = $localVarName
                    )
                } else {
                    setCode = setCode + quote(
                        obj.$(fc.identifier) = $localVarName.getOrThrow()
                    )
                }
            }
            return quote(
                var obj = $fullClassType()
                $setCode
                return obj
            )
        }
    }

    /*
     * Check if a type is directly supported by stdx stream readValue<T>().
     *
     * cjc 1.0.1 BUG: writeValue<HashSet<Int64>>() / readValue<HashSet<Int64>>()
     * fail with "'Class-HashSet<Int64>' is not a subtype of 'Interface-JsonSerializable'"
     * even though stdx has `extend<T> HashSet<T> <: JsonSerializable where T <: JsonSerializable`
     * and `extend Int64 <: JsonSerializable`. The generic constraint is not propagated.
     *
     * ArrayList<T> is NOT affected — writeValue<ArrayList<Int64>>() works fine.
     * Verified by direct hand-written test (testDirectWriteValueArrayList).
     * See TROUBLESHOOTING.md 5.2.
     */
    private func isStreamNativeType(fc: FieldConfig): Bool {
        let typeName = fc.typeName
        if (isPrimitiveTypeName(typeName)) {
            return true
        }
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
        var name = ""
        for (tk in tokens) {
            name = name + tk.value
        }
        return name
    }

}
