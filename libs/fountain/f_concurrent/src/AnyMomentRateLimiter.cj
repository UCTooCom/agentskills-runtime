/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package f_concurrent

/**
 * 任意时刻限流器
 */
public class AnyMomentRateLimiter<T> <: RateLimiter<T> {
    private let queue: ArrayBlockingQueue<Unit>
    /**
     * @param maxTokens 任意时刻允许最多这么多任务并发执行
     * @param timeout 任务等待时长
     */
    public init(maxTokens!: Int64, timeout!: Duration) {
        super(timeout)
        queue = ArrayBlockingQueue<Unit>(maxTokens)
    }

    public func exec(default: ?T, task: () -> ?T): ?T {
        if (queue.add((), timeout)) {
            let result = try {
                task()
            } finally {
                queue.tryRemove()
            }
            if (let Some(x) <- result) {
                x
            } else {
                default
            }
        } else {
            default
        }
    }
}
