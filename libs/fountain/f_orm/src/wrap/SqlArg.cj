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

public abstract class SqlArg <: Hashable & Equatable<SqlArg> & ToString {
    public SqlArg(protected let index: Int64) {}
    protected func setValue<T>(statement: Statement, value: Any): Unit {
        match (value) {
            case x: T => statement.set<T>(index, x)
            case x: Option<T> => match (x) {
                case Some(x) => statement.set<T>(index, x)
                case _ => statement.setNull(index)
            }
            case _ => SqlArgException(
                'sql index ${index}, requires ${TypeInfo.of<T>()}, actually ${TypeInfo.of(value)}')
        }
    }
    public func set(statement: Statement): Unit
    public static func new<T>(index: Int64, value: T): SqlArg {
        match (value) {
            case x: Bool => BoolSqlArg(index, x)
            case x: Int8 => Int8SqlArg(index, x)
            case x: UInt8 => UInt8SqlArg(index, x)
            case x: Int16 => Int16SqlArg(index, x)
            case x: UInt16 => UInt16SqlArg(index, x)
            case x: Int32 => Int32SqlArg(index, x)
            case x: UInt32 => UInt32SqlArg(index, x)
            case x: Int64 => Int64SqlArg(index, x)
            case x: UInt64 => UInt64SqlArg(index, x)
            case x: Float16 => Float16SqlArg(index, x)
            case x: Float32 => Float32SqlArg(index, x)
            case x: Float64 => Float64SqlArg(index, x)
            case x: Decimal => DecimalSqlArg(index, x)
            case x: BigInt => BigIntSqlArg(index, x)
            case x: Rune => RuneSqlArg(index, x)
            case x: String => StringSqlArg(index, x)
            case x: Duration => DurationSqlArg(index, x)
            case x: DateTime => DateTimeSqlArg(index, x)
            case x: Array<Byte> => ByteArraySqlArg(index, x)
            case x: InputStream => InputStreamSqlArg(index, x)
            case _ => throw SqlArgException('type of arg index ${index} which is ${TypeInfo.of<T>()} does not exist')
        }
    }

    protected func toString<T>(value: T): String where T <: ToString {
        '(${index}, ${TypeInfo.of<T>()}, ${value})'
    }
    protected var h = 0
    protected func hashCode<T>(value: T): Int64 where T <: Hashable {
        if (h == 0) {
            h = HashBuilder().append(index).append(TypeInfo.of<T>()).append(value).build()
        }
        h
    }
    protected func equals(other: SqlArg): Bool {
        this.hashCode() == other.hashCode() && this.index == other.index && ClassTypeInfo.of(this) == ClassTypeInfo.of(
            other)
    }
}

public class BoolSqlArg <: SqlArg {
    public BoolSqlArg(index: Int64, private let value: Bool) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<Bool>(statement, value)
    }
    public func toString() {
        toString(value)
    }
    public func hashCode() {
        hashCode(value)
    }
    public operator func ==(other: SqlArg): Bool {
        equals(other) && match (other) {
            case x: BoolSqlArg => refEq(this, other) ||  x.value == value
            case _ => false
        }
    }
}

public class Int8SqlArg <: SqlArg {
    public Int8SqlArg(index: Int64, private let value: Int8) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<Int8>(statement, value)
    }
    public func toString() {
        toString(value)
    }
    public func hashCode() {
        hashCode(value)
    }
    public operator func ==(other: SqlArg): Bool {
        equals(other) && match (other) {
            case x: Int8SqlArg => refEq(this, other) || x.value == value
            case _ => false
        }
    }
}

public class UInt8SqlArg <: SqlArg {
    public UInt8SqlArg(index: Int64, private let value: UInt8) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<UInt8>(statement, value)
    }
    public func toString() {
        toString(value)
    }
    public func hashCode() {
        hashCode(value)
    }
    public operator func ==(other: SqlArg): Bool {
        equals(other) && match (other) {
            case x: UInt8SqlArg => refEq(this, other) || x.value == value
            case _ => false
        }
    }
}

type ByteSqlArg = UInt8SqlArg

public class Int16SqlArg <: SqlArg {
    public Int16SqlArg(index: Int64, private let value: Int16) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<Int16>(statement, value)
    }
    public func toString() {
        toString(value)
    }
    public func hashCode() {
        hashCode(value)
    }
    public operator func ==(other: SqlArg): Bool {
        equals(other) && match (other) {
            case x: Int16SqlArg => refEq(this, other) || x.value == value
            case _ => false
        }
    }
}

