/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.plugins.doc_helper

import std.collection.ArrayList
import magic.log.LogUtils
import plugin_spi.{Plugin, PluginContext, PluginAnnotation}

/**
 * DocSummaryService - 文档摘要服务接口（插件对外契约）
 *
 * 服务注册名 = 接口全限定名 "magic.plugins.doc_helper.DocSummaryService"，
 * 消费方经 ServiceRegistry.getService<DocSummaryService>() 类型安全轨获取
 */
public interface DocSummaryService {
    /// 朴素文本摘要：按句终符切分后取前 maxSentences 句
    func summarize(text: String, maxSentences: Int32): String
}

/**
 * SimpleDocSummaryService - 朴素摘要实现
 *
 * 按"中文句号 + 换行"切句（演示级实现，不追求 NLP 质量），
 * 聚合前 maxSentences 句以中文句号重新拼接
 */
public class SimpleDocSummaryService <: DocSummaryService {
    public init() {}

    public func summarize(text: String, maxSentences: Int32): String {
        if (text.isEmpty() || maxSentences <= 0) {
            return ""
        }

        // 切句：中文句号分段，段内再按换行拆分，过滤空白句
        let sentences = ArrayList<String>()
        for (para in text.split("。")) {
            for (line in para.split("\n")) {
                let trimmed = line.trimAscii()
                if (!trimmed.isEmpty()) {
                    sentences.add(trimmed)
                }
            }
        }
        if (sentences.isEmpty()) {
            return text.trimAscii()
        }

        // 取前 N 句（不足 N 句取全部），句间补回中文句号
        let limit = min(sentences.size, Int64(maxSentences))
        let sb = StringBuilder()
        for (i in 0..limit) {
            if (i > 0) {
                sb.append("。")
            }
            sb.append(sentences[i])
        }
        return sb.toString()
    }
}

/**
 * DocHelperPlugin - Service + Skill + Route 三合一示例插件（PS-T009）
 *
 * 演示插件三维一体：
 * - Service：注册 doc-summary 摘要服务（本文件）
 * - Skill：plugins/doc-helper/SKILL.md 经 SkillBridge 自动注册（AI 行为）
 * - Route：DocHelperRoute 经 PluginRouteScanner 反射注册（双轨插件路由）
 *
 * 服务与路由的接线方式：PluginRouteScanner 无参构造 Controller，
 * 故由本插件在 onLoad 时把服务实例注入 Controller 的静态接点，
 * 停用/卸载时清空接点（路由降级为 503，不删除路由注册）
 */
@PluginAnnotation[name: "doc-helper", version: "1.0.0", dependencies: ""]
public class DocHelperPlugin <: Plugin {
    public init() {}

    public func getName(): String {
        return "doc-helper"
    }

    public func onLoad(context: PluginContext): Unit {
        let service = SimpleDocSummaryService()

        // 1. 注册摘要服务（注册名 = 服务接口全限定名）
        let ok = context.registerService("magic.plugins.doc_helper.DocSummaryService", service)
        if (ok) {
            LogUtils.info("[DocHelperPlugin] doc-summary service registered")
        } else {
            LogUtils.error("[DocHelperPlugin] doc-summary service register failed: name conflict")
        }

        // 2. 路由服务接线（Controller 由扫描器无参构造，经静态接点取服务）
        DocHelperController.wiredService = Some(service)

        // 3. 可逆清理：注销服务 + 断开路由接线（清理栈逆序执行）
        context.onCleanup({ =>
            let removed = context.serviceRegistry.unregister("magic.plugins.doc_helper.DocSummaryService")
            DocHelperController.wiredService = None
            LogUtils.info("[DocHelperPlugin] doc-summary service cleanup: removed=${removed}")
        })
    }

    public func onActivate(): Unit {
        LogUtils.info("[DocHelperPlugin] activated")
    }

    public func onDeactivate(): Unit {
        LogUtils.info("[DocHelperPlugin] deactivated")
    }

    public func onUnload(): Unit {
        LogUtils.info("[DocHelperPlugin] unloaded")
    }
}
