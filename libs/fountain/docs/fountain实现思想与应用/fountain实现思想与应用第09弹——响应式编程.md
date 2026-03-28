# fountain实现思想与应用第八弹

##### ——响应式编程

## 什么是响应式编程

-   它是一种编程范式

    其核心思想是通过声明式的方式处理异步数据流，实现高并发、低延迟的系统响应能力。

-   面向数据流和变更

    将数据视为动态的“流”（Stream），所有操作（如过滤、转换、组合）围绕数据流展开。当数据源产生新事件或数据变化时，系统自动将变更传播至依赖组件。

-   基于观察者模式

    基于观察者模式，当数据流中的值发生变化时，相关观察者（订阅者）立即被通知并触发响应逻辑，无需手动管理状态同步。

## 核心特性

-   声明式

    开发者只需定义“做什么”（如数据转换规则），而非“如何做”，代码更简洁且易维护。

-   异步非阻塞

    通过事件驱动和回调机制处理I/O操作，避免线程阻塞，显著提升资源利用率和系统吞吐量，尤其适合高并发场景（如API网关、实时数据处理）。

-   背压管理

    当数据生产速度超过消费能力时，自动反向通知生产者调整速率，防止系统过载或内存溢出

## 初始化函数

1.  接收一个`Iterable<T>`实例

    ```
    let iterable: Iterable<Int64> = [1, 2, 3]
    let observable = Observable<Int64>.iterable(iterable)
    ```

2.  接收一个`()->Iterable<T>`实例

    ```
    let iterable: ()->Iterable<Int64> = {=>[1, 2, 3]}
    let observable = Observable<Int64>.iterable(iterable)
    ```

3.  接收一个`()->Future<Iterable<T>>`实例

    ```
    let iterable = {=>spawn{[1, 2, 3]}}
    let observable = Observable<Int64>.iterable(iterable)
    ```

4.  接收一个`Future<Iterable<T>>`实例

    ```
    let future = spawn{[1, 2, 3]}
    let observable = Observable<Int64>.iterable(future)
    ```

5.  接收一个`()->Iterable<Future<T>>`实例

    ```
    let futures = {=> [spawn{1},spawn{2},spawn{3}]}
    let observable = Observable<Int64>.iterable(futures)
    ```

6.  接收单值`T`

    ```
    let single = 1
    let observable = Observable<Int64>.single(single)
    ```

7.  接收返回单值的闭包`()->T`

    ```
    let single = {=>1}
    let observable = Observable<Int64>.single(single)
    ```

8.  接收返回单值的`Future<T>`

    ```
    let single = spawn{1}
    let observable = Observable<Int64>.single(single)
    ```

9.  接收返回单值的`()->Future<T>`

    ```
    let single = {=>spawn{1}}
    let observable = Observable<Int64>.single(single)
    ```

10.  接收`?T`

     ```
     let single = Some(1)
     let observable = Observable<Int64>.maybe(single)
     ```

11.  接收`()->?T`

     ```
     let single = {=>Some(1)}
     let observable = Observable<Int64>.maybe(single)
     ```

12.  接收返回单值的`Future<?T>`

     ```
     let single = spawn{Some(1)}
     let observable = Observable<Int64>.maybe(single)
     ```

13.  接收返回单值的`()->Future<?T>`

     ```
     let single = {=>spawn{Some(1)}}
     let observable = Observable<Int64>.maybe(single)
     ```

