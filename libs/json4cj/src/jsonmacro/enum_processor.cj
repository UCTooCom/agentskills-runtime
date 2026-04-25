macro package json4cj.jsonmacro

import std.ast.*
import std.collection.{ArrayList, HashSet}

/*
 * Generates JSON serialization/deserialization code for enums.
 *
 * Supports both simple (unit-variant) and parameterized (ADT) enums.
 *
 * Serialization strategy (serde externally-tagged):
 *   - Unit variant:   Active         => "Active"
 *   - Single param:   Circle(3.14)   => {"Circle": 3.14}
 *   - Multi param:    Rect(3.0, 4.0) => {"Rect": [3.0, 4.0]}
 *
 * Backward compatible: pure unit-variant enums still serialize as plain strings.
 *
 * Generated code layout:
 *   enum Shape <: JsonCodec<Shape> {
 *       | Circle(Float64) | Rect(Float64, Float64) | Point
 *       func toJsonValue(): JsonValue { ... }
 *       func toJson(): String { ... }
 *       static func fromJsonValue(value: JsonValue): Shape { ... }
 *       static func fromJson(json: String): Shape { ... }
 *   }
 *   extend Shape <: JsonSerializable { ... }
 *   extend Shape <: JsonDeserializable<Shape> { ... }
 *
 * Constraints:
 *   - Same-name constructors with different arities are rejected (ambiguous JSON key)
 *   - Recursive enums are supported (param types must implement JsonValueSerializable<T>)
 */
class EnumProcessor {
    private let enumDecl: EnumDecl
    // Polymorphic tagging configuration (from @JsonTypeInfo)
    private var taggingStrategy: String
    private var typeInfoTag: String
    private var contentField: String

    public init(enumDecl: EnumDecl, taggingStrategy: String, 
                typeInfoTag: String, contentField: String) {
        this.enumDecl = enumDecl
        this.taggingStrategy = taggingStrategy
        this.typeInfoTag = typeInfoTag
        this.contentField = contentField
    }

    /*
     * Main entry: validate and compose the full macro output.
     */
    public func compose(): Tokens {
        let constructors = enumDecl.constructors
        let enumIdent = enumDecl.identifier
        let enumModifiers = enumDecl.modifiers
        let existingSuperTypes = enumDecl.superTypes
        let existingDecls = enumDecl.decls

        if (constructors.size == 0) {
            throw MacroExpansionException(
                "@JsonSerialize requires at least one enum constructor. Enum '${enumIdent.value}' is empty.")
        }

        // Reject duplicate constructor names (e.g., | Red | Red(UInt8))
        let nameSet = HashSet<String>()
        for (ctor in constructors) {
            let name = ctor.identifier.value
            if (nameSet.contains(name)) {
                throw MacroExpansionException(
                    "@JsonSerialize does not support same-name enum constructors with different arities. " +
                    "Enum '${enumIdent.value}' has duplicate constructor '${name}'.")
            }
            nameSet.add(name)
        }

        // Check if any constructor has parameters (determines generation strategy)
        let hasParameterized = hasParameterizedConstructors(constructors)

        // Generate functions
        let toJsonValueFunc = makeToJsonValueFunc(constructors, hasParameterized)
        let toJsonFunc = makeToJsonFunc()
        let fromJsonValueFunc = makeFromJsonValueFunc(enumIdent, constructors, hasParameterized)
        let fromJsonFunc = makeFromJsonFunc(enumIdent)

        // Reconstruct constructors as tokens
        let ctorTokens = reconstructConstructors(constructors)

        // Reconstruct existing member decls as tokens
        let declTokens = reconstructDecls(existingDecls)

        // Build supertype expression
        var superTypeExpr = Tokens()
        if (existingSuperTypes.size != 0) {
            superTypeExpr = quote(<: $existingSuperTypes & JsonCodec<$enumIdent>)
        } else {
            superTypeExpr = quote(<: JsonCodec<$enumIdent>)
        }

        // Stream extends
        let streamToJsonExtend = makeStreamToJsonExtend(enumIdent, hasParameterized)
        let streamFromJsonExtend = makeStreamFromJsonExtend(enumIdent)

        return quote(
            $enumModifiers enum $enumIdent $superTypeExpr {
                $ctorTokens
                $declTokens
                $toJsonValueFunc
                $toJsonFunc
                $fromJsonValueFunc
                $fromJsonFunc
            }
            $streamToJsonExtend
            $streamFromJsonExtend
        )
    }

