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

public class DataCollectionIterator<T> <: Iterator<Data> where T <: DataFields<T> {
    public DataCollectionIterator(private let itr: Iterator<T>) {}
    public func next(): ?Data {
        itr.next()?.toData()
    }
}

public class DataCollection<C, T> <: Data & Collection<Data> where T <: DataFields<T>,
    C <: DataFields<C> & Collection<T> {
    public DataCollection(public let data: C) {}
    public func iterator(): Iterator<Data> {
        DataCollectionIterator<T>(data.iterator())
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
        let b = StringGenerator('[')
        for (d in data) {
            if (b.size > 1) {
                b.append(',')
            }
            b.append(d.toData().toString())
        }
        b.append(']')
        b.toString()
    }
    public static func tryParse(s: String): ?Data {
        None<Data>
    }
    public static func parse(s: String): Data {
        throw DataParsableException('${s} cannot be parsed to ${TypeInfo.of<DataCollection<C, T>>()}')
    }
}

public interface CollectionRawType {
    prop rawType: TypeInfo
}

public interface CollectionData<C, T> <: DataFields<C> & CollectionRawType where T <: DataFields<T>,
    C <: DataFields<C> & Collection<T> {
    func toData(): Data
    static func tryFromData(data: Data, flag: DataConversionFlag): Any
    prop rawType: TypeInfo {
        get() {
            TypeInfo.of<T>()
        }
    }
}

extend<T> Array<T> <: CollectionData<Array<T>, T> where T <: DataFields<T> {
    public func toData(): Data {
        DataCollection<Array<T>, T>(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case d: DataCollection<Array<T>, T> where (flag & DEEP) == 0 => d.data
            case itr: Iterable<Data> =>
                let list = ArrayList<T>()
                for (d in itr) {
                    if (let Some(x) <- internal_f_data_tryFromData<T>(d, flag)) {
                        list.add(x)
                    }
                }
                unsafe { list.getRawArray() }
            case _ =>
                if (let Some(x) <- internal_f_data_tryFromData<T>(data, flag)) {
                    Array<T>(1, repeat: x)
                } else {
                    Array<T>()
                }
        }
    }
}

extend<T> ArrayList<T> <: CollectionData<ArrayList<T>, T> where T <: DataFields<T> {
    public func toData(): Data {
        DataCollection<ArrayList<T>, T>(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case d: DataCollection<ArrayList<T>, T> where (flag & DEEP) == 0 => d.data
            case itr: Iterable<Data> =>
                let list = ArrayList<T>()
                for (d in itr) {
                    if (let Some(x) <- internal_f_data_tryFromData<T>(d, flag)) {
                        list.add(x)
                    }
                }
                list
            case _ =>
                if (let Some(x) <- internal_f_data_tryFromData<T>(data, flag)) {
                    let list = ArrayList<T>()
                    list.add(x)
                    list
                } else {
                    ArrayList<T>()
                }
        }
    }
}

extend<T> LinkedList<T> <: CollectionData<LinkedList<T>, T> where T <: DataFields<T> {
    public func toData(): Data {
        DataCollection<LinkedList<T>, T>(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case d: DataCollection<LinkedList<T>, T> where (flag & DEEP) == 0 => d.data
            case itr: Iterable<Data> =>
                let list = LinkedList<T>()
                for (d in itr) {
                    if (let Some(x) <- internal_f_data_tryFromData<T>(d, flag)) {
                        list.addLast(x)
                    }
                }
                list
            case _ =>
                if (let Some(x) <- internal_f_data_tryFromData<T>(data, flag)) {
                    let list = LinkedList<T>()
                    list.addLast(x)
                    list
                } else {
                    LinkedList<T>()
                }
        }
    }
}

extend<T> HashSet<T> <: CollectionData<HashSet<T>, T> where T <: Hashable & Equatable<T> & DataFields<T> {
    public func toData(): Data {
        DataCollection<HashSet<T>, T>(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case d: DataCollection<HashSet<T>, T> where (flag & DEEP) == 0 => d.data
            case itr: Iterable<Data> =>
                let set = HashSet<T>()
                for (d in itr) {
                    if (let Some(x) <- internal_f_data_tryFromData<T>(d, flag)) {
                        set.add(x)
                    }
                }
                set
            case _ =>
                if (let Some(x) <- internal_f_data_tryFromData<T>(data, flag)) {
                    let set = HashSet<T>()
                    set.add(x)
                    set
                } else {
                    HashSet<T>()
                }
        }
    }
}

extend<T> TreeSet<T> <: CollectionData<TreeSet<T>, T> where T <: Comparable<T> & DataFields<T> {
    public func toData(): Data {
        DataCollection<TreeSet<T>, T>(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case d: DataCollection<TreeSet<T>, T> where (flag & DEEP) == 0 => d.data
            case itr: Iterable<Data> =>
                let set = TreeSet<T>()
                for (d in itr) {
                    if (let Some(x) <- internal_f_data_tryFromData<T>(d, flag)) {
                        set.add(x)
                    }
                }
                set
            case _ =>
                if (let Some(x) <- internal_f_data_tryFromData<T>(data, flag)) {
                    let set = TreeSet<T>()
                    set.add(x)
                    set
                } else {
                    TreeSet<T>()
                }
        }
    }
}

extend<T> LinkedHashSet<T> <: CollectionData<LinkedHashSet<T>, T> where T <: Hashable & Equatable<T> & DataFields<T> {
    public func toData(): Data {
        DataCollection<LinkedHashSet<T>, T>(this)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        match (data) {
            case d: DataCollection<LinkedHashSet<T>, T> where (flag & DEEP) == 0 => d.data
            case itr: Iterable<Data> =>
                let set = LinkedHashSet<T>()
                for (d in itr) {
                    if (let Some(x) <- internal_f_data_tryFromData<T>(d, flag)) {
                        set.add(x)
                    }
                }
                set
            case _ =>
                if (let Some(x) <- internal_f_data_tryFromData<T>(data, flag)) {
                    let set = LinkedHashSet<T>()
                    set.add(x)
                    set
                } else {
                    LinkedHashSet<T>()
                }
        }
    }
}
public class DataIterable <: Data & Iterable<Data>{
    public DataIterable(private let list: Iterable<Data>){}
    public func iterator(): Iterator<Data>{
        list.iterator()
    }
    public static func tryParse(_: String): ?Data {
        throw DataException()
    }
    public static func parse(_: String): Data {
        throw DataException()
    }
    public func toString(): String {
        throw DataException()
    }
}