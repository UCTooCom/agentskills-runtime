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

public interface Observer<T> {
    /**
     * 处理数据
     */
    func onNext(item: T): Unit
    /**
     * 处理异常
     */
    func onError(ex: Exception): Unit 
    /**
     * 完成函数
     */
    func onComplete(): Unit
}
public type Single<T> = SingleIterator<T>
public class EmptyObserver<T> <: Observer<T> {
    public func onNext(_: T): Unit {}
    public func onError(_: Exception): Unit {}
    public func onComplete(): Unit {}
}
public class FuncObserver<T> <: Observer<T> {
    private var nextFunc: (T) -> Unit = {_ => }
    private var errorFunc: (Exception) -> Unit = {_ => }
    private var completeFunc: () -> Unit = { => }
    FuncObserver(let name: String){}
    public func onNext(item: T): Unit {
        try{
            nextFunc(item)
        }catch(e: Exception){
            onError(e)
        }
    }
    public func onError(ex: Exception): Unit {
        errorFunc(ex)
    }
    public func onComplete(): Unit {
        try{
            completeFunc()
        }catch(e: Exception){
            onError(e)
        }
    }
    /**
     * 注册数据处理函数
     */
    public func setNext(callee: (Single<T>) -> Unit): This {
        setNext{v => callee(Single<T>(v))}
    }
    /**
     * 注册数据处理函数
     */
    public func setNext(callee: (T) -> Unit): This {
        nextFunc = {v => callee(v)}
        this
    }
    /**
     * 注册异常处理函数
     */
    public func setError(callee: (Exception) -> Unit): This {
        errorFunc = callee
        this
    }
    /**
     * 注册完成函数
     */
    public func setComplete(callee: () -> Unit): This {
        completeFunc = callee
        this
    }
}

/**
 * 多个观察者的组合，async决定是所有观察者由一个线程执行，还是观察者跟线程一一对应
 */
public class CombinedObserver<T> <: Observer<T> {
    private let observers = ConcurrentHashMap<String, Observer<T>>()
    public CombinedObserver(private let async!: Bool = false){}

    public prop size: Int64 {
        get(){
            observers.size
        }
    }
    /**
     * 清除观察者，如果completion是true，每个观察者被清除时都向其发送完成事件
     */
    public func clear(completion: Bool){
        for((k, _) in observers) {
            remove(k, completion)
        }
    }
    /**
     * 添加观察者，name是观察者的名称
     */
    public func add(name: String, observer: FuncObserver<T>): Unit {
        addIfAbsent(name, observer)
    }
    /**
     * 添加观察者，使用observer的全限定名做观察者名称，
     * 如果如果试图注册FuncObserver<T>会抛出异常，如果同一类型的观察者重复注册会抛出异常
     */
    public func add(observer: Observer<T>): This{
        add(if(let ob: FuncObserver<T> <- observer){
            ob.name
        }else{
            TypeInfo.of(observer).qualifiedName
        }, observer)
        this
    }
    /**
     * 注册观察者
     * name是观察者名称，observer是注册的观察者
     */
    public func add(name: String, observer: Observer<T>): This {
        addIfAbsent(name, observer)
        this
    }
    private func addIfAbsent(name: String, observer: Observer<T>){
        if(observers.addIfAbsent(name, wrapAsyncIfNeed(observer)).isSome()){
            throw ObserverRegistrationException("observer ${name} already registered")
        }
    }
    private func wrapAsyncIfNeed(observer: Observer<T>) {
        if(async){
            match(observer){
                case x: AsyncObserver<T> => x
                case _ => AsyncObserver<T>(observer)
            }
        }else{
            match(observer){
                case x: AsyncObserver<T> => x.observer
                case _ => observer
            }
        }
    }
    private func unwrapAsync(observer: Observer<T>){
        match(observer){
            case x: AsyncObserver<T> => x.observer
            case _ => observer
        }
    }
    /**
     * 删除指定名称的观察者，如果completion是true向被清除的观察者发送完成事件
     */
    public func remove(name: String, completion: Bool): Unit {
        if(let Some(o) <- observers.remove(name) && completion){
            o.onComplete()
        }
    }
    /**
     * 删除指定名称的观察者且已注册观察者与参数observer是同一实例，如果不是同一实例会抛出异常，如果completion是true向被清除的观察者发送完成事件
     */
    public func remove<O>(name: String, observer: O, completion: Bool): Unit where O <: Object & Observer<T> {
        if(let Some(o) <- observers.get(name)){
            if(isSame(observer, o)){
                remove(name, completion)
            }else{
                throw ObserverRegistrationException("registered observer ${name} does not match current specified")
            }
        }
    }
    /**
     * 删除指定观察者，如果没有找到相同实例的观察者将什么也不做，如果completion是true向被清除的观察者发送完成事件
     */
    public func remove<O>(observer: O, completion: Bool): Unit where O <: Object & Observer<T> {
        for((n, o) in this.observers where isSame(observer, o)) {
            remove(n, completion)
            return;
        }
    }
    private func isSame<O>(observer: O, o: Observer<T>): Bool where O <: Object & Observer<T> {
        match((observer, unwrapAsync(o))){
            case (o1: Object, o2: Object) => refEq(o1, o2)
            case _ => false
        }
    }
    /**
     * 删除指定类型的观察者全部，如果completion是true向被清除的观察者发送完成事件
     */
    public func remove<O>(completion: Bool): Unit where O <: Observer<T> {
        for((n, o) in this.observers where o is O) {
            remove(n, completion)
        }
    }
    private func call(fn: (Observer<T>) -> Unit): Unit {
        for((_, o) in observers){
            fn(o)
        }
    }
    public func onNext(item: T): Unit {
        call{o => 
            try{
                o.onNext(item)
            }catch(e: Exception){
                onError(e)
            }
        }
    }
    public func onError(ex: Exception): Unit {
        call{o => o.onError(ex)}
    }
    public func onComplete(): Unit {
        call{o => 
            try{
                o.onComplete()
            }catch(e: Exception){
                onError(e)
            }
        }
    }
}
class AsyncObserver<T> <: Observer<T> {
    private let q = ArrayBlockingQueue<T>(1)
    private let e = AtomicOptionReference<Exception>()
    private let c = AtomicBool(false)
    AsyncObserver(let observer: Observer<T>){
        spawn{
            while(e.load().isNone() && !c.load() && let Some(d) <- q.remove(Duration.millisecond * 100)){
                observer.onNext(d)
            }
            while(let Some(d) <- q.tryRemove()){
                observer.onNext(d)
            }
            if(let Some(ex) <- e.load()){
                observer.onError(ex)
            }
            if(c.load()){
                observer.onComplete()
            }
        }
    }
    public func onNext(item: T): Unit {
        q.add(item)
    }
    public func onError(ex: Exception): Unit {
        e.store(ex)
    }
    public func onComplete(): Unit {
        c.store(true)
    }
}