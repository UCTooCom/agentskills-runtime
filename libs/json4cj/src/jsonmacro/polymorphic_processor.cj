macro package json4cj.jsonmacro

import std.ast.*
import std.unicode.*
import std.collection.{ArrayList, HashMap}

/*
 * Generates JSON serialization/deserialization code for polymorphic classes.
 *
 * Polymorphic mode is activated when:
 * - Base class: @JsonTypeInfo[tag="type"] + @JsonSubTypes["dog"=>Dog,...] are present
 * - Subclass: @JsonType["dog"] is present (explicit opt-in)
 *
 * Base class generated code:
 *   open class Animal <: JsonCodec<Animal> {
 *       var name: String = ""
 *
 *       // Helper for subclasses to parse base fields from JsonObject
 *       public func initFromJsonValue(jsonObject: JsonObject, _path: String): Unit { ... }
 *
 *       public open func toJsonValue(): JsonValue { ... }  // open for subclass override
 *       public static func fromJsonValue(json: JsonValue, _path: String): Animal {
 *           // Read discriminator, dispatch to subclass
 *       }
 *   }
 *
 * Subclass generated code:
 *   class Dog <: Animal {
 *       var breed: String = ""
 *
 *       public func toJsonValue(): JsonValue {
 *           // super.toJsonValue() merge + type field + own fields
 *       }
 *       public static func fromJsonValue(json: JsonValue, _path: String): Dog {
 *           // ret.initFromJsonValue() + own fields
 *       }
 *   }
 */
class PolymorphicProcessor {

    /*
     * Generate the full macro output for a polymorphic BASE class.
     */
    public static func composeBaseClass(
        classIdent: Token,
        classModifier: ArrayList<Modifier>,
        classKeyWord: Token,
        classBody: ArrayList<Decl>,
        superTypes: ArrayList<TypeNode>,
        fieldConfigs: ArrayList<FieldConfig>,
        classConfig: ClassConfig,
        isGeneric: Bool,
        typeParams: Tokens
    ): Tokens {
        let tag = classConfig.typeInfoTag
        let subTypeMapping = classConfig.subTypeMapping
        let strategy = classConfig.taggingStrategy  // NEW: "INTERNAL", "EXTERNAL", "ADJACENT", "UNTAGGED"

        // Build supertype expression
        var classTypeExpr = Tokens()
        if (isGeneric) {
            let typeParamList = buildTypeParamList(typeParams)
            classTypeExpr = quote($classIdent<$typeParamList>)
        } else {
            classTypeExpr = quote($classIdent)
        }

        var superTypeExpr = Tokens()
        if (superTypes.size != 0) {
            superTypeExpr = quote(<: $superTypes & JsonCodec<$classTypeExpr>)
        } else {
            superTypeExpr = quote(<: JsonCodec<$classTypeExpr>)
        }

        // Generate functions based on strategy
        let initFromJsonValueFunc = makeInitFromJsonValueFunc(classIdent, fieldConfigs, classConfig)
        let toJsonValueFunc = makeBaseToJsonValueFunc(classIdent, fieldConfigs, classConfig, strategy)
        let fromJsonValueFunc = makeBaseFromJsonValueFunc(classIdent, fieldConfigs, classConfig, tag, subTypeMapping, strategy)
        let fromJsonFunc = makeBaseFromJsonFunc(classIdent)
        let toJsonFunc = makeBaseToJsonFunc()

        // Stream extends (JsonValue bridge)
        let streamToJsonExtend = makeBaseStreamToJsonExtend(classIdent)
        let streamFromJsonExtend = makeBaseStreamFromJsonExtend(classIdent)

        return quote(
            $classModifier $classKeyWord $classTypeExpr $superTypeExpr {
                $classBody
                $initFromJsonValueFunc
                $toJsonValueFunc
                $fromJsonValueFunc
                $fromJsonFunc
                $toJsonFunc
            }
            $streamToJsonExtend
            $streamFromJsonExtend
        )
    }