    private func hasParameterizedConstructors(constructors: ArrayList<Constructor>): Bool {
        for (ctor in constructors) {
            if (ctor.typeArguments.size > 0) {
                return true
            }
        }
        return false
    }

    /*
     * Reconstruct enum constructors as tokens: | Active | Circle(Float64) | Rect(Float64, Float64)
     * Constructor.toTokens() does not include the leading `|` separator,
     * so we must add it explicitly.
     */
    private func reconstructConstructors(constructors: ArrayList<Constructor>): Tokens {
        var result = Tokens()
        for (ctor in constructors) {
            result = result + Token(TokenKind.BITOR, "|") + ctor.toTokens()
        }
        return result
    }

    /*
     * Reconstruct existing enum member declarations (functions, properties, etc.)
     */
    private func reconstructDecls(decls: ArrayList<Decl>): Tokens {
        var result = Tokens()
        for (d in decls) {
            result = result + d.toTokens()
        }
        return result
    }

    /*
     * Generate binding variable tokens for match patterns: v0, v1, ...
     */
    private func makeBindingVars(count: Int64): Tokens {
        var result = Tokens()
        for (i in 0..count) {
            if (i > 0) {
                result = result + Token(TokenKind.COMMA, ",")
            }
            result = result + Token(TokenKind.IDENTIFIER, "v${i}")
        }
        return result
    }

    /*
     * Generate toJsonValue() with strategy-aware code generation.
     *
     * INTERNAL (default): {"type":"Dog","name":"Buddy"}
     * EXTERNAL: {"Dog":{"name":"Buddy"}}
     * ADJACENT: {"type":"Dog","data":{"name":"Buddy"}}
     * UNTAGGED: {"name":"Buddy"}
     */
    private func makeToJsonValueFunc(constructors: ArrayList<Constructor>, hasParameterized: Bool): Tokens {
        match (this.taggingStrategy) {
            case "EXTERNAL" => makeToJsonValueExternal(constructors)
            case "ADJACENT" => makeToJsonValueAdjacent(constructors)
            case "UNTAGGED" => makeToJsonValueUntagged(constructors)
            case _ => makeToJsonValueInternal(constructors)  // INTERNAL is default
        }
    }

    /*
     * INTERNAL strategy: {"type":"Dog","name":"Buddy"}
     * Type discriminator is added as a field inside the object.
     */
    private func makeToJsonValueInternal(constructors: ArrayList<Constructor>): Tokens {
        var matchArms = Tokens()
        for (ctor in constructors) {
            let name = ctor.identifier.value
            let ctorIdent = ctor.identifier
            let paramCount = ctor.typeArguments.size
            let tagField = this.typeInfoTag
            
            if (paramCount == 0) {
                // Unit variant: {"type":"VariantName"}
                matchArms = matchArms + quote(
                    case $ctorIdent =>
                        let _map = HashMap<String, JsonValue>()
                        _map.add($tagField, JsonString($name))
                        JsonObject(_map)
                )
            } else {
                // Parameterized variant: add type field + all params
                let bindVars = makeBindingVars(paramCount)
                var fieldAdds = Tokens()
                // Add type discriminator first
                fieldAdds = fieldAdds + quote(
                    _map.add($tagField, JsonString($name))
                )
                // Add each parameter field
                for (i in 0..paramCount) {
                    let vi = Token(TokenKind.IDENTIFIER, "v${i}")
                    let fieldName = Token(TokenKind.STRING_LITERAL, "v${i}")
                    fieldAdds = fieldAdds + quote(
                        _map.add($fieldName, $vi.toJsonValue())
                    )
                }
                
                matchArms = matchArms + quote(
                    case $ctorIdent($bindVars) =>
                        let _map = HashMap<String, JsonValue>()
                        $fieldAdds
                        JsonObject(_map)
                )
            }
        }
        
        return quote(
            public func toJsonValue(): JsonValue {
                match (this) {
                    $matchArms
                }
            }
        )
    }

