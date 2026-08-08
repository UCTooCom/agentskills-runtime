/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.interaction

import std.collection.{ArrayList, HashMap}
import std.time.DateTime
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonNull, JsonArray}
import magic.log.LogUtils

public class TuningMetrics {
    public var agentId: String = ""
    public var successRate: Float64 = 0.0
    public var avgDurationMs: Int64 = 0
    public var promptTokens: Int64 = 0
    public var completionTokens: Int64 = 0
    public var totalTokens: Int64 = 0
    public var toolCallCount: Int64 = 0
    public var sideEffectCount: Int64 = 0
    public var evaluationType: String = "agent"
    public var evaluatedAt: DateTime = DateTime.now()

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("agent_id", JsonString(this.agentId))
        map.add("success_rate", JsonFloat(this.successRate))
        map.add("avg_duration_ms", JsonInt(this.avgDurationMs))
        map.add("total_tokens", JsonInt(this.totalTokens))
        map.add("tool_call_count", JsonInt(this.toolCallCount))
        map.add("evaluation_type", JsonString(this.evaluationType))
        map.add("evaluated_at", JsonString(this.evaluatedAt.toString()))
        JsonObject(map)
    }
}

public class TuningConfigEntry {
    public var id: String = ""
    public var agentId: String = ""
    public var strategyType: String = ""
    public var config: String = ""
    public var isEnabled: Bool = true
    public var lastAppliedAt: Option<DateTime> = None<DateTime>
    public var createdAt: DateTime = DateTime.now()

    public init() {}
}

public class TuningEngine {
    private let _metricsProvider: (String) -> ArrayList<TuningMetrics>
    private let _tuningConfigWriter: (String, String, String, Bool) -> Bool
    private let _tuningConfigReader: (String) -> ArrayList<TuningConfigEntry>

    public init() {
        _metricsProvider = { _ => ArrayList<TuningMetrics>() }
        _tuningConfigWriter = { _, _, _, _ => false }
        _tuningConfigReader = { _ => ArrayList<TuningConfigEntry>() }
    }

    public init(metricsProvider!: (String) -> ArrayList<TuningMetrics>, tuningConfigWriter!: (String, String, String, Bool) -> Bool, tuningConfigReader!: (String) -> ArrayList<TuningConfigEntry>) {
        _metricsProvider = metricsProvider
        _tuningConfigWriter = tuningConfigWriter
        _tuningConfigReader = tuningConfigReader
    }

    public func analyzeAndTune(agentId: String): Option<TuningResult> {
        LogUtils.info("[TuningEngine] Analyzing and tuning agent: ${agentId}")

        let metrics = _metricsProvider(agentId)

        if (metrics.size == 0) {
            LogUtils.info("[TuningEngine] No metrics found for agent: ${agentId}")
            return None<TuningResult>
        }

        let latestMetrics = metrics[0]

        let strategyOpt = selectStrategy(latestMetrics)
        if (strategyOpt.isNone()) {
            LogUtils.info("[TuningEngine] No tuning strategy needed for agent: ${agentId}")
            return None<TuningResult>
        }

        let strategy = strategyOpt.getOrThrow()

        let applied = applyTuning(agentId, strategy)
        if (!applied) {
            LogUtils.error("[TuningEngine] Failed to apply tuning for agent: ${agentId}")
            return None<TuningResult>
        }

        let result = TuningResult(
            agentId: agentId,
            strategy: strategy,
            beforeMetrics: Some(latestMetrics),
            afterMetrics: None<TuningMetrics>,
            appliedAt: DateTime.now()
        )

        LogUtils.info("[TuningEngine] Tuning applied: agentId=${agentId}, strategyType=${strategy.strategyType}")
        return Some(result)
    }

    public func applyTuning(agentId: String, strategy: TuningStrategy): Bool {
        LogUtils.info("[TuningEngine] Applying tuning: agentId=${agentId}, strategyType=${strategy.strategyType}")
        _tuningConfigWriter(agentId, strategy.strategyType, strategy.toJsonValue().toString(), true)
    }

    public func getTuningHistory(agentId: String): ArrayList<TuningResult> {
        let results = ArrayList<TuningResult>()
        let configs = _tuningConfigReader(agentId)

        for (config in configs) {
            let strategy = TuningStrategy(
                strategyType: config.strategyType,
                promptOptimization: None<PromptOptimization>,
                toolSelectionOptimization: None<ToolSelectionOptimization>,
                executionPathOptimization: None<ExecutionPathOptimization>
            )

            let appliedAt = match (config.lastAppliedAt) {
                case Some(t) => t
                case None => config.createdAt
            }

            let result = TuningResult(
                agentId: agentId,
                strategy: strategy,
                beforeMetrics: None<TuningMetrics>,
                afterMetrics: None<TuningMetrics>,
                appliedAt: appliedAt
            )
            results.add(result)
        }

        results
    }

