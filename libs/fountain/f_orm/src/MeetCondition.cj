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

public class MeetCondition {
    //condition: Bool, sqlFrag: String, argInSql!: Bool, value!: () -> ToString
    private var _argInSql = false
    private var _value: () -> Any = {=> ''}
    public MeetCondition(private let condition: Bool, private let partial: String, private let executor: SqlExecutor) {}

    public prop argInSql: MeetCondition {
        get() {
            _argInSql = true
            this
        }
    }
    public func value(value: () -> Any): MeetCondition {
        this._value = value
        this
    }
    public func value(value: Any): MeetCondition {
        this._value = {=> value}
        this
    }
    public func frag(frag: String): String {
        this.frag{frag}
    }
    public func frag(frag: () -> String): String {
        let sql = if(condition){
            '${partial} ${frag()} ${Condition.delimiter}'
        }else{
            ''
        }
        executor.partials.append(sql)
        sql
    }
    public func BETWEEN(one: Any, two: Any): String {
        frag{
            if(_argInSql && let (x: ToString, y: ToString) <- (one, two)){
                ' between ${x} and ${y} '
            }else{
                executor.add(one)
                executor.add(two)
                ' between ? and ? '
            }
        }
    }
    public func NOT_BETWEEN(one: Any, two: Any): String {
        frag{
            if(_argInSql && let (x: ToString, y: ToString) <- (one, two)){
                ' not between ${x} and ${y} '
            }else{
                executor.add(one)
                executor.add(two)
                ' not between ? and ? '
            }
        }
    }
    public func IN<I, T>(itr: I): String where I <: Iterable<T> {
        frag{
            let builder = StringBuilder(' in (')
            var i = 0
            for(v in itr){
                if(i > 0){
                    builder.append(',')
                }
                if(_argInSql && let x: ToString <- v){
                    builder.append(x)
                }else{
                    executor.add(v)
                    builder.append('?')
                }
                i++
            }
            builder.append(') ')
            builder.toString()
        }
    }
    public func NOT_IN<I, T>(itr: I): String where I <: Iterable<T> {
        frag{
            let builder = StringBuilder(' not in (')
            var i = 0
            for(v in itr){
                if(i > 0){
                    builder.append(',')
                }
                if(_argInSql && let x: ToString <- v){
                    builder.append(x)
                }else{
                    executor.add(v)
                    builder.append('?')
                }
                i++
            }
            builder.append(') ')
            builder.toString()
        }
    }
    public func EXISTS(fn: () -> String): String {
        frag {
            ' exists (${fn()})'
        }
    }
    public func NOT_EXISTS(fn: () -> String): String {
        frag {
            ' not exists (${fn()})'
        }
    }
    public func done(): String {
        frag{
            if(_argInSql){
                match(_value()){
                    case x: ToString => x.toString()
                    case x =>
                        executor.add(x)
                        '?'
                }
            }else{
                executor.add(_value())
                '?'
            }
        }
    }
}