    /*
     * EXTERNAL strategy: {"Dog":{"name":"Buddy"}}
     * Type discriminator is the key, data is the value.
     */
    private func makeToJsonValueExternal(constructors: ArrayList<Constructor>): Tokens {
        var matchArms = Tokens()
        for (ctor in constructors) {
            let name = ctor.identifier.value
            let ctorIdent = ctor.identifier
            let paramCount = ctor.typeArguments.size
            
            if (paramCount == 0) {
                // Unit variant: "VariantName"
                matchArms = matchArms + quote(
                    case $ctorIdent => JsonString($name)
                )
            } else if (paramCount == 1) {
                // Single-param: {"CtorName": value}
                let bindVars = makeBindingVars(paramCount)
                let v0 = Token(TokenKind.IDENTIFIER, "v0")
                matchArms = matchArms + quote(
                    case $ctorIdent($bindVars) =>
                        let _map = HashMap<String, JsonValue>()
                        _map.add($name, $v0.toJsonValue())
                        JsonObject(_map)
                )
            } else {
                // Multi-param: {"CtorName": [v0, v1, ...]}
                let bindVars = makeBindingVars(paramCount)
                var arrAdds = Tokens()
                for (i in 0..paramCount) {
                    let vi = Token(TokenKind.IDENTIFIER, "v${i}")
                    arrAdds = arrAdds + quote(
                        _arr.add($vi.toJsonValue())
                    )
                }
                
                matchArms = matchArms + quote(
                    case $ctorIdent($bindVars) =>
                        let _arr = JsonArray()
                        $arrAdds
                        let _map = HashMap<String, JsonValue>()
                        _map.add($name, _arr)
                        JsonObject(_map)
                )
            }
        }
        
        return quote(
            public func toJsonValue(): JsonValue {
                match (this) {
                    $matchArms
                }
            }
        )
    }

    /*
     * ADJACENT strategy: {"type":"Dog","data":{"name":"Buddy"}}
     * Type discriminator and data are separate fields at same level.
     */
    private func makeToJsonValueAdjacent(constructors: ArrayList<Constructor>): Tokens {
        var matchArms = Tokens()
        let tagField = this.typeInfoTag
        let dataField = this.contentField
        
        for (ctor in constructors) {
            let name = ctor.identifier.value
            let ctorIdent = ctor.identifier
            let paramCount = ctor.typeArguments.size
            
            if (paramCount == 0) {
                // Unit variant: {"type":"VariantName"}
                matchArms = matchArms + quote(
                    case $ctorIdent =>
                        let _map = HashMap<String, JsonValue>()
                        _map.add($tagField, JsonString($name))
                        JsonObject(_map)
                )
            } else {
                // Parameterized variant: {"type":"CtorName","data":{...}}
                let bindVars = makeBindingVars(paramCount)
                var innerFieldAdds = Tokens()
                for (i in 0..paramCount) {
                    let vi = Token(TokenKind.IDENTIFIER, "v${i}")
                    let fieldName = Token(TokenKind.STRING_LITERAL, "v${i}")
                    innerFieldAdds = innerFieldAdds + quote(
                        _innerMap.add($fieldName, $vi.toJsonValue())
                    )
                }
                
                matchArms = matchArms + quote(
                    case $ctorIdent($bindVars) =>
                        let _innerMap = HashMap<String, JsonValue>()
                        $innerFieldAdds
                        let _outerMap = HashMap<String, JsonValue>()
                        _outerMap.add($tagField, JsonString($name))
                        _outerMap.add($dataField, JsonObject(_innerMap))
                        JsonObject(_outerMap)
                )
            }
        }
        
        return quote(
            public func toJsonValue(): JsonValue {
                match (this) {
                    $matchArms
                }
            }
        )
    }