    /*
     * Generate the full macro output for a polymorphic SUBCLASS.
     */
    public static func composeSubClass(
        classIdent: Token,
        classModifier: ArrayList<Modifier>,
        classKeyWord: Token,
        classBody: ArrayList<Decl>,
        superTypes: ArrayList<TypeNode>,
        fieldConfigs: ArrayList<FieldConfig>,
        classConfig: ClassConfig
    ): Tokens {
        let typeValue = classConfig.typeValue
        // Subclass doesn't have @JsonTypeInfo, so typeInfoTag may be empty.
        // Default to "type" (the standard serde convention for internal tagging).
        // TODO: Support explicit tag propagation via @JsonType["dog", tag="type"]
        let tag = if (classConfig.typeInfoTag != "") { classConfig.typeInfoTag } else { "type" }
        let strategy = classConfig.taggingStrategy  // NEW: Inherit from base class config

        // Subclass keeps its existing supertypes (e.g., <: Animal)
        // Does NOT add JsonCodec — it inherits from base class
        var superTypeExpr = Tokens()
        if (superTypes.size != 0) {
            superTypeExpr = quote(<: $superTypes)
        }

        // Generate functions based on strategy
        let toJsonValueFunc = makeSubToJsonValueFunc(classIdent, fieldConfigs, classConfig, typeValue, tag, strategy)
        let fromJsonValueFunc = makeSubFromJsonValueFunc(classIdent, fieldConfigs, classConfig)
        // Subclass does NOT generate fromJson()/toJson() — inherits from base class
        // Generating them would cause "cannot override function" error

        // Stream extends (JsonValue bridge)
        let streamToJsonExtend = makeSubStreamToJsonExtend(classIdent)
        let streamFromJsonExtend = makeSubStreamFromJsonExtend(classIdent)

        return quote(
            $classModifier $classKeyWord $classIdent $superTypeExpr {
                $classBody
                $toJsonValueFunc
                $fromJsonValueFunc
            }
            $streamToJsonExtend
            $streamFromJsonExtend
        )
    }

    // ===== Base class code generation =====

    /*
     * Generate initFromJsonValue() — helper for subclasses to parse base fields.
     *
     *   public func initFromJsonValue(jsonObject: JsonObject, _path: String): Unit {
     *       if (jsonObject.getFields().contains("name")) {
     *           this.name = String.fromJsonValue(jsonObject.get("name").getOrThrow(), _path + ".name")
     *       }
     *   }
     */
    private static func makeInitFromJsonValueFunc(
        classIdent: Token,
        fieldConfigs: ArrayList<FieldConfig>,
        classConfig: ClassConfig
    ): Tokens {
        var fieldParseCode = Tokens()
        for (fc in fieldConfigs) {
            let code = makeFieldParseCode(fc, "this")
            fieldParseCode = fieldParseCode + code
        }

        return quote(
            public func initFromJsonValue(jsonObject: JsonObject, _path: String): Unit {
                $fieldParseCode
            }
        )
    }

    /*
     * Generate open toJsonValue() for base class.
     * 
     * Strategy-aware:
     * - INTERNAL: {"type":"animal","name":"..."} (default)
     * - EXTERNAL: {"Animal":{"name":"..."}} (wrapper by class name)
     * - ADJACENT: {"type":"animal","data":{"name":"..."}}
     * - UNTAGGED: {"name":"..."} (no type field)
     */
    private static func makeBaseToJsonValueFunc(
        classIdent: Token,
        fieldConfigs: ArrayList<FieldConfig>,
        classConfig: ClassConfig,
        strategy: String  // NEW: "INTERNAL", "EXTERNAL", "ADJACENT", "UNTAGGED"
    ): Tokens {
        let tag = classConfig.typeInfoTag
        let tagToken = Token(TokenKind.STRING_LITERAL, tag)
        let contentField = classConfig.contentField
        let contentFieldToken = Token(TokenKind.STRING_LITERAL, contentField)

        var fieldSerCode = Tokens()
        for (fc in fieldConfigs) {
            let code = makeFieldSerCode(fc, classConfig)
            fieldSerCode = fieldSerCode + code
        }

        // Use class name as default type value for base class instances
        let className = classIdent.value
        let defaultTypeValue = toLowerFirst(className)
        let defaultTypeValueToken = Token(TokenKind.STRING_LITERAL, defaultTypeValue)
        let classNameToken = Token(TokenKind.STRING_LITERAL, className)

        // Generate based on strategy
        match (strategy) {
            case "EXTERNAL" =>
                // External: {"Animal":{"name":"..."}}
                return quote(
                    public open func toJsonValue(): JsonValue {
                        var innerMap = HashMap<String, JsonValue>()
                        $fieldSerCode
                        var outerMap = HashMap<String, JsonValue>()
                        outerMap.add($classNameToken, JsonObject(innerMap))
                        JsonObject(outerMap)
                    }
                )
            
            case "ADJACENT" =>
                // Adjacent: {"type":"animal","data":{"name":"..."}}
                return quote(
                    public open func toJsonValue(): JsonValue {
                        var dataMap = HashMap<String, JsonValue>()
                        $fieldSerCode
                        var outerMap = HashMap<String, JsonValue>()
                        outerMap.add($tagToken, JsonString($defaultTypeValueToken))
                        outerMap.add($contentFieldToken, JsonObject(dataMap))
                        JsonObject(outerMap)
                    }
                )
            
            case "UNTAGGED" =>
                // Untagged: {"name":"..."} (no type field)
                return quote(
                    public open func toJsonValue(): JsonValue {
                        var map = HashMap<String, JsonValue>()
                        $fieldSerCode
                        JsonObject(map)
                    }
                )
            
            case _ =>  // INTERNAL (default)
                // Internal: {"type":"animal","name":"..."}
                return quote(
                    public open func toJsonValue(): JsonValue {
                        var map = HashMap<String, JsonValue>()
                        map.add($tagToken, JsonString($defaultTypeValueToken))
                        $fieldSerCode
                        JsonObject(map)
                    }
                )
        }
    }

