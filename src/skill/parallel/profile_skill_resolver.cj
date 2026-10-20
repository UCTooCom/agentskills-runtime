package magic.skill.parallel

import magic.core.skill.{Skill, SkillManager}
import std.collection.ArrayList

/**
 * 沿 AgentDefinition.profiles 持有的 profile 技能引用（仅名称），从 SkillManager 一次性取出全部 profile 技能实例（T100）。
 *
 * 设计要点：
 * - 数据模型只存「引用」（技能名），不存提示词正文；正文在技能元数据 / skills 目录中。
 * - 导出 / 传输时调用 resolve()，沿引用还原出技能实例，便于序列化或跨端携带。
 */
public class ProfileSkillResolver {
    public init() {}

    public func resolve(profileRefs: ArrayList<String>, manager: SkillManager): ArrayList<Skill> {
        let result = ArrayList<Skill>()
        for (ref in profileRefs) {
            let opt = manager.getSkill(ref)
            if (opt.isSome()) {
                result.add(opt.getOrThrow())
            }
        }
        return result
    }
}