    /*
     * UNTAGGED strategy: {"name":"Buddy"}
     * No type discriminator, just the data.
     */
    private func makeToJsonValueUntagged(constructors: ArrayList<Constructor>): Tokens {
        var matchArms = Tokens()
        for (ctor in constructors) {
            let ctorIdent = ctor.identifier
            let paramCount = ctor.typeArguments.size
            
            if (paramCount == 0) {
                // Unit variant: empty object
                matchArms = matchArms + quote(
                    case $ctorIdent => JsonObject(HashMap<String, JsonValue>())
                )
            } else if (paramCount == 1) {
                // Single-param: just the value
                let bindVars = makeBindingVars(paramCount)
                let v0 = Token(TokenKind.IDENTIFIER, "v0")
                matchArms = matchArms + quote(
                    case $ctorIdent($bindVars) => $v0.toJsonValue()
                )
            } else {
                // Multi-param: array of values
                let bindVars = makeBindingVars(paramCount)
                var arrAdds = Tokens()
                for (i in 0..paramCount) {
                    let vi = Token(TokenKind.IDENTIFIER, "v${i}")
                    arrAdds = arrAdds + quote(
                        _arr.add($vi.toJsonValue())
                    )
                }
                
                matchArms = matchArms + quote(
                    case $ctorIdent($bindVars) =>
                        let _arr = JsonArray()
                        $arrAdds
                        _arr
                )
            }
        }
        
        return quote(
            public func toJsonValue(): JsonValue {
                match (this) {
                    $matchArms
                }
            }
        )
    }

    /*
     * Generate toJson():
     *   public func toJson(): String {
     *       this.toJsonValue().toString()
     *   }
     */
    private func makeToJsonFunc(): Tokens {
        return quote(
            public func toJson(): String {
                this.toJsonValue().toString()
            }
        )
    }

    /*
     * Generate fromJsonValue() for pure unit-variant enums (simple string match).
     */
    private func makeFromJsonValueFuncSimple(enumIdent: Token, constructors: ArrayList<Constructor>): Tokens {
        var matchArms = Tokens()
        for (ctor in constructors) {
            let name = ctor.identifier.value
            let ctorIdent = ctor.identifier
            matchArms = matchArms + quote(
                case $name => $ctorIdent
            )
        }

        let enumName = enumIdent.value
        let prefix = "JSON deserialization error at '"
        return quote(
            public static func fromJsonValue(value: JsonValue): $enumIdent {
                return $enumIdent.fromJsonValue(value, "$")
            }

            public static func fromJsonValue(value: JsonValue, _path: String): $enumIdent {
                let str = (value as JsonString).getOrThrow().getValue()
                match (str) {
                    $matchArms
                    case _ => throw Exception($prefix + _path + "': unknown " + $enumName + " enum value: " + str)
                }
            }
        )
    }

