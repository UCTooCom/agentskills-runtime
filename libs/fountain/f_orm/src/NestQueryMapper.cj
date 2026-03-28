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

public class NestQueryMapper<T, O> <: QueryMapper<O> where O <: QueryMappersInit<O>, T <: QueryMappersInit<T> {
    public NestQueryMapper(
        private let nested!: QueryMappers<T>,
        private let nestPutter!: (O, T) -> Unit
    ) {
        super(putter: {o, v =>}, dataType: UnknownDataType(true, '', ''))
    }
    func newNest<SUB>(): QueryMapper<SUB> where SUB <: QueryMappersInit<SUB> {
        NestQueryMapper<T, SUB>(
            nested: nested,
            nestPutter: {sub, nest => nestPutter((sub as O).getOrThrow(), nest)}
        )
    }
    public func populate(result: QueryResultWrap, o: O): O {
        let n = nested.map(result)
        nestPutter(o, n)
        o
    }
}

public class NullableNestQueryMapper<T, O> <: QueryMapper<O> {
    public NullableNestQueryMapper(
        private let nested!: QueryMappers<T>,
        private let nestGetter!: (O) -> Option<T>,
        private let nestPutter!: (O, T) -> Unit
    ) {
        super(putter: {o, v =>}, dataType: UnknownDataType(true, '', ''))
    }
    func newNullableNest<SUB>(): QueryMapper<SUB> {
        NullableNestQueryMapper<T, SUB>(
            nested: nested,
            nestGetter: {sub => nestGetter((sub as O).getOrThrow())},
            nestPutter: {sub, nest => nestPutter((sub as O).getOrThrow(), nest)}
        )
    }
    public func populate(result: QueryResultWrap, o: O): O {
        let n = nested.map(result)
        nestPutter(o, n)
        o
    }
}
