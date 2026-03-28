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

public interface ExtendString {
    prop AND: String
    prop OR: String
    prop NOT: String
    operator func ()(sql: String): String
    operator func ()(sql: () -> Unit): String
}
extend String <: ExtendString {
    private func getPartials(){
        SqlExecutor.getCurrent().partials
    }
    private func append(sql: String){
        getPartials().append(' ').append(sql).append(' ')
        ''
    }
    public prop AND: String {
        get(){
            append(' and ')
        }
    }
    public prop OR: String {
        get(){
            append(' or ')
        }
    }
    public prop NOT: String {
        get(){
            append(' not ')
        }
    }
    public operator func ()(sql: String): String {
        getPartials()(sql)
        ''
    }
    public operator func ()(sql: () -> Unit): String {
        getPartials()(sql)
        ''
    }
}