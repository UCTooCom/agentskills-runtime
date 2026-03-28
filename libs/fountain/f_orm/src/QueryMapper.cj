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

import std.collection.{ArrayList, Map, HashMap, Set, List}
import f_base.OverSizeException
import f_exception.TypeCastException
import f_base.EmptyMap
import f_base.ExtendOption

/* 数据映射类型，把数据库里的值，读出来调用putter，把值填充到指定的对象，
 * 一个数据库列对应一个QueryMapper, 泛型O是要填充的对象类型
 * name: 列名
 * dataType: 列数据类型
 * putter: 第一个参数是当前要映射的实例，第二个参数是要填入的值，本函数会把第二个参数填入映射实例的对应成员。
 * @QueryMappersGenerator 会把公共实例成员变量和公共实例成员属性与数据表列映射
 */
public open class QueryMapper<O> {
    public QueryMapper(
        protected let dataType!: DataType = UnknownDataType(true, '', ''),
        protected let putter!: (O, Any) -> Unit
    ) {}

    protected func new<T>(): QueryMapper<T> {
        QueryMapper<T>(
            dataType: dataType,
            putter: {
                instance, value => putter((instance as O).getOrThrow(), value)
            }
        )
    }
    protected prop columnName: String {
        get(){
            dataType.columnName
        }
    }
    protected prop fieldName: String {
        get(){
            dataType.fieldName
        }
    }
    protected open prop isGrouped: Bool {
        get() {
            false
        }
    }
    protected open prop isId: Bool {
        get() {
            false
        }
    }

    public func get<T>(result: QueryResultWrap): ?T {
        match (dataType.get(result)) {
            case x: T => x
            case x: ?T => x
            case _ => None<T>
        }
    }
    public open func populate(result: QueryResultWrap, o: O): O {
        putter(o, dataType.get(result))
        o
    }
}

public open class FieldQueryMapper<T, O> <: QueryMapper<O> {
    public init(
        dataType!: DataType = UnknownDataType(true, '', ''),
        putter!: (O, T) -> Unit
    ) {
        super(dataType: dataType, putter: {o, v => 
            if(dataType.nullable){
                if(let Some(v) <- ORMConverter.convertNullable<T>(v)){
                    putter(o, v)
                }
            }else{
                putter(o, ORMConverter.convert<T>(v))
            }
        })
    }
    public open func populate(result: QueryResultWrap, o: O): O {
        if (let Some(id) <- super.get<T>(result)) {
            putter(o, id)
        }
        o
    }
}
