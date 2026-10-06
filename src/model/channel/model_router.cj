/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.model.channel

import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.{JsonValue, JsonObject, JsonInt}
import magic.jsonable.JsonUtils
import magic.log.LogUtils

/**
 * 解析结果：命中的通道快照 + 模型 ID（原样，不改写）。
 */
public struct ResolvedChannel {
    let channel: ChannelSnapshot
    let modelId: String

    public init(channel: ChannelSnapshot, modelId: String) {
        this.channel = channel
        this.modelId = modelId
    }
}

/**
 * 选路请求（design.md §7 / spec REQ-DMC-010）。
 *
 * @param scope 作用域：global / agent:<id> / task:<type>（具体者优先）
 * @param requireCapabilities 必须全部满足的能力位（tools / vision / reasoning / stream ...）
 */
public struct RouteRequest {
    let scope: String
    let requireCapabilities: ArrayList<String>

    public init(scope: String, requireCapabilities: ArrayList<String>) {
        this.scope = scope
        this.requireCapabilities = requireCapabilities
    }
}

/**
 * 一条路由规则（由 llm_route_rule 表解析而来；JSON 数组字段已在 ChannelService 解析为 ArrayList）。
 */
public struct RouteRule {
    let scope: String
    let requireCapabilities: ArrayList<String>
    let channelChain: ArrayList<String>
    let fallbackChain: ArrayList<String>
    let strategy: String
    let shadowPercent: Int32
    let priority: Int32
    let enabled: Bool

    public init(
        scope: String,
        requireCapabilities: ArrayList<String>,
        channelChain: ArrayList<String>,
        fallbackChain: ArrayList<String>,
        strategy: String,
        shadowPercent: Int32,
        priority: Int32,
        enabled: Bool
    ) {
        this.scope = scope
        this.requireCapabilities = requireCapabilities
        this.channelChain = channelChain
        this.fallbackChain = fallbackChain
        this.strategy = strategy
        this.shadowPercent = shadowPercent
        this.priority = priority
        this.enabled = enabled
    }
}

/**
 * 影子流量选路结果（T032）。
 *
 * @param channel 主通道 —— **真正拿去回答用户的就是它**，影子永不替换主结果
 * @param shadow 影子通道 —— 命中抽样时取次优通道，由调用方另发对照请求后记账
 * @param percent 生效的影子比例（0 表示未开影子）
 */
public struct ShadowRoute {
    let channel: Option<ChannelSnapshot>
    let shadow: Option<ChannelSnapshot>
    let percent: Int32

    public init(channel: Option<ChannelSnapshot>, shadow: Option<ChannelSnapshot>, percent: Int32) {
        this.channel = channel
        this.shadow = shadow
        this.percent = percent
    }
}

/**
 * 影子指标累加器（按 "<code>:main" / "<code>:shadow" 分桶）。
 */
public struct ShadowStat {
    let requests: Int64
    let failures: Int64
    let totalLatencyMs: Int64

    public init(requests: Int64, failures: Int64, totalLatencyMs: Int64) {
        this.requests = requests
        this.failures = failures
        this.totalLatencyMs = totalLatencyMs
    }
}

/**
 * ModelRouter — 选路核心（T006 / T029 / T028 / T032）。
 *
 * - 单 provider 解析（resolveChannel）：hot path 等价替换 ChannelRegistry.getChannel，
 *   作为 createChatModel 的规范入口（T006 去死代码）。
 * - 完整选路（resolve）：作用域（具体优先） + 能力过滤 + 策略排序 + 回退链。
 *   策略（T029）：priority（按规则既定顺序）/ cost（按单价升序）/ health（按健康度降序）/
 *   system1（预留，暂以 priority 兜底，待 Laya 打分接入 Phase 3）。
 * - 成本策略（T028）依赖可注入的单价查询 pricingProvider：默认返回 0（中性），
 *   由 ChannelService 启动时从 model_pricing 表注入（见 channel_service.cj loadRouteRules）。
 *
 * 设计边界：ModelRouter 不直接碰 DB/DAO，规则由 ChannelService 解析后注入（setRules）。
 */
