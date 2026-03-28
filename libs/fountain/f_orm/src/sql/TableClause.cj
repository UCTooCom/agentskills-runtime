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
package f_orm.sql

abstract sealed class TableClause<T> <: ToString where T <: QueryMappersInit<T> {
    let sqlgen = StringGenerator()
    private var idType_ = None<DataType>
    TableClause(partial: String, private let exe: SqlExecutor) {
        for (mapper in T.queryMappers().mappers where mapper.isId) {
            idType_ = mapper.dataType
            break
        }
        sqlgen.append(partial)
    }
    prop tableName: String {
        get() {
            T.tableName()
        }
    }
    public prop executor: SqlExecutor {
        get() {
            exe
        }
    }

    protected func appendPartial(keyword: String, trim: String, partial: String): This {
        let sql = if(trim.isEmpty()){
            partial
        }else{
            '^(\\s*${trim}\\s*)|(\\s*${trim}\\s*)$'.regex(flags: [IgnoreCase], solid: true).replaceAll(partial, '')
        }
        if(sql.size > 0){
            sqlgen.append(' ').append(keyword).append(' ').append(sql)
        }
        this
    }

    protected open func setSql(): SqlExecutor {
        exe.setSql(sqlgen.toString())
    }

    prop idType: ?DataType {
        get() {
            idType_
        }
    }
    prop dialect: SqlDialect {
        get() {
            SqlDialectMediator.instance.getDialect(exe.driverName)
        }
    }
    public func toString(): String {
        sqlgen.toString()
    }
}

public abstract class ExceptInsertClause<T> <: TableClause<T> where T <: QueryMappersInit<T> {
    protected func join<T>(keyword: String, AS: String, ON: String): This where T <: QueryMappersInit<T> {
        sqlgen.append(' ').append(keyword).append(' join ').append(T.tableName())
        if (AS.size > 0) {
            sqlgen.append(' AS ').append(AS)
        }
        if (ON.size > 0) {
            sqlgen.append(' ON ').append(ON)
        }
        this
    }
    init(sql: String, executor: SqlExecutor) {
        super(sql, executor)
    }
    public func INNER_JOIN<T>(AS!: String = '', ON!: String = ''): This where T <: QueryMappersInit<T> {
        join<T>('inner', AS, ON)
    }
    public func LEFT_JOIN<T>(AS!: String = '', ON!: String = ''): This where T <: QueryMappersInit<T> {
        join<T>('left outer', AS, ON)
    }
    public func RIGHT_JOIN<T>(AS!: String = '', ON!: String = ''): This where T <: QueryMappersInit<T> {
        join<T>('right outer', AS, ON)
    }
    public func FULL_JOIN<T>(AS!: String = '', ON!: String = ''): This where T <: QueryMappersInit<T> {
        join<T>('full outer', AS, ON)
    }
    private func condition(cond: () -> Unit, keyword: String, trim: String): This {
        try{
            executor.partials.clear()
            cond()
            let sql = executor.partials.toString()
            if(sql.size > 0){
                appendPartial(keyword, trim, sql)
            }
        }finally{
            executor.partials.clear()
        }
        this
    }
    public func WHERE(condition: () -> Unit): This {
        this.condition(condition, 'where', 'and|or')
    }
    public func WHERE(condition: String): This {
        appendPartial('where', 'and|or', condition)//这个不能用this.condition
    }
    public func AND(condition: () -> Unit): This {
        this.condition(condition, 'and', 'and|or')
    }
    public func AND(condition: String): This {
        appendPartial('and', 'and|or', condition)
    }
    public func OR(condition: () -> Unit): This {
        this.condition(condition, 'or', 'and|or')
    }
    public func OR(condition: String): This {
        appendPartial('or', 'and|or', condition)
    }
    public func NOT(condition: () -> Unit): This {
        this.condition(condition, 'not', 'and|or')
    }
    public func NOT(condition: String): This {
        appendPartial('not', 'and|or', condition)
    }
    public func PAREN(condition: () -> Unit): This {
        try{
            executor.partials.clear()
            condition()
            let sql = executor.partials.toString()
            PAREN(sql)
        }finally{
            executor.partials.clear()
        }
        this
    }
    public func PAREN(condition: String): This {
        if(condition.size > 0){
            sqlgen.append(' (').append(condition).append(') ')
        }
        this
    }
    public func PAREN(op: CondRelOp, condition: () -> Unit): This {
        try{
            executor.partials.clear()
            condition()
            let sql = executor.partials.toString()
            PAREN(op, sql)
        }finally{
            executor.partials.clear()
        }
        this
    }
    public func PAREN(op: CondRelOp, condition: String): This {
        if(condition.size > 0){
            sqlgen.append(' ${op} (').append(condition).append(') ')
        }
        this
    }
    public func WHERE(arg: Map<String, Any>, condition: () -> String): This {
        WHERE(parseSqlFromMap(executor, condition(), arg))
    }
    public func WHERE<T>(arg: T, condition: () -> String): This where T <: ObjectData<T> {
        WHERE(parseSqlFromObject<T>(executor, condition(), arg))
    }
    public func ORDER_BY(orderBy: () -> String): This {
        appendPartial('order by', ',', orderBy())
    }
    public func LIMIT(size: Int64, offset!: Int64 = 0): This {
        let (one, two, sql) = dialect.limit(size, offset)
        this.executor.add(one).add(two)
        sqlgen.append(' ').append(sql)
        this
    }
}

