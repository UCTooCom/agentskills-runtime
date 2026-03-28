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
package f_data

import std.convert.Parsable

public interface ToDataFields <: ToData {
    static func dataFields(): ObjectFields
    func getDataFields(): ObjectFields {
        dataFields()
    }
}

public interface ObjectData<T> <: ToDataFields & DataFields<T> where T <: ObjectData<T> & DataFields<T> {
    static prop isSimple: Bool {
        get() {
            false
        }
    }
    static func tryFromData(data: Data, flag: DataConversionFlag): Any
}

class FieldIterator<T> <: Iterator<(String, Data)> where T <: DataFields<T> {
    public FieldIterator(private let data: T, private let itr: Iterator<ReadableField>) {}

    public func next(): ?(String, Data) {
        for (f in itr) {
            return (f.name, f.get(data))
        }
        None<(String, Data)>
    }
}

public interface SimpleDataObject <: Data {
    func iterator(): Iterator<(String, Data)>
    prop typeInfo: TypeInfo
    func getData(): Any
    func dataCreator(): () -> SimpleDataObject
    prop size: Int64
    func fields(): Iterator<ReadableField>
    func mutableFields(): Iterator<MutableField>
    func set(name: String, value: Data, flag: DataConversionFlag): Unit
    func set<V>(name: String, value: V, flag: DataConversionFlag): Unit where V <: DataFields<V> {
        set(name, value.toData(), flag)
    }
    func set<V>(name: String, value: V): Unit where V <: DataFields<V> {
        set(name, value.toData(), DEFAULT_DATA_FLAG)
    }
    func set(name: String, value: Data) {
        set(name, value, DEFAULT_DATA_FLAG)
    }
}

