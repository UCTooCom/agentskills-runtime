macro package json4cj.jsonmacro

import std.ast.{VarDecl, Token, TypeNode}
import std.collection.ArrayList

/*
 * Builds FieldConfig list from VarDecl list + ClassConfig.
 *
 * Performs the annotation inspection and type analysis once,
 * so that all 4 generators can consume pre-computed FieldConfig
 * without repeating the decision logic.
 */
class FieldConfigBuilder {
    private var classConfig: ClassConfig

    public init(classConfig: ClassConfig) {
        this.classConfig = classConfig
    }

    /*
     * Build FieldConfig list, filtering out @JsonIgnore fields.
     */
    public func build(varDeclList: ArrayList<VarDecl>): ArrayList<FieldConfig> {
        let result = ArrayList<FieldConfig>()
        for (varDecl in varDeclList) {
            let fc = buildOne(varDecl)
            if (let Some(config) <- fc) {
                result.add(config)
            }
        }
        return result
    }

    /*
     * Build a single FieldConfig. Returns None if field is @JsonIgnore'd.
     */
    private func buildOne(varDecl: VarDecl): Option<FieldConfig> {
        let varInfo = getVarInfo(varDecl)
        let identString = varInfo.identifier.toTokens().toString()

        // Filter out @JsonIgnore fields
        if (classConfig.ignoredVarSet.contains(identString)) {
            return None
        }

        let jsonName = getMappedName(varInfo.name)
        let category = resolveCategory(varInfo, identString)
        let includeMode = resolveIncludeMode(varInfo, identString)
        let formatPattern = resolveFormatPattern(identString)
        let adapterName = resolveAdapterName(identString)

        return Some(FieldConfig(
            varInfo.identifier,
            jsonName,
            varInfo.typeName,
            varInfo.typeArguments,
            category,
            includeMode,
            formatPattern,
            adapterName
        ))
    }

    /*
     * Determine the FieldCategory for a field.
     *
     * Priority order matches existing serializer/deserializer decision trees:
     *   1. CUSTOM_ADAPTER   - @JsonDeserialize[AdapterType]
     *   2. FORMAT_DATETIME  - DateTime + @JsonFormat
     *   3. OPTION           - Option<T>
     *   4. GENERIC_CONTAINER - ArrayList<T>, HashMap<K,V>, etc.
     *   5. PRIMITIVE        - everything else (including user-defined types!)
     *
     * NOTE: User-defined types (e.g., CustomTime) without @JsonDeserialize or
     * @JsonFormat fall into PRIMITIVE. The stream serializers detect this via
     * isPrimitiveTypeName() and use the JsonValue bridge for non-primitive types
     * in PRIMITIVE category. See class_stream_serializer.cj emitPrimitive().
     */
    private func resolveCategory(varInfo: VarInfo, identString: String): FieldCategory {
        if (classConfig.propAdapterFactory.hasAdapter(identString)) {
            return FieldCategory.CUSTOM_ADAPTER
        } else if (classConfig.formatMap.contains(identString)) {
            return FieldCategory.FORMAT_DATETIME
        } else if (varInfo.typeName.contains("Option")) {
            return FieldCategory.OPTION
        } else if (varInfo.typeArguments.size > 0) {
            return FieldCategory.GENERIC_CONTAINER
        } else {
            return FieldCategory.PRIMITIVE
        }
    }

    /*
     * Determine the IncludeMode for serialization output.
     *
     * Returns Option<IncludeMode>:
     * - Some(mode) when @JsonInclude annotation is present
     * - None when no annotation (generators will use library default)
     */
    private func resolveIncludeMode(varInfo: VarInfo, identString: String): Option<IncludeMode> {
        if (let Some("NON_EMPTY") <- classConfig.includeMode) {
            return Some(IncludeMode.NON_EMPTY)
        } else if (let Some("NON_NULL") <- classConfig.includeMode) {
            return Some(IncludeMode.NON_NULL)
        } else {
            // No annotation → None, generators will use library default (ALWAYS)
            return None
        }
    }

    private func resolveFormatPattern(identString: String): Option<String> {
        if (classConfig.formatMap.contains(identString)) {
            return Some(classConfig.formatMap.get(identString).getOrThrow())
        }
        return None
    }

    private func resolveAdapterName(identString: String): Option<String> {
        if (classConfig.propAdapterFactory.hasAdapter(identString)) {
            return Some(classConfig.propAdapterFactory.getAdapter(identString))
        }
        return None
    }

    // Reuse the same helper from ClassProcessor
    private func getVarInfo(vark_Tk: VarDecl): VarInfo {
        return vark_Tk.getVarInfo()
    }

    private func getMappedName(varName: String): String {
        var mappedNameValue = varName
        if (classConfig.userDefinedVarMap.contains(varName)) {
            mappedNameValue = classConfig.userDefinedVarMap.get(varName).getOrThrow()
        }
        return mappedNameValue
    }
}
