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

public class SingleIterable<T> <: Iterable<T> {
    public SingleIterable(private let value: T) {}
    public func iterator(): Iterator<T> {
        SingleIterator<T>(value)
    }
}

public class SingleIterator<T> <: Iterator<T> {
    public SingleIterator(private var value: ?T) {}

    public func next(): Option<T> {
        let r = value
        value = None<T>
        r
    }
}
