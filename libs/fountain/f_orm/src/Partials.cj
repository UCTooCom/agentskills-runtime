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

internal class Partials {
    private let partials = StringGenerator()
    internal func clear(){
        partials.clear()
    }
    private func append(op: String, sql: String){
        if(sql.trimAscii().size > 0){
            partials.append(op).append(' ').append(sql).append(' ')
        }
    }
    private func append(op: String, sql: () -> Unit){
        let rel = ' ${op} '
        partials.append(rel)
        sql()
        if(partials.endsWith(rel)){
            partials.removeLast(rel)
        }
    }
    internal func append(sql: String): This {
        partials.append(sql)
        this
    }
    internal func AND(sql: String): Unit {
        append('and', sql)
    }
    internal func AND(sql: () -> Unit): Unit {
        append('and', sql)
    }
    internal func OR(sql: String): Unit {
        append('or', sql)
    }
    internal func OR(sql: () -> Unit): Unit {
        append('or', sql)
    }
    internal func NOT(sql: String): Unit {
        append('not', sql)
    }
    internal func NOT(sql: () -> Unit): Unit {
        append('not', sql)
    }
    internal func PAREN(sql: String): Unit {
        if(sql.trimAscii().size > 0){
            partials.append(' (').append(sql).append(') ')
        }
    }
    internal func PAREN(sql: () -> Unit): Unit {
        partials.append(' (')
        sql()
        if(partials.endsWith(' (')){
            partials.removeLast(' (')
        }else{
            partials.append(') ')
        }
    }
    internal operator func ()(sql: String): Unit {
        PAREN(sql)
    }
    internal operator func ()(sql: () -> Unit): Unit {
        PAREN(sql)
    }
    internal func toString(){
        partials.toString().trimAscii()
    }
}