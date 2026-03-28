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
package f_base

public class PeekableIterator<T> <: Iterator<T> {
    private var peek_ = None<T>
    public PeekableIterator(private let itr: Iterator<T>){}

    public func next(): ?T {
        if(peek_.isSome()){
            let p = peek_
            peek_ = None<T>
            p
        }else{
            itr.next()
        }
    }
    public func peek(): ?T {
        if(peek_.isNone()){
            peek_ = itr.next()
        }
        peek_
    }
}
public interface Peekable<T>{
    func peekable(): PeekableIterator<T>
}
extend<T> Iterator<T> <: Peekable<T> {
    public func peekable() {
        PeekableIterator<T>(this)
    }
}