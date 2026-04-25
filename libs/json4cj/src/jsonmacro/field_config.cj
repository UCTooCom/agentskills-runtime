macro package json4cj.jsonmacro

import std.ast.{Token, TypeNode}
import std.collection.ArrayList

/*
 * Behavior category for a field, pre-computed from annotations and type info.
 * Each category maps to fixed code templates in all 4 generators.
 */
enum FieldCategory {
    | PRIMITIVE          // String, Int64, Bool, DateTime, etc. (no generic params)
    | OPTION             // Option<T>
    | GENERIC_CONTAINER  // ArrayList<T>, HashMap<K,V>, HashSet<T>, etc.
    | FORMAT_DATETIME    // DateTime with @JsonFormat
    | CUSTOM_ADAPTER     // field with @JsonDeserialize[AdapterType]
}

/*
 * Include mode controlling when a field is serialized.
 * Affects serialization output only (deserialization always reads all fields).
 */
enum IncludeMode {
    | ALWAYS
    | NON_NULL
    | NON_EMPTY
}

/*
 * Pre-computed configuration for a single field.
 *
 * Created by FieldConfigBuilder from VarDecl + ClassConfig.
 * Each generator consumes FieldConfig list to emit code fragments
 * without repeating annotation inspection logic.
 *
 * Note: includeMode is Option<IncludeMode> so generators can distinguish
 * None means no annotation was specified — use library defaults.
 */
class FieldConfig {
    public let identifier: Token
    public let jsonName: String
    public let typeName: String
    public let typeArguments: ArrayList<TypeNode>
    public let category: FieldCategory
    public let includeMode: Option<IncludeMode>  // None = no annotation, use library default (ALWAYS)
    public let formatPattern: Option<String>
    public let adapterName: Option<String>

    public init(identifier: Token,
                jsonName: String,
                typeName: String,
                typeArguments: ArrayList<TypeNode>,
                category: FieldCategory,
                includeMode: Option<IncludeMode>,
                formatPattern: Option<String>,
                adapterName: Option<String>) {
        this.identifier = identifier
        this.jsonName = jsonName
        this.typeName = typeName
        this.typeArguments = typeArguments
        this.category = category
        this.includeMode = includeMode
        this.formatPattern = formatPattern
        this.adapterName = adapterName
    }
}
