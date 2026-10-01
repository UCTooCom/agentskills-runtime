/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2024-2025. All rights reserved.
 */
package magic.agent_executor.react

import magic.agent_executor.common.*
import magic.core.agent.*
import magic.core.rag.RetrieverMode
import magic.core.message.WithTag
import magic.config.Config
import magic.log.LogUtils

public class ReactExecutor <: AgentExecutor {
    public ReactExecutor(private let loop!: Int64 = Config.normalReactSteps) {}

    override public prop name: String {
        get() { "react" }
    }

    override public func run(agent: Agent, request: AgentRequest): AgentResponse {
        let task = ReactTask(agent, request)
        try {
            task.begin()
            for (_ in 0..this.loop) {
                if (let Some(answer) <- task.runOnce()) {
                    return AgentResponse(AgentResponseStatus.Success, answer, execution: task.execution)
                } else if (let Some(stopInfo) <- task.stopInfo) {
                    LogUtils.info("Task stopped: ${stopInfo.reason}")
                    // v15: Forward collected reasoning_content even on early stop
                    if (!task.reasoningContent.isEmpty()) {
                        task.execution.setAnswerReason(task.reasoningContent)
                    }
                    return AgentResponse(AgentResponseStatus.Success, stopInfo.result, execution: task.execution)
                }
                task.handleAgentStepEvent()
            }
            let answer = task.summarize()
            task.markMaxStepsExhausted()
            return AgentResponse(AgentResponseStatus.Success, answer, execution: task.execution)
        } finally {
            task.end()
        }
    }

    override public func asyncRun(agent: Agent, request: AgentRequest): AsyncAgentResponse {
        let task = ReactTask(agent, request)
        // Create a thread to execute the react task
        let fut: Future<Iterator<String>> = spawn {
            var stepCount = 0
            try {
                task.begin()
                for (_ in 0..this.loop) {
                    stepCount += 1
                    // 单步失败重试 1 次（2026-09-23 定夺）：模型通道的网络抖动
                    // （TLS 握手失败 / DNS 解析失败）在跨境链路或 VPN 环境下偶发，
                    // 一次抖动不该直接变成一条失败回复。只重试 1 次——连续失败必须
                    // 如实上报，重试不是掩盖故障的手段。重试若再抛，由外层 catch 统一处理。
                    var stepResult: Option<AsyncReactAnswer> = None
                    try {
                        stepResult = task.asyncRunOnce()
                    } catch (e1: Exception) {
                        LogUtils.warn(agent.name, "react 第 ${stepCount} 步异常，重试 1 次: ${e1.message}")
                        stepResult = task.asyncRunOnce()
                    }
                    if (let Some(asyncAnswer) <- stepResult) {
                        return asyncAnswer
                    }
                    if (let Some(stopInfo) <- task.stopInfo) {
                        LogUtils.info("Task stopped: ${stopInfo.reason}")
                        return AsyncAgentResponse([stopInfo.result].iterator(), execution: task.execution)
                    }
                    task.handleAgentStepEvent()
                }
                LogUtils.info("Exceed the max react loop")
                task.markMaxStepsExhausted()
                return task.asyncSummarize()
            } catch (ex: Exception) {
                // 异步 ReAct 循环此前没有任何异常隔离：LLM 调用失败、工具未捕获异常、
                // UnsupportedException 等都会冒泡到 AsyncAgentResponse.next() 的 catch，
                // 触发 finishFn(false) -> AgentEndEvent(None) -> onAgentEnd 把任务标成
                // status=2(completed) 但 result=NULL，前端永远 loading（2026-09-20 实测
                // 两次长程任务均如此静默死亡）。这里捕获异常、记 ERROR 日志、标记
                // terminationReason=Error、返回可读失败答案，使 onAgentEnd 经
                // resolveTaskStatus 正确映射成 status=3(failed) 且 result 有内容。
                LogUtils.error(agent.name, "async react loop crashed at step ${stepCount}: ${ex.toString()}")
                task.execution.setTerminationReason(AgentTerminationReason.Error)
                // 【文案分流 · 2026-09-23】原实现对所有场景一律返回任务中断模板。
                // 后果：普通聊天时模型通道一抖（TLS 握手失败 / evomap 域名解析失败），
                // 聊天框就弹出「任务执行异常中断（第 N 步）…已完成步骤的产物…」，
                // 用户据此判断"系统在自动续跑我遗留的 agent_tasks"，实际只是这一次
                // 回复的模型调用没成功。故按场景分流：
                // - LRT 任务回合（request.lrtTaskId 非空，由 LrtHostExecutor 注入）：
                //   保留任务中断模板，产物/输出目录提示对它才有意义；
                // - 普通聊天：只说"本次回复失败"，不提任务、步骤、产物。
                let failMsg = if (request.lrtTaskId.isSome()) {
                    "任务执行异常中断（第 ${stepCount} 步）：${ex.message}。" +
                    "请查看 runtime 日志定位根因；已完成步骤的产物（如有）可在任务输出目录查看。"
                } else {
                    "本次回复失败：${ex.message}。请稍后重试；若持续失败请检查模型服务连通性（runtime 日志有记录）。"
                }
                return AsyncAgentResponse([failMsg].iterator(), execution: task.execution)
            } finally {
                task.end()
            }
        }
        return AsyncAgentResponse(FutureIteratorWrapper(task, fut), execution: task.execution)
    }
}