public class UInt16SqlArg <: SqlArg {
    public UInt16SqlArg(index: Int64, private let value: UInt16) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<UInt16>(statement, value)
    }
    public func toString() {
        toString(value)
    }
    public func hashCode() {
        hashCode(value)
    }
    public operator func ==(other: SqlArg): Bool {
        equals(other) && match (other) {
            case x: UInt16SqlArg => refEq(this, other) || x.value == value
            case _ => false
        }
    }
}

public class Int32SqlArg <: SqlArg {
    public Int32SqlArg(index: Int64, private let value: Int32) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<Int32>(statement, value)
    }
    public func toString() {
        toString(value)
    }
    public func hashCode() {
        hashCode(value)
    }
    public operator func ==(other: SqlArg): Bool {
        equals(other) && match (other) {
            case x: Int32SqlArg => refEq(this, other) || x.value == value
            case _ => false
        }
    }
}

public class UInt32SqlArg <: SqlArg {
    public UInt32SqlArg(index: Int64, private let value: UInt32) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<UInt32>(statement, value)
    }
    public func toString() {
        toString(value)
    }
    public func hashCode() {
        hashCode(value)
    }
    public operator func ==(other: SqlArg): Bool {
        equals(other) && match (other) {
            case x: UInt32SqlArg => refEq(this, other) || x.value == value
            case _ => false
        }
    }
}

public class Int64SqlArg <: SqlArg {
    public Int64SqlArg(index: Int64, private let value: Int64) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<Int64>(statement, value)
    }
    public func toString() {
        toString(value)
    }
    public func hashCode() {
        hashCode(value)
    }
    public operator func ==(other: SqlArg): Bool {
        equals(other) && match (other) {
            case x: Int64SqlArg => refEq(this, other) || x.value == value
            case _ => false
        }
    }
}

public class UInt64SqlArg <: SqlArg {
    public UInt64SqlArg(index: Int64, private let value: UInt64) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<UInt64>(statement, value)
    }
    public func toString() {
        toString(value)
    }
    public func hashCode() {
        hashCode(value)
    }
    public operator func ==(other: SqlArg): Bool {
        equals(other) && match (other) {
            case x: UInt64SqlArg => refEq(this, other) || x.value == value
            case _ => false
        }
    }
}

public class Float16SqlArg <: SqlArg {
    public Float16SqlArg(index: Int64, let value: Float16) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<Float32>(statement, Float32(value))
    }
    public func toString() {
        toString(value)
    }
    public func hashCode() {
        hashCode(value)
    }
    public operator func ==(other: SqlArg): Bool {
        refEq(this, other) || (equals(other) && match (other) {
            case x: Float16SqlArg => x.value == value
            case x: Float32SqlArg => x.value == Float32(value)
            case x: Float64SqlArg => x.value == Float64(value)
            case x: DecimalSqlArg => x.value == Decimal(value)
            case _ => false
        })
    }
}

public class Float32SqlArg <: SqlArg {
    public Float32SqlArg(index: Int64, let value: Float32) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<Float64>(statement, value)
    }
    public func toString() {
        toString(value)
    }
    public func hashCode() {
        hashCode(value)
    }
    public operator func ==(other: SqlArg): Bool {
        refEq(this, other) || (equals(other) && match (other) {
            case x: Float16SqlArg => Float32(x.value) == value
            case x: Float32SqlArg => x.value == value
            case x: Float64SqlArg => x.value == Float64(value)
            case x: DecimalSqlArg => x.value == Decimal(value)
            case _ => false
        })
    }
}

public class Float64SqlArg <: SqlArg {
    public Float64SqlArg(index: Int64, let value: Float64) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<Float64>(statement, value)
    }
    public func toString() {
        toString(value)
    }
    public func hashCode() {
        hashCode(value)
    }
    public operator func ==(other: SqlArg): Bool {
        refEq(this, other) || (equals(other) && match (other) {
            case x: Float16SqlArg => Float64(x.value) == value
            case x: Float32SqlArg => Float64(x.value) == value
            case x: Float64SqlArg => x.value == value
            case x: DecimalSqlArg => x.value == Decimal(value)
            case _ => false
        })
    }
}

