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

import f_collection.*

public class DataTuples <: Iterator<(Data, Data)> & Data {
    public DataTuples(private let itr: Iterator<(Data, Data)>){}
    public func next(): ?(Data, Data) {
        itr.next()
    }
    public func toString(): String {
        let b = StringGenerator('{')
        for (d in this) {
            if (b.size > 1) {
                b.append(',')
            }
            b.append('${d[0]},${d[1]}')
        }
        b.append('}')
        b.toString()
    }
    public static func tryParse(s: String): ?Data {
        None<Data>
    }
    public static func parse(s: String): Data {
        throw DataParsableException('${s} cannot be parsed to ${TypeInfo.of<DataTuples>()}')
    }
}
public class DataMapIterator<K, V> <: Iterator<(Data, Data)> where K <: Equatable<K> & DataFields<K>, V <: DataFields<V> {
    public DataMapIterator(private let itr: Iterator<(K, V)>) {}
    public func next(): ?(Data, Data) {
        for ((k, v) in itr) {
            return (k.toData(), v.toData())
        }
        return None
    }
}

public struct DataMap<M, K, V> <: Data & Collection<(Data, Data)> where K <: Equatable<K> & DataFields<K>,
    V <: DataFields<V>, M <: DataFields<M> & Map<K, V> {
    public DataMap(public let data: M) {}
    public func iterator(): Iterator<(Data, Data)> {
        DataMapIterator<K, V>(data.iterator())
    }
    public prop size: Int64 {
        get() {
            data.size
        }
    }
    public func isEmpty(): Bool {
        data.isEmpty()
    }
    public func toString(): String {
        let b = StringGenerator('{')
        for (d in this) {
            if (b.size > 1) {
                b.append(',')
            }
            b.append('${d[0]},${d[1]}')
        }
        b.append('}')
        b.toString()
    }
    public static func tryParse(s: String): ?Data {
        None<Data>
    }
    public static func parse(s: String): Data {
        throw DataParsableException('${s} cannot be parsed to ${TypeInfo.of<DataMap<M, K, V>>()}')
    }
}

public interface MapRawType {
    prop rawType: (TypeInfo, TypeInfo)
}

public interface MapData<M, K, V> <: DataFields<M> & MapRawType where K <: Equatable<K> & DataFields<K>,
    V <: DataFields<V>, M <: DataFields<M> & Map<K, V> {
    func toData(): Data
    static func tryFromData(data: Data, flag: DataConversionFlag): Any
    prop rawType: (TypeInfo, TypeInfo) {
        get() {
            (TypeInfo.of<K>(), TypeInfo.of<V>())
        }
    }
}

private func tryFromDataToMap<M, K, V>(data: Data, flag: DataConversionFlag, creator: () -> M): M where K <: Equatable<K> & DataFields<K>,
    V <: DataFields<V>, M <: DataFields<M> & Map<K, V> {
    match (data) {
        case x: DataMap<M, K, V> where (flag & DEEP) == 0 => x.data
        case itr: Iterable<(Data, Data)> =>
            let map = creator()
            for ((dk, dv) in itr) {
                if (let (Some(k: K), Some(v: V)) <- (internal_f_data_tryFromData<K>(dk, flag),
                    internal_f_data_tryFromData<V>(dv, flag))) {
                    map[k] = v
                } else if ((flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0) {
                    throw DataException('data cannot be converted to tuple for ${TypeInfo.of<M>()} ')
                }
            }
            map
        case itr: Iterable<(String, Data)> =>
            let map = creator()
            for ((k, v) in itr) {
                match (k) {
                    case mk: K =>
                        if (let Some(mv: V) <- internal_f_data_tryFromData<V>(v, flag)) {
                            map[mk] = mv
                        } else if ((flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0) {
                            throw DataException(
                                'data cannot be converted to tuple for ${TypeInfo.of<M>()}, current tuple is (${k}, ${v})')
                        }
                    case _ =>
                        if (let (Some(mk: K), Some(mv: V)) <- (internal_f_data_tryFromData<K>(k.toData(), flag),
                            internal_f_data_tryFromData<V>(v, flag))) {
                            map[mk] = mv
                        } else if ((flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0) {
                            throw DataException(
                                'data cannot be converted to tuple for ${TypeInfo.of<M>()}, current tuple is (${k}, ${v})')
                        }
                }
            }
            map
        case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
            'data cannot be converted to tuple for ${TypeInfo.of<M>()}, data is ${data}')
        case _ => creator()
    }
}

extend<K, V> HashMap<K, V> <: MapData<HashMap<K, V>, K, V> where K <: Equatable<K> & DataFields<K>, V <: DataFields<V> {
    public func toData(): Data {
        DataMap(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        tryFromDataToMap<HashMap<K, V>, K, V>(data, flag) {HashMap<K, V>()}
    }
}

extend<K, V> LinkedHashMap<K, V> <: MapData<LinkedHashMap<K, V>, K, V> where K <: Equatable<K> & DataFields<K>,
    V <: DataFields<V> {
    public func toData(): Data {
        DataMap(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        tryFromDataToMap<LinkedHashMap<K, V>, K, V>(data, flag) {LinkedHashMap<K, V>()}
    }
}

extend<K, V> TreeMap<K, V> <: MapData<TreeMap<K, V>, K, V> where K <: Equatable<K> & DataFields<K>, V <: DataFields<V> {
    public func toData(): Data {
        DataMap(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        tryFromDataToMap<TreeMap<K, V>, K, V>(data, flag) {TreeMap<K, V>()}
    }
}
