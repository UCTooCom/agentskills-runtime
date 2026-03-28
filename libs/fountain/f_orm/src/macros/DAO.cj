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
macro package f_orm.macros

import std.ast.*
import f_macros.*

//DAO 接口必须是public，不能带泛型形参，且必须继承orm.RootDAO
//在DAO接口函数的默认实现添加生成sql和调用RootDAO函数完成访问数据库的工作
//一个持久化对象一个DAO接口
//模块内的DAO接口的函数声明不能重名。
//对于良好的编程实践，由于DAO接口不应该暴露到模块外面，一个包内导入的DAO接口函数不重名就不会有影响，
//不同包内导入的不同DAO接口函数重名也不会有影响，不过原则上还是不建议这样做。
//实际使用时，在Service层应该是有类似以下代码
//    //Service层的代码
//    package fountain.apppack.service
//    import apppack.model.ArgData
//    import apppack.model.po.SomePO
//    import fountain.orm.RootService
//    public interface SomePOService <: RootService{
//        func queryData(arg: ArgData): ArrayList<SomePO>
//    }
//    //===========================
//    package fountain.apppack.service.impl
//    import fountain.orm.{ORM, SqlExecutor}
//    import apppack.service.SomePOService
//    import apppack.model.ArgData
//    import apppack.model.po.SomePO
//    import apppack.dao.SomePODAO
//    public class SomePOServiceImpl <: SomePOService{
//        public func queryData(arg: ArgData): ArrayList<SomePO>{
//            executor().execute<ArrayList<SomePO>>{exe: SqlExecutor =>
//                exe.listSomePO(arg)
//            }
//        }
//    }
//    //DAO层的代码
//    package fountain.apppack.dao
//    import fountain.base.*
//    import fountain.orm.*
//    import apppack.model.ArgData
//    import apppack.model.po.SomePO
//    @DAO
//    public interface SomeDAO {
//        prop executor: SqlExecutor//所有dao必须有这一行
//        func listSomePO(arg: ArgData): ArrayList<SomePO>{
//            executor.setSql(
//                """
//                select *
//                  from some_table
//                 WHERE('and'){'''
//                       id = ${arg(arg.id)}
//                   and ${meet(arg.name != String.empty, " `name` like ").value{"${arg.name}%"}.donw()}
//                   and ${meet(arg.minBirthday.isSome() && arg.maxBirthday.isSome(), " birthday ").BETWEEN(arg.minBirthday.getOrThrow(), arg.maxBirthday.getOrThrow())}")}
//                 ''''
//                }
//                """
//            ).list<SomePO>(somePOMappers)
//        }
//        prop somePOMappers: QueryMappers<SomePO>{
//            get(){
//                QueryMappers<SomePO>(
//                    mappers: [QueryMapper<SomePO>(
//                        index: 0,
//                        name: "id",
//                        dataType: int64,
//                        putter: {o: SomePO, v: Any => o.id = orm.convert<Int64>(v)}
//                    ), QueryMapper<SomePO>(
//                        index: 1,
//                        name: "name",
//                        dataType: string,
//                        putter: {o: SomePO, v: Any => o.name = orm.convert<String>(v)}
//                    ),...],
//                    creator: {=> SomePO()}
//                )
//            }
//        }
//    }
public macro DAO(input: Tokens): Tokens {
    match (parseDecl(input)) {
        case d: InterfaceDecl => expand(d, input)
        case d: MacroExpandDecl => match (extract(d)) {
            case x: InterfaceDecl => expand(x, input)
            case _ => reportError(input)
        }
        case _ => reportError(input)
    }
}

private func expand(d: InterfaceDecl, input: Tokens): Tokens {
    quote(
        $input
        extend SqlExecutor <: $(d.identifier){}
    )
}

private func reportError(input: Tokens) {
    diagReport(ERROR, input, 'input must be interface decl', '')
    throw IllegalArgumentException("input must be a interface decl")
}
