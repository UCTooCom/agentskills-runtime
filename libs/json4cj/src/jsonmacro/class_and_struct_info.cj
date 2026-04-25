macro package json4cj.jsonmacro

import std.ast.*
import std.unicode.*

/*
 * Composes the full macro output for a @JsonSerialize-annotated class/struct.
 *
 * Generated code layout:
 *
 *   class Clazz <: JsonCodec<Clazz> {     // HashMap-based interface (renamed from JsonSerializable)
 *       // original field declarations
 *       static func fromJsonValue(...)... // HashMap deserialization
 *       func toJsonValue()...             // HashMap serialization
 *   }
 *   extend Clazz <: JsonSerializable {     // stdx stream serialization
 *       public func toJson(w: JsonWriter): Unit { ... }
 *   }
 *   extend Clazz <: JsonDeserializable<Clazz> {  // stdx stream deserialization
 *       public static func fromJson(r: JsonReader): Clazz { ... }
 *   }
 *
 * Key design decisions:
 * - JsonCodec<T> (not JsonSerializable<T>) to avoid naming collision with
 *   stdx.encoding.json.stream.JsonSerializable. See TROUBLESHOOTING.md 5.1.
 * - extend blocks are OUTSIDE the class body because a class cannot extend
 *   both JsonCodec<T> and JsonSerializable simultaneously (different supertype chains).
 * - Stream serializers use writeValue<T>() for native types, but fall back to
 *   JsonValue bridge for HashSet/HashMap/user types due to cjc 1.0.1 constraint
 *   propagation failure. See TROUBLESHOOTING.md 5.2.
 * - Short type names (JsonSerializable, JsonWriter, etc.) are used in generated
 *   code because macro quote() does not support fully-qualified type names.
 *   Users must import stdx.encoding.json.stream.* in their files.
 *   See TROUBLESHOOTING.md 5.3.
 */
struct ClassAndStructInfo {
    public var varDeclList: ArrayList<VarDecl> = ArrayList<VarDecl>()
    public var classModifier: ArrayList<Modifier> = ArrayList<Modifier>()
    public var classKeyWord: Token = Token()
    public var classIdent: Token = Token()
    public var classBody: ArrayList<Decl> = ArrayList<Decl>()
    public var superTypes: ArrayList<TypeNode> = ArrayList<TypeNode>()

    // Generic class metadata (populated when class has type parameters)
    public var typeParams: Tokens = Tokens()                          // e.g., `T` or `T1, T2, T3`
    public var genericConstraint: ArrayList<GenericConstraint> = ArrayList<GenericConstraint>()  // existing where clauses
    public var isGeneric: Bool = false

    /*
     * Build where clause for generic classes: where T <: JsonValueSerializable<T>
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
     * Build comma-separated type parameter list for use in angle brackets
     * e.g., "K, V" for use as Class<K, V>
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

    public func composeWithJsonFunc(classConfig: ClassConfig): Tokens {
        // Phase 1: Build FieldConfig list once from varDeclList + classConfig
        let fieldConfigs = FieldConfigBuilder(classConfig).build(varDeclList)

        // Detect polymorphic mode
        // Base class: has @JsonTypeInfo + @JsonSubTypes
        let isPolymorphicBase = classConfig.typeInfoTag != "" && classConfig.subTypeMapping.size > 0
        // Subclass: has @JsonType (explicit opt-in for polymorphic subclass)
        let isPolymorphicSub = classConfig.typeValue != ""

        if (isPolymorphicBase) {
            return PolymorphicProcessor.composeBaseClass(
                classIdent, classModifier, classKeyWord, classBody, superTypes,
                fieldConfigs, classConfig, isGeneric, typeParams
            )
        } else if (isPolymorphicSub) {
            // Default typeValue from class name if not set
            if (classConfig.typeValue == "") {
                classConfig.typeValue = toLowerFirst(classIdent.value)
            }
            return PolymorphicProcessor.composeSubClass(
                classIdent, classModifier, classKeyWord, classBody, superTypes,
                fieldConfigs, classConfig
            )
        }

        // Phase 2a: HashMap-based generators (inside class body) — standard non-polymorphic path
        let fromJsonFunc = ClassJsonDeserializer(classConfig).makeFromJsonFunc(classIdent, fieldConfigs, isGeneric, typeParams)
        let toJsonFunc = ClassJsonSerializer(classConfig).makeToJsonFunc(fieldConfigs, isGeneric, typeParams)

        // Phase 2b: Stream-based generators (extend blocks outside class)
        // NOTE: Generic class stream extend blocks fail with cjc 1.0.1 due to constraint propagation.
        // extend<T> ClassName<T> <: JsonSerializable where T <: JsonValueSerializable<T>
        // fails because cjc cannot propagate T <: JsonValueSerializable<T> to resolve
        // T <: JsonSerializable (needed for writeValue<T>) or Option<T> <: JsonDeserializable.
        // For now, only generate stream serializers for non-generic classes.
        var streamToJsonExtend = Tokens()
        var streamFromJsonExtend = Tokens()
        if (!isGeneric) {
            let streamSerializer = ClassStreamSerializer(classConfig)
            let streamDeserializer = ClassStreamDeserializer(classConfig)
            streamToJsonExtend = streamSerializer.makeStreamToJsonExtend(classIdent, fieldConfigs, isGeneric, typeParams)
            streamFromJsonExtend = streamDeserializer.makeStreamFromJsonExtend(classIdent, fieldConfigs, isGeneric, typeParams, genericConstraint)
        }

        // Class supertype: JsonCodec<T> (renamed from JsonSerializable<T>)
        // For generic classes: class GenericWithOption<T> <: JsonCodec<GenericWithOption<T>> where T <: JsonValueSerializable<T>
        // For non-generic: class User <: JsonCodec<User>
        var classTypeExpr = Tokens()
        var fullClassType = Tokens()
        if (isGeneric) {
            // Build properly comma-separated type parameter list
            let typeParamList = buildTypeParamList(typeParams)
            classTypeExpr = quote($classIdent<$typeParamList>)
            fullClassType = classTypeExpr
        } else {
            classTypeExpr = quote($classIdent)
            fullClassType = classTypeExpr
        }

        var superTypeExpr = Tokens()
        if (superTypes.size != 0) {
            superTypeExpr = quote(<: $superTypes & JsonCodec<$fullClassType>)
        } else {
            superTypeExpr = quote(<: JsonCodec<$fullClassType>)
        }

        // For generic classes, add where clause AFTER the superTypeExpr
        var whereClause = Tokens()
        if (isGeneric) {
            whereClause = buildWhereClause(typeParams)
        }

        return quote(
            $classModifier $classKeyWord $classTypeExpr $superTypeExpr $whereClause {
                $classBody
                $fromJsonFunc
                $toJsonFunc
            }
            $streamToJsonExtend
            $streamFromJsonExtend
        )
    }

    /*
     * Lowercase the first character of a string.
     * "Dog" -> "dog", "URLResponse" -> "uRLResponse"
     */
    private func toLowerFirst(s: String): String {
        if (s.size == 0) {
            return s
        }
        return s[0..1].toLower() + s[1..]
    }
}
