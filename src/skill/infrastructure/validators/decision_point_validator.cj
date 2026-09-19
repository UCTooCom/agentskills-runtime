/*
 * DecisionPointValidator（spec 5.15 / tasks.md §13.1 第 3 项）
 * 技能加载时校验 SKILL.md frontmatter 中的 decision-points 段。
 *
 * 校验规则（spec 5.15.1）：
 *   1. options.length >= 2（规则 4：至少两个选项才有"选择"意义）
 *   2. default 必须是合法 option id（规则 3 的合法性前提）
 *   3. recommended 必须是合法 option id（规则 2 的可选推荐项）
 *   4. 非法则技能加载告警且该决策点不生效（5.15.3 异常场景 3，不阻断加载）
 *
 * 修复要点（v15 复核问题 C/D/E）：
 *   - C：返回结构化 DecisionPointParseResult，用 invalidPointIds 表达"该决策点不生效"，
 *        而非仅靠自由文本 warning；下游可据此真正跳过失效决策点。
 *   - D：取消短路，累积同一决策点的全部问题，降低技能作者迭代成本。
 *   - E：复用 ValidationResult.success() 工厂，不再手写全字段构造。
 *
 * 编码依据：
 *   - YAML 解析：yaml4cj.yaml.decode + JsonObject 模式（同 dag_config.cj / yaml_utils.cj）
 *   - frontmatter 提取：YamlUtils.extractYamlFrontmatter
 *   - ValidationResult：domain/models/validation_result.cj
 */
package magic.skill.infrastructure.validators

import magic.skill.domain.models.{ValidationResult, DecisionPoint, DecisionOption, DecisionPointParseResult}
import magic.skill.infrastructure.utils.YamlUtils
import std.collection.{ArrayList, HashMap}
import std.convert.Parsable
import stdx.encoding.json.*
import yaml4cj.yaml.decode

public class DecisionPointValidator {

    /// 校验 SKILL.md 全文中的 decision-points 段，只产出 ValidationResult（兼容既有调用）。
    /// 非法决策点记为 warning（不阻断加载，只告警）。
    /// 无告警时复用 ValidationResult.success()，有告警时复用 .withWarnings()（问题 E 修复）。
    public func validate(content: String): ValidationResult {
        let parsed = this.parseAndValidate(content)
        if (parsed.warnings.isEmpty()) {
            return ValidationResult.success()
        }
        return ValidationResult.withWarnings(parsed.warnings)
    }

    /// 解析 + 校验，返回结构化结果。
    /// **这是供加载链消费的入口**：validPoints 可正常参与人在回路，
    /// invalidPointIds 对应的决策点必须被下游跳过（即"不生效"）。
    public func parseAndValidate(content: String): DecisionPointParseResult {
        let frontmatterOpt = YamlUtils.extractYamlFrontmatter(content)
        if (frontmatterOpt.isNone()) {
            return DecisionPointParseResult.empty()
        }

        let rawPoints = this.parseRawDecisionPoints(frontmatterOpt.getOrThrow())
        if (rawPoints.isNone()) {
            // frontmatter 存在但无 decision-points 段：绝大多数技能属于此类
            return DecisionPointParseResult.empty()
        }

        let validPoints = ArrayList<DecisionPoint>()
        let invalidPointIds = ArrayList<String>()
        let warnings = ArrayList<String>()

        for (raw in rawPoints.getOrThrow()) {
            this.validateSingleDecisionPoint(raw, validPoints, invalidPointIds, warnings)
        }

        return DecisionPointParseResult(
            validPoints: validPoints.toArray(),
            invalidPointIds: invalidPointIds.toArray(),
            warnings: warnings.toArray(),
            declared: true
        )
    }

    /// 解析 frontmatter 中的 decision-points 数组为原始字段表
    private func parseRawDecisionPoints(frontmatter: String): Option<ArrayList<HashMap<String, JsonValue>>> {
        try {
            let parsed = decode(frontmatter.toArray())
            if (!(parsed is JsonObject)) {
                return None
            }
            let jsonObj = (parsed as JsonObject).getOrThrow()
            match (jsonObj.get("decision-points")) {
                case Some(dpVal) =>
                    match (dpVal.kind()) {
                        case JsonKind.JsArray =>
                            let result = ArrayList<HashMap<String, JsonValue>>()
                            for (item in dpVal.asArray().getItems()) {
                                match (item.kind()) {
                                    case JsonKind.JsObject =>
                                        result.add(item.asObject().getFields())
                                    case _ => ()
                                }
                            }
                            return Some(result)
                        case _ => return None
                    }
                case None => return None
            }
        } catch (e: Exception) {
            return None
        }
    }

