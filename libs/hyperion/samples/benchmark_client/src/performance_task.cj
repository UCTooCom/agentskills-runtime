/**
 * Copyright 2024 Beijing Baolande Software Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Runtime Library Exception to the Apache 2.0 License:
 *
 * As an exception, if you use this Software to compile your source code and
 * portions of this Software are embedded into the binary product as a result,
 * you may redistribute such product without providing attribution as would
 * otherwise be required by Sections 4(a), 4(b) and 4(d) of the License.
 */

package benchmark_client

/**
 * 压测任务封装
 * 
 * @author yangfuping
 */
public class PerformanceTask {
    static let indexGenerator = AtomicUInt64(0)

    let sessions: Array<Session>

    private let totalRequestCount: Int64

    private let executeNum: Int64

    private let message: String

    private let barrier: Barrier

    public init(
        sessions: Array<Session>,
        totalRequestCount: Int64,
        executeNum: Int64,
        message: String,
        barrier: Barrier
    ) {
        this.sessions = sessions
        this.totalRequestCount = totalRequestCount
        this.executeNum = executeNum
        this.message = message
        this.barrier = barrier
    }

    public func run() {
        // 等待所有线程一起执行
        barrier.wait()

        var i = 0
        while (TaskController.running.load() && (executeNum == -1 || i < executeNum)) {
            // 发送消息，并收取对应的响应
            let echoRequest = EchoRequest(TaskController.requestIdGenerator.fetchAdd(1), message)

            let session = sessions[nextIndex()]
            session.writeAndFlushMessage(echoRequest)

            try {
                let echoResponse = echoRequest.waitForResponse()

                if (TaskController.stopTime.load() == 0) {
                    let totalCount = TaskController.totalInvokeCount.fetchAdd(1)
                    if (totalCount + 1 >= totalRequestCount) {
                        // 设置停止时间
                        TaskController.stopTime.compareAndSwap(0, DateTime.now().toUnixTimeStamp().toMilliseconds());
                    }
                }
                i++
            } catch (ex: Exception) {
                ex.printStackTrace()
                break
            }
        }
    }

    @OverflowWrapping
    private func nextIndex(): Int64 {
        let index = indexGenerator.fetchAdd(1) % UInt64(sessions.size)
        return Int64(index)
    }
}
