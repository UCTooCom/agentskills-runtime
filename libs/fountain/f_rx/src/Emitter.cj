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

enum EmitterState<T>{
    | Data(?T)
    | Ex(Exception)
}
/**
 * 务必确保调用on*(*)函数的线程跟调用next()函数的线程不是同一个
 */
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
class EmitterIterator<T> <: Iterator<T> {
    EmitterIterator(private let emitter: Emitter<T>) {}
    public func next(): ?T {
        emitter.next()
    }
}