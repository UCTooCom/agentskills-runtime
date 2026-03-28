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

import std.env.getStdOut
internal import std.reflect.*
internal import std.collection.{HashMap, Map, ArrayList}
internal import std.env.ConsoleWriter
public import std.database.sql.*

internal let output = getStdOut()

public class MOCKDB {
    private init(){}

    private static let execution_ = ThreadLocal<() -> Unit>()
    private static let queryResultList_ = ThreadLocal<ArrayList<Array<Any>>>()
    private static let queryResultColumnInfos_ = ThreadLocal<ArrayList<ColumnInfo>>()
    private static let lastInsertId_ = ThreadLocal<Int64>()
    private static let rowCount_ = ThreadLocal<Int64>()
    private static let toThrowOnExecuting_ = ThreadLocal<(String, ArrayList<Any>) -> Bool>()
    private static let metadata_ = ThreadLocal<Map<String, String>>()
    private static let toThrowOnBeginning_ = ThreadLocal<Bool>()
    private static let toThrowOnCommitting_ = ThreadLocal<Bool>()
    private static let toThrowOnReleasing_ = ThreadLocal<HashMap<String, Bool>>()
    private static let toThrowOnRollbacking_ = ThreadLocal<Bool>()
    private static let toThrowOnRollbackingSavePoint_ = ThreadLocal<HashMap<String, Bool>>()
    private static let toThrowOnSavingSavePoint_ = ThreadLocal<HashMap<String, Bool>>()

    static func clear(): Unit {
        execution_.set(None)
        queryResultList_.set(None)
        queryResultColumnInfos_.set(None)
        lastInsertId_.set(None)
        rowCount_.set(None)
        toThrowOnExecuting_.set(None)
        metadata_.set(None)
        toThrowOnBeginning_.set(None)
        toThrowOnCommitting_.set(None)
        toThrowOnReleasing_.set(None)
        toThrowOnRollbacking_.set(None)
        toThrowOnRollbackingSavePoint_.set(None)
        toThrowOnSavingSavePoint_.set(None)
    }

    static prop currentThreadId: Int64 {
        get(){
            Thread.currentThread.id
        }
    }
    /**
     * 本函数会在MockConnection构造函数执行，可以在本函数执行本类的其他函数
     */
    public static mut prop execution: () -> Unit {
        get(){
            execution_.get() ?? {=>}
        }
        set(value){
            execution_.set(value)
        }
    }
    public static func addQueryResultRow(row: Array<Any>): Unit {
        if(let Some(list) <- queryResultList_.get()){
            list
        }else {
            let list = ArrayList<Array<Any>>()
            queryResultList_.set(list)
            list
        }.add(row)
    }
    public static func getQueryResultRows(): ArrayList<Array<Any>> {
        queryResultList_.get() ?? ArrayList<Array<Any>>()
    }
    public static func addQueryResultColumnInfo(
        name!: String, nullable!: Bool, typeName!: String
    ){
        let info = MockColumnInfo(name, nullable, typeName)
        if(let Some(list) <- queryResultColumnInfos_.get()){
            list
        }else{
            let list = ArrayList<ColumnInfo>()
            queryResultColumnInfos_.set(list)
            list
        }.add(info)
    }
    public static prop queryResultColumnInfos: Array<ColumnInfo> {
        get(){
            (queryResultColumnInfos_.get()?.toArray()) ?? []
        }
    }
    public static mut prop lastInsertId: Int64 {
        get(){
            lastInsertId_.get() ?? 0
        }
        set(value){
            lastInsertId_.set(value)
        }
    }
    public static mut prop rowCount: Int64 {
        get(){
            rowCount_.get() ?? 0
        }
        set(value){
            rowCount_.set(value)
        }
    }
    public static mut prop toThrowOnExecuting: (String, ArrayList<Any>) -> Bool {
        get() {
            toThrowOnExecuting_.get() ?? {_, _ => false}
        }
        set(value){
            toThrowOnExecuting_.set(value)
        }
    }
    public static mut prop metadata: Map<String, String> {
        get(){
            metadata_.get() ?? HashMap<String, String>()
        }
        set(value){
            metadata_.set(value)
        }
    }
    public static mut prop toThrowOnBeginning: Bool {
        get(){
            toThrowOnBeginning_.get() ?? false
        }
        set(value){
            toThrowOnBeginning_.set(value)
        }
    }
    public static mut prop toThrowOnCommitting: Bool {
        get(){
            toThrowOnCommitting_.get() ?? false
        }
        set(value){
            toThrowOnCommitting_.set(value)
        }
    }
    public static func toThrowOnReleasing(savepoint: String, toThrow: Bool): Unit {
        match(toThrowOnReleasing_.get()){
            case Some(m) => m[savepoint] = toThrow
            case _ =>
                let m = HashMap<String, Bool>()
                toThrowOnReleasing_.set(m)
                m[savepoint] = toThrow
        }
    }
    public static func toThrowOnReleasing(savepoint: String){
        if(let Some(m) <- toThrowOnReleasing_.get()){
            m.get(savepoint) ?? false
        }else{
            false
        }
    }
    public static mut prop toThrowOnRollbacking: Bool {
        get(){
            toThrowOnRollbacking_.get() ?? false
        }
        set(value){
            toThrowOnRollbacking_.set(value)
        }
    }
    public static func toThrowOnRollbacingSavePoint(savepoint: String, toThrow: Bool): Unit {
        match(toThrowOnRollbackingSavePoint_.get()){
            case Some(m) => m[savepoint] = toThrow
            case _ =>
                let m = HashMap<String, Bool>()
                toThrowOnRollbackingSavePoint_.set(m)
                m[savepoint] = toThrow
        }
    }
    public static func toThrowOnRollbacingSavePoint(savepoint: String){
        if(let Some(m) <- toThrowOnRollbackingSavePoint_.get()){
            m.get(savepoint) ?? false
        }else{
            false
        }
    }
    
    public static func toThrowOnSavingSavePoint(savepoint: String, toThrow: Bool): Unit {
        match(toThrowOnSavingSavePoint_.get()){
            case Some(m) => m[savepoint] = toThrow
            case _ =>
                let m = HashMap<String, Bool>()
                toThrowOnSavingSavePoint_.set(m)
                m[savepoint] = toThrow
        }
    }
    public static func toThrowOnSavingSavePoint(savepoint: String){
        if(let Some(m) <- toThrowOnSavingSavePoint_.get()){
            m.get(savepoint) ?? false
        }else{
            false
        }
    }
}