public class FromClause<T> <: ExceptInsertClause<T> where T <: QueryMappersInit<T> {
    init(executor: SqlExecutor) {
        super(' from ${T.tableName()} ', executor)
    }
    public func DELETE(): Int64 {
        DELETE('')
    }
    public func DELETE(sql: String): Int64 {
        executor.setSql('delete ${sql} ${sqlgen}').delete
    }

    public func GROUP_BY(groupBy: () -> String): This {
        appendPartial('group by', ',', groupBy())
    }
    public func findById(id: Int64): ?T {
        executor.setSql('select * ${this} where ${T.queryMappers().idName ?? 'id'}=${executor.arg(id)}').first<T>()
    }
    public func findById(id: UInt64): ?T {
        executor.setSql('select * ${this} where ${T.queryMappers().idName ?? 'id'}=${executor.arg(id)}').first<T>()
    }
    public func findById(id: String): ?T {
        executor.setSql('select * ${this} where ${T.queryMappers().idName ?? 'id'}=${executor.arg(id)}').first<T>()
    }

    public func deleteById(id: Int64): ?T {
        executor.setSql('delete ${this} where ${T.queryMappers().idName ?? 'id'}=${executor.arg(id)}').first<T>()
    }
    public func deleteById(id: UInt64): ?T {
        executor.setSql('delete ${this} where ${T.queryMappers().idName ?? 'id'}=${executor.arg(id)}').first<T>()
    }
    public func deleteById(id: String): ?T {
        executor.setSql('delete ${this} where ${T.queryMappers().idName ?? 'id'}=${executor.arg(id)}').first<T>()
    }
    
    public func first<T>(): ?T where T <: QueryMappersInit<T> {
        executor.setSql('select * ${LIMIT(1)}').first<T>()
    }
    public func first<T>(columns: String): ?T where T <: QueryMappersInit<T> {
        executor.setSql('select ${columns} ${LIMIT(1)}').first<T>()
    }
    public func singleFirst<T>(column: String): ?T {
        executor.setSql('select ${column} ${LIMIT(1)}').singleFirst<T>()
    }
    public func list<T>(): ArrayList<T> where T <: QueryMappersInit<T> {
        executor.setSql('select * ${sqlgen}').list<T>()
    }
    public func list<T>(columns: String): ArrayList<T> where T <: QueryMappersInit<T> {
        executor.setSql('select ${columns} ${sqlgen}').list<T>()
    }
    public func singleList<T>(): ArrayList<T> {
        singleList<T>('id')
    }
    public func singleList<T>(column: String): ArrayList<T> {
        executor.setSql('select ${column} ${sqlgen}').singleList<T>()
    }

    public func count(): Int64 {
        count(true)
    }
    private func count(clearArgsAfterExec: Bool): Int64 {
        executor.setSql('select count(*) from (select 1 ${sqlgen}) as __tmp___', clearArgsAfterExec: clearArgsAfterExec).first<Int64>() ?? 0
    }
    public func singlePage<R>(size: Int64, page!: Int64 = 1): Pagination<R> where R <: DataFields<R> {
        singlePage<R>('id', size, page: page)
    }

    public func singlePage<R>(column: String, size: Int64, page!: Int64 = 1): Pagination<R> where R <: DataFields<R> {
        executor.singlePage<R>('select ${column} ${sqlgen}', size, page: page)
    }
    
    public func page<R>(size: Int64, page!: Int64 = 1): Pagination<R> where R <: QueryMappersInit<R> & DataFields<R> {
        this.page<R>('*', size, page: page)
    }
    public func page<R>(columns: String, size: Int64, page!: Int64 = 1): Pagination<R> where R <: QueryMappersInit<R> & DataFields<R> {
        executor.page<R>('select ${columns} ${sqlgen}', size, page: page)
    }
}

