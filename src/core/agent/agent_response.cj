/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */
package magic.core.agent

import magic.core.message.MessageList

import std.deriving.Derive

/**
 * The status of the agent response
 */
@Derive[ToString, Equatable]
public enum AgentResponseStatus {
    | Success // The execution is successful
    | Cancelled  // The execution is canceled by user
    | Failed // The execution is failed
}

/**
 * 任务终止原因（Ch0 / spec long-running-task 中断语义）。
 * 用于区分「正常收敛完成」与「步数预算耗尽但未达成目标」等中断态，
 * 使持久化层能落可区分的任务状态，而不是一律记为 completed。
 * 对标业界实践（LangGraph / AutoGen 的 termination reason）：
 * 收敛成功与预算耗尽是两种不同的终态，必须可区分。
 */
@Derive[ToString, Equatable]
public enum AgentTerminationReason {
    | Completed           // 正常收敛完成
    | MaxStepsExhausted  // 步数预算耗尽，未达成目标（区别于正常完成）
    | Cancelled          // 用户取消
    | Error              // 运行期异常
}

/**
 The execution response from an agent executor
 */
open public class AgentResponse <: Iterator<String> {
    /**
     * The status of the agent response
     */
    protected var _status: AgentResponseStatus

    /**
     * The agent result
     */
    protected var _content: String

    /**
     * Internal information during the execution
     */
    protected var _execution: Option<AgentExecution> = None

    open public prop status: AgentResponseStatus {
        get() { this._status }
    }

    public prop execution: AgentExecution {
        get() { this._execution.getOrThrow() }
    }

    /**
     * 任务终止原因（见 AgentTerminationReason）。默认 Completed。
     * 优先取执行上下文（AgentExecution）上记录的原因，使异步路径下
     * 外层 AsyncAgentResponse 也能反映内层设置的中断原因。
     */
    protected var _terminationReason: AgentTerminationReason = Completed

    open public prop terminationReason: AgentTerminationReason {
        get() {
            if (let Some(exec) <- this._execution) {
                let r = exec.terminationReason
                if (r != AgentTerminationReason.Completed) {
                    return r
                }
            }
            return this._terminationReason
        }
    }

    public func setTerminationReason(reason: AgentTerminationReason): Unit {
        this._terminationReason = reason
    }

    open public prop content: String {
        get() { this._content }
    }

    public init(status: AgentResponseStatus, content: String) {
        this._status = status
        this._content = content
    }

    public init(status: AgentResponseStatus, content: String, execution!: AgentExecution) {
        this._status = status
        this._content = content
        this._execution = execution
        execution.setAnswer(content)
    }

    /**
     * Since AsyncAgentResponse cannot inherit from both Iterator<String> and AgentResponse,
     * we need to override the next() method to return None.
     */
    open override public func next(): Option<String> {
        return None
    }
}