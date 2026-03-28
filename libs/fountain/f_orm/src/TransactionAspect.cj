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

import std.reflect.*
import f_aspect.*
import f_base.*
import f_bean.{BeanFactory, BeanMeta}
import f_orm.wrap.ORMConfig
public import f_aspect.*

@AspectRoute[FuncAnnotationRouteRule("f_orm.Transactional") | ConfigExecutionRouteRule(ORMConfig.transactionalFuncExecution)]
@BeanMeta
public class TransactionAspect <: Aspect {
    static init() {
        BeanFactory.instance.register<TransactionAspect>({=> TransactionAspect()})
    }
    private init() {}

    public func proceed(funcInfo: InvocationFuncInfo, point: (Array<Any>) -> Any): Any {
        let transactional = funcInfo.funcInfo.findAnnotation<Transactional>()
        var driverName = ""
        var propagation = None<Propagation>
        var isoLevel = None<TransactionIsoLevel>
        var accessMode = None<TransactionAccessMode>
        var deferrableMode = None<TransactionDeferrableMode>
        var noRollbackFor = None<String>
        var rollbackFor = None<String>
        if (let Some(x) <- transactional) {
            driverName = x.driverName
            propagation = x.propagation
            isoLevel = x.isoLevel
            accessMode = x.accessMode
            deferrableMode = x.deferrableMode
            noRollbackFor = x.noRollbackFor
            rollbackFor = x.rollbackFor
        }
        if (propagation.isNone()) {
            propagation = ORMConfig.getTransactionPropagation(driverName: driverName)
        }
        if (isoLevel.isNone()) {
            isoLevel = ORMConfig.getTransactionLevel(driverName: driverName)
        }
        if (accessMode.isNone()) {
            accessMode = ORMConfig.getTransactionAccessMode(driverName: driverName)
        }
        if (deferrableMode.isNone()) {
            deferrableMode = ORMConfig.getTransactionDeferrableMode(driverName: driverName)
        }
        if(noRollbackFor.isNone()){
            noRollbackFor = ORMConfig.getTransactionNoRollbackFor(driverName: driverName)
        }
        if(rollbackFor.isNone()){
            rollbackFor = ORMConfig.getTransactionRollbackFor(driverName: driverName)
        }
        let exe = ORM.executor(driverName) // 如果此处发生异常就无所谓回滚事务了，所以ORM.executor(driverName)不必在try块内
        exe.execute<Any>(
            propagation: propagation ?? Propagation.Required,
            isoLevel: isoLevel,
            accessMode: accessMode,
            deferrableMode: deferrableMode,
            noRollbackFor: noRollbackFor,
            rollbackFor: rollbackFor
        ){_ => (point(funcInfo.args), true)}
    }
}
