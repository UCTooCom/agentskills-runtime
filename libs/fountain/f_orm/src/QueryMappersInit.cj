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

public import std.time.DateTime
public import std.math.numeric.{Decimal, BigInt}
public import std.io.InputStream

public interface QueryMappersInit<T> where T <: QueryMappersInit<T> {
    static func tableName(): String
    static func isSimpleData(): Bool 
    static func queryMappers(): QueryMappers<T> 
}
public interface SimpleDataQueryMappersInit<T> <: QueryMappersInit<T> where T <: QueryMappersInit<T> {
    static func isSimpleData(): Bool {
        true
    }
    static func queryMappers(): QueryMappers<T> {
        throw ORMException("not supported")
    }
    static func tableName(): String {
        ''
    }
}

extend<T> Option<T> <: QueryMappersInit<T> where T <: QueryMappersInit<T> {
    public static func isSimpleData(): Bool {
        T.isSimpleData()
    }
    public static func queryMappers(): QueryMappers<T> {
        T.queryMappers()
    }
    public static func tableName(): String {
        T.tableName()
    }
}

extend Int8 <: SimpleDataQueryMappersInit<Int8> {}

extend UInt8 <: SimpleDataQueryMappersInit<UInt8> {}

extend Int16 <: SimpleDataQueryMappersInit<Int16> {}

extend UInt16 <: SimpleDataQueryMappersInit<UInt16> {}

extend Int32 <: SimpleDataQueryMappersInit<Int32> {}

extend UInt32 <: SimpleDataQueryMappersInit<UInt32> {}

extend Int64 <: SimpleDataQueryMappersInit<Int64> {}

extend UInt64 <: SimpleDataQueryMappersInit<UInt64> {}

extend Float16 <: SimpleDataQueryMappersInit<Float16> {}

extend Float32 <: SimpleDataQueryMappersInit<Float32> {}

extend Float64 <: SimpleDataQueryMappersInit<Float64> {}

extend Rune <: SimpleDataQueryMappersInit<Rune> {}

extend String <: SimpleDataQueryMappersInit<String> {}

extend Bool <: SimpleDataQueryMappersInit<Bool> {}

extend Duration <: SimpleDataQueryMappersInit<Duration> {}

extend DateTime <: SimpleDataQueryMappersInit<DateTime> {}

extend<T> Array<T> <: SimpleDataQueryMappersInit<Array<T>> where T <: QueryMappersInit<T> {}

extend Decimal <: SimpleDataQueryMappersInit<Decimal> {}
extend BigInt <: SimpleDataQueryMappersInit<BigInt> {}