public class DecimalSqlArg <: SqlArg {
    public DecimalSqlArg(index: Int64, let value: Decimal) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<Decimal>(statement, value)
    }
    public func toString() {
        toString(value)
    }
    public func hashCode() {
        hashCode(value)
    }
    public operator func ==(other: SqlArg): Bool {
        refEq(this, other) || (equals(other) && match (other) {
            case x: Float16SqlArg => Decimal(x.value) == value
            case x: Float32SqlArg => Decimal(x.value) == value
            case x: Float64SqlArg => Decimal(x.value) == value
            case x: DecimalSqlArg => x.value == value
            case _ => false
        })
    }
}

public class BigIntSqlArg <: SqlArg {
    public BigIntSqlArg(index: Int64, private let value: BigInt) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<String>(statement, value.toString())
    }
    public func toString() {
        toString(value)
    }
    public func hashCode() {
        hashCode(value)
    }
    public operator func ==(other: SqlArg): Bool {
        refEq(this, other) || (equals(other) && match (other) {
            case x: BigIntSqlArg => x.value == value
            case _ => false
        })
    }
}

public class RuneSqlArg <: SqlArg {
    public RuneSqlArg(index: Int64, let value: Rune) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<Rune>(statement, value)
    }
    public func toString() {
        toString(value)
    }
    public func hashCode() {
        hashCode(value)
    }
    public operator func ==(other: SqlArg): Bool {
        refEq(this, other) || (equals(other) && match (other) {
            case x: RuneSqlArg => x.value == value
            case x: StringSqlArg => x.value == value.toString()
            case _ => false
        })
    }
}

public class StringSqlArg <: SqlArg {
    public StringSqlArg(index: Int64, let value: String) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<String>(statement, value)
    }
    public func toString() {
        toString(value)
    }
    public func hashCode() {
        hashCode(value)
    }
    public operator func ==(other: SqlArg): Bool {
        refEq(this, other) || (equals(other) && match (other) {
            case x: RuneSqlArg => x.value.toString() == value
            case x: StringSqlArg => x.value == value
            case _ => false
        })
    }
}

public class InputStreamSqlArg <: SqlArg {
    public InputStreamSqlArg(index: Int64, private let value: InputStream) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<InputStream>(statement, value)
    }
    public func toString() {
        '(${index}, ${TypeInfo.of<InputStream>()}, std.io.InputStream)'
    }
    public func hashCode() {
        if (h == 0) {
            h = HashBuilder().append(index).append(TypeInfo.of<InputStream>()).append('std.io.InputStream').build()
        }
        h
    }
    public operator func ==(other: SqlArg): Bool {
        refEq(this, other) || (equals(other) && match (other) {
            case x: InputStreamSqlArg => true
            case _ => false
        })
    }
}

public class DurationSqlArg <: SqlArg {
    public DurationSqlArg(index: Int64, private let value: Duration) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<Duration>(statement, value)
    }
    public func toString() {
        toString(value)
    }
    public func hashCode() {
        hashCode(value)
    }
    public operator func ==(other: SqlArg): Bool {
        refEq(this, other) || (equals(other) && match (other) {
            case x: DurationSqlArg => x.value == value
            case _ => false
        })
    }
}

public class DateTimeSqlArg <: SqlArg {
    public DateTimeSqlArg(index: Int64, private let value: DateTime) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<DateTime>(statement, value)
    }
    public func toString() {
        toString(value)
    }
    public func hashCode() {
        hashCode(value)
    }
    public operator func ==(other: SqlArg): Bool {
        refEq(this, other) || (equals(other) && match (other) {
            case x: DateTimeSqlArg => x.value == value
            case _ => false
        })
    }
}

public class ByteArraySqlArg <: SqlArg {
    public ByteArraySqlArg(index: Int64, private let value: Array<Byte>) {
        super(index)
    }
    public func set(statement: Statement): Unit {
        setValue<Array<Byte>>(statement, value)
    }
    public func toString() {
        toString(value)
    }
    public func hashCode() {
        hashCode<String>(value.toString())
    }
    public operator func ==(other: SqlArg): Bool {
        refEq(this, other) || (equals(other) && match (other) {
            case x: ByteArraySqlArg => x.value == value
            case _ => false
        })
    }
}
public class NullSqlArg <: SqlArg {
    public init(index: Int64){
        super(index)
    }
    public func set(statement: Statement): Unit {
        statement.setNull(index)
    }
    public func toString(){
        'null'
    }
    public func hashCode(){
        0
    }
    public operator func ==(other: SqlArg): Bool {
        refEq(this, other) || equals(other)
    }
}