public class ModelRouter {
    private static let INSTANCE = ModelRouter()
    private var rules: ArrayList<RouteRule> = ArrayList<RouteRule>()
    private var pricingProvider: (String) -> Float64 = { _ => 0.0 }
    /** T032：scope → 影子抽样序号（进程内自增，保证同会话分布稳定） */
    private var shadowSeqs: HashMap<String, Int64> = HashMap<String, Int64>()
    /** T032：影子指标，key = "<code>:main" / "<code>:shadow" */
    private var shadowStats: HashMap<String, ShadowStat> = HashMap<String, ShadowStat>()
    /** T031：难度打分器（可插拔，由 Laya / Agent 侧注入）；None 表示未接入 */
    private var difficultyScorer: Option<(String) -> Float64> = None<(String) -> Float64>
    /** T031：当前请求难度提示 0..1；None 表示未设置（system1 退化为 healthScore） */
    private var difficultyHint: Option<Float64> = None<Float64>
    /** T031：通道优先级查询（归一化用），由 ChannelService 启动时注入 */
    private var priorityProvider: Option<(String) -> Float64> = None<(String) -> Float64>

    public static func shared(): ModelRouter {
        INSTANCE
    }

    /**
     * 注入路由规则（由 ChannelService 从 llm_route_rule 表加载后调用）。
     */
    public func setRules(rules: ArrayList<RouteRule>): Unit {
        this.rules = rules
        LogUtils.info("ModelRouter.setRules: 载入 ${rules.size} 条路由规则")
    }

    public func getRules(): ArrayList<RouteRule> {
        this.rules
    }

    /**
     * 注入单价查询（cost 策略用）。默认中性；ChannelService 启动时从 model_pricing 注入。
     */
    public func setPricingProvider(p: (String) -> Float64): Unit {
        this.pricingProvider = p
    }

    /**
     * 单 provider 解析：provider:model 中的 provider 必须命中运行注册表。
     * 等价于 ChannelRegistry.getChannel(provider)，作为 createChatModel 的规范入口。
     */
    public func resolveChannel(provider: String): Option<ChannelSnapshot> {
        ChannelRegistry.shared().getChannel(provider)
    }

    /**
     * provider 是否在运行注册表中（checkProvider 的注册表优先判定）。
     */
    public func hasProvider(provider: String): Bool {
        ChannelRegistry.shared().getChannel(provider).isSome()
    }

    /**
     * 当前全局默认通道（热切换目标）。
     */
    public func defaultChannel(): Option<ChannelSnapshot> {
        ChannelRegistry.shared().getDefault()
    }

    /**
     * 完整选路（design.md §7）：作用域 + 能力 + 策略 + 回退。
     * 返回命中通道；无规则/无候选时回退到全局默认通道；都没有返回 None。
     */
    public func resolve(request: RouteRequest): Option<ChannelSnapshot> {
        let ruleOpt = selectRule(request.scope)
        var candidates = ArrayList<ChannelSnapshot>()
        if (let Some(rule) <- ruleOpt) {
            for (code in rule.channelChain) {
                if (let Some(snap) <- ChannelRegistry.shared().getChannel(code)) {
                    if (capabilitiesSatisfied(snap, request.requireCapabilities)) {
                        candidates.add(snap)
                    }
                }
            }
            if (candidates.isEmpty()) {
                for (code in rule.fallbackChain) {
                    if (let Some(snap) <- ChannelRegistry.shared().getChannel(code)) {
                        if (capabilitiesSatisfied(snap, request.requireCapabilities)) {
                            candidates.add(snap)
                        }
                    }
                }
            }
            candidates = sortByStrategy(rule.strategy, candidates)
        } else {
            if (let Some(def) <- defaultChannel()) {
                candidates.add(def)
            }
        }
        if (candidates.isEmpty()) {
            return None<ChannelSnapshot>
        }
        return Some<ChannelSnapshot>(candidates.get(0).getOrThrow())
    }

