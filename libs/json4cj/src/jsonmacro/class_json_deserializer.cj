macro package json4cj.jsonmacro

import std.ast.*
internal import std.collection.*

/*
 * Deserializer of json for target class.
 *
 * Generates fromJsonValue(value) and fromJsonValue(value, path) with
 * JSON path propagation for error reporting.
 *
 * Each field deserialization is wrapped in try-catch:
 *   - Exceptions with path prefix: re-thrown as-is (already has path)
 *   - Other exceptions: wrapped with field path context
 *
 * Note: Generated code uses Exception (not JsonDeserializeException) because
 * the macro-expanded code appears in the user's file context where
 * JsonDeserializeException may not be imported. Path detection uses message
 * prefix convention: "JSON deserialization error at '...'".
 * See TROUBLESHOOTING.md for details on FQN limitations in macros.
 */
class ClassJsonDeserializer <: ClassProcessor {
    // Prefix used for path-aware exception messages.
    // Generated code checks this prefix to avoid double-wrapping.
    static let ERR_PREFIX = "JSON deserialization error at '"

    public init(classConfig: ClassConfig) {
        super(classConfig)
    }

    /*
     * Makes fromJson(), fromJsonValue() and fromJsonValue(value, path) using FieldConfig list.
     */
    public func makeFromJsonFunc(classIdentity_Tk: Token, fieldConfigs: ArrayList<FieldConfig>, isGeneric: Bool, typeParams: Tokens): Tokens {
        var jsonObjectToken = Token(TokenKind.IDENTIFIER, "jsonObject")
        let pathToken = Token(TokenKind.IDENTIFIER, "_path")
        
        // Build full class type for return types
        var fullClassType = Tokens()
        if (isGeneric && typeParams.size > 0) {
            let typeParamList = buildTypeParamList(typeParams)
            fullClassType = quote($classIdentity_Tk<$typeParamList>)
        } else {
            fullClassType = quote($classIdentity_Tk)
        }

        if (globalConfig.useCreator) {
            return makeCreatorFromJsonFunc(classIdentity_Tk, fieldConfigs, jsonObjectToken, pathToken, isGeneric, typeParams, fullClassType)
        }

        var fieldParseCode = parseJsonFieldsFromConfigs(fieldConfigs, jsonObjectToken, pathToken)
        var strictCheckCode = Tokens()
        if (let Some(false) <- globalConfig.ignoreUnknown) {
            // Annotation explicitly set to false → strict mode (hardcoded)
            strictCheckCode = makeStrictFieldCheckFromConfigs(classIdentity_Tk, fieldConfigs, jsonObjectToken, pathToken)
        }
        // When ignoreUnknown == None or Some(true): use lenient mode (skip unknown fields silently)
        // Default: lenient mode (ignore unknown fields) — library default
        
        // Build where clause for generic methods
        // NOTE: Static methods inside a generic class don't need where clause
        // The class-level where clause already constrains the type parameters
        
        return quote(
            public static func fromJson(json: String): $fullClassType {
                return $fullClassType.fromJsonValue(JsonValue.fromStr(json))
            }

            public static func fromJsonValue(json: JsonValue): $fullClassType {
                return $fullClassType.fromJsonValue(json, "$")
            }

            public static func fromJsonValue(json: JsonValue, $pathToken: String): $fullClassType {
                var ret = $fullClassType()
                var $jsonObjectToken = json.asObject()
                $fieldParseCode
                $strictCheckCode
                return ret
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
     * Legacy entry point: builds FieldConfig internally from VarDecl list.
     * NOTE: Not currently used - all callers use the FieldConfig version.
     */
    public func makeFromJsonFuncFromVarDecl(classIdentity_Tk: Token, var_Tk_List: ArrayList<VarDecl>, isGeneric: Bool, typeParams: Tokens): Tokens {
        let builder = FieldConfigBuilder(globalConfig)
        let fieldConfigs = builder.build(var_Tk_List)
        return makeFromJsonFunc(classIdentity_Tk, fieldConfigs, isGeneric, typeParams)
    }

    /*
     * Generates fromJson/fromJsonValue using constructor call instead of setter injection.
     * Used when @JsonCreator is present - enables let (immutable) field support.
     */
    private func makeCreatorFromJsonFunc(classIdentity_Tk: Token, fieldConfigs: ArrayList<FieldConfig>,
                                          jsonObject_Tk: Token, path_Tk: Token,
                                          isGeneric: Bool, typeParams: Tokens, fullClassType: Tokens): Tokens {
        var fieldParseCode = Tokens()
        var constructorArgs = Tokens()
        var first = true
        let prefix = ERR_PREFIX

        // Pre-compute bare type param names (e.g., "T", "K", "V")
        let bareTypeParamNames = extractTypeParamNames(typeParams)

        for (fc in fieldConfigs) {
            let mappedNameValue = fc.jsonName
            let localVarName = Token(TokenKind.IDENTIFIER, "_" + fc.jsonName)
            let fieldPath = fc.jsonName
            let typeToken = Token(TokenKind.IDENTIFIER, fc.typeName)

            // Check if this field is a bare type param (e.g., let data: T)
            let isBare = isBareTypeParam(fc.typeName, bareTypeParamNames)

            if (isBare) {
                // Bare type param: use Option<T> pattern to avoid T() constructor call
                // var _data: Option<T> = Option<T>.None
                // _data = Option<T>.Some(T.fromJsonValue(...))
                // if _data is None → throw "required field missing" (like serde)
                // constructor arg: _data.getOrThrow() (safe because we checked)
                let parseValueExpr = parseCreatorFieldValueFromConfig(fc, jsonObject_Tk, path_Tk)
                fieldParseCode = fieldParseCode + quote(
                    var $localVarName: Option<$typeToken> = Option<$typeToken>.None
                    if($jsonObject_Tk.getFields().contains($mappedNameValue)) {
                        try {
                            $localVarName = Option<$typeToken>.Some($parseValueExpr)
                        } catch (e: Exception) {
                            if (e.message.startsWith($prefix)) {
                                throw e
                            }
                            throw Exception($prefix + $path_Tk + "." + $fieldPath + "': " + e.message)
                        }
                    }
                    if($localVarName.isNone()) {
                        throw Exception($prefix + $path_Tk + "." + $fieldPath + "': required field is missing")
                    }
                )

                // Add .getOrThrow() for constructor arg
                if (!first) {
                    constructorArgs = constructorArgs + Token(TokenKind.COMMA, ",")
                }
                constructorArgs = constructorArgs + quote($localVarName.getOrThrow())
            } else {
                // Regular field: use default value pattern
                let parseAssignExpr = parseCreatorFieldAssignFromConfig(fc, jsonObject_Tk, localVarName, path_Tk)
                fieldParseCode = fieldParseCode + quote(
                    var $localVarName: $typeToken = $(getDefaultValue(fc))
                    if($jsonObject_Tk.getFields().contains($mappedNameValue)) {
                        try {
                            $parseAssignExpr
                        } catch (e: Exception) {
                            if (e.message.startsWith($prefix)) {
                                throw e
                            }
                            throw Exception($prefix + $path_Tk + "." + $fieldPath + "': " + e.message)
                        }
                    }
                )

                // Add to constructor args directly
                if (!first) {
                    constructorArgs = constructorArgs + Token(TokenKind.COMMA, ",")
                }
                constructorArgs = constructorArgs + quote($localVarName)
            }
            first = false
        }

        var strictCheckCode = Tokens()
        if (let Some(false) <- globalConfig.ignoreUnknown) {
            // Annotation explicitly set to false → strict mode (hardcoded)
            strictCheckCode = makeStrictFieldCheckFromConfigs(classIdentity_Tk, fieldConfigs, jsonObject_Tk, path_Tk)
        }
        // When ignoreUnknown == None or Some(true): use lenient mode (skip unknown fields silently)
        // Default: lenient mode (ignore unknown fields) — library default

        // Build where clause for generic methods
        // NOTE: Static methods inside a generic class don't need where clause

        return quote(
            public static func fromJson(json: String): $fullClassType {
                return $fullClassType.fromJsonValue(JsonValue.fromStr(json))
            }

            public static func fromJsonValue(json: JsonValue): $fullClassType {
                return $fullClassType.fromJsonValue(json, "$")
            }

            public static func fromJsonValue(json: JsonValue, $path_Tk: String): $fullClassType {
                var $jsonObject_Tk = json.asObject()
                $fieldParseCode
                $strictCheckCode
                return $fullClassType($constructorArgs)
            }
        )
    }

    /*
     * Generates assignment to a local variable for @JsonCreator mode.
     */
    private func parseCreatorFieldAssignFromConfig(fc: FieldConfig, jsonObjectVar_Tk: Token,
                                                    localVarName: Token, path_Tk: Token): Tokens {
        let mappedNameValue = fc.jsonName
        var nodeJson_Tk = quote($jsonObjectVar_Tk.get($mappedNameValue).getOrThrow())
        let fieldPath = fc.jsonName

        match (fc.category) {
            case CUSTOM_ADAPTER =>
                let serializer_Tk = Token(TokenKind.IDENTIFIER, fc.adapterName.getOrThrow())
                return quote($localVarName = $serializer_Tk.fromJsonValue($nodeJson_Tk, $path_Tk + "." + $fieldPath))
            case FORMAT_DATETIME =>
                let pattern = fc.formatPattern.getOrThrow()
                return quote($localVarName = DateTime.parse($nodeJson_Tk.asString().getValue(), $pattern))
            case OPTION =>
                if (fc.typeArguments.size == 0) {
                    throw Exception("Option generic type not provided")
                }
                let optionType = fc.typeArguments[0]
                return quote(
                    if ($nodeJson_Tk is JsonNull) {
                        $localVarName = Option<$optionType>.None
                    } else {
                        $localVarName = $optionType.fromJsonValue($nodeJson_Tk, $path_Tk + "." + $fieldPath)
                    }
                )
            case GENERIC_CONTAINER =>
                var serializer_Tk = Token(TokenKind.IDENTIFIER, fc.typeName)
                var genericType_Tk = fc.typeArguments.flattenWithComma()
                return quote($localVarName = $serializer_Tk<$genericType_Tk>.fromJsonValue($nodeJson_Tk, $path_Tk + "." + $fieldPath))
            case PRIMITIVE =>
                var serializer_Tk = Token(TokenKind.IDENTIFIER, fc.typeName)
                return quote($localVarName = $serializer_Tk.fromJsonValue($nodeJson_Tk, $path_Tk + "." + $fieldPath))
        }
    }

    /*
     * Generates just the VALUE expression for a bare type param field in @JsonCreator mode.
     * Unlike parseCreatorFieldAssignFromConfig, this returns ONLY the RHS expression
     * (no assignment), suitable for wrapping in Option<T>.Some(...).
     *
     * Bare type params are always PRIMITIVE category, so we only handle that case.
     */
    private func parseCreatorFieldValueFromConfig(fc: FieldConfig, jsonObjectVar_Tk: Token,
                                                   path_Tk: Token): Tokens {
        let mappedNameValue = fc.jsonName
        var nodeJson_Tk = quote($jsonObjectVar_Tk.get($mappedNameValue).getOrThrow())
        let fieldPath = fc.jsonName
        var serializer_Tk = Token(TokenKind.IDENTIFIER, fc.typeName)
        return quote($serializer_Tk.fromJsonValue($nodeJson_Tk, $path_Tk + "." + $fieldPath))
    }

    private func getDefaultValue(fc: FieldConfig): Tokens {
        let typeName = fc.typeName
        if (typeName == "String") {
            return quote("")
        } else if (typeName == "Int64") {
            return quote(0)
        } else if (typeName == "Int32") {
            return quote(Int32(0))
        } else if (typeName == "Int16") {
            return quote(Int16(0))
        } else if (typeName == "Int8") {
            return quote(Int8(0))
        } else if (typeName == "UInt64") {
            return quote(UInt64(0))
        } else if (typeName == "UInt32") {
            return quote(UInt32(0))
        } else if (typeName == "UInt16") {
            return quote(UInt16(0))
        } else if (typeName == "UInt8") {
            return quote(UInt8(0))
        } else if (typeName == "Float64") {
            return quote(0.0)
        } else if (typeName == "Float32") {
            return quote(Float32(0.0))
        } else if (typeName == "Float16") {
            return quote(Float16(0.0))
        } else if (typeName == "Bool") {
            return quote(false)
        } else if (typeName == "DateTime") {
            return quote(DateTime.now())
        } else if (typeName == "Option") {
            return quote(None)
        } else if (typeName == "ArrayList") {
            return quote(ArrayList())
        } else if (typeName == "HashSet") {
            return quote(HashSet())
        } else if (typeName == "HashMap") {
            return quote(HashMap())
        } else {
            return quote($(Token(TokenKind.IDENTIFIER, typeName))())
        }
    }

    private func parseJsonFieldsFromConfigs(fieldConfigs: ArrayList<FieldConfig>, jsonObject_Tk: Token, path_Tk: Token): Tokens {
        var fieldParseToken = Tokens()
        for (fc in fieldConfigs) {
            fieldParseToken = fieldParseToken + parseJsonFieldFromConfig(fc, jsonObject_Tk, path_Tk)
        }
        return fieldParseToken
    }

    private func parseJsonFieldFromConfig(fc: FieldConfig, jsonObjectVar_Tk: Token, path_Tk: Token): Tokens {
        let mappedNameValue = fc.jsonName
        let getFieldCore_Tk = parseJsonFieldCoreFromConfig(fc, jsonObjectVar_Tk, path_Tk)
        let fieldPath = fc.jsonName
        let prefix = ERR_PREFIX

        return quote(
            if($jsonObjectVar_Tk.getFields().contains($mappedNameValue)) {
                try {
                    $getFieldCore_Tk
                } catch (e: Exception) {
                    if (e.message.startsWith($prefix)) {
                        throw e
                    }
                    throw Exception($prefix + $path_Tk + "." + $fieldPath + "': " + e.message)
                }
            }
        )
    }

    private func parseJsonFieldCoreFromConfig(fc: FieldConfig, jsonObjectVar_Tk: Token, path_Tk: Token): Tokens {
        let mappedNameValue = fc.jsonName
        var nodeJson_Tk = quote($jsonObjectVar_Tk.get($mappedNameValue).getOrThrow())

        match (fc.category) {
            case CUSTOM_ADAPTER => getCustomProp(nodeJson_Tk, fc, path_Tk)
            case FORMAT_DATETIME => getFormatProp(nodeJson_Tk, fc)
            case OPTION => getOptionProp(nodeJson_Tk, fc, path_Tk)
            case GENERIC_CONTAINER => getGenericProp(nodeJson_Tk, fc, path_Tk)
            case PRIMITIVE => getProp(nodeJson_Tk, fc, path_Tk)
        }
    }

    private func getCustomProp(nodeJson_Tk: Tokens, fc: FieldConfig, path_Tk: Token): Tokens {
        let serializer_Tk = Token(TokenKind.IDENTIFIER, fc.adapterName.getOrThrow())
        let fieldPath = fc.jsonName
        return quote(
            ret.$(fc.identifier) = $serializer_Tk.fromJsonValue($nodeJson_Tk, $path_Tk + "." + $fieldPath)
        )
    }

    private func getFormatProp(nodeJson_Tk: Tokens, fc: FieldConfig): Tokens {
        let pattern = fc.formatPattern.getOrThrow()
        return quote(
            ret.$(fc.identifier) = DateTime.parse($nodeJson_Tk.asString().getValue(), $pattern)
        )
    }

    private func getOptionProp(nodeJson_Tk: Tokens, fc: FieldConfig, path_Tk: Token): Tokens {
        if (fc.typeArguments.size == 0) {
            throw Exception("Option generic type not provided")
        }

        let optionType = fc.typeArguments[0]
        let fieldPath = fc.jsonName
        return quote(
            if ($nodeJson_Tk is JsonNull) {
                ret.$(fc.identifier) = Option<$optionType>.None
            } else {
                ret.$(fc.identifier) = $optionType.fromJsonValue($nodeJson_Tk, $path_Tk + "." + $fieldPath)
            }
        )
    }

    private func getGenericProp(nodeJson_Tk: Tokens, fc: FieldConfig, path_Tk: Token): Tokens {
        var serializer_Tk = Token(TokenKind.IDENTIFIER, fc.typeName)
        var genericType_Tk = fc.typeArguments.flattenWithComma()
        let fieldPath = fc.jsonName
        return quote(
            ret.$(fc.identifier) = $serializer_Tk<$genericType_Tk>.fromJsonValue($nodeJson_Tk, $path_Tk + "." + $fieldPath)
        )
    }

    private func getProp(nodeJson_Tk: Tokens, fc: FieldConfig, path_Tk: Token): Tokens {
        var serializer_Tk = Token(TokenKind.IDENTIFIER, fc.typeName)
        let fieldPath = fc.jsonName
        return quote(
            ret.$(fc.identifier) = $serializer_Tk.fromJsonValue($nodeJson_Tk, $path_Tk + "." + $fieldPath)
        )
    }

    /*
     * Generates strict field validation code that collects ALL unknown fields
     * and throws a single exception listing them all with path context.
     * Only used when @JsonIgnoreUnknown(false) is set.
     */
    private func makeStrictFieldCheckFromConfigs(classIdentity_Tk: Token, fieldConfigs: ArrayList<FieldConfig>,
                                                  jsonObject_Tk: Token, path_Tk: Token): Tokens {
        var knownFieldAddCode = Tokens()
        for (fc in fieldConfigs) {
            let mappedName = fc.jsonName
            knownFieldAddCode = knownFieldAddCode + quote(
                knownFields.add($mappedName)
            )
        }
        let prefix = ERR_PREFIX
        return quote(
            let knownFields = HashSet<String>()
            $knownFieldAddCode
            var unknownFields = ArrayList<String>()
            for((key, _) in $jsonObject_Tk.getFields()) {
                if(!knownFields.contains(key)) {
                    unknownFields.add(key)
                }
            }
            if(unknownFields.size > 0) {
                throw Exception($prefix + $path_Tk + "': unknown fields " + unknownFields.toString())
            }
        )
    }

    /*
     * Extract type parameter identifier names from typeParams Tokens.
     * E.g., for `class Foo<T, K>`, typeParams = [T, ,, K] → ["T", "K"]
     */
    private func extractTypeParamNames(typeParams: Tokens): ArrayList<String> {
        let names = ArrayList<String>()
        for (i in 0..typeParams.size) {
            let tk = typeParams[i]
            if (tk.kind == TokenKind.IDENTIFIER) {
                names.add(tk.value)
            }
        }
        return names
    }

    /*
     * Check if a typeName matches one of the class's type parameters.
     * A "bare type param" field like `let data: T` where T is a generic parameter.
     */
    private func isBareTypeParam(typeName: String, typeParamNames: ArrayList<String>): Bool {
        for (name in typeParamNames) {
            if (typeName == name) {
                return true
            }
        }
        return false
    }
}
