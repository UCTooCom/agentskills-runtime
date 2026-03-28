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

import f_bean.macros.*

public abstract class SqlDialect {
    public prop dialect: String
    public open func lastInsertId(id: String): String {
        ''
    }
    public func lastInsertId(dataType: DataType): String {
        lastInsertId(dataType.columnName)
    }
    public func lastInsertId<ID, O>(id: IdQueryMapper<ID, O>): String where ID <: Hashable & Equatable<ID> {
        lastInsertId(id.dataType)
    }
    public open func limit(size: Int64, offset: Int64): (Int64, Int64, String) {
        (size, offset, ' limit ? offset ?')
    }
    public open prop startInvolver: String {
        get(){
            '"'
        }
    }
    public open prop endInvolver: String {
        get(){
            '"'
        }
    }
    public func involvedIdentifier(identifier: String): String {
        if(identifier.startsWith(startInvolver)){
            return identifier
        }else if(let Some(idx) <- identifier.indexOf('.')){
            '${startInvolver}${identifier[0 .. idx]}${endInvolver}.${startInvolver}${identifier[idx + 1 ..]}${endInvolver}'
        }else{
            '${startInvolver}${identifier}${endInvolver}'
        }
    }
}
@Bean
@BeanMeta[condition: ConfCond.Value('orm_drivers', StringCond.Contains('mysql'))]
public open class MySqlDialect <: SqlDialect {
    public open prop dialect: String {
        get(){
            'mysql'
        }
    }
    public prop startInvolver: String {
        get(){
            '`'
        }
    }
    public prop endInvolver: String {
        get(){
            '`'
        }
    }
}
@Bean
@BeanMeta[condition: ConfCond.Value('orm_drivers', StringCond.Contains('mariadb'))]
public class MariaDBDialect <: MySqlDialect {
    public open prop dialect: String {
        get(){
            'mariadb'
        }
    }
}
@Bean
@BeanMeta[condition: ConfCond.Value('orm_drivers', StringCond.Contains('sqlite'))]
public class SqliteDialect <: SqlDialect {
    public prop dialect: String {
        get(){
            'sqlite'
        }
    }
}
@Bean
@BeanMeta[condition: ConfCond.Value('orm_drivers', StringCond.Contains('postgres'))]
public open class PostgresDialect <: SqlDialect {
    public open prop dialect: String {
        get(){
            'postgres'
        }
    }
    public open func lastInsertId(id: String): String {
        ' returning ${id}'
    }
}
@Bean
@BeanMeta[condition: ConfCond.Value('orm_drivers', StringCond.Contains('opengauss'))]
public class OpenGaussDialect <: PostgresDialect {
    public prop dialect: String {
        get(){
            'opengauss'
        }
    }
}
@Bean
@BeanMeta[condition: ConfCond.Value('orm_drivers', StringCond.Contains('oracle'))]
public class OracleDialect <: SqlDialect {
    public prop dialect: String {
        get(){
            'oracle'
        }
    }
    public func limit(size: Int64, offset: Int64): (Int64, Int64, String) {
        (offset, size, ' OFFSET ? ROWS FETCH NEXT ? ROWS ONLY')
    }
}
@Bean
@BeanMeta[condition: ConfCond.Value('orm_drivers', StringCond.Contains('db2'))]
public class DB2Dialect <: SqlDialect {
    public prop dialect: String {
        get(){
            'db2'
        }
    }
    public func limit(size: Int64, offset: Int64): (Int64, Int64, String) {
        (offset, size, ' OFFSET ? ROWS FETCH FIRST ? ROWS ONLY')
    }
}
@Bean
@BeanMeta[condition: ConfCond.Value('orm_drivers', StringCond.Contains('mockdb'))]
public class MockdbDialect <: SqlDialect {
    private var mock_: String = 'opengauss'
    public prop dialect: String {
        get(){
            'mockdb'
        }
    }
    public mut prop mock: String {
        get(){
            mock_
        }
        set(value){
            if(value == dialect){
                throw MockDBException('cannot mock itself')
            }
            mock_ = value
        }
    }
    public func limit(size: Int64, offset: Int64): (Int64, Int64, String) {
        SqlDialectMediator.instance.getDialect(this.mock_).limit(size, offset)
    }
    public prop startInvolver: String {
        get(){
            SqlDialectMediator.instance.getDialect(this.mock_).startInvolver
        }
    }
    public prop endInvolver: String {
        get(){
            SqlDialectMediator.instance.getDialect(this.mock_).endInvolver
        }
    }
}
struct SqlDialectMediator {
    private init(){}
    public static let instance = SqlDialectMediator()

    func getDialect(dialect: String): SqlDialect {
        if(dialects.isEmpty()){
            for(dialect in lookupList<SqlDialect>()){
                this.dialects[dialect.dialect] = dialect
            }
        }
        dialects[dialect]
    }

    private let dialects = ConcurrentHashMap<String, SqlDialect>()

    func lastInsertId(dialect: String, id: String): String {
        getDialect(dialect).lastInsertId(id)
    }
    func lastInsertId(dialect: String, dataType: DataType): String {
        getDialect(dialect).lastInsertId(dataType)
    }
    func lastInsertId<ID, O>(dialect: String, id: IdQueryMapper<ID, O>): String where ID <: Hashable & Equatable<ID> {
        getDialect(dialect).lastInsertId(id)
    }

    func limit(dialect: String, size: Int64, offset: Int64): (Int64, Int64, String) {
        getDialect(dialect).limit(size, offset)
    }
}