    /*
     * Generate fromJsonValue() for base class with discriminator dispatch.
     * Strategy-aware dispatch logic.
     */
    private static func makeBaseFromJsonValueFunc(
        classIdent: Token,
        fieldConfigs: ArrayList<FieldConfig>,
        classConfig: ClassConfig,
        tag: String,
        subTypeMapping: HashMap<String, String>,
        strategy: String  // NEW: "INTERNAL", "EXTERNAL", "ADJACENT", "UNTAGGED"
    ): Tokens {
        let tagToken = Token(TokenKind.STRING_LITERAL, tag)
        let className = classIdent.value
        let unknownTypeMsg = Token(TokenKind.STRING_LITERAL, "unknown " + className + " type: ")
        let missingDiscMsg = Token(TokenKind.STRING_LITERAL, "missing type discriminator: " + tag)
        let contentFieldToken = Token(TokenKind.STRING_LITERAL, classConfig.contentField)

        // Build dispatch branches
        var dispatchCode = Tokens()
        var first = true
        for ((discValue, subClassName) in subTypeMapping) {
            let discToken = Token(TokenKind.STRING_LITERAL, discValue)
            let subClassToken = Token(TokenKind.IDENTIFIER, subClassName)
            if (first) {
                dispatchCode = dispatchCode + quote(
                    if (typeStr == $discToken) { return $subClassToken.fromJsonValue(json, _path) }
                )
                first = false
            } else {
                dispatchCode = dispatchCode + quote(
                    else if (typeStr == $discToken) { return $subClassToken.fromJsonValue(json, _path) }
                )
            }
        }
        // Final else: unknown type
        dispatchCode = dispatchCode + quote(
            else { throw Exception($unknownTypeMsg + typeStr) }
        )

        // Generate strategy-specific fromJsonValue
        match (strategy) {
            case "EXTERNAL" =>
                // External: {"Dog":{"name":"Buddy"}}
                // Iterate over outer keys to find type
                var externalDispatchCode = Tokens()
                var extFirst = true
                for ((_, subClassName) in subTypeMapping) {
                    let subClassToken = Token(TokenKind.IDENTIFIER, subClassName)
                    if (extFirst) {
                        externalDispatchCode = externalDispatchCode + quote(
                            if (fields.contains($subClassName)) {
                                let innerJson = jsonObject.get($subClassName).getOrThrow()
                                return $subClassToken.fromJsonValue(innerJson, _path)
                            }
                        )
                        extFirst = false
                    } else {
                        externalDispatchCode = externalDispatchCode + quote(
                            else if (fields.contains($subClassName)) {
                                let innerJson = jsonObject.get($subClassName).getOrThrow()
                                return $subClassToken.fromJsonValue(innerJson, _path)
                            }
                        )
                    }
                }
                externalDispatchCode = externalDispatchCode + quote(
                    else { throw Exception($unknownTypeMsg + "(cannot determine from outer key)") }
                )
                
                return quote(
                    public static func fromJsonValue(json: JsonValue): $classIdent {
                        return $classIdent.fromJsonValue(json, "$")
                    }

                    public static func fromJsonValue(json: JsonValue, _path: String): $classIdent {
                        let jsonObject = json.asObject()
                        let fields = jsonObject.getFields()
                        $externalDispatchCode
                    }
                )
            
            case "ADJACENT" =>
                // Adjacent: {"type":"dog","data":{"name":"Buddy"}}
                return quote(
                    public static func fromJsonValue(json: JsonValue): $classIdent {
                        return $classIdent.fromJsonValue(json, "$")
                    }

                    public static func fromJsonValue(json: JsonValue, _path: String): $classIdent {
                        let jsonObject = json.asObject()
                        var typeStr = ""
                        match (jsonObject.get($tagToken)) {
                            case Some(typeValue) => typeStr = (typeValue as JsonString).getOrThrow().getValue()
                            case None => throw Exception($missingDiscMsg)
                        }
                        
                        // Get data field
                        let dataJson = match (jsonObject.get($contentFieldToken)) {
                            case Some(dataValue) => dataValue
                            case None => throw Exception("missing content field: " + $contentFieldToken.getValue())
                        }
                        
                        $dispatchCode
                    }
                )
            
            case "UNTAGGED" =>
                // Untagged: No type field, try each subtype
                // NOTE: This is a simple heuristic - try each subtype in order
                var untaggedDispatchCode = Tokens()
                var untFirst = true
                for ((_, subClassName) in subTypeMapping) {
                    let subClassToken = Token(TokenKind.IDENTIFIER, subClassName)
                    if (untFirst) {
                        untaggedDispatchCode = untaggedDispatchCode + quote(
                            // Try $subClassName
                            try {
                                return $subClassToken.fromJsonValue(json, _path)
                            } catch (_: Exception) {
                                // Try next
                            }
                        )
                        untFirst = false
                    } else {
                        untaggedDispatchCode = untaggedDispatchCode + quote(
                            // Try $subClassName
                            try {
                                return $subClassToken.fromJsonValue(json, _path)
                            } catch (_: Exception) {
                                // Try next
                            }
                        )
                    }
                }
                untaggedDispatchCode = untaggedDispatchCode + quote(
                    throw Exception($unknownTypeMsg + "(cannot determine from fields)")
                )
                
                return quote(
                    public static func fromJsonValue(json: JsonValue): $classIdent {
                        return $classIdent.fromJsonValue(json, "$")
                    }

                    public static func fromJsonValue(json: JsonValue, _path: String): $classIdent {
                        $untaggedDispatchCode
                    }
                )
            
            case _ =>  // INTERNAL (default)
                // Internal: {"type":"dog","name":"Buddy"}
                return quote(
                    public static func fromJsonValue(json: JsonValue): $classIdent {
                        return $classIdent.fromJsonValue(json, "$")
                    }

                    public static func fromJsonValue(json: JsonValue, _path: String): $classIdent {
                        let jsonObject = json.asObject()
                        var typeStr = ""
                        match (jsonObject.get($tagToken)) {
                            case Some(typeValue) => typeStr = (typeValue as JsonString).getOrThrow().getValue()
                            case None => throw Exception($missingDiscMsg)
                        }
                        $dispatchCode
                    }
                )
        }
    }