    /**
     * 调试/评估用：返回经能力过滤 + 策略排序后的候选通道 code 列表。
     * 供 llm_route_rule/evaluate 端点展示，便于运维确认规则生效。
     */
    public func candidatesFor(request: RouteRequest): ArrayList<String> {
        let ruleOpt = selectRule(request.scope)
        var codes = ArrayList<String>()
        if (let Some(rule) <- ruleOpt) {
            for (code in rule.channelChain) {
                if (let Some(snap) <- ChannelRegistry.shared().getChannel(code)) {
                    if (capabilitiesSatisfied(snap, request.requireCapabilities)) {
                        codes.add(code)
                    }
                }
            }
            if (codes.isEmpty()) {
                for (code in rule.fallbackChain) {
                    if (let Some(snap) <- ChannelRegistry.shared().getChannel(code)) {
                        if (capabilitiesSatisfied(snap, request.requireCapabilities)) {
                            codes.add(code)
                        }
                    }
                }
            }
            let sorted = sortByStrategy(rule.strategy, collectSnapshots(codes))
            var out = ArrayList<String>()
            for (s in sorted) { out.add(s.code) }
            return out
        }
        if (let Some(def) <- defaultChannel()) {
            codes.add(def.code)
        }
        return codes
    }

    /**
     * 完整选路 + 影子流量（T032）。
     *
     * 影子语义（关键约束）：**影子请求绝不影响主结果**——
     * - `channel` 永远是主通道（candidates[0]），真正拿去回答用户；
     * - `shadow` 仅在命中规则的 shadowPercent > 0 且本次抽样命中时才是**次优通道**，
     *   由调用方另行发起对照请求并调 recordShadowResult 记账，不替换主结果；
     * - 抽样用请求内自增计数器 + 规则 scope 做种子，保证同一会话内分布稳定，
     *   避免同一轮对话反复横跳（否则用户体验上像是"模型在变"）。
     */
    public func resolveWithShadow(request: RouteRequest): ShadowRoute {
        let mainOpt = resolve(request)
        var shadow = None<ChannelSnapshot>
        var percent: Int32 = 0

        let ruleOpt = selectRule(request.scope)
        if (let Some(rule) <- ruleOpt) {
            percent = rule.shadowPercent
            if (percent > 0 && percent < 100) {
                // 同 scope 同计数 → 稳定抽样
                let seq = nextShadowSeq(request.scope)
                let bucket = seq % 100
                if (bucket < Int64(percent)) {
                    // 命中影子：取候选列表里的次优通道（跳过主通道），影子不替换主结果
                    let mainCode = if (let Some(m) <- mainOpt) { m.code } else { "" }
                    let codes = candidatesFor(request)
                    var picked = ""
                    for (code in codes) {
                        if (code != mainCode) {
                            picked = code
                            break
                        }
                    }
                    if (!picked.isEmpty()) {
                        shadow = ChannelRegistry.shared().getChannel(picked)
                    }
                }
            }
        }

        // 规则未命中时不制造影子：percent 保持 0
        ShadowRoute(mainOpt, shadow, percent)
    }

    /**
     * 影子对比指标（T032）。主/影各记 请求数 / 失败数 / 累计延迟(ms)。
     * 供 shadow-compare 页面展示延迟与失败率差异。
     */
    public func recordShadowResult(mainCode: String, shadowCode: String, mainOk: Bool, mainLatencyMs: Int64, shadowOk: Bool, shadowLatencyMs: Int64): Unit {
        bumpShadowStat(mainCode, "main", mainOk, mainLatencyMs)
        bumpShadowStat(shadowCode, "shadow", shadowOk, shadowLatencyMs)
    }

    /**
     * 读影子指标快照（key = "<code>:main" / "<code>:shadow"）。
     * 返回 JSON 文本，交由 API 层直接透传给前端。
     */
    public func shadowStatsJson(): String {
        let obj = JsonObject()
        for ((k, v) in shadowStats) {
            let item = JsonObject()
            item.put("requests", JsonInt(v.requests))
            item.put("failures", JsonInt(v.failures))
            item.put("totalLatencyMs", JsonInt(v.totalLatencyMs))
            obj.put(k, item)
        }
        obj.toString()
    }

    /**
     * scope 维度的影子抽样序号（进程内自增）。同 scope 连续请求序号稳定递增，
     * 取模分桶即可得到稳定的百分比分布。
     */
    private func nextShadowSeq(scope: String): Int64 {
        // HashMap 计数写法对齐 result_aggregator.cj:96（get 判存 → add 写回）
        if (let Some(current) <- shadowSeqs.get(scope)) {
            shadowSeqs.add(scope, current + 1)
            return current + 1
        }
        shadowSeqs.add(scope, 1)
        1
    }

