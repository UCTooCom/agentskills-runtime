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
package f_mockdb

public class MockTransaction <: Transaction {
    private var accessMode_ = TransactionAccessMode.Unspecified
    private var deferrableMode_ = TransactionDeferrableMode.Unspecified
    private var isoLevel_ = TransactionIsoLevel.Unspecified
    public mut prop accessMode: TransactionAccessMode {
        get(){
            accessMode_
        }
        set(value){
            accessMode_ = value
        }
    }
    public mut prop deferrableMode: TransactionDeferrableMode{
        get(){
            deferrableMode_
        }
        set(value){
            deferrableMode_ = value
        }
    }
    public mut prop isoLevel: TransactionIsoLevel {
        get(){
            isoLevel_
        }
        set(value){
            isoLevel_ = value
        }
    }
    public func begin(): Unit {
        output.writeln('Transaction beginning, threadID: ${MOCKDB.currentThreadId}')
        if(MOCKDB.toThrowOnBeginning){
            throw MockDbException()
        }
    }
    public func commit(): Unit {
        output.writeln('Transaction committing, threadID: ${MOCKDB.currentThreadId}')
        if(MOCKDB.toThrowOnCommitting){
            throw MockDbException()
        }
    }
    public func release(savePointName: String): Unit {
        output.writeln('Transaction releasing, threadID: ${MOCKDB.currentThreadId}')
        if(MOCKDB.toThrowOnReleasing(savePointName)){
            throw MockDbException()
        }
    }
    public func rollback(): Unit {
        output.writeln('Transaction rollbacking, threadID: ${MOCKDB.currentThreadId}')
        if(MOCKDB.toThrowOnRollbacking){
            throw MockDbException()
        }
    }
    public func rollback(savePointName: String): Unit {
        output.writeln('Transaction rollbacking, threadID: ${MOCKDB.currentThreadId}; savePoint: ${savePointName}')
        if(MOCKDB.toThrowOnRollbacingSavePoint(savePointName)){
            throw MockDbException()
        }
    }
    public func save(savePointName: String): Unit {
        output.writeln('Transaction save, threadID: ${MOCKDB.currentThreadId}; savePoint: ${savePointName}')
        if(MOCKDB.toThrowOnSavingSavePoint(savePointName)){
            throw MockDbException()
        }
    }
}