    /*
     * Generate fromJsonValue() for mixed enums (unit + parameterized).
     *
     * Branches on JsonValue.kind:
     *   - JsonString => match unit variant names
     *   - JsonObject => extract single key, match parameterized variant names
     */
    private func makeFromJsonValueFuncMixed(enumIdent: Token, constructors: ArrayList<Constructor>): Tokens {
        let enumName = enumIdent.value
        let prefix = "JSON deserialization error at '"

        // Build unit variant match arms (for JsonString branch)
        var unitArms = Tokens()
        var hasUnitVariants = false
        for (ctor in constructors) {
            if (ctor.typeArguments.size == 0) {
                hasUnitVariants = true
                let name = ctor.identifier.value
                let ctorIdent = ctor.identifier
                unitArms = unitArms + quote(
                    case $name => $ctorIdent
                )
            }
        }

        // Build parameterized variant match arms (for JsonObject branch)
        var paramArms = Tokens()
        for (ctor in constructors) {
            let paramCount = ctor.typeArguments.size
            if (paramCount == 0) {
                continue
            }
            let name = ctor.identifier.value
            let ctorIdent = ctor.identifier

            if (paramCount == 1) {
                // Single param: CtorName(ParamType.fromJsonValue(_val))
                let paramType = ctor.typeArguments[0].toTokens()
                paramArms = paramArms + quote(
                    case $name => $ctorIdent($paramType.fromJsonValue(_val))
                )
            } else {
                // Multi param: extract from JsonArray
                // Build constructor arguments: Type0.fromJsonValue(_items[0]), Type1.fromJsonValue(_items[1]), ...
                var ctorArgs = Tokens()
                for (i in 0..paramCount) {
                    if (i > 0) {
                        ctorArgs = ctorArgs + Token(TokenKind.COMMA, ",")
                    }
                    let paramType = ctor.typeArguments[i].toTokens()
                    let idx = Token(TokenKind.INTEGER_LITERAL, "${i}")
                    ctorArgs = ctorArgs + quote($paramType.fromJsonValue(_items[$idx]))
                }
                paramArms = paramArms + quote(
                    case $name =>
                        let _items = _val.asArray().getOrThrow().getItems()
                        $ctorIdent($ctorArgs)
                )
            }
        }

        // Build the string branch body for unit variants
        var unitMatchBody = Tokens()
        if (hasUnitVariants) {
            unitMatchBody = quote(
                match (_str) {
                    $unitArms
                    case _ => throw Exception($prefix + _path + "': unknown " + $enumName + " enum value: " + _str)
                }
            )
        } else {
            unitMatchBody = quote(
                throw Exception($prefix + _path + "': expected JsonObject for " + $enumName + " enum, got " + value.toString())
            )
        }

        // Note: JsonObject.getFields() returns HashMap<String, JsonValue>,
        // which cannot be indexed by Int64. We iterate to extract the single key-value pair.
        // Use type pattern matching (case _s: JsonString =>) instead of match(value.kind)
        // to avoid resolution issues inside enum bodies.
        return quote(
            public static func fromJsonValue(value: JsonValue): $enumIdent {
                return $enumIdent.fromJsonValue(value, "$")
            }

            public static func fromJsonValue(value: JsonValue, _path: String): $enumIdent {
                match (value) {
                    case _s: JsonString =>
                        let _str = _s.getValue()
                        $unitMatchBody
                    case _o: JsonObject =>
                        var _key = ""
                        var _val: JsonValue = _o
                        let _fields = _o.getFields()
                        if (_fields.size != 1) {
                            throw Exception($prefix + _path + "': expected single-key JSON object for " + $enumName + " enum, got " + value.toString())
                        }
                        for ((_k, _v) in _fields) {
                            _key = _k
                            _val = _v
                        }
                        match (_key) {
                            $paramArms
                            case _ => throw Exception($prefix + _path + "': unknown " + $enumName + " enum constructor: " + _key)
                        }
                    case _ => throw Exception($prefix + _path + "': expected JsonString or JsonObject for " + $enumName + " enum, got " + value.toString())
                }
            }
        )
    }

    /*
     * Dispatch to strategy-aware fromJsonValue generator.
     */
    private func makeFromJsonValueFunc(enumIdent: Token, constructors: ArrayList<Constructor>,
                                       hasParameterized: Bool): Tokens {
        match (this.taggingStrategy) {
            case "EXTERNAL" => makeFromJsonValueExternal(enumIdent, constructors)
            case "ADJACENT" => makeFromJsonValueAdjacent(enumIdent, constructors)
            case "UNTAGGED" => makeFromJsonValueUntagged(enumIdent, constructors)
            case _ => makeFromJsonValueInternal(enumIdent, constructors)  // INTERNAL is default
        }
    }

