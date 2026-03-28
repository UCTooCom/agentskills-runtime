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

import std.collection.ArrayList
import f_orm.exception.ORMException

public class ChooseCondition {
    private static let emptyPartial: () -> (String, Any) = {=> ('', '')}
    private let conditions = ArrayList<(() -> Bool, () -> (String, Any))>()
    private var _otherwise: () -> (String, Any) = emptyPartial
    private var pair = true
    private var _argInSql: Bool = false
    public ChooseCondition(private let executor: SqlExecutor) {}
    public prop argInSql: ChooseCondition {
        get() {
            _argInSql = true
            this
        }
    }
    public func condition(condition: () -> Bool): ChooseCondition {
        if (pair) {
            pair = false
            conditions.add((condition, emptyPartial))
            this
        } else {
            throw ORMException('condition and sql partial generation function arg not paring')
        }
    }
    public func partial(partial: () -> (String, Any)): ChooseCondition {
        if (pair) {
            throw ORMException('condition and sql partial generation function arg not paring')
        } else {
            pair = true
            let idx = conditions.size - 1
            let (c, _) = conditions[idx]
            conditions[idx] = (c, partial)
            this
        }
    }
    private func callee(partial: () -> Any): () -> (String, Any) {
        {=> ('', partial())}
    }
    private func callee(partial: () -> String): () -> (String, Any){
        {=> (partial(), ())}
    }
    public func partial(partial: () -> Any): ChooseCondition {
        this.partial(callee(partial))
    }
    public func partial(partial: () -> String): ChooseCondition {
        this.partial(callee(partial))
    }
    public func otherwise(partial: () -> (String, Any)): ChooseCondition {
        _otherwise = partial
        this
    }
    public func otherwise(partial: () -> String): ChooseCondition {
        otherwise(callee(partial))
    }
    public func otherwise(partial: () -> Any): ChooseCondition {
        otherwise(callee(partial))
    }
    public func done(): String {
        if (!pair) {
            throw ORMException('condition and sql partial generation function arg not paring')
        }
        func gen(partial: () -> (String, Any)) {
            let (frag, arg) = partial()
            if (frag.size > 0) {
                if (_argInSql) {
                    match (arg) {
                        case _: Unit => ' ${frag} ${Condition.delimiter} '
                        case x: ToString => ' ${frag} ${x} ${Condition.delimiter} '
                        case x =>
                            executor.add(arg)
                            ' ${frag} ? ${Condition.delimiter} '
                    }
                } else {
                    executor.add(arg)
                    ' ${frag} ? ${Condition.delimiter} '
                }
            } else if (_argInSql) {
                match (arg) {
                    case x: ToString => ' ${x} ${Condition.delimiter} '
                    case x =>
                        executor.add(arg)
                        ' ? ${Condition.delimiter} '
                }
            } else {
                executor.add(arg)
                ' ? ${Condition.delimiter} '
            }
        }
        func gen(){
            for ((cond, partial) in conditions where cond()) {
                return gen(partial)
            }
            gen(_otherwise)
        }
        let sql = gen()
        executor.partials.append(sql)
        sql
    }
}