    private func bumpShadowStat(code: String, bucket: String, ok: Bool, latencyMs: Int64): Unit {
        if (code.isEmpty()) {
            return
        }
        let key = "${code}:${bucket}"
        if (let Some(prev) <- shadowStats.get(key)) {
            var failures = prev.failures
            if (!ok) {
                failures = prev.failures + 1
            }
            shadowStats.add(key, ShadowStat(
                prev.requests + 1,
                failures,
                prev.totalLatencyMs + latencyMs
            ))
        } else {
            let failures = if (ok) { 0 } else { 1 }
            shadowStats.add(key, ShadowStat(1, failures, latencyMs))
        }
    }

    // ==================== 私有辅助 ====================

    private func collectSnapshots(codes: ArrayList<String>): ArrayList<ChannelSnapshot> {
        var out = ArrayList<ChannelSnapshot>()
        for (code in codes) {
            if (let Some(snap) <- ChannelRegistry.shared().getChannel(code)) {
                out.add(snap)
            }
        }
        out
    }

    /**
     * 选中与 scope 最匹配的规则：具体作用域优先（task > agent > global），同 scope 取 priority 最高。
     */
    private func selectRule(scope: String): Option<RouteRule> {
        var best: Option<RouteRule> = None<RouteRule>
        var bestPriority: Int32 = -1
        for (r in rules) {
            if (!r.enabled) {
                continue
            }
            if (r.scope == scope || r.scope == "global") {
                if (r.priority > bestPriority) {
                    best = Some(r)
                    bestPriority = r.priority
                }
            }
        }
        best
    }

    private func capabilitiesSatisfied(snap: ChannelSnapshot, required: ArrayList<String>): Bool {
        if (required.isEmpty()) {
            return true
        }
        let have = parseJsonStringArray(snap.capabilities)
        for (cap in required) {
            var found = false
            for (h in have) {
                if (h == cap) {
                    found = true
                    break
                }
            }
            if (!found) {
                return false
            }
        }
        true
    }

    /**
     * 按策略对候选通道排序（手选排序，避免依赖具体 sortBy API）。
     * - priority / system1：保持规则既定顺序，仅做稳定优选（enabled 优先于 degraded）。
     * - cost：单价升序（便宜优先）。
     * - health：健康度降序（enabled > degraded > 其它）。
     */
    private func sortByStrategy(strategy: String, candidates: ArrayList<ChannelSnapshot>): ArrayList<ChannelSnapshot> {
        let n = candidates.size
        var order = ArrayList<Int64>()
        var k = 0
        while (k < n) {
            order.add(Int64(k))
            k = k + 1
        }
        var i = 0
        while (i < n) {
            var bestIdx = i
            var j = i + 1
            while (j < n) {
                let sBest = strategyScore(strategy, candidates.get(order.get(bestIdx).getOrThrow()).getOrThrow())
                let sJ = strategyScore(strategy, candidates.get(order.get(j).getOrThrow()).getOrThrow())
                let better = if (strategy == "cost") { sJ < sBest } else { sJ > sBest }
                if (better) {
                    bestIdx = j
                }
                j = j + 1
            }
            if (bestIdx != i) {
                let tmp = order.get(i).getOrThrow()
                order[i] = order.get(bestIdx).getOrThrow()
                order[bestIdx] = tmp
            }
            i = i + 1
        }
        var out = ArrayList<ChannelSnapshot>()
        var m = 0
        while (m < n) {
            out.add(candidates.get(order.get(m).getOrThrow()).getOrThrow())
            m = m + 1
        }
        out
    }

    /**
     * 策略打分（用于排序）。
     * priority：状态健康度作为稳定优选键（降序）。
     * cost：单价（越小越优先，故升序）。
     * health：状态健康度（降序）。
     * system1：难度分流（T031）——按 difficultyHint 与通道能力/优先级综合打分，
     *          高难度倾向"强模型"（优先级数值大者），低难度倾向"快模型"。
     *          difficulty 未注入时退化为 healthScore，保持与旧行为兼容。
     */
    private func strategyScore(strategy: String, snap: ChannelSnapshot): Float64 {
        if (strategy == "cost") {
            return this.pricingProvider(snap.code)
        }
        if (strategy == "health") {
            return healthScore(snap)
        }
        if (strategy == "system1") {
            return system1Score(snap)
        }
        // priority：稳定优选键
        return healthScore(snap)
    }

