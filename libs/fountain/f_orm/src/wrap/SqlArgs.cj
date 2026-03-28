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

public class SqlArgs <: Hashable & Equatable<SqlArgs> & ToString {
    protected SqlArgs(private var args: ArrayList<SqlArg>){}
    public init(){
        this.args = ArrayList<SqlArg>()
    }
    protected func clear() {
        args = ArrayList<SqlArg>()
    }
    protected func clone(){
        SqlArgs(args)
    }
    protected func set(statement: Statement) {
        for (arg in args) {
            arg.set(statement)
        }
    }
    public func add(arg: SqlArg) {
        args.add(arg)
    }
    public func add(arg: Bool) {
        add(BoolSqlArg(args.size, arg))
    }
    public func add(arg: Int8) {
        add(Int8SqlArg(args.size, arg))
    }
    public func add(arg: UInt8) {
        add(UInt8SqlArg(args.size, arg))
    }
    public func add(arg: Int16) {
        add(Int16SqlArg(args.size, arg))
    }
    public func add(arg: UInt16) {
        add(UInt16SqlArg(args.size, arg))
    }
    public func add(arg: Int32) {
        add(Int32SqlArg(args.size, arg))
    }
    public func add(arg: UInt32) {
        add(UInt32SqlArg(args.size, arg))
    }
    public func add(arg: Int64) {
        add(Int64SqlArg(args.size, arg))
    }
    public func add(arg: UInt64) {
        add(UInt64SqlArg(args.size, arg))
    }
    public func add(arg: BigInt) {
        add(BigIntSqlArg(args.size, arg))
    }
    public func add(arg: Decimal) {
        add(DecimalSqlArg(args.size, arg))
    }
    public func add(arg: Float16) {
        add(Float16SqlArg(args.size, arg))
    }
    public func add(arg: Float32) {
        add(Float32SqlArg(args.size, arg))
    }
    public func add(arg: Float64) {
        add(Float64SqlArg(args.size, arg))
    }
    public func add(arg: Rune) {
        add(RuneSqlArg(args.size, arg))
    }
    public func add(arg: String) {
        add(StringSqlArg(args.size, arg))
    }
    public func add(arg: InputStream) {
        add(InputStreamSqlArg(args.size, arg))
    }
    public func add(arg: Duration) {
        add(DurationSqlArg(args.size, arg))
    }
    public func add(arg: DateTime) {
        add(DateTimeSqlArg(args.size, arg))
    }
    public func add(arg: Array<Byte>) {
        add(ByteArraySqlArg(args.size, arg))
    }
    public func addNull() {
        add(NullSqlArg(args.size))
    }
    protected func add(all!: SqlArgs) {
        this.args.add(all: all.args)
    }
    public func toString() {
        args.toString()
    }
    private var h = 0
    public func hashCode() {
        if (h == 0) {
            let hasher = HashBuilder()
            hasher.append(TypeInfo.of<SqlArgs>())
            for (arg in args) {
                hasher.append(arg)
            }
            h = hasher.build()
        }
        h
    }
    public operator func ==(other: SqlArgs) {
        refEq(this, other) || args == other.args
    }
}
