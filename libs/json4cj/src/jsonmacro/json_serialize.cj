macro package json4cj.jsonmacro

import std.ast.*

/*
 * Macro for inserting json serialization/deserialization functions onto target class
 * @param input_Tk the target class token
 * @return token the expanded token representation
 */
public macro JsonSerialize(input_Tk: Tokens): Tokens {
    let declTriple = TokenVerifier.verifyClassOrEnumDecl(input_Tk, Const.JSON_SERIALIZE_MACRO_NAME)

    // Fast path: enum declaration — delegate to EnumProcessor
    if (let (_, _, Some(ve)) <- declTriple) {
        // Read @JsonTypeInfo configuration for enums
        // Default to EXTERNAL (backward compatible with original behavior)
        var enumTaggingStrategy = "EXTERNAL"
        var enumTypeInfoTag = "type"
        var enumContentField = "data"
        
        let typeInfoMessages = getChildMessages(Const.JSON_TYPE_INFO_MACRO_NAME)
        for (msg in typeInfoMessages) {
            let strategyStr = msg.getString(Const.KEY_TAGGING_STRATEGY)
            if (strategyStr != "") {
                enumTaggingStrategy = strategyStr
            }
            let tag = msg.getString(Const.KEY_TYPE_INFO_TAG)
            if (tag != "") {
                enumTypeInfoTag = tag
            }
            let content = msg.getString(Const.KEY_CONTENT_FIELD)
            if (content != "") {
                enumContentField = content
            }
        }
        
        try {
            return EnumProcessor(ve, enumTaggingStrategy, enumTypeInfoTag, enumContentField).compose()
        } catch (exp: MacroExpansionException) {
            throw exp
        }
    }

    // Class/struct path: collect annotations and delegate to ClassAndStructInfo
    var config = ClassConfig()

    // Collect @JsonCreator child messages
    let creatorMessages = getChildMessages(Const.JSON_CREATOR_MACRO_NAME)
    for (msg in creatorMessages) {
        let value = msg.getString(Const.KEY_USE_CREATOR)
        if (value == "true") {
            config.useCreator = true
        }
    }

    // Collect @JsonInclude child messages
    let includeMessages = getChildMessages(Const.JSON_INCLUDE_MACRO_NAME)
    for (msg in includeMessages) {
        let mode = msg.getString(Const.KEY_INCLUDE_MODE)
        if (mode != "") {
            config.includeMode = Some(mode)
        }
    }

    // Collect @JsonIgnoreUnknown child messages
    let ignoreUnknownMessages = getChildMessages(Const.JSON_IGNORE_UNKNOWN_MACRO_NAME)
    for (msg in ignoreUnknownMessages) {
        let value = msg.getString(Const.KEY_IGNORE_UNKNOWN)
        if (value == "true") {
            config.ignoreUnknown = Some(true)
        } else if (value == "false") {
            config.ignoreUnknown = Some(false)
        }
    }

    // Collect @JsonIgnore child messages
    let ignoredMessages = getChildMessages(Const.JSON_IGNORE_MACRO_NAME)
    for (msg in ignoredMessages) {
        let ignoredProp = msg.getString(Const.KEY_IGNORED_PROP)
        if (ignoredProp != "") {
            config.ignoredVarSet.add(ignoredProp)
        }
    }

    // Collect @JsonProperty child messages
    let propMessages = getChildMessages(Const.JSON_PROPERTY_MACRO_NAME)
    for (msg in propMessages) {
        let originalName = msg.getString(Const.KEY_PROP_ORIGINAL_NAME)
        let mappedName = msg.getString(Const.KEY_PROP_MAPPED_NAME)
        if (originalName != "" && mappedName != "") {
            config.userDefinedVarMap.add(originalName, mappedName)
        }
    }

    var classAndStructInfo = ClassAndStructInfo()

    match (declTriple) {
        case (Some(vc), None, None) =>
            classAndStructInfo.classModifier = vc.modifiers
            classAndStructInfo.classKeyWord = vc.keyword
            classAndStructInfo.classIdent = vc.identifier
            classAndStructInfo.classBody = vc.body.decls
            classAndStructInfo.superTypes = vc.superTypes
            classAndStructInfo.varDeclList = checkVars(vc, config)
            // Extract generic metadata
            if (vc.isGenericDecl) {
                classAndStructInfo.isGeneric = true
                classAndStructInfo.typeParams = vc.genericParam.parameters
                classAndStructInfo.genericConstraint = vc.genericConstraint
            }
        case (None, Some(vs), None) =>
            classAndStructInfo.classModifier = vs.modifiers
            classAndStructInfo.classKeyWord = vs.keyword
            classAndStructInfo.classIdent = vs.identifier
            classAndStructInfo.classBody = vs.body.decls
            classAndStructInfo.superTypes = vs.superTypes
            classAndStructInfo.varDeclList = checkVars(vs, config)
            // Extract generic metadata
            if (vs.isGenericDecl) {
                classAndStructInfo.isGeneric = true
                classAndStructInfo.typeParams = vs.genericParam.parameters
                classAndStructInfo.genericConstraint = vs.genericConstraint
            }

        case _ => ()
    }

    // Collect @JsonFormat child messages
    let formatMessages = getChildMessages(Const.JSON_FORMAT_MACRO_NAME)
    for (msg in formatMessages) {
        let propName = msg.getString(Const.KEY_FORMAT_PROP)
        let pattern = msg.getString(Const.KEY_FORMAT_PATTERN)
        if (propName != "" && pattern != "") {
            config.formatMap.add(propName, pattern)
        }
    }

    // Collect @JsonDeserialize child messages
    var messages = getChildMessages(Const.JSON_DESERIALIZE_MACRO_NAME)
    for (msg in messages) {
        let propName = msg.getString(Const.KEY_PROP)
        let serializer = msg.getString(Const.KEY_SERIALIZER)
        if (propName != "" && serializer != "") {
            config.propAdapterFactory.register(propName, serializer)
        }
    }

    // Collect @JsonTypeInfo child messages
    let typeInfoMessages = getChildMessages(Const.JSON_TYPE_INFO_MACRO_NAME)
    for (msg in typeInfoMessages) {
        let tag = msg.getString(Const.KEY_TYPE_INFO_TAG)
        if (tag != "") {
            config.typeInfoTag = tag
        }
        
        // NEW: Read tagging strategy
        let strategyStr = msg.getString(Const.KEY_TAGGING_STRATEGY)
        if (strategyStr != "") {
            // strategyStr is already a string: "INTERNAL", "EXTERNAL", etc.
            config.taggingStrategy = strategyStr
        }
        
        // NEW: Read content field for ADJACENT strategy
        let contentField = msg.getString(Const.KEY_CONTENT_FIELD)
        if (contentField != "") {
            config.contentField = contentField
        }
    }

    // Collect @JsonSubTypes child messages
    let subTypeMessages = getChildMessages(Const.JSON_SUB_TYPES_MACRO_NAME)
    for (msg in subTypeMessages) {
        let mapping = msg.getString(Const.KEY_SUB_TYPE_MAPPING)
        if (mapping != "") {
            config.parseSubTypeMapping(mapping)
        }
    }

    // Collect @JsonType child messages (for subclasses)
    let typeMessages = getChildMessages(Const.JSON_TYPE_MACRO_NAME)
    for (msg in typeMessages) {
        let value = msg.getString(Const.KEY_TYPE_VALUE)
        if (value != "") {
            config.typeValue = value
        }
    }

    // NOTE: Bare type parameter fields (e.g., 'var value: T') are now supported!
    // The where clause (where T <: JsonValueSerializable<T>) ensures T has fromJsonValue/toJsonValue.
    // This is similar to Rust serde and Go generics - compile-time type resolution.
    // Unlike Java, Cangjie doesn't have type erasure.

    try {
        return classAndStructInfo.composeWithJsonFunc(config)
    } catch (exp: AdapterMissingException | TypeInferenceException) {
        throw MacroExpansionException(
            "Exception when expanding @JsonSerialize at class/struct ${classAndStructInfo.classIdent.value}: " + exp
                .message)
    }
}

func checkVars(classDecl_Tk: Node, config: ClassConfig): ArrayList<VarDecl> {
    let varVisitor = ClassVarDeclVisitor(config)
    classDecl_Tk.traverse(varVisitor)
    config.defaultValueMap = varVisitor.getDefaultVarValueMap()
    return varVisitor.getVarTokenList()
}
