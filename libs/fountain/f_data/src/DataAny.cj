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

public struct DataAny <: DataFields<DataAny> & Data {
    public DataAny(public let data: Data){}
    public func toString(): String {
        this.data.toString()
    }
    public static func tryParse(data: String): ?Data {
        data.toData()
    }
    public static func parse(data: String): Data {
        data.toData()
    }
    public func toData(): Data {
        data
    }
    public static func tryFromData(data: Data, _: DataConversionFlag): Any {
        tryFromData(data)
    }
    public static func tryFromData(data: Data): Any {
        if(let any: DataAny <- data){
            any
        }else{
            DataAny(data)
        }
    }
    public static func fromData(data: Data, _: DataConversionFlag): Any {
        fromData(data)
    }
    public static func fromData(data: Data){
        tryFromData(data)
    }
}
private func convertForMap<V>(value: ?DataAny): ?V where V <: DataFields<V> {
    match(value){
        case Some(x) => match(V.tryFromData(x.data)){
            case x: ?V => x
            case x: V => x
            case _ => None<V>
        }
        case _ => None<V>
    }
}
public interface DataAnyMap<K> where K <: DataFields<K> {
    func add(key: K, value: DataAny): ?DataAny
    func get(key: K): ?DataAny
    
    public func addData<V>(key: K, value: V): ?V where V <: DataFields<V> {
        convertForMap<V>(add(key, DataAny(value.toData())))
    }
    func getData<V>(key: K): ?V where V <: DataFields<V> {
        convertForMap<V>(get(key))
    }
}
public interface DataAnyList {
    func getData<T>(index: Int64): T where T <: DataFields<T>
    func addData<T>(value: T): Unit where T <: DataFields<T>
}
extend<K> HashMap<K, DataAny> <: DataAnyMap<K> where K <: DataFields<K> & Hashable & Equatable<K> {}
extend<K> TreeMap<K, DataAny> <: DataAnyMap<K> where K <: DataFields<K> & Comparable<K> {}
extend<K> LinkedHashMap<K, DataAny> <: DataAnyMap<K> where K <: DataFields<K> & Hashable & Equatable<K> {}
extend<K> ConcurrentHashMap<K, DataAny> <: DataAnyMap<K> where K <: DataFields<K> & Hashable & Equatable<K> {}
extend ArrayList<DataAny> <: DataAnyList {
    public func getData<T>(index: Int64): T where T <: DataFields<T> {
        match(T.fromData(this[index].data)){
            case x: ?T => x.getOrThrow()
            case x: T => x
            case x => throw DataException('${TypeInfo.of(x)} cannot be converted to ${TypeInfo.of<T>()}')
        }
    }
    public func addData<T>(value: T): Unit where T <: DataFields<T> {
        this.add(DataAny(value.toData()))
    }
}