    private static func makeBaseFromJsonFunc(classIdent: Token): Tokens {
        return quote(
            public static func fromJson(json: String): $classIdent {
                $classIdent.fromJsonValue(JsonValue.fromStr(json), "$")
            }
        )
    }

    private static func makeBaseToJsonFunc(): Tokens {
        return quote(
            public func toJson(): String {
                this.toJsonValue().toString()
            }
        )
    }

    // ===== Subclass code generation =====

    /*
     * Generate toJsonValue() for subclass.
     * Strategy-aware serialization.
     */
    private static func makeSubToJsonValueFunc(
        classIdent: Token,
        fieldConfigs: ArrayList<FieldConfig>,
        classConfig: ClassConfig,
        typeValue: String,
        tag: String,
        strategy: String  // NEW: "INTERNAL", "EXTERNAL", "ADJACENT", "UNTAGGED"
    ): Tokens {
        let tagToken = Token(TokenKind.STRING_LITERAL, tag)
        let typeValueToken = Token(TokenKind.STRING_LITERAL, typeValue)
        let contentFieldToken = Token(TokenKind.STRING_LITERAL, classConfig.contentField)
        let classNameToken = Token(TokenKind.STRING_LITERAL, classIdent.value)

        var fieldSerCode = Tokens()
        for (fc in fieldConfigs) {
            let code = makeFieldSerCode(fc, classConfig)
            fieldSerCode = fieldSerCode + code
        }

        // Generate based on strategy
        match (strategy) {
            case "EXTERNAL" =>
                // External: {"Dog":{"name":"Buddy","breed":"Lab"}}
                return quote(
                    public func toJsonValue(): JsonValue {
                        var innerMap = HashMap<String, JsonValue>()
                        $fieldSerCode
                        var outerMap = HashMap<String, JsonValue>()
                        outerMap.add($classNameToken, JsonObject(innerMap))
                        JsonObject(outerMap)
                    }
                )
            
            case "ADJACENT" =>
                // Adjacent: {"type":"dog","data":{"name":"Buddy","breed":"Lab"}}
                return quote(
                    public func toJsonValue(): JsonValue {
                        var dataMap = HashMap<String, JsonValue>()
                        $fieldSerCode
                        var outerMap = HashMap<String, JsonValue>()
                        outerMap.add($tagToken, JsonString($typeValueToken))
                        outerMap.add($contentFieldToken, JsonObject(dataMap))
                        JsonObject(outerMap)
                    }
                )
            
            case "UNTAGGED" =>
                // Untagged: {"name":"Buddy","breed":"Lab"} (no type field)
                return quote(
                    public func toJsonValue(): JsonValue {
                        var map = HashMap<String, JsonValue>()
                        $fieldSerCode
                        JsonObject(map)
                    }
                )
            
            case _ =>  // INTERNAL (default)
                // Internal: {"type":"dog","name":"Buddy","breed":"Lab"}
                return quote(
                    public func toJsonValue(): JsonValue {
                        let _parentMap = (super.toJsonValue() as JsonObject).getOrThrow().getFields()
                        var map = HashMap<String, JsonValue>()
                        for ((_k, _v) in _parentMap) {
                            map.add(_k, _v)
                        }
                        map.add($tagToken, JsonString($typeValueToken))
                        $fieldSerCode
                        JsonObject(map)
                    }
                )
        }
    }

