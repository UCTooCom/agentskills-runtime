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
package f_orm.wrap

public abstract class DataType {
    public DataType(
        public let nullable: Bool,
        public let columnName: String,
        public let fieldName: String
    ) {}
    protected func getValue<T>(result: QueryResultWrap): Any {
        result.getOrNull<T>(columnName)
    }
    public func get(result: QueryResultWrap): Any
}

public class UnknownDataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<Any>(result)
    }
}

public class BoolDataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<Bool>(result)
    }
}

public class Int8DataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<Int8>(result)
    }
}

public class UInt8DataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<UInt8>(result)
    }
}

type ByteDataType = UInt8DataType

public class Int16DataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<Int16>(result)
    }
}

public class UInt16DataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<UInt16>(result)
    }
}

public class Int32DataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<Int32>(result)
    }
}

public class UInt32DataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<UInt32>(result)
    }
}

public class Int64DataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<Int64>(result)
    }
}
type IntDataType = Int64DataType
public class UInt64DataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<UInt64>(result)
    }
}
type UIntDataType = UInt64DataType
public class Float32DataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<Float32>(result)
    }
}
public class Float64DataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<Float64>(result)
    }
}
public class Float16DataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<Float16>(result)
    }
}

public class DecimalDataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<Decimal>(result)
    }
}

public class BigIntDataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<BigInt>(result)
    }
}

public class RuneDataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<Rune>(result)
    }
}

public class StringDataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<String>(result)
    }
}

public class InputStreamDataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<InputStream>(result)
    }
}

public class DurationDataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<Duration>(result)
    }
}

public class DateTimeDataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<DateTime>(result)
    }
}

public class ByteArrayDataType <: DataType {
    public init(nullable: Bool, columnName: String, fieldName: String) {
        super(nullable, columnName, fieldName)
    }
    public func get(result: QueryResultWrap): Any {
        getValue<Array<Byte>>(result)
    }
}