14.  接收一个数据发射器

     ```
     let observable = Observable<Int64>.emitter({emitter => 
        emitter.onNext(1)
        emitter.onNext(2)
        emitter.onNext(3)
        emitter.onComplete()//此后不再发送数据
     })
     ```

     emitter函数接收的闭包会被包装为`class Emitter<T>`，`Observable<T>`又把`Emitter<T>`包装为迭代器`EmitterIterator<T>`。`Observable<T>`首次调用`EmitterIterator<T>`的`next()`函数时，会启动新线程执行这个闭包，并把产生的推到`Emitter<T>`内部的阻塞队列。每次调用`next()`函数都会从这个阻塞队列获取数据。闭包返回以前务必调用`emitter.onComplete()`表示以后不再有新数据，此后再调用`next()`都会返回`None<T>`。

     具体实现如下：

     ```cj
     public class Emitter<T> {
         private let q: LinkedBlockingQueue<EmitterState<T>>
         private let end = AtomicBool(false)
         private var f = None<Future<Unit>>
         public Emitter(qsize!: Int64 = 1, private let fn!: (Emitter<T>) -> Unit) {
             q = LinkedBlockingQueue<EmitterState<T>>(qsize)
         }
     
         func next(): ?T {
             if(end.load()){
                 return None<T>
             }else if(f.isNone()){
                 f = spawn {
                     fn(this)
                 }
             }
             match(q.remove()){
                 case Data(d) => if(d.isNone()){
                     end.store(true)
                 }
                 d
                 case Ex(e) => throw e
             }
         }
         public func onNext(data: T) {
             q.add(Data(data))
         }
         public func onError(e: Exception) {
             q.add(Ex(e))
         }
         public func onComplete() {
             q.add(Data(None))
         }
     }
     ```

     

15.  空数据的被观察者

     只发送onComplete事件，没有onNext事件

     ```
     let observable = Observable<Int64>.empty()
     ```

16.  展开多个Iterable初始化被观察者

     ```
     let ob1 = Observable<Int64>.concat({=>[[1,2,3],[4,5,6],[7,8,9]]})
     let ob2 = Observable<Int64>.concat([[1,2,3],[4,5,6],[7,8,9]])
     let ob3 = Observable<Int64>.concat({=>spawn{[[1,2,3],[4,5,6],[7,8,9]]})
     let ob4 = Observable<Int64>.concat(spawn{[[1,2,3],[4,5,6],[7,8,9]]})
     ```

## 注册观察者

```
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
```

```
observable.subscribe('test',FuncObserver<Int64>.setNextFunc{v => println(v)})
          .subscribe('test2', {o => o.setNextFunc{v => println(v * 2)}})
```

从这段代码可以看出来一个被观察者可以注册多个观察者。

## 回放数据

启动被观察者后，如果注册新的观察者则向新观察者重放已发送的数据数量，默认是0。

重放策略是因为内部维持着一个`LinkedList`，并有`Mutex`实例确保并发安全。

-   `replaySize(capacity!: Int64 = 0)`

## 执行策略

执行策略指的是指行观察者的方式

-   总是用当前线程执行观察者

```
observer.withCurrent()
```

观察者和产生数据的线程是同一个线程

-   总是用新线程执行观察者

```
observer.withAlwaysNew()
```

每次产生的新数据总是用新线程执行观察者

-   所有的观察者总是固定用一个线程执行观察者

```
observer.withSingle()
```

执行观察者的线程跟被观察者的线程不同，并且所有的观察者处理每条数据都使用一个固定的线程执行。

到达执行器的任务数达到任务队列限制时触发背压策略：

```cj
private func schedule(state: SingleSchedulerState<T>): Unit {
	if (queue.size < queue.capacity) {
		queue.add(state)
	} else {
		policy.schedule(state)
	}
}
```

单线程执行器与后面的多线程执行器深度耦合，多线程执行器完全依赖单线程执行器完成功能。执行器自身任务队列空闲时会从其他执行器的任务队列盗窃任务：

```cj
while (toSteal && this.queue.size == 0 && let Some(w) <- wrapper) {//wrapping是多线程执行器Option<FiexedScheduler>
	//this.queue.size == 0 表示当前执行器自身任务队列已空
	let queues = w.queues//得到所有单线程执行器
    let qsize = queues.size
    var stolen = 0
    for (i in 1..qsize) {
	    if (let Some(state) <- queues[(index + i) % qsize].queue.tryRemove()) {//盗窃任务，index是当前执行器的索引
	    //(index + i) % qsize会忽略当前执行器
    		stolen++
        	if (!exec(state, true)) {//执行盗窃的任务，state是盗窃的任务，true表示当前数据是盗窃的
        		toSteal = false
            	break
        	}
    	}
    	if (this.queue.size > 0) {
    		break
    	}
	}
	if (stolen == 0) {
		break
	}
	stolen = 0
}
```

在多线程模式中，单线程执行器判定后面不再有数据会向所有执行器发送毒丸：

