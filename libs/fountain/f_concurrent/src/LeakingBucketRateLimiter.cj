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
 * 漏桶限流器
 */
public class LeakingBucketRateLimiter<T> <: RateLimiter<T> {
    private let bucket: ArrayBlockingQueue<(MonoTime, SyncCounter)>
    private let leaked = AtomicInt64(0)
    /**
     * @param timeout 任务等待时长
     * @param maxWaitings 允许等待的最大任务数
     * @param leakingPerDuration 每个漏桶周期漏下的任务数
     * @param leakingDuration 漏桶周期
     */
    public init(
        timeout!: Duration,
        maxWaitings!: Int64,
        leakingPerDuration!: Int64,
        leakingDuration!: Duration
    ) {
        super(timeout)
        if (leakingDuration <= Duration.Zero || leakingPerDuration <= 0 || maxWaitings <= 0) {
            throw RateLimiterException('all parameters must be larger than zero')
        }
        this.bucket = ArrayBlockingQueue<(MonoTime, SyncCounter)>(maxWaitings)
        let timer = Timer.after(Duration.Zero) {
            leaked.store(0)
            var end: MonoTime
            var next: Duration
            do {
                end = MonoTime.now() + leakingDuration
                while (leaked.load() < leakingPerDuration && let remainder <- end - MonoTime.now() && remainder > Duration
                        .Zero && let Some((d, c)) <- bucket.remove(remainder)) {
                    if (MonoTime.now() - d < timeout) { //这个条件不能合并到while循环条件，这个条件不论结果都得继续下次循环
                        c.dec()
                        leaked.fetchAdd(1)
                    }//当false，说明任务已经等待超时了
                }
                next = end - MonoTime.now()
            } while (next <= Duration.Zero)//当false说明当前周期内已经漏过指定数量的任务
            //如果桶空了，当前线程会阻塞剩余的周期时间
            next
        }
        atExit(timer.cancel)
    }
    public func exec(default: ?T, task: () -> ?T): ?T {
        let tag = SyncCounter(1)
        let start = MonoTime.now()
        if (bucket.add((start, tag), timeout) && let _ <- tag.waitUntilZero(timeout: start + timeout - MonoTime.now()) &&
            tag.count <= 0 && let Some(x) <- task()) {
            x
        } else {
            default
        }
    }
}
