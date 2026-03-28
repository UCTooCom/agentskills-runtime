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

import std.collection.concurrent.{ConcurrentHashMap, ConcurrentMap}

public class DataConcurrentMapIterator<K, V> <: Iterator<(Data, Data)> where K <: Hashable & Equatable<K> & DataFields<K>,
    V <: DataFields<V> {
    public DataConcurrentMapIterator(private let itr: Iterator<(K, V)>) {}
    public func next(): ?(Data, Data) {
        for ((k, v) in itr) {
            return (k.toData(), v.toData())
        }
        return None
    }
}

public class DataConcurrentMap<M, K, V> <: Data & Collection<(Data, Data)> where K <: Hashable & Equatable<K> & DataFields<K>,
    V <: DataFields<V>, M <: DataFields<M> & ConcurrentMap<K, V> & Collection<(K, V)> {
    public DataConcurrentMap(public let data: M) {}
    public func iterator(): Iterator<(Data, Data)> {
        DataConcurrentMapIterator<K, V>(data.iterator())
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
        throw DataParsableException('${s} cannot be parsed to ${TypeInfo.of<DataConcurrentMap<M, K, V>>()}')
    }
}

public interface ConcurrentMapData<M, K, V> <: DataFields<M> & MapRawType where K <: Equatable<K> & DataFields<K>,
    V <: DataFields<V>, M <: DataFields<M> & ConcurrentMap<K, V> {
    func toData(): Data
    static func tryFromData(data: Data, flag: DataConversionFlag): Any
    prop rawType: (TypeInfo, TypeInfo) {
        get() {
            (TypeInfo.of<K>(), TypeInfo.of<V>())
        }
    }
}

extend<K, V> ConcurrentHashMap<K, V> <: ConcurrentMapData<ConcurrentHashMap<K, V>, K, V> where K <: Hashable & Equatable<K> & DataFields<K>,
    V <: DataFields<V> {
    public func toData(): Data {
        DataConcurrentMap(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case x: DataConcurrentMap<ConcurrentHashMap<K, V>, K, V> where (flag & DEEP) == 0 => x.data
            case itr: Iterable<(Data, Data)> =>
                let map = ConcurrentHashMap<K, V>()
                for ((dk, dv) in itr) {
                    if (let (Some(k: K), Some(v: V)) <- (internal_f_data_tryFromData<K>(dk, flag),
                        internal_f_data_tryFromData<V>(dv, flag))) {
                        map.add(k, v)
                    } else if ((flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0) {
                        throw DataException(
                            'data cannot be converted to tuple for ${TypeInfo.of<ConcurrentHashMap<K, V>>()} ')
                    }
                }
                map
            case itr: Iterable<(String, Data)> =>
                let map = ConcurrentHashMap<K, V>()
                for ((k, v) in itr) {
                    match (k) {
                        case mk: K =>
                            if (let Some(mv: V) <- internal_f_data_tryFromData<V>(v, flag)) {
                                map.add(mk, mv)
                            } else if ((flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0) {
                                throw DataException(
                                    'data cannot be converted to tuple for ${TypeInfo.of<ConcurrentHashMap<K, V>>()}, current tuple is (${k}, ${v})')
                            }
                        case _ =>
                            if (let (Some(mk: K), Some(mv: V)) <- (internal_f_data_tryFromData<K>(k.toData(), flag),
                                internal_f_data_tryFromData<V>(v, flag))) {
                                map.add(mk, mv)
                            } else if ((flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0) {
                                throw DataException(
                                    'data cannot be converted to tuple for ${TypeInfo.of<ConcurrentHashMap<K, V>>()}, current tuple is (${k}, ${v})')
                            }
                    }
                }
                map
            case _ where (flag & IGNORE_FIELD_TYPE_NOT_MATCH) == 0 => throw DataException(
                'data cannot be converted to tuple for ${TypeInfo.of<ConcurrentHashMap<K, V>>()}, data is ${data}')
            case _ => ConcurrentHashMap<K, V>()
        }
    }
}
