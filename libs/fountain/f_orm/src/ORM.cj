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

import std.collection.concurrent.ConcurrentHashMap
import f_collection.*
import f_orm.exception.ORMException
import f_log.*
public import std.convert.*
public import std.database.sql.*
public import std.reflect.*
public import f_bean.*
public import f_exception.{BaseException, UnreachableException}
public import f_orm.wrap.*
public import f_orm.exception.*

/**
 * 事务维持在连接内，要在一个事务内完成的数据库访问应确保使用一个连接。
 * 应用项目应当有一个初始化文件用来调用ORM.register(...)完成初始化
 */
public class ORM {
    private static let log = LoggerFactory.getLogger<ORM>()
    private static var default = String.empty
    private static let datasources = ConcurrentHashMap<String, NamedDatasource>()
    static let hooks = TransactionHooks()

    public static func close() {
        for ((_, s) in datasources) {
            s.close()
        }
    }
    protected static prop driverNames: Iterator<String> {
        get(){
            datasources.keys().iterator()
        }
    }
    public static func registerTransactionHooks<T>(): Unit where T <: TransactionHook {
        for(hook in lookupList<T>()) {
            registerTransactionHook<T>(hook)
        }
    }
    public static func registerTransactionHook<T>(hook: T): Unit where T <: TransactionHook {
        hooks.register<T>(hook)
    }

    public static func register(datasource: NamedDatasource, default!: Bool = true): Unit {
        if(datasources.addIfAbsent(datasource.driverName, datasource).isNone()){
            if(default){
                ORM.default = datasource.driverName
            }
        }else{
            datasource.close()
        }
    }
    public static func register(creator: DatasourceCreator, default!: Bool = true): Unit {
        let ds = creator.create()
        register(ds, default: default)
    }
    public static func register(driver: Driver, default!: Bool = true): Unit {
        if(datasources.contains(driver.name)){
            log.warn{'driver ${driver.name} has been registered'}
            return
        }
        log.debug{'driver ${driver.name} registering...'}
        register(NamedDatasource(driver), default: default)
    }
    public static func register(driver: Driver, opts: Array<(String, String)>, default!: Bool = true): Unit {
        if(datasources.contains(driver.name)){
            return
        }
        log.debug{'driver ${driver.name} registering...'}
        register(NamedDatasource(driver, opts), default: default)
    }
    public static func register(driver: Driver, url: String, default!: Bool = true): Unit {
        if(datasources.contains(driver.name)){
            log.warn{'driver ${driver.name} has been registered'}
            return
        }
        log.debug('driver ${driver.name} registering...')
        register(NamedDatasource(driver, url), default: default)
    }
    public static func register(driver: Driver, url: String, opts: Array<(String, String)>, default!: Bool = true): Unit {
        if(datasources.contains(driver.name)){
            log.warn{'driver ${driver.name} has been registered'}
            return
        }
        register(NamedDatasource(driver, url, opts), default: default)
    }
    public static func getDriver(driver: String){
        ORMConfig.getDriver(driver)
    }
    public static func register(driver: String, default!: Bool = true): Unit {
        register(NamedDatasource(getDriver(driver)), default: default)
    }
    public static func register(driver: String, opts: Array<(String, String)>, default!: Bool = true){
        register(NamedDatasource(getDriver(driver), opts), default: default)
    }
    public static func register(driver: String, url: String, default!: Bool = true){
        register(NamedDatasource(getDriver(driver), url), default: default)
    }
    public static func register(driver: String, url: String, opts: Array<(String, String)>, default!: Bool = true){
        register(NamedDatasource(getDriver(driver), url, opts), default: default)
    }
    public static func register(){
        let default = ORMConfig.getDefaultDriver()
        for(d in ORMConfig.getDrivers()){
            if(ORMConfig.getUseThirdPartyPool(d.name)){
                continue
            }
            register(NamedDatasource(d), default: default.isEmpty() || d.name == default)
        }
    }
    public static func initialize(){
        try{
            register()
            registerTransactionHooks<TransactionHook>()
        }catch(e: Exception){
            log.error('ORM initialization failed', e)
            throw e
        }
    }
    public static func deregister(name: String): Unit {
        if(let Some(d) <- datasources.remove(name)){
            DriverManager.deregister(name)
            d.close()
        }
        if (name == default) {
            default = String.empty
        }
    }
    public static func deregisterAndReplaceDefault(newDefault: String): Unit {
        deregister(default)
        default = newDefault
    }
    public static prop databasesNames: Array<String> {
        get() {
            DriverManager.drivers()
        }
    }
    private static func hasDefault() {
        if (default == String.empty) {
            throw ORMException("default datasource is not specified")
        }
    }

    public static func connection(): Connection {
        hasDefault()
        return connection(default)
    }
    public static func connection(name: String): Connection {
        if (name.isEmpty()) {
            return datasources[default].connect()
        } else {
            return datasources[name].connect()
        }
    }
    public static func executor(driverName: String): SqlExecutor {
        if (driverName.isEmpty()) {
            hasDefault()
            return SqlExecutor.getInstance(default)
        } else {
            return SqlExecutor.getInstance(driverName)
        }
    }
    public static func executor(): SqlExecutor {
        hasDefault()
        return executor(default)
    }
}