    /*
     * INTERNAL strategy deserialization: {"type":"Dog","name":"Buddy"}
     * Read type field, then dispatch to correct variant.
     */
    private func makeFromJsonValueInternal(enumIdent: Token, constructors: ArrayList<Constructor>): Tokens {
        let enumName = enumIdent.value
        let prefix = "JSON deserialization error at '"
        let tagField = this.typeInfoTag
        
        // Build match arms for each constructor
        var matchArms = Tokens()
        for (ctor in constructors) {
            let name = ctor.identifier.value
            let ctorIdent = ctor.identifier
            let paramCount = ctor.typeArguments.size
            
            if (paramCount == 0) {
                // Unit variant
                matchArms = matchArms + quote(
                    case $name => $ctorIdent
                )
            } else {
                // Parameterized variant: extract fields v0, v1, ...
                var ctorArgs = Tokens()
                for (i in 0..paramCount) {
                    if (i > 0) {
                        ctorArgs = ctorArgs + Token(TokenKind.COMMA, ",")
                    }
                    let paramType = ctor.typeArguments[i].toTokens()
                    let fieldName = Token(TokenKind.STRING_LITERAL, "v${i}")
                    ctorArgs = ctorArgs + quote($paramType.fromJsonValue(_map[$fieldName]))
                }
                matchArms = matchArms + quote(
                    case $name => $ctorIdent($ctorArgs)
                )
            }
        }
        
        return quote(
            public static func fromJsonValue(value: JsonValue): $enumIdent {
                return $enumIdent.fromJsonValue(value, "$")
            }

            public static func fromJsonValue(value: JsonValue, _path: String): $enumIdent {
                let _obj = value.asObject()
                let _map = _obj.getFields()
                let _typeVal = _map.get($tagField)
                match (_typeVal) {
                    case Some(_t) =>
                        let _typeStr = (_t as JsonString).getOrThrow().getValue()
                        match (_typeStr) {
                            $matchArms
                            case _ => throw Exception($prefix + _path + "': unknown " + $enumName + " variant: " + _typeStr)
                        }
                    case None =>
                        throw Exception($prefix + _path + "': missing type field '" + $tagField + "'")
                }
            }
        )
    }

    /*
     * EXTERNAL strategy deserialization: {"Dog":{"name":"Buddy"}}
     * Key is type, value is data.
     */
    private func makeFromJsonValueExternal(enumIdent: Token, constructors: ArrayList<Constructor>): Tokens {
        let enumName = enumIdent.value
        let prefix = "JSON deserialization error at '"
        
        // Build match arms for unit variants (used in JsonString branch)
        var stringMatchArms = Tokens()
        // Build match arms for parameterized variants (used in JsonObject branch)
        var objectMatchArms = Tokens()
        
        for (ctor in constructors) {
            let name = ctor.identifier.value
            let ctorIdent = ctor.identifier
            let paramCount = ctor.typeArguments.size
            
            if (paramCount == 0) {
                // Unit variant: just "VariantName"
                stringMatchArms = stringMatchArms + quote(
                    case $name => $ctorIdent
                )
            } else if (paramCount == 1) {
                // Single-param: {"CtorName": value}
                let paramType = ctor.typeArguments[0].toTokens()
                objectMatchArms = objectMatchArms + quote(
                    case $name => $ctorIdent($paramType.fromJsonValue(_val))
                )
            } else {
                // Multi-param: {"CtorName": [v0, v1, ...]}
                var ctorArgs = Tokens()
                for (i in 0..paramCount) {
                    if (i > 0) {
                        ctorArgs = ctorArgs + Token(TokenKind.COMMA, ",")
                    }
                    let paramType = ctor.typeArguments[i].toTokens()
                    let idx = Token(TokenKind.INTEGER_LITERAL, "${i}")
                    ctorArgs = ctorArgs + quote($paramType.fromJsonValue(_items[$idx]))
                }
                objectMatchArms = objectMatchArms + quote(
                    case $name =>
                        let _items = (_val as JsonArray).getOrThrow().getItems()
                        $ctorIdent($ctorArgs)
                )
            }
        }
        
        return quote(
            public static func fromJsonValue(value: JsonValue): $enumIdent {
                return $enumIdent.fromJsonValue(value, "$")
            }

            public static func fromJsonValue(value: JsonValue, _path: String): $enumIdent {
                match (value) {
                    case _s: JsonString =>
                        let _str = _s.getValue()
                        match (_str) {
                            $stringMatchArms
                            case _ => throw Exception($prefix + _path + "': unknown " + $enumName + " variant: " + _str)
                        }
                    case _o: JsonObject =>
                        let _fields = _o.getFields()
                        if (_fields.size != 1) {
                            throw Exception($prefix + _path + "': expected single-key JSON object for " + $enumName)
                        }
                        var _key = ""
                        var _val: JsonValue = JsonString("")  // Placeholder, will be set in loop
                        for ((_k, _v) in _fields) {
                            _key = _k
                            _val = _v
                        }
                        match (_key) {
                            $objectMatchArms
                            case _ => throw Exception($prefix + _path + "': unknown " + $enumName + " constructor: " + _key)
                        }
                    case _ => throw Exception($prefix + _path + "': expected JsonString or JsonObject for " + $enumName)
                }
            }
        )
    }

