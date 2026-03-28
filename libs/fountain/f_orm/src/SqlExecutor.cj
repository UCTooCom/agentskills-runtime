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

import std.collection.HashMap
import f_collection.*
import f_data.*
import f_log.impl.*
import f_orm.wrap.*
import f_orm.exception.*

public class SqlCacheKey <: Hashable & Equatable<SqlCacheKey> & ToString {
    private let h: Int64
    public SqlCacheKey(private let sql: String, private let args: SqlArgs) {
        h = HashBuilder().append(sql).append(args).build()
    }
    public func hashCode(): Int64 {
        h
    }
    public operator func ==(other: SqlCacheKey): Bool {
        refEq(this, other) || (h == other.h && sql == other.sql && args == other.args)
    }
    public func toString(): String {
        "${sql} | ${args}"
    }
}

public class SqlExecutor <: Resource & RootDAO {
    private static let logger = LoggerFactory.getLogger<SqlExecutor>()
    private static let blankRegex = Regex(#"\s{2,}"#)
    private static let currents = ThreadLocal<HashMap<String, SqlExecutor>>()
    private static let current = ThreadLocal<SqlExecutor>()
    private var sql_ = String.empty
    private var readOnly = false
    private var args: SqlArgs = SqlArgs()
    private var hasRealTx = false
    private var _connection_: Connection
    private var stmt = None<Statement>
    private var tx = None<TransactionWrap>
    private let cache: Map<SqlCacheKey, Any>
    private var clearCache = false
    private let useCache: Bool
    private var clearArgsAfterExec_ = true

    internal let partials = Partials()

    private SqlExecutor(let driverName: String) {
        useCache = ORMConfig.getUseCache(driverName: driverName) ?? true
        cache = if (useCache) {
            HashMap<SqlCacheKey, Any>()
        } else {
            EmptyMap<SqlCacheKey, Any>.INSTANCE()
        }
        _connection_ = getConnection(driverName)
    }

    protected mut prop sql: String {
        get() {
            sql_
        }
        set(value) {
            sql_ = blankRegex.replaceAll(value, " ").trimAsciiBlanks()
            if (!(sql_.trimAscii()[0..6].toAsciiLower() == 'select')) {
                readOnly = false
            }
        }
    }
    internal func clearSql(){
        sql_ = ''
        if(clearArgsAfterExec_){
            args.clear()
        }
    }
    public prop isReadOnly: Bool {
        get() {
            readOnly
        }
    }

    static func getInstance(driverName: String): SqlExecutor {
        let exe = currents
            .getOrCompute {HashMap<String, SqlExecutor>()}
            .computeIfAbsent(driverName) {SqlExecutor(driverName)}
        if (!(exe._connection_ is NoneConnection)) {
            match (exe._connection_.state) {
                case Closed => exe._connection_ = NoneConnection.instance
                case Broken =>
                    try {
                        exe._connection_.close()
                    } catch (e: Exception) {
                        logger.warn(e)
                    }
                    exe._connection_ = NoneConnection.instance
                case _ => ()
            }
        }
        current.set(exe)
        exe
    }
    static func getCurrent(): SqlExecutor {
        current.get().getOrThrow()
    }

    /**
     * DAO接口必须声明相同的属性，不必真的提供实现。所有的DAO都是SqlExecutor的扩展
     */
    public prop executor: SqlExecutor {
        get() {
            this
        }
    }

    private static func getConnection(driverName: String) {
        let conn = ORM.connection(driverName)
        conn
    }
    public func isClosed(): Bool {
        _connection_.isClosed()
    }
    public func close(): Unit {
        if (this.tx.isNone() && !isClosed()) {
            current.set(None)
            currents.get()?.remove(driverName)
            cache.clear()
            if(!(stmt?.isClosed() ?? true)){
                try{
                    stmt?.close()
                }catch(e: Exception){
                    logger.warn(e)
                }
                stmt = None<Statement>
            }
            try{
                _connection_.close()
            }catch(e: Exception){
                logger.warn(e)
            }
            _connection_ = NoneConnection.instance
            DirtyTag.clearAll()
        }
    }

    private func createTransaction(
        propagation!: Propagation = ORMConfig.getTransactionPropagation(driverName: driverName),
        isoLevel!: ?TransactionIsoLevel = ORMConfig.getTransactionLevel(driverName: driverName),
        accessMode!: ?TransactionAccessMode = ORMConfig.getTransactionAccessMode(driverName: driverName),
        deferrableMode!: ?TransactionDeferrableMode = ORMConfig.getTransactionDeferrableMode(driverName: driverName)
    ): TransactionWrap {
        func newDummyTx(
            mode!: DummyTransactionMode = Common,
            connection!: Connection = this.connection,
            suspend!: Bool = false,
            ex!: ?Exception = None
        ) {
            let tx = TransactionWrap(DummyTransaction(mode, ex), connection, suspend: suspend)
            tx.wrapping = this.tx
            this.tx = tx
        }
        match (propagation) {
            case Required =>
                //Support a current transaction, create a new one if none exists.
            try {
                if (!hasRealTx) {
                    if (let tx: TransactionWrap <- connection.createTransaction()) {
                        hasRealTx = true
                        tx.wrapping = this.tx
                        this.tx = tx
                    }
                } else {
                    newDummyTx()
                }
            } catch (e: Exception) {
                newDummyTx(mode: StartFailure, ex: e)
            }
            case Supports => //Support a current transaction, execute non-transactionally if none exists.
                newDummyTx()
            case Mandatory =>
                //Support a current transaction, throw an exception if none exists.
                if(hasRealTx){
                    newDummyTx(mode: DummyTransactionMode.Mandatory)
                }else{
                    throw MandatoryTransactionException()
                }
            case RequiresNew =>
                //Create a new transaction, and suspend the current transaction if one exists.
            try {
                let connection = if (hasRealTx) {
                    getConnection(driverName)
                } else {
                    this.connection
                }
                if (let tx: TransactionWrap <- connection.createTransaction()) {
                    tx.wrapping = this.tx
                    tx.suspend = hasRealTx
                    hasRealTx = true
                    this.tx = tx
                }
            } catch (e: Exception) {
                newDummyTx(mode: StartFailure, ex: e)
            }
            case NotSupported =>
                // Execute non-transactionally, suspend the current transaction if one exists.
                newDummyTx(
                connection: if (hasRealTx) {
                    getConnection(driverName)
                } else {
                    this.connection
                },
                suspend: hasRealTx
            )
            case Never =>
                //Execute non-transactionally, throw an exception if a transaction exists.
                if(hasRealTx){
                    throw NeverTransactionException()
                }else{
                    newDummyTx(mode: DummyTransactionMode.Never)
                }
            case Nested =>
                //Execute within a nested transaction if a current transaction exists, behave like REQUIRED otherwise.
                try {
                if (let tx: TransactionWrap <- connection.createTransaction()) {
                    tx.wrapping = this.tx
                    hasRealTx = true
                    this.tx = tx
                }
            } catch (e: Exception) {
                newDummyTx(mode: StartFailure, ex: e)
            }
        }
        let tx = this.tx.getOrThrow()
        if (let Some(lv) <- isoLevel) {
            tx.isoLevel = lv
        }
        if (let Some(mode) <- accessMode) {
            tx.accessMode = mode
        }
        if (let Some(mode) <- deferrableMode) {
            tx.deferrableMode = mode
        }
        this.tx.getOrThrow()
    }
    public func newTxAndBegin(
        propagation!: Propagation = ORMConfig.getTransactionPropagation(driverName: driverName),
        isoLevel!: ?TransactionIsoLevel = ORMConfig.getTransactionLevel(driverName: driverName),
        accessMode!: ?TransactionAccessMode = ORMConfig.getTransactionAccessMode(driverName: driverName),
        deferrableMode!: ?TransactionDeferrableMode = ORMConfig.getTransactionDeferrableMode(driverName: driverName)
    ): SqlExecutor {
        createTransaction(
            propagation: propagation,
            isoLevel: isoLevel,
            accessMode: accessMode,
            deferrableMode: deferrableMode
        ).begin()
        this
    }
    public func commit() {
        finishTransaction(false, false) {tx => tx.commit()}
    }
    public func rollback() {
        finishTransaction(true, false) {tx => tx.rollback()}
    }
    public func rollback(savepoint: String) {
        finishTransaction(false, true) {tx => tx.rollback(savepoint)}
    }
    private func finishTransaction(unwrapAnyway: Bool, withSavepoint: Bool, callback: (Transaction) -> Unit) {
        try {
            if (let Some(tx) <- this.tx) {
                try {
                    callback(tx)
                    if (!withSavepoint) {
                        this.tx = tx.wrapping
                    }
                } catch (e: Exception) {
                    if (unwrapAnyway && !withSavepoint) {
                        this.tx = tx.wrapping
                    }
                    throw e
                } finally {
                    if (tx.suspend && !withSavepoint) {
                        try {
                            if (!tx.connection.isClosed()) {
                                try{
                                    tx.connection.close()
                                }catch(e: Exception){
                                    logger.warn(e)
                                }
                                tx.connection = NoneConnection.instance
                            }
                        } catch (e: Exception) {
                            throw TransactionException(e)
                        }
                    }
                }
            }
        } finally {
            if(!(tx?.suspend ?? false) && !withSavepoint){
                close()
            }
        }
    }
    public func noRollbackFor(e: Exception): Exception {
        try {
            commit()
        } catch (ex: Exception) {
            let re: BaseException = match (ex) {
                case x: BaseException =>
                    x.addSuppressed(e)
                    x
                case x =>
                    let txe = TransactionException(x)
                    txe.addSuppressed(e)
                    txe
            }
            try {
                rollback()
            } catch (e: Exception) {
                re.addSuppressed(e)
            }
            return re
        }
        return e
    }
    public func rollbackFor(e: Exception): Exception {
        try {
            rollback()
        } catch (ex: BaseException) {
            ex.addSuppressed(e)
            return ex
        } catch (ex: Exception) {
            let txe = TransactionException(ex)
            txe.addSuppressed(e)
            return txe
        }
        return e
    }

    /**
     * 执行本函数前必须先启动一个事务，然后执行callee，最后commit。
     * 本函数不执行回滚。
     */
    public func callAndCommit<T>(callee: () -> T): T {
        tx.getOrThrow {TransactionException("no transaction started")}
        let result = callee()
        commit()
        return result
    }
    public func save(savepoint: String) {
        tx?.save(savepoint)
    }
    public func release(savepoint: String) {
        tx?.release(savepoint)
    }
    private prop connection: Connection {
        get() {
            while (!(this._connection_ is NoneConnection)) {
                match (this._connection_.state) {
                    case Connecting => continue
                    case Connected => return this._connection_
                    case Closed => throw ORMException("connection is closed")
                    case Broken =>
                        try {
                            this._connection_.close()
                        } catch (e: Exception) {
                            logger.warn(e)
                        }
                        throw ORMException("connection is broken")
                }
            }
            this._connection_ = getConnection(driverName)
            this.connection
        }
    }
    private func logMsg(now: DateTime): () -> String {
        let duration = now - start
        let sql = this.sql_
        let args = this.args.clone()
        {=>
            "${driverName} is executing a sql: ${sql}, args: ${args}, consumed: ${duration}"
        }
    }
    private var start = DateTime.UnixEpoch
    private prop statement: Statement {
        get() {
            start = DateTime.now()
            let stmt = connection.prepareStatement(sql)
            this.stmt = stmt
            args.set(stmt)
            stmt
        }
    }

    private prop updateOrDelete: Int64 {
        get() {
            execute<Int64> {r: UpdateResult => r.rowCount}
        }
    }
    public prop update: Int64 {
        get() {
            updateOrDelete
        }
    }
    public prop delete: Int64 {
        get() {
            updateOrDelete
        }
    }
    public prop insert: Int64 {
        get() {
            execute<Int64> {r: UpdateResult => r.lastInsertId}
        }
    }

    private prop query: QueryResultWrap {
        get() {
            execute<QueryResultWrap> {stmt =>
                (stmt.query() as QueryResultWrap).getOrThrow()
            }
        }
    }

    public func singleFirst<T>(): Option<T> {
        singleFirst<T>(0)
    }
    public func singleFirst<T>(index: Int64): Option<T> {
        execute<Option<T>> {result =>
            while (result.next()) {
                let value = result.get<T>(index)
                return value
            }
            return None<T>
        }
    }
    public func singleFirst<T>(column: String): Option<T> {
        execute<Option<T>> {result =>
            while (result.next()) {
                let value = result.get<T>(column)
                return value
            }
            return None<T>
        }
    }
    public func singleList<T>(): ArrayList<T> {
        singleList<T>(0)
    }
    public func singleList<T>(index: Int64): ArrayList<T> {
        execute<ArrayList<T>> {result =>
            let list = ArrayList<T>()
            while (result.next()) {
                let value = result.get<T>(index)
                list.add(value)
            }
            return list
        }
    }
    public func singleList<T>(column: String): ArrayList<T> {
        execute<ArrayList<T>> {result =>
            let list = ArrayList<T>()
            while (result.next()) {
                let value = result.get<T>(column)
                list.add(value)
            }
            return list
        }
    }
    public func singleIterator<T>(): Iterator<T> {
        singleIterator<T>(0)
    }
    public func singleIterator<T>(index: Int64): Iterator<T> {
        execute<Iterator<T>> {r =>
            SingleColumnIterator<T>(r, index: index)
        }
    }
    public func singleIterator<T>(column: String): Iterator<T> {
        execute<Iterator<T>> {r =>
            SingleColumnIterator<T>(r, column: column)
        }
    }
    public func first<T>(mappers: QueryMappers<T>): Option<T> {
        execute<Option<T>> {r =>
            try{
                mappers.doMap(r)
            }finally{
                DirtyTag.setBeforeDirty<T>()
            }
        }
    }
    public func first<T>(): Option<T> where T <: QueryMappersInit<T> {
        if (T.isSimpleData()) {
            singleFirst<T>()
        } else {
            first<T>(T.queryMappers())
        }
    }
    public func firstToMap(): Map<String, Any> {
        execute<Map<String, Any>> {result => 
            if (result.next()) {
                result.toMap()
            } else {
                EmptyMap<String, Any>.INSTANCE()
            }
        }
    }
    public func list<T>(mappers: QueryMappers<T>): ArrayList<T> {
        execute<ArrayList<T>> {r =>
            try{
                mappers.list(r)
            }finally{
                DirtyTag.setBeforeDirty<T>()
            }
        }
    }
    public func list<T>(): ArrayList<T> where T <: QueryMappersInit<T> {
        if (T.isSimpleData()) {
            singleList<T>()
        } else {
            list<T>(T.queryMappers())
        }
    }
    public func mapList(): ArrayList<HashMap<String, Any>> {
        execute<ArrayList<HashMap<String, Any>>> {result =>
            let list = ArrayList<HashMap<String, Any>>()
            while (result.next()) {
                list.add(result.toMap())
            }
            list
        }
    }
    public func iterator<T>(mappers: QueryMappers<T>): QueryResultIterator<T> {
        execute<QueryResultIterator<T>> {r =>
            mappers.iterator(r)
        }
    }
    public func iterator<T>(): Iterator<T> where T <: QueryMappersInit<T> {
        if (T.isSimpleData()) {
            singleIterator<T>()
        } else {
            iterator<T>(T.queryMappers())
        }
    }
    public func one<T>(mappers: QueryMappers<T>): Option<T> {
        execute<Option<T>> {r =>
            mappers.one(r)
        }
    }
    public func one<T>(): Option<T> where T <: QueryMappersInit<T> {
        if (T.isSimpleData()) {
            singleFirst<T>()
        } else {
            one<T>(T.queryMappers())
        }
    }

    public func add<T>(arg: T): SqlExecutor where T <: ToString {
        match (arg) {
            case x: Bool => add(x)
            case x: Int8 => add(x)
            case x: UInt8 => add(x)
            case x: Int16 => add(x)
            case x: UInt16 => add(x)
            case x: Int32 => add(x)
            case x: UInt32 => add(x)
            case x: Int64 => add(x)
            case x: UInt64 => add(x)
            case x: BigInt => add(x)
            case x: Decimal => add(x)
            case x: Float16 => add(x)
            case x: Float32 => add(x)
            case x: Float64 => add(x)
            case x: Rune => add(x)
            case x: String => add(x)
            case x: Duration => add(x)
            case x: DateTime => add(x)
            case x: Array<Byte> => add(x)

            case x: ?Bool => add(x)
            case x: ?Int8 => add(x)
            case x: ?UInt8 => add(x)
            case x: ?Int16 => add(x)
            case x: ?UInt16 => add(x)
            case x: ?Int32 => add(x)
            case x: ?UInt32 => add(x)
            case x: ?Int64 => add(x)
            case x: ?UInt64 => add(x)
            case x: ?BigInt => add(x)
            case x: ?Decimal => add(x)
            case x: ?Float16 => add(x)
            case x: ?Float32 => add(x)
            case x: ?Float64 => add(x)
            case x: ?Rune => add(x)
            case x: ?String => add(x)
            case x: ?Duration => add(x)
            case x: ?DateTime => add(x)
            case x: ?Array<Byte> => add(x)

            case x => add(x.toString())
        }
    }
    public func add(arg: Bool) {
        args.add(arg)
        this
    }
    public func add(arg: ?Bool) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func add(arg: Int8) {
        args.add(arg)
        this
    }
    public func add(arg: ?Int8) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func add(arg: UInt8) {
        args.add(arg)
        this
    }
    public func add(arg: ?UInt8) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func add(arg: Int16) {
        args.add(arg)
        this
    }
    public func add(arg: ?Int16) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func add(arg: UInt16) {
        args.add(arg)
        this
    }
    public func add(arg: ?UInt16) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func add(arg: Int32) {
        args.add(arg)
        this
    }
    public func add(arg: ?Int32) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func add(arg: UInt32) {
        args.add(arg)
        this
    }
    public func add(arg: ?UInt32) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func add(arg: Int64) {
        args.add(arg)
        this
    }
    public func add(arg: ?Int64) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func add(arg: UInt64) {
        args.add(arg)
        this
    }
    public func add(arg: ?UInt64) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func add(arg: BigInt) {
        args.add(arg)
        this
    }
    public func add(arg: ?BigInt) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func add(arg: Decimal) {
        args.add(arg)
        this
    }
    public func add(arg: ?Decimal) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func add(arg: Float16) {
        args.add(arg)
        this
    }
    public func add(arg: ?Float16) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func add(arg: Float32) {
        args.add(arg)
        this
    }
    public func add(arg: ?Float32) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func add(arg: Float64) {
        args.add(arg)
        this
    }
    public func add(arg: ?Float64) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func add(arg: Rune) {
        args.add(arg)
        this
    }
    public func add(arg: ?Rune) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func add(arg: String) {
        args.add(arg)
        this
    }
    public func add(arg: ?String) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func add(arg: InputStream) {
        args.add(arg)
        this
    }
    public func add(arg: ?InputStream) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func add(arg: Duration) {
        args.add(arg)
        this
    }
    public func add(arg: ?Duration) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func add(arg: DateTime) {
        args.add(arg)
        this
    }
    public func add(arg: ?DateTime) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func add(arg: Array<Byte>) {
        args.add(arg)
        this
    }
    public func add(arg: ?Array<Byte>) {
        match(arg){
            case Some(x) => add(x)
            case _ => addNull()
        }
    }
    public func addNull(){
        args.addNull()
        this
    }
    public func add(arg: Any) {
        match (arg) {
            case x: ToString => add<ToString>(x)
            case x: InputStream => add(x)
            case x: ?InputStream => add(x)
            case _ => throw SqlException("Unsupported data type")
        }
    }
    protected func add(all!: SqlExecutor){
        this.args.add(all: all.args)
    }

    public func setSql(sql: String, clearArgsAfterExec!: Bool = true): SqlExecutor {
        this.clearArgsAfterExec_ = clearArgsAfterExec
        this.sql = sql
        this
    }
    public operator func ()(sql: String): SqlExecutor {
        setSql(sql)
    }
    
    private func execute<T>(executor: () -> T): T {
        func exec() {
            if (tx.isSome()) {
                return executor()
            }
            try { 
                return executor()
            } finally {
                this.close()
            }
        }
        try {
            let v = if (useCache && !clearCache) {
                let key = SqlCacheKey(sql, args)
                match (cache.get(key)) {
                    case Some(v: T) => v
                    case Some(_) => throw ORMException("type of cached data with key '${key}' does not match")
                    case _ =>
                        let v = exec()
                        cache[key] = v
                        v
                }
            } else {
                exec()
            }
            if (useCache && clearCache) {
                cache.clear()
                clearCache = false
            }
            v
        } catch (e: Exception) {
            logger.warn(e, logMsg(DateTime.now()))
            throw e
        } finally { 
            //事务切面也会执行这个函数，从而一次事务内除了每次执行SQL会执行到这个finally，
            //结束事务时也会执行这个finally，不过结束事务前sql已经清除了，会导致记一行空日志
            //因此，记录日志前要做这个判断
            if(sql.size > 0){
                logger.debug(logMsg(DateTime.now()))
                start = DateTime.UnixEpoch
                clearSql()
            }
        }
    }
    private func execute<T>(executor: (Statement) -> T): T {
        execute<T>{
            let stmt = statement
            try{
                executor(stmt)
            }finally{
                stmt.close()
                this.stmt = None<Statement>
            }
        }
    }
    private func execute<T>(extract: (UpdateResult) -> T): T {
        clearCache = true
        execute<T> {stmt =>
            let result = stmt.update()
            extract(result)
        }
    }
    private func execute<T>(extract: (QueryResultWrap) -> T): T {
        execute<T> {
            var r = None<QueryResultWrap>
            try{
                r = query
                extract(r.getOrThrow())
            } finally {
                try{
                    r?.close()
                }catch(e: Exception){
                    logger.warn(e)
                }
            }
        }
    }
    public func execute<T>(executor: (SqlExecutor) -> T): T {
        execute<T> {
            exec: SqlExecutor => (executor(exec), true)
        }
    }

    private let rollbackExceptions = ConcurrentHashMap<String, HashSet<TypeInfo>>()
    //executor返回元组的第二个值，如果是true就执行commit，否则执行rollback
    public func execute<T>(
        propagation!: Propagation = ORMConfig.getTransactionPropagation(driverName: driverName),
        isoLevel!: ?TransactionIsoLevel = ORMConfig.getTransactionLevel(driverName: driverName),
        accessMode!: ?TransactionAccessMode = ORMConfig.getTransactionAccessMode(driverName: driverName),
        deferrableMode!: ?TransactionDeferrableMode = ORMConfig.getTransactionDeferrableMode(driverName: driverName),
        noRollbackFor!: ?String = ORMConfig.getTransactionNoRollbackFor(driverName: driverName),
        rollbackFor!: ?String = ORMConfig.getTransactionRollbackFor(driverName: driverName),
        executor!: (SqlExecutor) -> (T, Bool)): T {
        execute<T> {
            var txStatus = TransactionStatus.Unknown
            try {
                ORM.hooks.beforeTx()
                this.newTxAndBegin(
                    propagation: propagation,
                    isoLevel: isoLevel,
                    accessMode: accessMode,
                    deferrableMode: deferrableMode
                )
                let (result, commit) = executor(this)
                if(commit){
                    ORM.hooks.beforeCommit(this.isReadOnly)
                    this.commit()
                    txStatus = Committed
                    ORM.hooks.afterCommit()
                    result
                }else{
                    throw ORMException()
                }
            } catch (e: Exception) {
                ORM.hooks.afterThrowing(e)
                let et = ClassTypeInfo.of(e)
                func genExceptionSet(ex: String) {
                    rollbackExceptions.computeIfAbsent(ex){
                        let set = HashSet<TypeInfo>()
                        for (e in ex.split("|") where e.size > 0) {
                            set.add(TypeInfos.get(e.trimAscii()))
                        }
                        set
                    }
                }
                if (let Some(noRollbackFor) <- noRollbackFor && noRollbackFor.size > 0) {
                    let set: Set<TypeInfo> = genExceptionSet(noRollbackFor)
                    for (noRollback in set where et.isSubtypeOf(noRollback)) {
                        ORM.hooks.beforeCommit(this.isReadOnly)
                        let thrown = this.noRollbackFor(e)
                        txStatus = Committed
                        ORM.hooks.afterCommit()
                        throw thrown
                    }
                }
                if (let Some(rollbackFor) <- rollbackFor && rollbackFor.size > 0) {
                    let set: Set<TypeInfo> = genExceptionSet(rollbackFor)
                    for (rollback in set where et.isSubtypeOf(rollback)) {
                        ORM.hooks.beforeRollback(e)
                        let thrown = this.rollbackFor(e)
                        txStatus = Rollback
                        ORM.hooks.afterRollback(e)
                        throw thrown
                    }
                    ORM.hooks.beforeCommit(this.isReadOnly)
                    let thrown = this.noRollbackFor(e)
                    txStatus = Committed
                    ORM.hooks.afterCommit()
                    throw thrown
                } else {
                    ORM.hooks.beforeRollback(e)
                    this.rollback()
                    txStatus = Rollback
                    ORM.hooks.afterRollback(e)
                    throw e
                }
            } finally {
                ORM.hooks.afterComplete(txStatus)
                this.close()
            }
        }
    }
}