    /// 校验单个决策点：合法则收进 validPoints，非法则收进 invalidPointIds。
    /// **不短路**——同一决策点的所有问题一次性报全（问题 D 修复）。
    private func validateSingleDecisionPoint(
        dp: HashMap<String, JsonValue>,
        validPoints: ArrayList<DecisionPoint>,
        invalidPointIds: ArrayList<String>,
        warnings: ArrayList<String>
    ): Unit {
        let dpId = this.strField(dp, "id")
        if (dpId.isEmpty()) {
            // 无 id 无法定位，也谈不上"生效"，但记不进 invalidPointIds（无标识可用）
            warnings.add("decision-point 缺少 id 字段，已跳过（该决策点不生效）")
            return
        }

        let issues = ArrayList<String>()

        // 规则 4：选项至少 2 项
        let options = this.parseOptions(dp)
        if (options.size < 2) {
            issues.add("options 少于 2 个（实际 ${options.size}）")
        }

        let optionIds = ArrayList<String>()
        for (opt in options) {
            optionIds.add(opt.id)
        }

        // 规则 3：必须有 default（spec 5.15.3 异常场景 1 依赖它兜底）
        let defaultVal = this.strField(dp, "default")
        if (defaultVal.isEmpty()) {
            issues.add("缺少 default（规则 3 要求必须有默认项，禁止无限等待）")
        } else if (!optionIds.contains(defaultVal)) {
            issues.add("default='${defaultVal}' 不是合法 option id（合法值: ${this.joinIds(optionIds)}）")
        }

        // 规则 2：recommended 可选，但若声明则必须合法
        let recommendedVal = this.strField(dp, "recommended")
        if (!recommendedVal.isEmpty() && !optionIds.contains(recommendedVal)) {
            issues.add("recommended='${recommendedVal}' 不是合法 option id（合法值: ${this.joinIds(optionIds)}）")
        }

        if (!issues.isEmpty()) {
            invalidPointIds.add(dpId)
            for (issue in issues) {
                warnings.add("decision-point '${dpId}' 校验失败：${issue}，该决策点不生效")
            }
            return
        }

        // 全部规则通过：构造领域对象供下游消费
        validPoints.add(
            DecisionPoint(
                id: dpId,
                when: this.strField(dp, "when"),
                question: this.strField(dp, "question"),
                options: options.toArray(),
                defaultOption: defaultVal,
                recommended: recommendedVal,
                timeoutSeconds: this.intField(dp, "timeout_seconds")
            )
        )
    }

    /// 从决策点中解析出选项列表
    private func parseOptions(dp: HashMap<String, JsonValue>): ArrayList<DecisionOption> {
        let options = ArrayList<DecisionOption>()
        match (dp.get("options")) {
            case Some(optVal) =>
                match (optVal.kind()) {
                    case JsonKind.JsArray =>
                        for (opt in optVal.asArray().getItems()) {
                            match (opt.kind()) {
                                case JsonKind.JsObject =>
                                    let optMap = opt.asObject().getFields()
                                    let id = this.strField(optMap, "id")
                                    if (!id.isEmpty()) {
                                        options.add(
                                            DecisionOption(
                                                id: id,
                                                label: this.strField(optMap, "label"),
                                                description: this.strField(optMap, "description"),
                                                tradeoff: this.strField(optMap, "tradeoff")
                                            )
                                        )
                                    }
                                case _ => ()
                            }
                        }
                    case _ => ()
                }
            case None => ()
        }
        return options
    }

    private func strField(m: HashMap<String, JsonValue>, key: String): String {
        match (m.get(key)) {
            case Some(v) =>
                match (v.kind()) {
                    case JsonKind.JsString => v.asString().getValue()
                    case _ => ""
                }
            case None => ""
        }
    }

    /// 读整数型字段：YAML 数字与带引号的数字串都接受；缺失或非法返回 0。
    private func intField(m: HashMap<String, JsonValue>, key: String): Int64 {
        match (m.get(key)) {
            case Some(v) =>
                match (v.kind()) {
                    case JsonKind.JsInt => v.asInt().getValue()
                    case JsonKind.JsFloat => Int64(v.asFloat().getValue())
                    case JsonKind.JsString =>
                        match (Int64.tryParse(v.asString().getValue())) {
                            case Some(n) => n
                            case None => 0
                        }
                    case _ => 0
                }
            case None => 0
        }
    }

    private func joinIds(ids: ArrayList<String>): String {
        let sb = StringBuilder()
        var first = true
        for (id in ids) {
            if (!first) { sb.append(", ") }
            sb.append(id)
            first = false
        }
        return sb.toString()
    }
}