public class UpdateClause<T> <: ExceptInsertClause<T> where T <: QueryMappersInit<T> {
    init(executor: SqlExecutor) {
        super('update ${T.tableName()} ', executor)
    }
    public func SET(set: () -> String): This {
        appendPartial('set', ',', set())
    }
    public func SET(arg: Map<String, Any>, condition: () -> String): This {
        SET{
            parseSqlFromMap(executor, condition(), arg)
        }
    }
    public func SET<T>(arg: T, condition: () -> String): This where T <: ObjectData<T> {
        SET{
            parseSqlFromObject<T>(executor, condition(), arg)
        }
    }
    public func execute(): Int64 {
        setSql().update
    }
    
    public func byId(id: Int64): Int64 {
        appendPartial('where', '', '${T.queryMappers().idName ?? 'id'}=${executor.arg(id)}').execute()
    }
    public func byId(id: UInt64): Int64 {
        appendPartial('where', '', '${T.queryMappers().idName ?? 'id'}=${executor.arg(id)}').execute()
    }
    public func byId(id: String): Int64 {
        appendPartial('where', '', '${T.queryMappers().idName ?? 'id'}=${executor.arg(id)}').execute()
    }
}

public class IntoClause<T> <: TableClause<T> where T <: QueryMappersInit<T> {
    private let fields = ArrayList<DataType>()

    init(executor: SqlExecutor, ignores: Array<String>) {
        super('insert into ${T.tableName()}(', executor)
        let set = HashSet<String>(ignores)
        var i = 0
        for (mapper in T.queryMappers().mappers where !set.contains(mapper.dataType.columnName)) {
            if (i > 0) {
                sqlgen.append(',')
            }
            sqlgen.append(mapper.dataType.columnName)
            fields.add(mapper.dataType)
            i++
        }
        sqlgen.append(')')
    }
    public func VALUES<D>(value: D): This where D <: ObjectData<D> {
        sqlgen.append('values(')
        let data = DataObject<D>(value)
        for (i in 0..fields.size) {
            if (i > 0) {
                sqlgen.append(',')
            }
            let field = fields[i]
            func convert(val: Data){
                match (val) {
                    case _: DataNone => this.executor.argNull()
                    case x: DataBool => this.executor.arg(x.data)
                    case x: DataString => this.executor.arg(x.data)
                    case x: DataDuration => this.executor.arg(x.data)
                    case x: DataDateTime => this.executor.arg(x.data)
                    case x: DataCollection<Array<Byte>, Byte> => this.executor.arg(x.data)
                    case x: DataReal => match (field) {
                        case _: Int8DataType => this.executor.arg(x.toInt8())
                        case _: UInt8DataType => this.executor.arg(x.toUInt8())
                        case _: Int16DataType => this.executor.arg(x.toInt16())
                        case _: UInt16DataType => this.executor.arg(x.toUInt16())
                        case _: Int32DataType => this.executor.arg(x.toInt32())
                        case _: UInt32DataType => this.executor.arg(x.toUInt32())
                        case _: Int64DataType => this.executor.arg(x.toInt64())
                        case _: UInt64DataType => this.executor.arg(x.toUInt64())
                        case _: Float32DataType => this.executor.arg(x.toFloat32())
                        case _: Float64DataType => this.executor.arg(x.toFloat64())
                        case _: Float16DataType => this.executor.arg(x.toFloat16())
                        case _: DecimalDataType => this.executor.arg(x.toDecimal())
                        case _: BigIntDataType => this.executor.arg(x.toBigInt())
                        case x => throw SqlArgException(
                            'field ${field.fieldName} is a number, but ${TypeInfo.of(x)} is required.')
                    }
                    case x => throw SqlArgException(
                        'type of field ${field.fieldName} is ${TypeInfo.of(x)}, but it is not supported yet.')
                }
            }
            let val = data.get(field.fieldName)
            let holder = match(val){
                case Some(x) => convert(x)
                case _ => this.executor.argNull()
            }
            sqlgen.append(holder)
        }
        sqlgen.append(')')
        if (let Some(idType) <- super.idType) {
            sqlgen.append(dialect.lastInsertId(idType))
        }
        this
    }
    public func SELECT<T>(selectColumns: String): This where T <: QueryMappersInit<T> {
        SELECT<T>(selectColumns) {_ =>}
    }
    public func SELECT<T>(selectColumns: String, fromClause: (FromClause<T>) -> Unit): This where T <: QueryMappersInit<T> {
        let from = executor.FROM<T>()
        fromClause(from)
        sqlgen.append(' select ').append(selectColumns).append(' ').append(from.sqlgen)
        this
    }
    public func ON_DUPLICATE_KEY_UPDATE(columns: ()-> String): This {
        sqlgen.append(' on duplicate key update ').append(columns())
        this
    }
    public func execute() {
        setSql().insert
    }
}
