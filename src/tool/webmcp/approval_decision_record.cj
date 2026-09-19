/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool.webmcp

/**
 * 一次「人在回路」决策的**结果快照**（spec 5.15 / Ch13.4）
 *
 * 为什么要有这个类：
 * 审批工具位于基础设施层（`magic.tool.webmcp`），而落库在应用层（`magic.app.services.uctoo`）。
 * 若工具直接 import DAO，会新增 tool → app 的反向依赖，破坏既有分层
 * （对照 v15 修复问题 C：决策点校验同样是用「宿主注入回调」化解依赖，而不是让工具 import 注册表）。
 * 因此工具侧只负责**产出**这份纯数据快照，由宿主在组合根注入落库回调来消费它。
 *
 * 契约：
 * 1. 全部字段带默认值 ⇒ 构造零负担（`let r = ApprovalDecisionRecord()`），新增字段不会破坏调用方；
 * 2. 所有字段都是 String / Bool / Int64 原语 ⇒ 跨层可读，不引入任何 PO / ORM 类型；
 * 3. 只描述「一次决策发生了什么」，不含任何 IO 行为，便于单元测试直接构造断言。
 *
 * 字段落库映射见 `AgentApprovalsService.recordDecision`（→ `agent_approvals` 表）。
 */
public class ApprovalDecisionRecord {
    /** 请求批准的动作摘要（工具入参 action）→ content 首行 */
    public var action: String = ""

    /** 动作详情（工具入参 details）→ content 次行 */
    public var details: String = ""

    /** 决策点归属技能（工具入参 skillName，可为空） */
    public var skillName: String = ""

    /** 决策点 id（工具入参 decisionPointId，可为空） */
    public var decisionPointId: String = ""

    /** 实际下发给前端的选项集（JSON 文本）；决策点失效被剥离后为空 → options 列 */
    public var options: String = ""

    /** 决策点声明的默认项 id（超时兜底用） */
    public var defaultOption: String = ""

    /** 决策点声明的推荐项 id（仅用于事后复盘：当时推荐了什么） */
    public var recommended: String = ""

    /**
     * 用户实际选中的选项 id，或自动兜底采用的 default id。
     * ← Ch13.4 要求「agent_approvals 记录 selected_option」的就是这一字段。
     */
    public var selectedOption: String = ""

    /** 前端回传的原始结果文本（未解析），供事后复盘 → user_response 列 */
    public var userResponse: String = ""

    /** 终态：approved / rejected / timeout → status 列 */
    public var status: String = ""

    /** 是否以「未在时限内收到响应」的方式结束（含前端断开、超时、被判忙） */
    public var timedOut: Bool = false

    /** 是否因未响应而自动采用了 default（spec 5.15.3 异常场景 2：自动采用默认项继续） */
    public var autoDefaulted: Bool = false

    /** 本次等待上限（毫秒） → timeout_ms 列 */
    public var timeoutMs: Int64 = 0
}
