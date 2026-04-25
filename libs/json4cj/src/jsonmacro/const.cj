macro package json4cj.jsonmacro

class Const {
    static let JSON_SERIALIZE_MACRO_NAME = "JsonSerialize"
    static let JSON_IGNORE_MACRO_NAME = "JsonIgnore"
    static let JSON_PROPERTY_MACRO_NAME = "JsonProperty"
    static let JSON_DESERIALIZE_MACRO_NAME = "JsonDeserialize"
    static let JSON_IGNORE_UNKNOWN_MACRO_NAME = "JsonIgnoreUnknown"
    static let JSON_INCLUDE_MACRO_NAME = "JsonInclude"
    static let JSON_FORMAT_MACRO_NAME = "JsonFormat"
    static let JSON_CREATOR_MACRO_NAME = "JsonCreator"
    static let JSON_TYPE_INFO_MACRO_NAME = "JsonTypeInfo"
    static let JSON_SUB_TYPES_MACRO_NAME = "JsonSubTypes"
    static let JSON_TYPE_MACRO_NAME = "JsonType"
    static let KEY_PROP = "prop"
    static let KEY_SERIALIZER = "serializer"
    static let KEY_IGNORED_PROP = "ignoredProp"
    static let KEY_PROP_ORIGINAL_NAME = "propOriginalName"
    static let KEY_PROP_MAPPED_NAME = "propMappedName"
    static let KEY_IGNORE_UNKNOWN = "ignoreUnknown"
    static let KEY_INCLUDE_MODE = "includeMode"
    static let KEY_FORMAT_PROP = "formatProp"
    static let KEY_FORMAT_PATTERN = "formatPattern"
    static let KEY_USE_CREATOR = "useCreator"
    static let KEY_TYPE_INFO_TAG = "typeInfoTag"
    static let KEY_TAGGING_STRATEGY = "taggingStrategy"  // NEW: INTERNAL, EXTERNAL, ADJACENT, UNTAGGED
    static let KEY_CONTENT_FIELD = "contentField"  // NEW: For ADJACENT strategy
    static let KEY_SUB_TYPE_MAPPING = "subTypeMapping"
    static let KEY_TYPE_VALUE = "typeValue"
}
