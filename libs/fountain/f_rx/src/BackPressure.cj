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

/**
 * 背压策略
 */
public abstract class BackPressure<T> {
    var scheduler_: ?SingleScheduler<T> = None
    protected func schedule(state: SingleSchedulerState<T>): Unit
    protected func clone(): BackPressure<T>
    protected open mut prop scheduler: SingleScheduler<T> {
        get(){
            scheduler_.getOrThrow()
        }
        set(value){
            scheduler_ = value
        }
    }
}
/**
 * 丢弃当前数据
 */
public class Discarding<T> <: BackPressure<T> {
    public init(scheduler: SingleScheduler<T>){
        super.scheduler_ = scheduler
    }
    public init(){}
    protected func clone(): BackPressure<T> {
        let bp = Discarding<T>()
        bp.scheduler_ = this.scheduler_
        bp
    }
    protected func schedule(state: SingleSchedulerState<T>): Unit {}
}
/**
 * 丢弃最旧数据
 */
public class ToDropOldest<T> <: BackPressure<T> {
    public init(scheduler: SingleScheduler<T>){
        super.scheduler_ = scheduler
    }
    public init(){}
    protected func clone(): BackPressure<T> {
        let bp = ToDropOldest<T>()
        bp.scheduler_ = this.scheduler_
        bp
    }
    protected func schedule(state: SingleSchedulerState<T>): Unit {
        let s = scheduler
        s.tryRemove()
        s.add(state)
    }
}
/**
 * 一直阻塞
 */
public class AlwaysBlocking<T> <: BackPressure<T> {
    public init(scheduler: SingleScheduler<T>){
        super.scheduler = scheduler
    }
    public init(){}
    protected func clone(): BackPressure<T> {
        let bp = AlwaysBlocking<T>()
        bp.scheduler_ = this.scheduler_
        bp
    }
    protected func schedule(state: SingleSchedulerState<T>): Unit {
        scheduler.add(state)
    }
}
/**
 * 立即抛出异常
 */
public class Throwing<T> <: BackPressure<T> {
    public init(scheduler: SingleScheduler<T>){
        super.scheduler_ = scheduler
    }
    public init(){}
    protected func clone(): BackPressure<T> {
        let bp = Throwing<T>()
        bp.scheduler_ = this.scheduler_
        bp
    }
    protected func schedule(state: SingleSchedulerState<T>): Unit {
        throw FullSchedulerException()
    }
}
/**
 * 使用当前线程
 */
public class CurrentThread<T> <: BackPressure<T> {
    public init(scheduler: SingleScheduler<T>){
        super.scheduler = scheduler
    }
    public init(){}
    protected func clone(): BackPressure<T> {
        let bp = CurrentThread<T>()
        bp.scheduler_ = this.scheduler_
        bp
    }
    protected func schedule(state: SingleSchedulerState<T>): Unit {
        scheduler.doSchedule(state)
    }
}
/**
 * 使用新线程
 */
public class NewThread<T> <: BackPressure<T> {
    public init(scheduler: SingleScheduler<T>){
        super.scheduler = scheduler
    }
    public init(){}
    protected func clone(): BackPressure<T> {
        let bp = NewThread<T>()
        bp.scheduler_ = this.scheduler_
        bp
    }
    protected func schedule(state: SingleSchedulerState<T>): Unit {
        spawn{
            scheduler.doSchedule(state)
        }
    }
}
/**
 * 使用指定函数
 */
public class Action<T> <: BackPressure<T> {
    public Action(scheduler: SingleScheduler<T>, private let action: (() -> Unit) -> Unit){
        super.scheduler = scheduler
    }
    public init(action: (() -> Unit) -> Unit){
        this.action = action
    }
    protected func clone(): BackPressure<T> {
        let bp = Action<T>(action)
        bp.scheduler_ = this.scheduler_
        bp
    }
    protected func schedule(state: SingleSchedulerState<T>): Unit {
        action{
            scheduler.doSchedule(state)
        }
    }
}
/**
 * 阻塞指定时间后执行指定策略
 */
public class AfterBlocking<T> <: BackPressure<T> {
    public AfterBlocking(scheduler: SingleScheduler<T>, 
                         private let timeout: Duration,
                         private let then!: BackPressure<T> = Discarding<T>()){
        super.scheduler = scheduler
        this.then.scheduler = scheduler
    }
    public init(timeout: Duration, then!: BackPressure<T> = Discarding<T>()){
        this.timeout = timeout
        this.then = then
    }
    protected func clone(): BackPressure<T> {
        let bp = AfterBlocking<T>(timeout, then: then.clone())
        bp.scheduler_ = this.scheduler_
        bp
    }
    protected func schedule(state: SingleSchedulerState<T>): Unit {
        if(!scheduler.add(state, timeout)){
            then.schedule(state)
        }
    }
    protected mut prop scheduler: SingleScheduler<T> {
        get(){
            super.scheduler
        }
        set(value){
            super.scheduler = value
            then.scheduler = value
        }
    }
}
