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
 * 背压策略决定发往观察者内部由多少线程处理数据
 * asyncCombined决定是一个线程执行全部观察者还是每个观察者一个线程
 */
public class Observable<T> {
    private var iterator = None<Iterator<T>>
    private Observable(private let items: () -> Iterator<T>, private let asyncCombined!: Bool = false,
        private let observer!: CombinedObserver<T> = CombinedObserver<T>(async: asyncCombined),
        private var errorResumer!: ?(Exception) -> ?Iterable<T> = None,
        private var scheduler!: Scheduler<T> = Scheduler<T>.current(observer),
        private let disposed_!: AtomicBool = AtomicBool(false),
        private let completionOnDisposing!: AtomicBool = AtomicBool(false),
        private var cache!: Cache<T> = EmptyCache<T>()) {
    }

    /**
     * 使用迭代器I构造被观察者
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func iterable<I>(items: () -> Future<I>, asyncCombined!: Bool = false): Observable<T> where I <: Iterable<T> {
        Observable<T>({=> items().get().iterator()}, asyncCombined: asyncCombined)
    }
    /**
     * 使用迭代器I构造被观察者
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func iterable<I>(items: Future<I>, asyncCombined!: Bool = false): Observable<T> where I <: Iterable<T> {
        iterable<I>({=> items}, asyncCombined: asyncCombined)
    }
    /**
     * 使用迭代器I构造被观察者
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func iterable<I>(items: () -> I, asyncCombined!: Bool = false): Observable<T> where I <: Iterable<T> {
        Observable<T>({=> items().iterator()}, asyncCombined: asyncCombined)
    }
    /**
     * 使用迭代器I构造被观察者
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func iterable<I>(items: I, asyncCombined!: Bool = false): Observable<T> where I <: Iterable<T> {
        iterable<I>({=> items}, asyncCombined: asyncCombined)
    }

    /**
     * 将每个Future的结果连接成一个迭代器
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func iterable(futures: () -> Iterable<Future<T>>, asyncCombined!: Bool = false): Observable<T> {
        iterable<Iterator<T>>({=> futures().iterator().map {f => f.get()}}, asyncCombined: asyncCombined)
    }
    /**
     * 将每个Future的结果连接成一个迭代器
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func iterable(futures: Iterable<Future<T>>, asyncCombined!: Bool = false): Observable<T> {
        iterable({=> futures}, asyncCombined: asyncCombined)
    }
    /**
     * 将每个Future的结果连接成一个迭代器
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func iterable(futures: () -> Array<Future<T>>, asyncCombined!: Bool = false): Observable<T> {
        let f: () -> Iterable<Future<T>> = {=> futures().iterator()}
        iterable(f, asyncCombined: asyncCombined)
    }
    /**
     * 将每个Future的结果连接成一个迭代器
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func iterable(futures: Array<Future<T>>, asyncCombined!: Bool = false): Observable<T> {
        let f: () -> Iterable<Future<T>> = {=> futures.iterator()}
        iterable(f, asyncCombined: asyncCombined)
    }
    /**
     * 使用数据发射器构造被观察者
     */
    public static func emitter(emit: (Emitter<T>) -> Unit, bufSize!: Int64 = 1, asyncCombined!: Bool = false): Observable<T> {
        iterable({
            => EmitterIterator<T>(Emitter<T>(qsize: bufSize, fn: emit))
        }, asyncCombined: asyncCombined)
    }