    /**
     * System-1 难度分流打分（T031）。
     *
     * 设计（对齐 design.md「快/强模型分流」）：
     * - 难度 d ∈ [0,1]，由外部打分器注入（对接 laya-system1-integration 用例 #3）；
     * - 通道优先级 p = priority / 100（归一到 [0,1]，约定数值大 = 更强/更贵）；
     * - 难度高时偏好 p 大的通道，难度低时偏好 p 小的通道（更快更便宜）；
     * - 再叠加健康度作为次要权重，**健康度低于 0.3（degraded/failed）一律降权**，
     *   避免"高难度把流量压到故障通道"。
     *
     * 公式：score = (1 - d) * (1 - p) + d * p + 0.2 * health
     */
    private func system1Score(snap: ChannelSnapshot): Float64 {
        let health = healthScore(snap)
        if (health < 0.3) {
            // 故障/停用通道直接压到最低，避免 System-1 把高难度流量打过去
            return health - 1.0
        }
        var d = 0.5
        if (let Some(v) <- this.difficultyHint) {
            d = v
        }
        let p = this.priorityScale(snap)
        (1.0 - d) * (1.0 - p) + d * p + 0.2 * health
    }

    /**
     * 通道优先级归一化到 [0,1]。约定：priority 数值越大 = 越强/越贵，
     * 与种子数据（种子 priority 均为 0，实际靠 llm_channel.priority 列配置）一致。
     * 归一化用固定上界 100，避免依赖全局最大最小值导致排序结果随其它通道变化。
     */
    private func priorityScale(snap: ChannelSnapshot): Float64 {
        var raw = 0.0
        if (let Some(p) <- this.priorityProvider) {
            raw = p(snap.code)
        }
        if (raw <= 0.0) {
            return 0.0
        }
        if (raw >= 100.0) {
            return 1.0
        }
        raw / 100.0
    }

    /**
     * 注入难度打分器（T031）。
     *
     * @param scorer 形如 (prompt) -> [0,1]；由 Laya 侧或 Agent 侧注入，
     *               ModelRouter 只负责消费，不认识具体打分模型（保持可插拔）。
     *               传 None 表示清空，system1 退化为 healthScore。
     */
    public func setDifficultyScorer(scorer: Option<(String) -> Float64>): Unit {
        this.difficultyScorer = scorer
    }

    /**
     * 设置当前请求的难度提示（0..1），供 system1 策略分流。
     * 由调用方在选路前设置（例如 Agent 侧用任务描述打分后传入）。
     * 置 null 时 system1 退化为 healthScore。
     */
    public func setDifficultyHint(d: Float64): Unit {
        if (d < 0.0) {
            this.difficultyHint = Some<Float64>(0.0)
        } else if (d > 1.0) {
            this.difficultyHint = Some<Float64>(1.0)
        } else {
            this.difficultyHint = Some<Float64>(d)
        }
    }

    /**
     * 通道优先级查询（归一化用）。由 ChannelService 启动时从 llm_channel.priority 注入。
     */
    public func setPriorityProvider(p: (String) -> Float64): Unit {
        this.priorityProvider = Some(p)
    }

    private func healthScore(snap: ChannelSnapshot): Float64 {
        if (snap.status == "enabled") {
            1.0
        } else if (snap.status == "degraded") {
            0.3
        } else {
            0.0
        }
    }

    /**
     * 解析 JSON 数组字符串为 ArrayList<String>（如 capabilities / scopes）。
     * 解析失败返回空列表（不抛异常，保证选路不崩）。
     */
    private func parseJsonStringArray(s: String): ArrayList<String> {
        let out = ArrayList<String>()
        if (s.isEmpty()) {
            return out
        }
        try {
            let v = JsonValue.fromStr(s)
            if (let Some(arr) <- JsonUtils.asJsonArray(v)) {
                for (item in arr.getItems()) {
                    if (let Some(js) <- JsonUtils.toString(item)) {
                        out.add(js)
                    }
                }
            }
        } catch (_: Exception) {}
        out
    }
}
