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

import f_base.StringGenerator
import f_orm.exception.ORMException

public class LoopCondition<I, T> where I <: Iterable<T> {
    private var _wrapLeft = ''
    private var _wrapRight = ''
    private var _trimLeft = ''
    private var _trimRight = ''
    private var _delimiter = ''
    private var _argInSql = false
    private var _condition: (T, Int64) -> Bool = {v, i => true}
    private var _partial: (T, Int64) -> (String, Any) = {
        v, i => throw ORMException('partial for loop is not specified')
    }

    LoopCondition(private let values: I, private let executor: SqlExecutor) {}

    public func wrap(left: String, right: String): LoopCondition<I, T> {
        _wrapLeft = left
        _wrapRight = right
        this
    }
    public func wrapLeft(left: String): LoopCondition<I, T> {
        _wrapLeft = left
        this
    }
    public func wrapRight(right: String): LoopCondition<I, T> {
        _wrapRight = right
        this
    }
    public func trim(left: String, right: String): LoopCondition<I, T> {
        _trimLeft = left
        _trimRight = right
        this
    }
    public func trimLeft(left: String): LoopCondition<I, T> {
        _trimLeft = left
        this
    }
    public func trimRight(right: String): LoopCondition<I, T> {
        _trimRight = right
        this
    }
    public func delimiter(d: String): LoopCondition<I, T> {
        _delimiter = d
        this
    }
    public prop argInSql: LoopCondition<I, T> {
        get() {
            _argInSql = true
            this
        }
    }
    public func condition(cond: (T, Int64) -> Bool): LoopCondition<I, T> {
        _condition = cond
        this
    }
    public func partial(partial: (T, Int64) -> (String, Any)): LoopCondition<I, T> {
        _partial = partial
        this
    }
    public func partial(partial: (T, Int64) -> Any): LoopCondition<I, T> {
        func callee(v: T, i: Int64): (String, Any) {
            ('', partial(v, i))
        }
        this.partial(callee)
    }
    public func done(): String {
        let sqlFrag = Condition.trim(prefix: _trimLeft, suffix: _trimRight) {
            let builder = StringGenerator()
            var i = 0
            for (v in values where _condition(v, i)) {
                if (builder.size > 0) {
                    builder.append(' ')
                    builder.append(_delimiter)
                    builder.append(' ')
                }
                let (frag, arg) = _partial(v, i)
                builder.append(frag)
                if (_argInSql) {
                    match (arg) {
                        case x: ToString => builder.append(x)
                        case x =>
                            executor.add(arg)
                            builder.append('?')
                    }
                } else {
                    executor.add(arg)
                    builder.append('?')
                }
                i++
            }
            builder.toString()
        }
        ' ${_wrapLeft} ${sqlFrag} ${_wrapRight} '
    }
}
