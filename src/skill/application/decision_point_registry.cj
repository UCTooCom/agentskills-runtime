/*
 * DecisionPointRegistry —— 决策点的运行时注册表（spec 5.15.3 异常场景 3 的落地点）
 *
 * 职责：把"技能加载时校验过的决策点"集中登记，供执行器 / 审批工具按 id 取用。
 * 关键语义：**失效决策点不登记** ⇒ 查询返回 None ⇒ 天然"该决策点不生效"。
 *
 * 为什么需要它（v15 复核问题 C）：
 *   校验器原先只产出自由文本 warning，下游无法据此跳过决策点，"不生效"只是句空话。
 *   这里把结构化结果落成可查询的注册表，让"不生效"成为可被代码消费的事实：
 *     - registerFromManifest(manifest) 只登记 manifest.decisionPoints（即已通过校验的）
 *     - find(skillName, pointId) 查不到 ⇒ 走普通审批路径，不推送选项卡片
 */
package magic.skill.application

import magic.skill.domain.models.{SkillManifest, DecisionPoint}
import std.collection.{ArrayList, HashMap}
import magic.log.LogUtils

public class DecisionPointRegistry {
    /// skillName → (decisionPointId → DecisionPoint)，仅含**有效**决策点
    private let _bySkill: HashMap<String, HashMap<String, DecisionPoint>>

    public init() {
        this._bySkill = HashMap<String, HashMap<String, DecisionPoint>>()
    }

    /// 从已加载的 manifest 登记决策点。
    /// 只登记 `manifest.decisionPoints`（校验通过的），
    /// `manifest.invalidDecisionPointIds` 里的决策点**不登记** ⇒ 查询不到 ⇒ 不生效。
    public func registerFromManifest(manifest: SkillManifest): Unit {
        let pointMap = HashMap<String, DecisionPoint>()
        for (dp in manifest.decisionPoints) {
            pointMap.add(dp.id, dp)
        }
        _bySkill.add(manifest.name, pointMap)

        if (manifest.invalidDecisionPointIds.size > 0) {
            LogUtils.warn("Skill '${manifest.name}' 有 ${manifest.invalidDecisionPointIds.size} 个决策点未登记（不生效）: ${manifest.invalidDecisionPointIds.toString()}")
        }
    }

    /// 查询某个技能下**有效**的决策点。返回 None 表示：
    ///   - 该决策点不存在，或
    ///   - 该决策点因校验失败被禁用（spec 5.15.3 异常场景 3）
    /// 两种情况对调用方的处理方式相同：不推送选项卡片，走普通审批。
    public func find(skillName: String, pointId: String): Option<DecisionPoint> {
        match (_bySkill.get(skillName)) {
            case Some(points) => return points.get(pointId)
            case None => return None
        }
    }

    /// 该技能是否登记过决策点（用于区分"技能无决策点"与"技能未加载"）。
    public func hasSkill(skillName: String): Bool {
        return _bySkill.contains(skillName)
    }

    /// 某技能下所有**有效**决策点。
    public func listValidPoints(skillName: String): Array<DecisionPoint> {
        let result = ArrayList<DecisionPoint>()
        match (_bySkill.get(skillName)) {
            case Some(points) =>
                for ((_, dp) in points) {
                    result.add(dp)
                }
            case None => ()
        }
        return result.toArray()
    }

    /// 注销某技能的决策点（技能卸载时调用）。
    public func unregister(skillName: String): Bool {
        if (_bySkill.contains(skillName)) {
            _bySkill.remove(skillName)
            return true
        }
        return false
    }

    /// 已登记的技能数。
    public func skillCount(): Int64 {
        return _bySkill.size
    }
}
