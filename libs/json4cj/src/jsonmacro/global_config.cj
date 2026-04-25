macro package json4cj.jsonmacro

import std.ast.*

/*
 * The class-level configuration collected from annotations.
 *
 * ignoreUnknown and includeMode use Option types so the macro system
 * can distinguish "annotation present" from "annotation absent".
 * None means no annotation was specified — use library defaults.
 * fallback in that case.
 */

/*
 * Tagging strategy for polymorphic type serialization.
 * Aligned with Rust Serde's enum representations.
 */
class ClassConfig <: DefaultValueExprStore {
    public var propAdapterFactory: JsonPropAdapterFactory = JsonPropAdapterFactory()

    public let userDefinedVarMap: HashMap<String, String> = HashMap()
    public let ignoredVarSet: HashSet<String> = HashSet()
    public var defaultValueMap: Map<String, Expr> = HashMap()
    public var ignoreUnknown: Option<Bool> = None
    public var includeMode: Option<String> = None
    public let formatMap: HashMap<String, String> = HashMap()
    public var useCreator: Bool = false

    // Polymorphic type metadata
    // Tagging strategy: "INTERNAL" | "EXTERNAL" | "ADJACENT" | "UNTAGGED"
    public var taggingStrategy: String = "INTERNAL"  // Default: internal tagging
    public var typeInfoTag: String = ""           // "" = not polymorphic, e.g., "type" = discriminator field
    public var contentField: String = "data"      // For ADJACENT strategy only
    public let subTypeMapping: HashMap<String, String> = HashMap()  // "dog" => "Dog", "cat" => "Cat"
    public var typeValue: String = ""             // for subclasses: "dog" etc. (from @JsonType or lowercased class name)

    public func hasValueExpr(varIdentifierName: String): Bool {
        return defaultValueMap.contains(varIdentifierName)
    }

    public func getValueExpr(varIdentifierName: String): Expr {
        return defaultValueMap.get(varIdentifierName).getOrThrow()
    }

    /*
     * Parse "dog=>Dog,cat=>Cat" mapping string and populate subTypeMapping.
     * Note: No whitespace is expected since parseSubTypesAttr generates the
     * mapping string without spaces.
     */
    public func parseSubTypeMapping(mappingStr: String): Unit {
        let entries = mappingStr.split(",")
        for (entry in entries) {
            let parts = entry.split("=>")
            if (parts.size >= 2) {
                subTypeMapping.add(parts[0], parts[1])
            }
        }
    }
}
