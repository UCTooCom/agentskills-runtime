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
package f_orm

public class QueryResultIterator<T> <: Iterator<T> & Resource {
    QueryResultIterator(
        private let result: QueryResultWrap,
        private let mappers: QueryMappers<T>
    ) {}
    public func next(): ?T {
        mappers.doMap(result)
    }
    public func isClosed(): Bool {
        result.isClosed()
    }
    public func close(): Unit {
        result.close()
    }
}

public class SingleColumnIterator<T> <: Iterator<T> & Resource {
    SingleColumnIterator(
        private let result: QueryResultWrap,
        private let index!: Int64 = 0,
        private let column!: String = String.empty
    ) {}
    public func next(): ?T {
        if (column == String.empty) {
            if (result.next()) {
                result.getOrNull<T>(index)
            } else {
                throw ORMException("the first column does not match specified data type")
            }
        } else {
            if (result.next()) {
                result.getOrNull<T>(index)
            } else {
                throw ORMException("the first column does not match specified data type")
            }
        }
    }
    public func isClosed(): Bool {
        result.isClosed()
    }
    public func close(): Unit {
        result.close()
    }
}