    public func selectStrategy(metrics: TuningMetrics): Option<TuningStrategy> {
        if (metrics.successRate < 0.7) {
            LogUtils.info("[TuningEngine] Low success rate (${metrics.successRate}), selecting prompt_optimization")
            return Some(TuningStrategy(
                strategyType: "prompt_optimization",
                promptOptimization: Some(PromptOptimization(
                    templateId: "default",
                    adjustments: HashMap<String, String>()
                )),
                toolSelectionOptimization: None<ToolSelectionOptimization>,
                executionPathOptimization: None<ExecutionPathOptimization>
            ))
        }

        if (metrics.toolCallCount > 50) {
            LogUtils.info("[TuningEngine] High tool call count (${metrics.toolCallCount}), selecting tool_selection_optimization")
            return Some(TuningStrategy(
                strategyType: "tool_selection_optimization",
                promptOptimization: None<PromptOptimization>,
                toolSelectionOptimization: Some(ToolSelectionOptimization(
                    preferredTools: ArrayList<String>(),
                    excludedTools: ArrayList<String>()
                )),
                executionPathOptimization: None<ExecutionPathOptimization>
            ))
        }

        if (metrics.avgDurationMs > 30000) {
            LogUtils.info("[TuningEngine] High avg duration (${metrics.avgDurationMs}ms), selecting execution_path_optimization")
            return Some(TuningStrategy(
                strategyType: "execution_path_optimization",
                promptOptimization: None<PromptOptimization>,
                toolSelectionOptimization: None<ToolSelectionOptimization>,
                executionPathOptimization: Some(ExecutionPathOptimization(
                    maxRetries: 3,
                    timeoutMs: 60000,
                    parallelism: 2
                ))
            ))
        }

        None<TuningStrategy>
    }
}

public class TuningStrategy {
    public var strategyType: String = ""
    public var promptOptimization: Option<PromptOptimization> = None<PromptOptimization>
    public var toolSelectionOptimization: Option<ToolSelectionOptimization> = None<ToolSelectionOptimization>
    public var executionPathOptimization: Option<ExecutionPathOptimization> = None<ExecutionPathOptimization>

    public init() {}

    public init(strategyType!: String, promptOptimization!: Option<PromptOptimization>, toolSelectionOptimization!: Option<ToolSelectionOptimization>, executionPathOptimization!: Option<ExecutionPathOptimization>) {
        this.strategyType = strategyType
        this.promptOptimization = promptOptimization
        this.toolSelectionOptimization = toolSelectionOptimization
        this.executionPathOptimization = executionPathOptimization
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("strategy_type", JsonString(this.strategyType))

        if (let Some(po) <- this.promptOptimization) {
            map.add("prompt_optimization", po.toJsonValue())
        }
        if (let Some(tso) <- this.toolSelectionOptimization) {
            map.add("tool_selection_optimization", tso.toJsonValue())
        }
        if (let Some(epo) <- this.executionPathOptimization) {
            map.add("execution_path_optimization", epo.toJsonValue())
        }

        JsonObject(map)
    }
}

public class PromptOptimization {
    public var templateId: String = ""
    public var adjustments: HashMap<String, String> = HashMap<String, String>()

    public init() {}

    public init(templateId!: String, adjustments!: HashMap<String, String>) {
        this.templateId = templateId
        this.adjustments = adjustments
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("template_id", JsonString(this.templateId))
        var adjMap = HashMap<String, JsonValue>()
        for ((k, v) in this.adjustments) {
            adjMap.add(k, JsonString(v))
        }
        map.add("adjustments", JsonObject(adjMap))
        JsonObject(map)
    }
}

public class ToolSelectionOptimization {
    public var preferredTools: ArrayList<String> = ArrayList<String>()
    public var excludedTools: ArrayList<String> = ArrayList<String>()

    public init() {}

    public init(preferredTools!: ArrayList<String>, excludedTools!: ArrayList<String>) {
        this.preferredTools = preferredTools
        this.excludedTools = excludedTools
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        var prefArr = ArrayList<JsonValue>()
        for (t in this.preferredTools) {
            prefArr.add(JsonString(t))
        }
        map.add("preferred_tools", JsonArray(prefArr))

        var exclArr = ArrayList<JsonValue>()
        for (t in this.excludedTools) {
            exclArr.add(JsonString(t))
        }
        map.add("excluded_tools", JsonArray(exclArr))

        JsonObject(map)
    }
}

public class ExecutionPathOptimization {
    public var maxRetries: Int64 = 3
    public var timeoutMs: Int64 = 60000
    public var parallelism: Int64 = 2

    public init() {}

    public init(maxRetries!: Int64, timeoutMs!: Int64, parallelism!: Int64) {
        this.maxRetries = maxRetries
        this.timeoutMs = timeoutMs
        this.parallelism = parallelism
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("max_retries", JsonInt(this.maxRetries))
        map.add("timeout_ms", JsonInt(this.timeoutMs))
        map.add("parallelism", JsonInt(this.parallelism))
        JsonObject(map)
    }
}

public class TuningResult {
    public var agentId: String = ""
    public var strategy: TuningStrategy = TuningStrategy()
    public var beforeMetrics: Option<TuningMetrics> = None<TuningMetrics>
    public var afterMetrics: Option<TuningMetrics> = None<TuningMetrics>
    public var appliedAt: DateTime = DateTime.now()

    public init() {}

    public init(agentId!: String, strategy!: TuningStrategy, beforeMetrics!: Option<TuningMetrics>, afterMetrics!: Option<TuningMetrics>, appliedAt!: DateTime) {
        this.agentId = agentId
        this.strategy = strategy
        this.beforeMetrics = beforeMetrics
        this.afterMetrics = afterMetrics
        this.appliedAt = appliedAt
    }

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("agent_id", JsonString(this.agentId))
        map.add("strategy", this.strategy.toJsonValue())
        map.add("applied_at", JsonString(this.appliedAt.toString()))

        if (let Some(bm) <- this.beforeMetrics) {
            map.add("before_metrics", bm.toJsonValue())
        }
        if (let Some(am) <- this.afterMetrics) {
            map.add("after_metrics", am.toJsonValue())
        }

        JsonObject(map)
    }
}