    /**
     * 只有一个数据的被观察者，iterator把item转化成迭代器
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func single(item: () -> Future<T>, iterator!: (T) -> Iterator<T> = {t => SingleIterator<T>(t)},
        asyncCombined!: Bool = false): Observable<T> {
        Observable<T>({=> item().get() |> iterator}, asyncCombined: asyncCombined)
    }
    /**
     * 只有一个数据的被观察者，iterator把item转化成迭代器
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func single(item: Future<T>, iterator!: (T) -> Iterator<T> = {t => SingleIterator<T>(t)},
        asyncCombined!: Bool = false): Observable<T> {
        single({=> item}, iterator: iterator, asyncCombined: asyncCombined)
    }
    /**
     * 只有一个数据的被观察者，iterator把item转化成迭代器
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func single(item: () -> T, iterator!: (T) -> Iterator<T> = {t => SingleIterator<T>(t)},
        asyncCombined!: Bool = false): Observable<T> {
        Observable<T>({=> item() |> iterator}, asyncCombined: asyncCombined)
    }
    /**
     * 只有一个数据的被观察者，iterator把item转化成迭代器
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func single(item: T, iterator!: (T) -> Iterator<T> = {t => SingleIterator<T>(t)},
        asyncCombined!: Bool = false): Observable<T> {
        single({=> item}, iterator: iterator, asyncCombined: asyncCombined)
    }

    /**
     * 只有一个数据的被观察者，iterator把item转化成迭代器
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func maybe(item: () -> Future<?T>, iterator!: (?T) -> Iterator<T> = {t => SingleIterator<T>(t)},
        asyncCombined!: Bool = false): Observable<T> {
        Observable<T>({=> item().get() |> iterator}, asyncCombined: asyncCombined)
    }
    /**
     * 只有一个数据的被观察者，iterator把item转化成迭代器
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func maybe(item: Future<?T>, iterator!: (?T) -> Iterator<T> = {t => SingleIterator<T>(t)},
        asyncCombined!: Bool = false): Observable<T> {
        maybe({=> item}, iterator: iterator, asyncCombined: asyncCombined)
    }
    /**
     * 只有一个数据的被观察者，iterator把item转化成迭代器
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func maybe(item: () -> ?T, iterator!: (?T) -> Iterator<T> = {t => SingleIterator<T>(t)},
        asyncCombined!: Bool = false): Observable<T> {
        Observable<T>({=> item() |> iterator}, asyncCombined: asyncCombined)
    }
    /**
     * 只有一个数据的被观察者，iterator把item转化成迭代器
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func maybe(item: ?T, iterator!: (?T) -> Iterator<T> = {t => SingleIterator<T>(t)},
        asyncCombined!: Bool = false): Observable<T> {
        maybe({=> item}, iterator: iterator, asyncCombined: asyncCombined)
    }

    /**
     * 创建空的被观察者，每个观察者只会执行一次onComplete()
     */
    public static func empty(asyncCombined!: Bool = false): Observable<T> {
        Observable<T>({=> EmptyIterator<T>()}, asyncCombined: asyncCombined)
    }