public class DataObject<T> <: SimpleDataObject & Collection<(String, Data)> & NamedData where T <: ObjectData<T> & DataFields<T> {
    public DataObject(public let data: T) {}
    public func getData(): Any {
        this.data
    }
    public prop size: Int64 {
        get() {
            T.dataFields().size
        }
    }
    public func annotations(name: String): Collection<Annotation> {
        if (let Some(p) <- TypeMemberInfos.instanceProperty<T>(name)) {
            p.annotations
        } else if (let Some(v) <- TypeMemberInfos.instanceVariable<T>(name)) {
            v.annotations
        } else {
            []
        }
    }
    public func annotation<A>(name: String): ?A where A <: Annotation {
        if (let Some(p) <- TypeMemberInfos.instanceProperty<T>(name)) {
            p.findAnnotation<A>()
        } else if (let Some(v) <- TypeMemberInfos.instanceVariable<T>(name)) {
            v.findAnnotation<A>()
        } else {
            None
        }
    }
    public func isEmpty() {
        size == 0
    }
    public func iterator(): Iterator<(String, Data)> {
        let fields = fields()
        FieldIterator<T>(data, fields)
    }
    public prop typeInfo: TypeInfo {
        get() {
            TypeInfo.of<T>()
        }
    }
    public func fields(): Iterator<ReadableField> {
        T.dataFields().iterator()
    }
    public func mutableFields(): Iterator<MutableField> {
        T.dataFields().mutableFields()
    }
    public operator func [](name: String): Data {
        get(name).getOrThrow {DataException('field ${name} is not found in ${TypeInfo.of<T>()}')}
    }
    public operator func [](name: String, value!: Data): Unit {
        set(name, value)
    }
    public func set(name: String, value: Data, flag: DataConversionFlag): Unit {
        match (T.dataFields().mutableField(name)) {
            case Some(f) where f.set(data, value, flag: flag) => ()
            case Some(_) where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                "source field ${name} in ${TypeInfo.of<T>()} connot be converted")
            case Some(_) => ()
            case _ where (flag & IGNORE_FIELD_NOT_FOUND) == 0 => throw DataException(
                "field name ${name} is not found from ${TypeInfo.of<T>()}")
            case _ => ()
        }
    }
    public func get(name: String): ?Data {
        T.dataFields().readableField(name)?.get(data)
    }
    public func get<V>(name: String, flag: DataConversionFlag): ?V where V <: DataFields<V> {
        match (get(name)) {
            case Some(x) => match (V.tryFromData(x, flag)) {
                case x: ?V => x
                case x: V => x
                case _ where (flag & IGNORE_FIELD_NOT_FOUND) == 0 => throw DataException(
                    'field ${name} is not found in ${TypeInfo.of<T>()}')
                case _ => None<V>
            }
            case _ where (flag & IGNORE_FIELD_NOT_FOUND) == 0 => throw DataException(
                'field ${name} is not found in ${TypeInfo.of<T>()}')
            case _ => None<V>
        }
    }
    public func toString(): String {
        match (data) {
            case x: ToString => x.toString()
            case x =>
                let s = StringGenerator()
                s.append("{")
                for ((k, v) in this) {
                    if (s.size > 1) {
                        s.append(",")
                    }
                    s.append('\"${k}\":${v}')
                }
                s.append("}")
                s.toString()
        }
    }
    public static func tryParse(string: String): ?Data {
        let typeInfo = TypeInfo.of<T>()
        if (typeInfo.isSubtypeOf(TypeInfo.of<Parsable<T>>())) {
            let data = (TypeMemberInfos
                .staticFunction(typeInfo, 'tryParse', [TypeInfo.of<String>()])?
                .apply(typeInfo, string))
                .getOrThrow()
            match (data) {
                case x: ?T => match (x) {
                    case Some(x) => DataObject<T>(x)
                    case _ => None<Data>
                }
                case _ => throw UnreachableException()
            }
        } else {
            None<Data>
        }
    }
    public static func parse(string: String): Data {
        tryParse(string).getOrThrow {DataException("current type ${TypeInfo.of<T>()} is not Parsable")}
    }

    public func dataCreator(): () -> SimpleDataObject {
        {
            => if (let o: T <- T.dataFields().create() && let x: SimpleDataObject <- o.toData()) {
                x
            } else {
                throw UnreachableException()
            }
        }
    }
    public static func populate(src: Data, target: T, flag!: DataConversionFlag = DEFAULT_DATA_FLAG): ?T {
        match (src) {
            case x: Iterable<(String, Data)> =>
                let targetData = DataObject<T>(target)
                for ((n, d) in x) {
                    targetData.set(n, d, flag)
                }
                target
            case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                "src cannot be converted to ${TypeInfo.of<T>()}")
            case _ => target
        }
    }
    public static func populate(src: Data, flag!: DataConversionFlag = DEFAULT_DATA_FLAG): ?T {
        if ((flag & DEEP) == 0 && let d: DataObject<T> <- src) {
            return d.data
        }
        populate(src, (T.dataFields().create() as T).getOrThrow(), flag: flag)
    }
    public static func populate<S>(src: S, flag!: DataConversionFlag = DEFAULT_DATA_FLAG): ?T where S <: ObjectData<S> {
        populate(DataObject<S>(src), flag: flag)
    }
    public static func populate<S>(src: S, target: T, flag!: DataConversionFlag = DEFAULT_DATA_FLAG): ?T where S <: ObjectData<S> {
        populate(DataObject<S>(src), target, flag: flag)
    }
    public static func populate<M, V>(src: M, flag!: DataConversionFlag = DEFAULT_DATA_FLAG): ?T where M <: Map<String, V> & DataFields<M>,
        V <: DataFields<V> {
        populate(src.toData(), flag: flag)
    }
    public static func populate<M, V>(src: M, target: T, flag!: DataConversionFlag = DEFAULT_DATA_FLAG): ?T where M <: Map<String,
    V> & DataFields<M>, V <: DataFields<V> {
        populate(src.toData(), target, flag: flag)
    }
    public static func populate<M, V>(src: T, map: M, flag!: DataConversionFlag = DEFAULT_DATA_FLAG): M where M <: Map<String,
    V>, V <: DataFields<V> {
        for ((k, v) in DataObject<T>(src)) {
            match (V.tryFromData(v, flag)) {
                case x: ?V => match (x) {
                    case Some(x) => map[k] = x
                    case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                        'field ${k} of ${TypeInfo.of<T>()} cannot be converted to ${TypeInfo.of<V>()}')
                    case _ => continue
                }
                case x: V => map[k] = x
                case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0 => throw DataException(
                    'field ${k} of ${TypeInfo.of<T>()} cannot be converted to ${TypeInfo.of<V>()}')
                case _ => continue
            }
        }
        map
    }
}