    /*
     * ADJACENT strategy deserialization: {"type":"Dog","data":{"name":"Buddy"}}
     * Separate type and data fields.
     */
    private func makeFromJsonValueAdjacent(enumIdent: Token, constructors: ArrayList<Constructor>): Tokens {
        let enumName = enumIdent.value
        let prefix = "JSON deserialization error at '"
        let tagField = this.typeInfoTag
        let dataField = this.contentField
        
        var matchArms = Tokens()
        for (ctor in constructors) {
            let name = ctor.identifier.value
            let ctorIdent = ctor.identifier
            let paramCount = ctor.typeArguments.size
            
            if (paramCount == 0) {
                // Unit variant
                matchArms = matchArms + quote(
                    case $name => $ctorIdent
                )
            } else {
                // Parameterized variant: extract from data field
                var ctorArgs = Tokens()
                for (i in 0..paramCount) {
                    if (i > 0) {
                        ctorArgs = ctorArgs + Token(TokenKind.COMMA, ",")
                    }
                    let paramType = ctor.typeArguments[i].toTokens()
                    let fieldName = Token(TokenKind.STRING_LITERAL, "v${i}")
                    ctorArgs = ctorArgs + quote($paramType.fromJsonValue(_dataMap[$fieldName]))
                }
                matchArms = matchArms + quote(
                    case $name => $ctorIdent($ctorArgs)
                )
            }
        }
        
        return quote(
            public static func fromJsonValue(value: JsonValue): $enumIdent {
                return $enumIdent.fromJsonValue(value, "$")
            }

            public static func fromJsonValue(value: JsonValue, _path: String): $enumIdent {
                let _obj = value.asObject()
                let _map = _obj.getFields()
                let _typeVal = _map.get($tagField)
                
                match (_typeVal) {
                    case Some(_t) =>
                        let _typeStr = (_t as JsonString).getOrThrow().getValue()
                        
                        // For parameterized variants, extract data
                        let _dataVal = _map.get($dataField)
                        match (_dataVal) {
                            case Some(_d) =>
                                match (_d) {
                                    case _obj: JsonObject =>
                                        let _dataMap = _obj.getFields()
                                        match (_typeStr) {
                                            $matchArms
                                            case _ => throw Exception($prefix + _path + "': unknown " + $enumName + " variant: " + _typeStr)
                                        }
                                    case _ =>
                                        throw Exception($prefix + _path + "': data field is not a JsonObject")
                                }
                            case None =>
                                throw Exception($prefix + _path + "': missing data field '" + $dataField + "'")
                        }
                    case None =>
                        throw Exception($prefix + _path + "': missing type field '" + $tagField + "'")
                }
            }
        )
    }

