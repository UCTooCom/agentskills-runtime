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

import std.collection.ArrayList

public class GroupedQueryMapper<T, O> <: QueryMapper<O> {
    public GroupedQueryMapper(
        private let grouped!: QueryMappers<T>,
        private let groupedGetter!: (O) -> ArrayList<T>
    ) {
        super(putter: {o, v =>}, dataType: UnknownDataType(true, '', ''))
    }
    func newGrouped<SUB>(): QueryMapper<SUB> where SUB <: QueryMappersInit<SUB> {
        GroupedQueryMapper<T, SUB>(
            grouped: grouped,
            groupedGetter: {sub => groupedGetter((sub as O).getOrThrow())}
        )
    }
    protected prop isGrouped: Bool {
        get() {
            true
        }
    }
    public func populate(result: QueryResultWrap, o: O): O {
        let grouped = this.grouped.map(result)
        groupedGetter(o).add(grouped)
        o
    }
}

public class GroupedSingleQueryMapper<T, O> <: QueryMapper<O> {
    public GroupedSingleQueryMapper(
        private let name!: String,
        private let groupedGetter!: (O) -> ArrayList<T>
    ) {
        super(putter: {o, v =>}, dataType: UnknownDataType(false, name, ''))
    }
    func newGroupedSingle<SUB>(): QueryMapper<SUB> where SUB <: QueryMappersInit<SUB> {
        GroupedSingleQueryMapper<T, SUB>(
            name: name,
            groupedGetter: {sub => groupedGetter((sub as O).getOrThrow())}
        )
    }
    protected prop isGrouped: Bool {
        get() {
            true
        }
    }
    public func populate(result: QueryResultWrap, o: O): O {
        let list = groupedGetter(o)
        list.add(ORMConverter.convert<T>(result.getOrNull<T>(name)))
        o
    }
}

public class NullableGroupedQueryMapper<T, O> <: QueryMapper<O> {
    public NullableGroupedQueryMapper(
        private let ignoreNone!: Bool = true,
        private let grouped!: QueryMappers<T>,
        private let groupedGetter!: (O) -> ArrayList<Option<T>>
    ) {
        super(putter: {o, v =>}, dataType: UnknownDataType(true, '', ''))
    }
    func newNullableGrouped<SUB>(): QueryMapper<SUB> {
        NullableGroupedQueryMapper<T, SUB>(
            ignoreNone: ignoreNone,
            grouped: grouped,
            groupedGetter: {sub => groupedGetter((sub as O).getOrThrow())}
        )
    }
    protected prop isGrouped: Bool {
        get() {
            true
        }
    }
    public func populate(result: QueryResultWrap, o: O): O {
        let list = groupedGetter(o)
        let prevSize = list.size
        let mappers = grouped.mappers
        let groupedValue = grouped.creator()
        list.add(groupedValue)
        for (mapper in mappers) {
            let value = mapper.dataType.get(result)
            mapper.putter(groupedValue, value)
        }
        if (!ignoreNone && prevSize == list.size) {
            list.add(Option<T>.None)
        }
        o
    }
}