    /*
     * Generate fromJsonValue() for subclass.
     *
     *   public static func fromJsonValue(json: JsonValue, _path: String): Dog {
     *       let jsonObject = json.asObject()
     *       var ret = Dog()
     *       ret.initFromJsonValue(jsonObject, _path)
     *       // Parse own fields
     *       if (jsonObject.getFields().contains("breed")) {
     *           ret.breed = String.fromJsonValue(jsonObject.get("breed").getOrThrow(), _path + ".breed")
     *       }
     *       return ret
     *   }
     */
    private static func makeSubFromJsonValueFunc(
        classIdent: Token,
        fieldConfigs: ArrayList<FieldConfig>,
        classConfig: ClassConfig
    ): Tokens {
        var fieldParseCode = Tokens()
        for (fc in fieldConfigs) {
            let code = makeFieldParseCode(fc, "ret")
            fieldParseCode = fieldParseCode + code
        }

        return quote(
            public static func fromJsonValue(json: JsonValue): $classIdent {
                return $classIdent.fromJsonValue(json, "$")
            }

            public static func fromJsonValue(json: JsonValue, _path: String): $classIdent {
                let jsonObject = json.asObject()
                var ret = $classIdent()
                ret.initFromJsonValue(jsonObject, _path)
                $fieldParseCode
                return ret
            }
        )
    }

    private static func makeSubFromJsonFunc(classIdent: Token): Tokens {
        return quote(
            public static func fromJson(json: String): $classIdent {
                $classIdent.fromJsonValue(JsonValue.fromStr(json), "$")
            }
        )
    }

    private static func makeSubToJsonFunc(): Tokens {
        return quote(
            public func toJson(): String {
                this.toJsonValue().toString()
            }
        )
    }

    // ===== Shared field code generators =====

    /*
     * Generate serialization code for a single field.
     * Uses match on FieldCategory (Cangjie enums don't support ==).
     *
     * target: "this" for initFromJsonValue/base toJsonValue, "ret" for subclass fromJsonValue
     */
    private static func makeFieldSerCode(fc: FieldConfig, classConfig: ClassConfig): Tokens {
        let jsonName = Token(TokenKind.STRING_LITERAL, fc.jsonName)
        let fieldName = fc.identifier

        match (fc.category) {
            case OPTION => makeOptionSerCode(fc, jsonName, fieldName, classConfig)
            case CUSTOM_ADAPTER => makeAdapterSerCode(fc, jsonName, fieldName)
            case FORMAT_DATETIME => makeFormatSerCode(fc, jsonName, fieldName)
            case _ => quote(map.add($jsonName, this.$fieldName.toJsonValue()))
        }
    }