    /**
     * 把所有类型是I的迭代器连接成一个迭代器，
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func concat<I1, I2>(iterables: () -> I2, asyncCombined!: Bool = false): Observable<T> where I2 <: Iterable<I1>,
        I1 <: Iterable<T> {
        Observable<T>({=> iterables().iterator().flatMap {i => i.iterator()}}, asyncCombined: asyncCombined)
    }
    /**
     * 把所有类型是I的迭代器连接成一个迭代器，
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func concat<I1, I2>(iterables: I2, asyncCombined!: Bool = false): Observable<T> where I1 <: Iterable<T>,
        I2 <: Iterable<I1> {
        concat<I1, I2>({=> iterables}, asyncCombined: asyncCombined)
    }

    /**
     * 把所有类型是I的迭代器连接成一个迭代器，
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func concat<I1, I2>(iterables: () -> Future<I2>, asyncCombined!: Bool = false): Observable<T> where I2 <: Iterable<I1>,
        I1 <: Iterable<T> {
        concat<I1, I2>({=> iterables().get()}, asyncCombined: asyncCombined)
    }
    /**
     * 把所有类型是I的迭代器连接成一个迭代器，
     * asyncCombined决定是否异步执行每个观察者，false：单线程执行所有观察者，true：每个观察者对应一个线程；观察者接收到的数据是否启用新线程由背压策略决定
     */
    public static func concat<I1, I2>(iterables: Future<I2>, asyncCombined!: Bool = false): Observable<T> where I1 <: Iterable<T>,
        I2 <: Iterable<I1> {
        concat<I1, I2>({=> iterables}, asyncCombined: asyncCombined)
    }
    private func replayCached(observer: Observer<T>, fn: () -> Unit): Unit {
        cache.replay(observer, fn)
    }
    /**
     * 添加一个FuncObserver<T>，name是观察者名称，creator接收刚添加的观察者实例，可在此闭包内对观察者做修改
     */
    public func subscribe(name: String, creator: (FuncObserver<T>) -> Unit): This {
        let ob = FuncObserver<T>(name)
        creator(ob)
        replayCached(ob) {
            this.observer.add(name, ob)
        }
        disposed_.store(false)
        this
    }
    /**
     * 订阅观察者
     */
    public func subscribe(observer: Observer<T>): This {
        replayCached(observer) {
            this.observer.add(observer)
        }
        disposed_.store(false)
        this
    }
    /**
     * 订阅一个观察者，name是观察者名称
     */
    public func subscribe(name: String, observer: Observer<T>): This {
        replayCached(observer) {
            this.observer.add(name, observer)
        }
        disposed_.store(false)
        this
    }
    /**
     * 总是用当前线程执行观察者
     */
    public func withCurrent(): This {
        this.scheduler = Scheduler<T>.current(this.observer)
        this
    }
    /**
     * 总是用新线程执行观察者
     */
    public func withAlwaysNew(): This {
        this.scheduler = Scheduler<T>.alwaysNew(this.observer)
        this
    }
    /**
     * 单线程执行观察者，policy是背压策略，观察者队列上限是queueSize
     */
    public func withSingle(queueSize: Int64, policy!: BackPressure<T> = CurrentThread<T>()): This {
        this.scheduler = Scheduler<T>.single(this.observer, queueSize, policy: policy)
        this
    }
    /**
     * 单线程执行观察者，policy是背压策略，观察者队列上限是Int64.Max
     */
    public func withSingle(policy!: BackPressure<T> = CurrentThread<T>()): This {
        this.scheduler = Scheduler<T>.single(this.observer, policy: policy)
        this
    }
    /**
     * 指定threads数量的线程执行观察者，policy是背压策略
     */
    public func withFixed(threads: Int64, policy!: BackPressure<T> = CurrentThread<T>()): This {
        this.scheduler = Scheduler<T>.fixed(this.observer, threads, policy: policy)
        this
    }
    /**
     * 指定threads数量的线程执行观察者，观察者队列容量是queueSize，policy是观察者背压策略
     */
    public func withFixed(threads: Int64, queueSize: Int64, policy!: BackPressure<T> = CurrentThread<T>()): This {
        this.scheduler = Scheduler<T>.fixed(this.observer, threads, queueSize, policy: policy)
        this
    }
    /**
     * 指定重放大小
     */
    public func replaySize(capacity!: Int64 = 0): This {
        this.cache = if (capacity <= 0) {
            EmptyCache<T>()
        } else {
            QueuedCache<T>(capacity)
        }
        this
    }
    private func setErrorResumer(resumer: (Exception) -> ?Iterable<T>): This {
        this.errorResumer = resumer
        this
    }
    /**
     * 指定错误恢复器，产生或消费数据时如果抛出异常将执行当前指定的恢复器，并使用恢复器返回的迭代器和当前Observable的成员创建新的Observable
     * 多次调用本函数及其重载函数只有最后一个恢复器生效。
     */
    public func setErrorResumer(resumeIfNone: Bool, resumer: (Exception) -> ?Iterable<T>): This {
        this.errorResumer = {
            e => return if (let Some(i) <- resumer(e)) {
                i.iterator()
            } else if (resumeIfNone) {
                EmptyIterator<T>()
            } else {
                None<Iterable<T>>
            }
        }
        this
    }
    /**
     * 指定错误恢复器，产生或消费数据时如果抛出异常将执行当前指定的恢复器，并使用恢复器返回的数据和当前Observable的成员创建新的Observable
     * 多次调用本函数及其重载函数只有最后一个恢复器第一次。
     */
    public func setErrorResumer(resumeIfNone: Bool, resumer: (Exception) -> ?T): This {
        setErrorResumer {
            e => return if (let Some(v) <- resumer(e)) {
                SingleIterator<T>(v)
            } else if (resumeIfNone) {
                EmptyIterator<T>()
            } else {
                None<Iterable<T>>
            }
        }
    }
    /**
     * 指定错误恢复器，产生或消费数据时如果抛出异常将执行当前指定的恢复器，并使用恢复器返回的数据和当前Observable的成员创建新的Observable
     * 多次调用本函数及其重载函数只有最后一个恢复器第一次。
     */
    public func setErrorResumer(resumeIfNone: Bool, bufSize!: Int64 = 1, resumer!: (Exception) -> ?(Emitter<T>) -> Unit): This {
        setErrorResumer {
            e => return if (let Some(e) <- resumer(e)) {
                EmitterIterator<T>(Emitter<T>(qsize: bufSize, fn: e))
            } else if (resumeIfNone) {
                EmptyIterator<T>()
            } else {
                None<Iterable<T>>
            }
        }
    }
    /**
     * 指定错误恢复器，产生或消费数据时如果抛出异常将执行当前指定的恢复器，并继续使用当前Observable的全部成员创建新的Observable
     * 多次调用本函数及其重载函数只有最后一个恢复器生效。
     * 如果resumeWithEmpty是true使用空迭代器恢复，否则使用当前迭代器恢复
     */
    public func setErrorResumer(resumeWithEmpty: Bool, resumer: (Exception) -> Unit): This {
        this.setErrorResumer {
            e =>
                resumer(e)
                if (resumeWithEmpty) {
                    EmptyIterator<T>()
                } else {
                    this.iterator.getOrThrow()
                }
        }
    }
    /**
     * 指定错误恢复器，产生或消费数据时如果抛出异常将执行当前指定的恢复器，如果闭包参数返回true会继续使用当前Observable的全部成员创建新的Observable
     * 多次调用本函数及其重载函数只有最后一个恢复器生效
     */
    public func setErrorResumer(resumeIfFalse: Bool, resumer: (Exception) -> Bool): This {
        this.setErrorResumer {
            e => if (resumer(e)) {
                this.iterator.getOrThrow()
            } else if (resumeIfFalse) {
                EmptyIterator<T>()
            } else {
                None<Iterable<T>>
            }
        }
    }
    /**
     * 判断是否取消
     */
    public prop isDisposed: Bool {
        get() {
            if (disposed_.load()) {
                if (completionOnDisposing.load()) {
                    scheduler.schedule(None<T>)
                }
                return true
            }
            false
        }
    }

