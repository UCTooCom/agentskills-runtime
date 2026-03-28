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
package f_rx

import f_concurrent.{RateLimiter, AnyMomentRateLimiter, LeakingBucketRateLimiter, SlidingWindowRateLimiter, TokenBucketRateLimiter}

/**
 * limiter 是限流算法，policy是被限流算法命中时执行的策略，discardedPolicy是被限流算法丢弃时的背压策略
 */
public class RateLimited<T> <: BackPressure<T> {
    public RateLimited(scheduler: SingleScheduler<T>, 
        private let limiter: RateLimiter<Unit>,
        private let policy!: BackPressure<T> = CurrentThread<T>(),
        private let discardedPolicy!: BackPressure<T> = Discarding<T>()){
        super.scheduler = scheduler
        policy.scheduler = scheduler
        discardedPolicy.scheduler = scheduler
    }
    public init(limiter: RateLimiter<Unit>, policy!: BackPressure<T> = CurrentThread<T>(), discardedPolicy!: BackPressure<T> = Discarding<T>()){
        this.limiter = limiter
        this.policy = policy
        this.discardedPolicy = discardedPolicy
    }
    public static func tokenBucket(scheduler: SingleScheduler<T>, tokens!: Int64, timeout!: Duration, populationPeriod!: Duration, 
        policy!: BackPressure<T> = CurrentThread<T>(), discardedPolicy!: BackPressure<T> = Discarding<T>()) {
        RateLimited<T>(scheduler, TokenBucketRateLimiter<Unit>(tokens: tokens, timeout: timeout, populationPeriod: populationPeriod), policy: policy, discardedPolicy: discardedPolicy)
    }
    public static func tokenBucket(tokens!: Int64, timeout!: Duration, populationPeriod!: Duration, 
        policy!: BackPressure<T> = CurrentThread<T>(), discardedPolicy!: BackPressure<T> = Discarding<T>()){
        RateLimited<T>(TokenBucketRateLimiter<Unit>(tokens: tokens, timeout: timeout, populationPeriod: populationPeriod), policy: policy, discardedPolicy: discardedPolicy)
    }
    public static func slidingWindow(scheduler: SingleScheduler<T>, window!: Duration, timeout!: Duration, limit!: Int64, 
        policy!: BackPressure<T> = CurrentThread<T>(), discardedPolicy!: BackPressure<T> = Discarding<T>()){
        RateLimited<T>(scheduler, SlidingWindowRateLimiter<Unit>(window: window, timeout: timeout, limit: limit), policy: policy, discardedPolicy: discardedPolicy)
    }
    public static func slidingWindow(window!: Duration, timeout!: Duration, limit!: Int64, 
        policy!: BackPressure<T> = CurrentThread<T>(), discardedPolicy!: BackPressure<T> = Discarding<T>()){
        RateLimited<T>(SlidingWindowRateLimiter<Unit>(window: window, timeout: timeout, limit: limit), policy: policy, discardedPolicy: discardedPolicy)
    }
    public static func leakingBucket(scheduler: SingleScheduler<T>, timeout!: Duration, maxWaitings!: Int64, leakingPerDuration!: Int64, leakingDuration!: Duration, 
        policy!: BackPressure<T> = CurrentThread<T>(), discardedPolicy!: BackPressure<T> = Discarding<T>()){
        RateLimited<T>(scheduler, LeakingBucketRateLimiter<Unit>(timeout: timeout, maxWaitings: maxWaitings, leakingPerDuration: leakingPerDuration, leakingDuration: leakingDuration), policy: policy, discardedPolicy: discardedPolicy)
    }
    public static func leakingBucket(timeout!: Duration, maxWaitings!: Int64, leakingPerDuration!: Int64, leakingDuration!: Duration, 
        policy!: BackPressure<T> = CurrentThread<T>(), discardedPolicy!: BackPressure<T> = Discarding<T>()){
        RateLimited<T>(LeakingBucketRateLimiter<Unit>(timeout: timeout, maxWaitings: maxWaitings, leakingPerDuration: leakingPerDuration, leakingDuration: leakingDuration), policy: policy, discardedPolicy: discardedPolicy)
    }
    public static func anyMoment(scheduler: SingleScheduler<T>, maxTokens!: Int64, timeout!: Duration, 
        policy!: BackPressure<T> = CurrentThread<T>(), discardedPolicy!: BackPressure<T> = Discarding<T>()){
        RateLimited<T>(scheduler, AnyMomentRateLimiter<Unit>(maxTokens: maxTokens, timeout: timeout), policy: policy, discardedPolicy: discardedPolicy)
    }
    public static func anyMoment(maxTokens!: Int64, timeout!: Duration, 
        policy!: BackPressure<T> = CurrentThread<T>(), discardedPolicy!: BackPressure<T> = Discarding<T>()){
        RateLimited<T>(AnyMomentRateLimiter<Unit>(maxTokens: maxTokens, timeout: timeout), policy: policy, discardedPolicy: discardedPolicy)
    }
    
    protected func schedule(state: SingleSchedulerState<T>): Unit {
        let exe = limiter.exec{
            policy.schedule(state)
        }
        if(exe.isNone()){
            discardedPolicy.schedule(state)
        }
    }
    protected mut prop scheduler: SingleScheduler<T> {
        get(){
            super.scheduler
        }
        set(value){
            super.scheduler = value
            policy.scheduler = value
            discardedPolicy.scheduler = value
        }
    }
    protected func clone(): BackPressure<T> {
        let p = policy.clone()
        let dp = discardedPolicy.clone()
        let bp = RateLimited<T>(this.limiter, policy: p, discardedPolicy: dp)
        bp.scheduler_ = this.scheduler_
        p.scheduler_ = this.scheduler_
        dp.scheduler_ = this.scheduler_
        bp
    }
}