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

public class TransactionTest <: Transaction {
    public mut prop accessMode: TransactionAccessMode{
        get(){
            ReadWrite
        }
        set(value){

        }
    }
    public mut prop deferrableMode: TransactionDeferrableMode{
        get(){
            Deferrable
        }
        set(value){

        }
    }
    public mut prop isoLevel: TransactionIsoLevel{
        get(){
            RepeatableRead
        }
        set(value){

        }
    }
    public func begin(): Unit{}
    public func commit(): Unit{}
    public func release(savePointName: String): Unit{}
    public func rollback(): Unit{}
    public func rollback(savePointName: String): Unit{}
    public func save(savePointName: String): Unit{}
}