package ystyle::cordis_core

import stdx.serialization.serialization.*
import std.collection.ArrayList

/**
 * 配置字段规格（docs/cordis-comparison.md §4 Config schema 校验）
 *
 * 描述插件私有配置的单个字段：白名单、类型、必填。类型取值：
 * - "string" / "bool" / "int"（整数，DataModelInt/DataModelFloat 整数值）
 * - "float" / "array" / "object"
 */
public class ConfigFieldSpec {
    public let name: String
    public let typeName: String
    public let required: Bool

    public init(name: String, typeName: String, required!: Bool = false) {
        this.name = name
        this.typeName = typeName
        this.required = required
    }
}

/**
 * 配置 Schema（docs/cordis-comparison.md §4 Config schema 校验）
 *
 * 声明插件私有配置的字段白名单与类型约束，宿主在加载/调谐时校验
 * PluginEntry.config，错误带完整路径（如 `plugins[0].config.port`）。
 *
 * 用法（宿主侧）：
 * ```cangjie
 * let schema = ConfigSchema(ArrayList<ConfigFieldSpec>.of([
 *     ConfigFieldSpec("host", "string", required: true),
 *     ConfigFieldSpec("port", "int"),
 * ]))
 * let err = schema.validate(entry.config, "plugins[0].config")
 * // err: None（通过）或 Some("plugins[0].config.port: expected int, got string")
 * ```
 */
public class ConfigSchema {
    public let fields: ArrayList<ConfigFieldSpec>

    public init(fields: ArrayList<ConfigFieldSpec>) {
        this.fields = fields
    }

    /**
     * 校验 DataModel 配置
     * @param config 插件私有配置（DataModel）
     * @param path 错误路径前缀（如 "plugins[0].config"）
     * @return None 校验通过；Some(message) 首个错误（含完整路径）
     */
    public func validate(config: DataModel, path: String): ?String {
        // 无配置（null）且无必填字段 → 通过
        if (config is DataModelNull) {
            for (f in this.fields) {
                if (f.required) {
                    return Some("${path}.${f.name}: missing required field")
                }
            }
            return None
        }
        let dms = match (config) {
            case s: DataModelStruct => s
            case _ => return Some("${path}: expected object")
        }
        // 1. 必填检查 + 类型校验
        for (f in this.fields) {
            let value = dms.get(f.name)
            if (value is DataModelNull) {
                if (f.required) {
                    return Some("${path}.${f.name}: missing required field")
                }
            } else {
                match (this.checkType(f.typeName, value)) {
                    case Some(err) => return Some("${path}.${f.name}: ${err}")
                    case None => ()
                }
            }
        }
        // 2. 白名单检查：未知字段警告（不阻断，返回 None；如需严格可在宿主侧另行判断）
        None
    }

    /**
     * 严格校验：与 validate 相同，但未知字段也报错
     */
    public func validateStrict(config: DataModel, path: String): ?String {
        match (this.validate(config, path)) {
            case Some(err) => return Some(err)
            case None => ()
        }
        let dms = match (config) {
            case s: DataModelStruct => s
            case _ => return None   // null/非 object 已由 validate 处理
        }
        for (field in dms.getFields()) {
            var known = false
            for (f in this.fields) {
                if (f.name == field.getName()) {
                    known = true
                    break
                }
            }
            if (!known) {
                return Some("${path}.${field.getName()}: unknown field")
            }
        }
        None
    }

    /**
     * 类型检查：返回 None（匹配）或 Some(错误描述)
     */
    private func checkType(typeName: String, v: DataModel): ?String {
        match (typeName) {
            case "string" =>
                if (v is DataModelString) { None } else { Some("expected string, got ${describeType(v)}") }
            case "bool" =>
                if (v is DataModelBool) { None } else { Some("expected bool, got ${describeType(v)}") }
            case "int" =>
                if (v is DataModelInt) { None }
                else if (v is DataModelFloat) {
                    match (v as DataModelFloat) {
                        case Some(f) =>
                            let fv = f.getValue()
                            if (fv == Float64(Int64(fv))) { None } else { Some("expected int, got float ${fv}") }
                        case None => Some("expected int")
                    }
                } else { Some("expected int, got ${describeType(v)}") }
            case "float" =>
                if (v is DataModelFloat || v is DataModelInt) { None } else { Some("expected float, got ${describeType(v)}") }
            case "array" =>
                if (v is DataModelSeq) { None } else { Some("expected array, got ${describeType(v)}") }
            case "object" =>
                if (v is DataModelStruct) { None } else { Some("expected object, got ${describeType(v)}") }
            case _ => None   // 未知类型约束：不校验
        }
    }

    private static func describeType(v: DataModel): String {
        match (v) {
            case _: DataModelNull => "null"
            case _: DataModelBool => "bool"
            case _: DataModelInt => "int"
            case _: DataModelFloat => "float"
            case _: DataModelString => "string"
            case _: DataModelSeq => "array"
            case _: DataModelStruct => "object"
            case _ => "unknown"
        }
    }
}