    private static func makeOptionSerCode(fc: FieldConfig, jsonName: Token, fieldName: Token, classConfig: ClassConfig): Tokens {
        if (let Some("NON_NULL") <- classConfig.includeMode || let Some("NON_EMPTY") <- classConfig.includeMode) {
            return quote(
                if (this.$fieldName.isSome()) {
                    map.add($jsonName, this.$fieldName.getOrThrow().toJsonValue())
                }
            )
        } else {
            return quote(
                map.add($jsonName, this.$fieldName.toJsonValue())
            )
        }
    }

    private static func makeAdapterSerCode(fc: FieldConfig, jsonName: Token, fieldName: Token): Tokens {
        let adapterName = fc.adapterName.getOrThrow()
        let adapterToken = Token(TokenKind.IDENTIFIER, adapterName)
        return quote(
            map.add($jsonName, $adapterToken.toJsonValue(this.$fieldName))
        )
    }

    private static func makeFormatSerCode(fc: FieldConfig, jsonName: Token, fieldName: Token): Tokens {
        let pattern = fc.formatPattern.getOrThrow()
        let patternToken = Token(TokenKind.STRING_LITERAL, pattern)
        return quote(
            map.add($jsonName, JsonString(this.$fieldName.format($patternToken)))
        )
    }

    /*
     * Generate deserialization code for a single field.
     * target: "this" for initFromJsonValue, "ret" for subclass fromJsonValue
     */
    private static func makeFieldParseCode(fc: FieldConfig, target: String): Tokens {
        let fieldName = fc.identifier
        let jsonName = Token(TokenKind.STRING_LITERAL, fc.jsonName)
        let typeName = Token(TokenKind.IDENTIFIER, fc.typeName)
        let fieldPath = Token(TokenKind.STRING_LITERAL, "." + fc.jsonName)
        let targetToken = Token(TokenKind.IDENTIFIER, target)

        match (fc.category) {
            case OPTION => quote(
                if (jsonObject.getFields().contains($jsonName)) {
                    let _jv = jsonObject.get($jsonName).getOrThrow()
                    if (_jv.kind == JsonValueKind.JsNull) {
                        $targetToken.$fieldName = None
                    } else {
                        $targetToken.$fieldName = Some($typeName.fromJsonValue(_jv, _path + $fieldPath))
                    }
                }
            )
            case _ => quote(
                if (jsonObject.getFields().contains($jsonName)) {
                    $targetToken.$fieldName = $typeName.fromJsonValue(jsonObject.get($jsonName).getOrThrow(), _path + $fieldPath)
                }
            )
        }
    }

    // ===== Stream extends =====
    // Only base class gets Stream extends. Subclasses inherit from base class
    // which already implements JsonSerializable and JsonDeserializable<Animal>.
    // Adding extend Sub <: JsonSerializable would cause "interface already implemented" error.

    private static func makeBaseStreamToJsonExtend(classIdent: Token): Tokens {
        return quote(
            extend $classIdent <: JsonSerializable {
                public func toJson(w: JsonWriter): Unit {
                    w.jsonValue(this.toJsonValue().toString())
                }
            }
        )
    }

    private static func makeBaseStreamFromJsonExtend(classIdent: Token): Tokens {
        return quote(
            extend $classIdent <: JsonDeserializable<$classIdent> {
                public static func fromJson(r: JsonReader): $classIdent {
                    $classIdent.fromJsonValue(JsonValue.fromStr(String.fromUtf8(r.readValueBytes())), "$")
                }
            }
        )
    }

    // Subclass: no Stream extends (inherits from base class)
    private static func makeSubStreamToJsonExtend(classIdent: Token): Tokens {
        return Tokens()
    }

    private static func makeSubStreamFromJsonExtend(classIdent: Token): Tokens {
        return Tokens()
    }

    // ===== Helpers =====

    private static func buildTypeParamList(typeParams: Tokens): Tokens {
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
     * Lowercase the first character of a string.
     * "Dog" -> "dog", "URLResponse" -> "uRLResponse"
     */
    private static func toLowerFirst(s: String): String {
        if (s.size == 0) {
            return s
        }
        return s[0..1].toLower() + s[1..]
    }
}
