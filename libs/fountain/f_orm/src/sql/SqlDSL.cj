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

import std.ast.*
import f_cache.HeapCache
import f_data.path.*

public interface SqlDSL {
    func setSqlFromObject<T>(dsl: String, arg: T, clearArgsAfterExec!: Bool): SqlExecutor where T <: ObjectData<T>
    func setSqlFromMap(dsl: String, arg: Map<String, Any>, clearArgsAfterExec!: Bool): SqlExecutor 
}
private interface SqlDSLPart{}
private class StringSqlDSLPart <: SqlDSLPart {
    StringSqlDSLPart(let partial: String){}
}
private class ArgSqlDSLPart <: SqlDSLPart {
    ArgSqlDSLPart(let name: String){}
    func get(arg: Map<String, Any>): ?Any {
        arg.get(this.name)
    }
    func get<T>(arg: T): ?Data where T <: ObjectData<T> {
        T.dataFields().readableField(this.name)?.get(arg)
    }
}
private class DataPathDSLPart <: SqlDSLPart {
    DataPathDSLPart(private let path: DataPath, let name: String){}
    func get<T>(arg: T): ?Data where T <: ObjectData<T> { 
        path.get(arg.toData()).next()
    }
}
private let dslcache = HeapCache<ArrayList<SqlDSLPart>>(maxLife: Duration.day, maxSize: 10000)
private func compile(dsl: String){
    dslcache.getOrCompute(dsl){
        let list = ArrayList<SqlDSLPart>()
        let gen = StringGenerator(' ')
        let tokens = cangjieLex(dsl)
        var i = 0
        while(i < tokens.size) {
            let token = tokens[i]
            match(token.kind){
                case NL => ()
                case QUEST => throw IllegalArgumentException('QUEST token MUST NOT be used with parameterised SQL together!')
                case COLON => 
                    if(gen.size > 0){
                        list.add(StringSqlDSLPart(gen.toString()))
                        gen.reset()
                    }
                    i++
                    if(i < tokens.size){
                        let token = tokens[i]
                        match(token.kind){
                            case IDENTIFIER => 
                                list.add(ArgSqlDSLPart(token.value))
                            case LCURL => 
                                var path = Tokens()
                                i++
                                while(i < tokens.size && token.kind != RCURL){
                                    path += tokens[i]
                                    i++
                                }
                                if((i < tokens.size && tokens[i].kind != RCURL) || tokens[tokens.size - 1].kind != RCURL){
                                    throw IllegalArgumentException('not completely data path in ${dsl}, it is lack of RCURL')
                                } else if (path.size == 0) {
                                    throw IllegalArgumentException('sql dsl can not be empty path in ${dsl} between :{ and }')
                                } else if (path.size == 1 && path[0].kind == IDENTIFIER) {
                                    list.add(ArgSqlDSLPart(path[0].value))
                                } else {
                                    if(path[0].kind != DOLLAR){
                                        path = Token(DOLLAR) + quote(.) + path
                                    }
                                    let name = path[path.size - 1].value
                                    let dataPath = DataPath.solid(path.toString())
                                    list.add(DataPathDSLPart(dataPath, name))
                                }
                            case _ => throw IllegalArgumentException('sql dsl can only be IDENTIFIER or LCURL after COLON, but it is ${token.kind} in ${dsl}')
                        }
                    }
                case IDENTIFIER => gen.append(token.value).append(' ')
                case _ => gen.append(token.value)
            }
            i++
        }
        if(gen.size > 0){
            list.add(StringSqlDSLPart(gen.toString()))
        }
        list
    }
}
private func convert<T>(exe: SqlExecutor, sqlgen: StringGenerator, name: String, data: ?Data): Unit {
    match(data){
        case Some(x: DataNone) => exe.argNull()
        case Some(x: DataBool) => exe.arg(x.data)
        case Some(x: DataDateTime) => exe.arg(x.data)
        case Some(x: DataDuration) => exe.arg(x.data)
        case Some(x: DataString) => exe.arg(x.data)
        case Some(x: DataCollection<Array<Byte>, Byte>) => exe.arg(x.data)
        case Some(x: DataReal) => exe.arg(x.data.toString())
        case Some(x: Iterable<Data>) => 
            var c = 0
            for(d in x){
                convert<T>(exe, sqlgen, name, d)
                if(c > 0){
                    sqlgen.append(',')
                }
                sqlgen.append('?')
                c++
            }
            return
        case x => throw IllegalArgumentException('${TypeInfo.of(x)} which field name is ${name} in ${TypeInfo.of<T>()} is not supported yet.')
    }
    sqlgen.append(' ? ')
}
internal func parseSqlFromMap(exe: SqlExecutor, dsl: String, arg: Map<String, Any>): String {
    let sqlgen = StringGenerator()
    for(part in compile(dsl)){
        match(part){
            case x: StringSqlDSLPart => sqlgen.append(x.partial)
            case p: ArgSqlDSLPart => match(p.get(arg)){
                case Some(x: ToData) => convert<Map<String, Any>>(exe, sqlgen, p.name, x.toData())
                case Some(x: InputStream) => 
                    exe.arg(x)
                    sqlgen.append(' ? ')
                case None => 
                    exe.argNull()
                    sqlgen.append(' ? ')
                case Some(x) => throw IllegalArgumentException('${TypeInfo.of(x)} which key is ${p.name} in current Map<String, Any> is not supported yet.')
            }
            case _: DataPathDSLPart => throw IllegalArgumentException('DataPathDSLPart cannot be used for Map<String, Any>')
            case _ => throw UnreachableException()
        }
    }
    sqlgen.toString()
}
internal func parseSqlFromObject<T>(exe: SqlExecutor, dsl: String, arg: T): String where T <: ObjectData<T> {
    let sqlgen = StringGenerator()
    let fields = T.dataFields()
    for(part in compile(dsl)){
        match(part){
            case x: StringSqlDSLPart => sqlgen.append(x.partial)
            case x: ArgSqlDSLPart => convert<T>(exe, sqlgen, x.name, x.get(arg))
            case x: DataPathDSLPart => convert<T>(exe, sqlgen, x.name, x.get(arg))
            case _ => throw UnreachableException()
        }
    }
    sqlgen.toString()
}
extend SqlExecutor <: SqlDSL {
    public func setSqlFromMap(dsl: String, arg: Map<String, Any>, clearArgsAfterExec!: Bool = true): SqlExecutor {
        let sql = parseSqlFromMap(this, dsl, arg)
        this.setSql(sql, clearArgsAfterExec: clearArgsAfterExec)
    }
    public func setSqlFromObject<T>(dsl: String, arg: T, clearArgsAfterExec!: Bool = true): SqlExecutor where T <: ObjectData<T> {
        let sql = parseSqlFromObject(this, dsl, arg)
        this.setSql(sql, clearArgsAfterExec: clearArgsAfterExec)
    }
}