```cj
case Item(item) => match (item) {
	case Some(v) => this.observer.onNext(v)
    case _ =>//Item的参数类型是Item(?T)，item是None表示数据发生器已经完成，后面不再有数据
    	if (let Some(w) <- wrapper) {
        	let queues = w.queues
            let qsize = queues.size
            let counter = SyncCounter(qsize)
            for (ss in queues) {//向其他执行器发送毒丸，也会向自己发送一颗毒丸
            	ss.queue.add(Poison(counter, ss, index))//index是发送毒丸的执行器索引
            	//ss.schedule会触发背压策略，所以不能使用ss.schedule代替ss.queue.add，毒丸必须发送成功
            }
        } else {
        this.observer.onComplete() //当前是单线程调度器立即结束
        return false
    }
}
```

如果毒丸是偷来的，要立即归还：

```cj
case Poison(c, ss, idx) where steal =>
	ss.queue.add(Poison(c, ss, idx))
    return false
```

服下自己的毒丸：

```cj
case Poison(c, _, idx) =>
	c.dec()//执行器计数器减1
    if (idx == this.index) {//判定为true说明毒丸是当前执行器发出的，否则立即结束
    	c.waitUntilZero()//等待计数器减到0，说明所有执行器都结束了
        this.observer.onComplete()//执行观察者完成事件
    }
return false
```

-   使用固定数的线程执行观察者

```
let threads = 10
observer.withFixed(threads)
```

执行观察者的线程跟被观察者的线程不同，并且每个数据在指定数量的线程之间轮换执行

-   观察者执行器使用指定数量的单线程执行器
    -   每个任务轮询分配到各个单线程执行器

-   并行执行每个观察者

    以上每一个初始化方式都有一个命名参数`asyncCombined!: Bool = false`

    每个数据经过执行策略后，如果此参数是`true`，每个观察者会为每个数据启动新线程。

## 背压策略

背压策略指的是异步队列满时的数据处理策略。

可在指定执行策略时同时指定背压策略，默认是当前线程

-   直接丢弃（Discarding）
-   丢弃队列中最早的数据（ToDropOldest）
-   一直阻塞（AlwaysBlocking）
-   立即抛出异常（Throwing）
-   当前线程（Current）
-   新线程（NewThread）
-   使用指定函数（Action((() -> Unit) -> Unit)）
-   限流策略（RateLimited）
    -   可以指定当前支持的限流算法作为背压策略
    -   被限流的任务也可以指定另一个背压策略作为丢弃策略



## 错误恢复器

产生数据，以及观察者与生产者在同一线程时，如果发生错误会执行错误恢复函数。

此函数返回一个Iterable实例，Observable实例会使用这个Iterable和当前Observable的其它成员创建新的Observable。

创建的新Observable会启动新线程延迟启动。

-   `setErrorResumer(resumer: (Exception) -> ?Iterable<T>)`

    resumer如果返回了None就不会创建新的Observable

-   `setErrorResumer(resumer: (Exception) -> Unit)`

    执行这个恢复器后会使用当前的Observable全部成员创建新的Observable

## 暂停

`pause(completion!: Bool = false)`

暂停后，参数决定是否向观察者发送完成事件

## 取消观察者

如果所有观察者都取消了，数据发生器也会停止，直到注册新的观察者并重新调用启动函数后才会继续发生新数据

-   `disposeAll(completion!: Bool = false)`

    取消全部观察者，参数决定是否向被取消的观察者发送完成事件

-   `dispose(name: String, completion!: Bool = false)`

    取消指定名称的观察者

-   `dispose<O>(name: String, observer: O, completion!: Bool = false): Unit where O <: Object & Observer<T>`

    取消指定名称的观察者，如果注册的观察者与指定的观察者实例不是同一个就什么也不做

-   `dispose<O>(observer: O, completion!: Bool = false): Unit where O <: Object & Observer<T>`

    取消与指定观察者同一实例的观察者

-   `dispose<O>(completion!: Bool = false): Unit where O <: Observer<T>`

    取消指定类型的观察者，同一类型的观察者都会被取消

## 启动

-   `delay(Duration)`

    使用Timer，延迟指定时间后启动

-   `defer()`

    启动新线程零延迟执行

-   immediately()

    立即启动，使用当前线程，即与数据发生器在同一线程