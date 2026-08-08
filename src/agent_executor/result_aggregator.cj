/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.agent_executor

import std.collection.{ArrayList, HashMap}
import stdx.encoding.json.{JsonValue, JsonObject, JsonArray, JsonString, JsonInt, JsonBool}
import magic.log.LogUtils

public enum AggregationStrategy {
    | Merge
    | Vote
    | Arbitrate
}

public class StepAggregationResult {
    public var strategy: AggregationStrategy = AggregationStrategy.Merge
    public var mergedOutput: HashMap<String, JsonValue> = HashMap<String, JsonValue>()
    public var conflicts: ArrayList<String> = ArrayList<String>()
    public var voteResults: HashMap<String, Int64> = HashMap<String, Int64>()
    public var finalDecision: String = ""

    public init() {}

    public func toJsonValue(): JsonValue {
        var map = HashMap<String, JsonValue>()
        map.add("strategy", JsonString(aggregationStrategyToString(this.strategy)))
        map.add("merged_output", JsonObject(this.mergedOutput))
        let conflictsArr = JsonArray()
        for (c in this.conflicts) {
            conflictsArr.add(JsonString(c))
        }
        map.add("conflicts", conflictsArr)
        var voteMap = HashMap<String, JsonValue>()
        for ((k, v) in this.voteResults) {
            voteMap.add(k, JsonInt(v))
        }
        map.add("vote_results", JsonObject(voteMap))
        map.add("final_decision", JsonString(this.finalDecision))
        return JsonObject(map)
    }

    public static func aggregationStrategyToString(s: AggregationStrategy): String {
        match (s) {
            case AggregationStrategy.Merge => "merge"
            case AggregationStrategy.Vote => "vote"
            case AggregationStrategy.Arbitrate => "arbitrate"
        }
    }
}

public class ResultAggregator {
    public init() {}

    public func aggregate(stepResults: HashMap<String, StepResult>, strategy: AggregationStrategy): StepAggregationResult {
        match (strategy) {
            case AggregationStrategy.Merge => return mergeResults(stepResults)
            case AggregationStrategy.Vote => return voteResults(stepResults)
            case AggregationStrategy.Arbitrate => return arbitrateResults(stepResults)
        }
    }

    public func mergeResults(stepResults: HashMap<String, StepResult>): StepAggregationResult {
        let result = StepAggregationResult()
        result.strategy = AggregationStrategy.Merge

        for ((stepName, stepResult) in stepResults) {
            if (let Some(output) <- stepResult.output) {
                if (output is JsonObject) {
                    let fields = (output as JsonObject).getOrThrow().getFields()
                    for ((key, value) in fields) {
                        if (result.mergedOutput.contains(key)) {
                            result.conflicts.add("Key '${key}' overwritten by step '${stepName}'")
                        }
                        result.mergedOutput.add(key, value)
                    }
                } else {
                    result.mergedOutput.add(stepName, output)
                }
            }
        }

        return result
    }

    public func voteResults(stepResults: HashMap<String, StepResult>): StepAggregationResult {
        let result = StepAggregationResult()
        result.strategy = AggregationStrategy.Vote

        let voteCounts = HashMap<String, Int64>()
        var totalVotes: Int64 = 0

        for ((stepName, stepResult) in stepResults) {
            if (let Some(output) <- stepResult.output) {
                let voteKey = output.toString()
                totalVotes = totalVotes + 1
                if (let Some(count) <- voteCounts.get(voteKey)) {
                    voteCounts.add(voteKey, count + 1)
                } else {
                    voteCounts.add(voteKey, 1)
                }
            }
        }

        result.voteResults = voteCounts

        var maxVotes: Int64 = 0
        var winner = ""
        for ((key, count) in voteCounts) {
            if (count > maxVotes) {
                maxVotes = count
                winner = key
            }
        }
        result.finalDecision = winner

        if (totalVotes > 0 && maxVotes * 2 <= totalVotes) {
            result.conflicts.add("No majority consensus (max votes: ${maxVotes.toString()}/${totalVotes.toString()})")
        }

        return result
    }

    public func arbitrateResults(stepResults: HashMap<String, StepResult>): StepAggregationResult {
        let result = StepAggregationResult()
        result.strategy = AggregationStrategy.Arbitrate

        var priorityOrder: Int64 = 9223372036854775807
        var selectedOutput: Option<JsonValue> = None<JsonValue>
        var selectedStep = ""

        for ((stepName, stepResult) in stepResults) {
            if (let Some(output) <- stepResult.output) {
                let priority = stepResult.durationMs
                if (priority < priorityOrder) {
                    priorityOrder = priority
                    selectedOutput = Some(output)
                    selectedStep = stepName
                }
            }
        }

        if (selectedOutput.isSome()) {
            let output = selectedOutput.getOrThrow()
            if (output is JsonObject) {
                let fields = (output as JsonObject).getOrThrow().getFields()
                for ((k, v) in fields) {
                    result.mergedOutput.add(k, v)
                }
            } else {
                result.mergedOutput.add(selectedStep, output)
            }
            result.finalDecision = "Selected step '${selectedStep}' as arbiter (fastest: ${priorityOrder.toString()}ms)"
        }

        return result
    }

    public func incrementalAggregate(existing: HashMap<String, JsonValue>, newResult: StepResult): HashMap<String, JsonValue> {
        let merged = HashMap<String, JsonValue>()
        for ((k, v) in existing) {
            merged.add(k, v)
        }
        if (let Some(output) <- newResult.output) {
            if (output is JsonObject) {
                let fields = (output as JsonObject).getOrThrow().getFields()
                for ((k, v) in fields) {
                    merged.add(k, v)
                }
            } else {
                merged.add(newResult.stepName, output)
            }
        }
        return merged
    }

    public func detectConflicts(stepResults: HashMap<String, StepResult>): ArrayList<String> {
        let conflicts = ArrayList<String>()
        let keySources = HashMap<String, ArrayList<String>>()

        for ((stepName, stepResult) in stepResults) {
            if (let Some(output) <- stepResult.output) {
                if (output is JsonObject) {
                    let fields = (output as JsonObject).getOrThrow().getFields()
                    for ((key, _) in fields) {
                        if (!keySources.contains(key)) {
                            keySources.add(key, ArrayList<String>())
                        }
                        if (let Some(sources) <- keySources.get(key)) {
                            sources.add(stepName)
                        }
                    }
                }
            }
        }

        for ((key, sources) in keySources) {
            if (sources.size > 1) {
                var sourceStr = ""
                for (i in 0..sources.size) {
                    if (i > 0) {
                        sourceStr = sourceStr + ", "
                    }
                    sourceStr = sourceStr + sources[i]
                }
                conflicts.add("Key '${key}' produced by multiple steps: ${sourceStr}")
            }
        }

        return conflicts
    }
}