    /*
     * UNTAGGED strategy deserialization: {"name":"Buddy"}
     * No type field, must infer from structure (limited support).
     * For now, only works with single-constructor enums.
     */
    private func makeFromJsonValueUntagged(enumIdent: Token, constructors: ArrayList<Constructor>): Tokens {
        let enumName = enumIdent.value
        let prefix = "JSON deserialization error at '"
        
        // Try each constructor in order (first match wins)
        // This is a simplification - real implementation would need more sophisticated disambiguation
        if (constructors.size == 1) {
            let ctor = constructors[0]
            let ctorIdent = ctor.identifier
            let paramCount = ctor.typeArguments.size
            
            if (paramCount == 0) {
                // Unit variant
                return quote(
                    public static func fromJsonValue(value: JsonValue): $enumIdent {
                        return $ctorIdent
                    }

                    public static func fromJsonValue(value: JsonValue, _path: String): $enumIdent {
                        return $ctorIdent
                    }
                )
            } else if (paramCount == 1) {
                // Single-param
                let paramType = ctor.typeArguments[0].toTokens()
                return quote(
                    public static func fromJsonValue(value: JsonValue): $enumIdent {
                        return $enumIdent.fromJsonValue(value, "$")
                    }

                    public static func fromJsonValue(value: JsonValue, _path: String): $enumIdent {
                        return $ctorIdent($paramType.fromJsonValue(value))
                    }
                )
            } else {
                // Multi-param: expect array
                var ctorArgs = Tokens()
                for (i in 0..paramCount) {
                    if (i > 0) {
                        ctorArgs = ctorArgs + Token(TokenKind.COMMA, ",")
                    }
                    let paramType = ctor.typeArguments[i].toTokens()
                    let idx = Token(TokenKind.INTEGER_LITERAL, "${i}")
                    ctorArgs = ctorArgs + quote($paramType.fromJsonValue(_items[$idx]))
                }
                return quote(
                    public static func fromJsonValue(value: JsonValue): $enumIdent {
                        return $enumIdent.fromJsonValue(value, "$")
                    }

                    public static func fromJsonValue(value: JsonValue, _path: String): $enumIdent {
                        let _items = value.asArray().getItems()
                        return $ctorIdent($ctorArgs)
                    }
                )
            }
        } else {
            // Multiple constructors - cannot safely deserialize without type info
            throw MacroExpansionException(
                "@JsonTypeInfo[UNTAGGED] does not support enums with multiple constructors. " +
                "Enum '" + enumName + "' has " + constructors.size.toString() + " constructors. " +
                "Use EXTERNAL, ADJACENT, or INTERNAL strategy instead.")
        }
    }

    /*
     * Generate fromJson():
     *   public static func fromJson(json: String): Shape {
     *       Shape.fromJsonValue(JsonValue.fromStr(json))
     *   }
     */
    private func makeFromJsonFunc(enumIdent: Token): Tokens {
        return quote(
            public static func fromJson(json: String): $enumIdent {
                $enumIdent.fromJsonValue(JsonValue.fromStr(json), "$")
            }
        )
    }

    /*
     * Generate stream serializer extend.
     *
     * For pure unit-variant enums, writes as a string:
     *   w.writeValue<String>(this.toJson())
     *
     * For mixed enums, writes via JsonValue bridge (since the output
     * may be a string or an object depending on the variant):
     *   w.jsonValue(this.toJsonValue().toString())
     */
    private func makeStreamToJsonExtend(enumIdent: Token, hasParameterized: Bool): Tokens {
        if (!hasParameterized) {
            return quote(
                extend $enumIdent <: JsonSerializable {
                    public func toJson(w: JsonWriter): Unit {
                        w.writeValue<String>(this.toJson())
                    }
                }
            )
        } else {
            return quote(
                extend $enumIdent <: JsonSerializable {
                    public func toJson(w: JsonWriter): Unit {
                        w.jsonValue(this.toJsonValue().toString())
                    }
                }
            )
        }
    }

    /*
     * Generate stream deserializer extend:
     *   extend Shape <: JsonDeserializable<Shape> {
     *       public static func fromJson(r: JsonReader): Shape {
     *           Shape.fromJsonValue(JsonValue.fromStr(String.fromUtf8(r.readValueBytes())))
     *       }
     *   }
     */
    private func makeStreamFromJsonExtend(enumIdent: Token): Tokens {
        return quote(
            extend $enumIdent <: JsonDeserializable<$enumIdent> {
                public static func fromJson(r: JsonReader): $enumIdent {
                    $enumIdent.fromJsonValue(JsonValue.fromStr(String.fromUtf8(r.readValueBytes())), "$")
                }
            }
        )
    }
}
