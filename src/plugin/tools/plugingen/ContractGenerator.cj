/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugin.tools.plugingen

import std.collection.HashMap

/**
 * ContractGenerator - DATA_CONTRACT.yaml 骨架生成器（tasks.md §14.1）
 *
 * 与 PluginGenerator 同源：复用其 `readTableInfo`（读 db_info），
 * 把表结构**确定性地**渲染成数据契约骨架，落地到 `skills/{name}/DATA_CONTRACT.yaml`。
 *
 * 为什么并入 plugingen 而不是另起一个 contractgen：
 *   1. 数据源同一份（db_info）+ 同一套 ORM 初始化（.env → Config.set → ORMConfig.refresh）；
 *      另起工具等于把这条 DB 连接链再抄一遍，是纯重复。
 *   2. 产物落在同一个目录（skills/{name}/）——契约必须与 SKILL.md / plugin.yaml 同居，
 *      由同一次生成动作产出才不会有"生成了插件却忘了契约"的缺口。
 *   3. 类型读取逻辑已被 PluginGenerator 实现（readTableInfo），复用它就不会出现
 *      "两处各自解释 db_info 字段含义"的漂移。
 *
 * 边界（刻意不做）：
 *   - 不生成 role / write_rule / sample_rows 的**内容**：这三项是业务语义，机器无从推断，
 *     只能给 TODO 占位并由人工补齐（tasks.md §14.1 原文即"再由人工裁剪与补充"）。
 *   - 不查业务数据填 sample_rows：受行级权限约束，且"真实示例"应体现语义而非巧合。
 *   - 不推断业务幂等键：db_info 不含主键/唯一约束信息，故默认填 ["id"] 并标 TODO。
 */
public class ContractGenerator {
    private let templateEngine = TemplateEngine()
    private let pluginGenerator = PluginGenerator()
    private let skillsRoot: String = "./skills"
    private let templatesDir: String

    public init(templatesDir!: String = "./src/plugin/tools/plugingen/templates") {
        this.templatesDir = templatesDir
    }

    /**
     * 生成 DATA_CONTRACT.yaml 骨架。
     *
     * @param name       插件/技能名（已规范化）
     * @param dbName     数据库名（db_info.table_catalog）
     * @param tableNames 纳入契约的表名列表
     * @return 是否至少为一张表产出了契约
     */
    public func generate(name: String, dbName: String, tableNames: Array<String>): Bool {
        if (tableNames.size == 0) {
            println("错误: 未指定任何表（用 --table 或 --tables）")
            return false
        }

        let sb = StringBuilder()
        var okCount = 0
        for (raw in tableNames) {
            let t = raw.trimAscii()
            if (t.isEmpty()) {
                continue
            }
            let info = this.pluginGenerator.readTableInfo(dbName, t)
            if (info.fields.isEmpty()) {
                println("警告: 表 ${dbName}.${t} 在 db_info 中无字段记录，已跳过")
                println("      请先执行 npm run loadDbInfo ${dbName} 刷新数据库信息")
                continue
            }
            sb.append(this.renderTable(info))
            okCount++
        }

        if (okCount == 0) {
            println("错误: 没有任何表可用于生成契约（db_info 未命中），未写出文件")
            return false
        }

        let tplPath = "${this.templatesDir}/DATA_CONTRACT.yaml.tpl"
        let tpl = this.templateEngine.loadTemplate(tplPath)
        if (tpl.isEmpty()) {
            println("错误: 契约模板加载失败: ${tplPath}")
            return false
        }

        let variables = HashMap<String, String>()
        variables.add("name", name)
        variables.add("dbName", dbName)
        variables.add("tablesDecl", sb.toString())
        let content = this.templateEngine.replaceVariables(tpl, variables)

        let outPath = "${this.skillsRoot}/${name}/DATA_CONTRACT.yaml"
        this.templateEngine.writeFile(outPath, content)
        println("已生成: ${outPath}（${okCount} 张表）")
        println("注意: 这是骨架 —— 请人工补齐每张表的 role / idempotent_key / write_rule / sample_rows")
        return true
    }

    /// 渲染单表的 YAML 片段（列信息来自 db_info，业务语义留 TODO）
    private func renderTable(info: TableInfo): String {
        let sb = StringBuilder()
        sb.append("  - name: ${info.tableName}\n")
        sb.append("    access: read_write   # TODO: read_write | read_only\n")
        sb.append("    role: TODO 本表在本技能中的角色\n")
        sb.append("    idempotent_key: [\"id\"]   # TODO: 换成真正的业务幂等键（默认仅主键占位）\n")
        sb.append("    columns:\n")
        for (f in info.fields) {
            let required = if (this.isNullable(f)) { "false" } else { "true" }
            let dataType = if (f.dataType.isEmpty()) { "text" } else { f.dataType }
            sb.append("      - {name: ${f.columnName}, type: ${dataType}, required: ${required}")
            sb.append(", example: null, comment: ${this.yamlQuote(f.columnComment)}}\n")
        }
        sb.append("    write_rule:\n")
        sb.append("      - TODO 写入纪律（先查后写 / 禁止状态倒退 / 软删过滤 ...）\n")
        sb.append("    sample_rows: []   # TODO 必须补齐：真实示例值（spec §5.16 明确要求，不是可选项）\n")
        return sb.toString()
    }

    /// db_info.is_nullable 判定（YES 表示可空 → required=false）
    private func isNullable(f: FieldInfo): Bool {
        f.isNullable.toAsciiLower() == "yes"
    }

    /// 双引号包裹 YAML 标量（flow mapping 里的值含 `,`/`:`/`{` 会破结构，必须引号化）。
    /// 先转义反斜杠再转义引号，顺序不可颠倒（否则会把刚加的转义符再转一次）。
    private func yamlQuote(raw: String): String {
        var s = raw.replace("\\", "\\\\")
        s = s.replace("\"", "\\\"")
        s = s.replace("\r", " ")
        s = s.replace("\n", " ")
        return "\"" + s + "\""
    }
}