    /**
     * 暂停执行，如果completion是true就向消费者发送完成事件
     * 只停止不清空观察者
     */
    public func pause(completion!: Bool = false): Unit {
        disposed_.store(true)
        completionOnDisposing.store(completion)
    }
    private func noObserver() {
        if (this.observer.size == 0) {
            disposed_.store(true)
        }
    }
    /**
     * 取消全部观察者
     */
    public func disposeAll(completion!: Bool = false): Unit {
        this.observer.clear(completion)
        disposed_.store(true)
    }
    /**
     * 取消指定名称的观察者
     */
    public func dispose(name: String, completion!: Bool = false): Unit {
        this.observer.remove(name, completion)
        noObserver()
    }
    /**
     * 取消指定名称的观察者，如果参数observer与已注册观察者不是同一实例会抛出异常
     */
    public func dispose<O>(name: String, observer: O, completion!: Bool = false): Unit where O <: Object & Observer<T> {
        this.observer.remove<O>(name, observer, completion)
        noObserver()
    }
    /**
     * 取消指定观察者，如果没有找到相同实例的观察者将什么也不做
     */
    public func dispose<O>(observer: O, completion!: Bool = false): Unit where O <: Object & Observer<T> {
        this.observer.remove<O>(observer, completion)
        noObserver()
    }
    /**
     * 取消指定类型的观察者
     */
    public func dispose<O>(completion!: Bool = false): Unit where O <: Observer<T> {
        observer.remove<O>(completion)
        noObserver()
    }
    /**
     *  当前线程执行
     */
    public func immediately(): Unit {
        try {
            if (isDisposed) {
                return
            }
            let itr = if (let Some(i) <- this.iterator) {
                i
            } else {
                let iterator = this.items()
                this.iterator = iterator
                iterator
            }
            while (!isDisposed && let Some(item) <- itr.next()) {
                this.cache.set(item)
                scheduler.schedule(item)
                if (isDisposed) {
                    return
                }
                if (observer.size == 0) {
                    noObserver()
                    return
                }
            }
            scheduler.schedule(None<T>)
        } catch (e: Exception) {
            scheduler.schedule(e)
            if (let Some(r) <- errorResumer && let Some(i) <- r(e)) {
                Observable<T>(
                    {=> i.iterator()},
                    asyncCombined: this.asyncCombined,
                    observer: this.observer,
                    errorResumer: this.errorResumer,
                    scheduler: this.scheduler,
                    disposed_: this.disposed_,
                    completionOnDisposing: this.completionOnDisposing,
                    cache: this.cache.new()
                ).defer()
            }
        }
    }
    /**
     * 延迟duration时长执行
     */
    public func delay(duration: Duration): This {
        Timer.once(duration, immediately)
        this
    }
    /**
     * 延迟0时长执行
     */
    public func defer(): This {
        delay(Duration.Zero)
    }
}

public class SingleIterator<T> <: Iterator<T> {
    public SingleIterator(private var item: ?T) {}

    public func next(): Option<T> {
        let r = item
        item = None<T>
        r
    }
}

public class EmptyIterator<T> <: Iterator<T> {
    public func next(): Option<T> {
        None
    }
}
