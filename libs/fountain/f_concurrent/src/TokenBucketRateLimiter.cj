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
 * 令牌桶限流器
 */
public class TokenBucketRateLimiter<T> <: RateLimiter<T> {
    private let tokens: LinkedBlockingQueue<Unit>
    public init(tokens!: Int64, timeout!: Duration, populationPeriod!: Duration) {
        super(timeout)
        if (tokens <= 0 || timeout <= Duration.Zero || populationPeriod <= Duration.Zero) {
            throw RateLimiterException('all parameters must be larger than zero')
        }
        this.tokens = LinkedBlockingQueue<Unit>(tokens)
        let timer = Timer.after(Duration.Zero) {
            var end: MonoTime
            var next: Duration
            do {
                end = MonoTime.now() + populationPeriod
                var i = 0
                while (i < tokens && this.tokens.size < tokens) {
                    this.tokens.add(())
                    i++
                }
                next = end - MonoTime.now()
            } while (next <= Duration.Zero)
            next
        }
        atExit(timer.cancel)
    }
    public func exec(default: ?T, task: () -> ?T): ?T {
        if (let Some(_) <- tokens.remove(timeout) && let Some(x) <- task()) {
            x
        } else {
            default
        }
    }
}
