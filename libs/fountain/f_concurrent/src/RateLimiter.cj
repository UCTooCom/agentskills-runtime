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

abstract sealed class RateLimiter<T> {
    public RateLimiter(protected let timeout: Duration) {
        if (timeout <= Duration.Zero) {
            throw RateLimiterException('timeout must be greater than zero, but current is ${timeout}')
        }
    }
    public func exec(task: () -> ?T): ?T {
        exec(None<T>, task)
    }
    public func exec(default: ?T, task: () -> ?T): ?T
}

public class UnlimitedRateLimiter<T> <: RateLimiter<T> {
    // public static let INSTANCE = UnlimitedRateLimiter<T>()
    public init() {
        super(Duration.Max)
    }
    public func exec(_: ?T, task: () -> ?T): ?T {
        task()
    }
}
