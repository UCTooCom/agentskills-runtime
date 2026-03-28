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

import std.math.numeric.{BigInt, Decimal}
import std.time.DateTime

import f_base.*
import f_data.*

/**
 * 所有的DAO接口都要继承本接口
 */
public interface RootDAO {
    /**
     * 本接口函数不必实现，所有DAO都是SqlExecutor的扩展，SqlExecutor已经提供了相同声明的属性，
     * 且SqlExecutor已经实现本接口，故任意DAO接口可以直接调用本属性
     */
    prop executor: SqlExecutor

    func arg(value: Bool): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?Bool): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: Int8): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?Int8): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: UInt8): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?UInt8): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: Int16): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?Int16): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: UInt16): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?UInt16): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: Int32): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?Int32): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: UInt32): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?UInt32): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: Int64): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?Int64): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: UInt64): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?UInt64): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: Float16): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?Float16): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: Float32): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?Float32): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: Float64): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?Float64): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: BigInt): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?BigInt): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: Decimal): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?Decimal): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: Rune): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?Rune): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: String): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?String): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: InputStream): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?InputStream): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: Duration): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?Duration): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: DateTime): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?DateTime): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: Array<Byte>): String {
        executor.add(value)
        '?'
    }
    func arg(value: ?Array<Byte>): String {
        match(value){
            case Some(x) => arg(x)
            case _ => argNull()
        }
    }
    func arg(value: Data): String {
        match(value){
            case x: DataBool => arg(x.data)
            case x: DataReal => arg(x.data.toString())
            case x: DataString => arg(x.data)
            case x: DataDuration => arg(x.data)
            case x: DataDateTime => arg(x.data)
            case x: DataCollection<Array<Byte>, Byte> => arg(x.data)
            case x: DataAny => arg(x.data)
            case x: DataNone => argNull()
            case x => throw SqlArgException('${TypeInfo.of(x)} does not support for sql arg')
        }
    }
    func arg(value: Any): String {
        match(value){
            case x: Data => arg(x)
            case x: Bool => arg(x)
            case x: ?Bool => arg(x)
            case x: Int8 => arg(x)
            case x: ?Int8 => arg(x)
            case x: UInt8 => arg(x)
            case x: ?UInt8 => arg(x)
            case x: Int16 => arg(x)
            case x: ?Int16 => arg(x)
            case x: UInt16 => arg(x)
            case x: ?UInt16 => arg(x)
            case x: Int32 => arg(x)
            case x: ?Int32 => arg(x)
            case x: UInt32 => arg(x)
            case x: ?UInt32 => arg(x)
            case x: Int64 => arg(x)
            case x: ?Int64 => arg(x)
            case x: UInt64 => arg(x)
            case x: ?UInt64 => arg(x)
            case x: Float16 => arg(x)
            case x: ?Float16 => arg(x)
            case x: Float32 => arg(x)
            case x: ?Float32 => arg(x)
            case x: Float64 => arg(x)
            case x: ?Float64 => arg(x)
            case x: BigInt => arg(x)
            case x: ?BigInt => arg(x)
            case x: Decimal => arg(x)
            case x: ?Decimal => arg(x)
            case x: Float16 => arg(x)
            case x: ?Float16 => arg(x)
            case x: Rune => arg(x)
            case x: ?Rune => arg(x)
            case x: String => arg(x)
            case x: ?String => arg(x)
            case x: InputStream => arg(x)
            case x: ?InputStream => arg(x)
            case x: Duration => arg(x)
            case x: ?Duration => arg(x)
            case x: DateTime => arg(x)
            case x: ?DateTime => arg(x)
            case x: Array<Byte> => arg(x)
            case x: ?Array<Byte> => arg(x)
            case x: ?Any => match(x){
                case Some(y) => arg(y)
                case _ => argNull()
            }
            case x => throw SqlArgException('${TypeInfo.of(x)} does not support for sql arg')
        }
    }
    func arg<I, T>(value: I): String where I <: Iterable<T> {
        let frag = StringGenerator(' (')
        let s = frag.size
        for(v in value){
            if(frag.size > s){
                frag.append(',')
            }
            match(v){
                case x: Int8 => arg(x)
                case x: Int16 => arg(x)
                case x: Int32 => arg(x)
                case x: Int64 => arg(x)
                case x: UInt8 => arg(x)
                case x: UInt16 => arg(x)
                case x: UInt32 => arg(x)
                case x: UInt64 => arg(x)
                case x: Float16 => arg(x)
                case x: Float32 => arg(x)
                case x: Float64 => arg(x)
                case x: BigInt => arg(x)
                case x: Decimal => arg(x)
                case x: String => arg(x)
                case x: Duration => arg(x)
                case x: DateTime => arg(x)
                case x: InputStream => arg(x)
                case x: Array<Byte> => arg(x)
                case x: Rune => arg(x)
                case x: Bool => arg(x)

                case x: ?Int8 => arg(x)
                case x: ?Int16 => arg(x)
                case x: ?Int32 => arg(x)
                case x: ?Int64 => arg(x)
                case x: ?UInt8 => arg(x)
                case x: ?UInt16 => arg(x)
                case x: ?UInt32 => arg(x)
                case x: ?UInt64 => arg(x)
                case x: ?Float16 => arg(x)
                case x: ?Float32 => arg(x)
                case x: ?Float64 => arg(x)
                case x: ?BigInt => arg(x)
                case x: ?Decimal => arg(x)
                case x: ?String => arg(x)
                case x: ?Duration => arg(x)
                case x: ?DateTime => arg(x)
                case x: ?InputStream => arg(x)
                case x: ?Array<Byte> => arg(x)
                case x: ?Rune => arg(x)
                case x: ?Bool => arg(x)
                case _ => throw ORMException('type does not support')
            }
            frag.append('?')
        }
        if(frag.size == s){
            return ''
        }
        frag.append(')')
        frag.toString()
    }
    func argNull(){
        executor.addNull()
        '?'
    }
    func meet(condition: Bool, partial: ()->String): String {
        let sql = if(condition){
            partial()
        }else{
            ''
        }
        executor.partials.append(sql)
        sql
    }
    func meet(condition: Bool, partial: String): MeetCondition {
        MeetCondition(condition, partial, executor)
    }
    func meet(condition: Bool, partial: String, value: Any): String {
        meet(condition, partial){value}
    }
    func meet(condition: Bool, partial: String, value: ()->Any): String {
        meet(condition, partial).value(value).done()
    }
    
    prop choose: ChooseCondition {
        get() {
            ChooseCondition(executor)
        }
    }
    func loop<I, T>(values: I): LoopCondition<I, T> where I <: Iterable<T> {
        Condition.loop<I, T>(values, executor)
    }
    func IN<I, T>(value: I): String where I <: Iterable<T> {
        let args = arg<I, T>(value)
        if(args.isEmpty()){
            return ''
        }
        ' in ${args} '
    }
    func NOT_IN<I, T>(value: I): String where I <: Iterable<T> {
        let args = arg<I, T>(value)
        if(args.isEmpty()){
            return ''
        }
        ' not in ${args} '
    }
    func EXISTS(exists: () -> String): String {
        ' exists (${exists()}) '
    }
    func NOT_EXISTS(notExists: () -> String): String {
        ' not exists (${notExists()}) '
    }
    func SET(partial: () -> String): String {
        Condition.SET(partial)
    }
    func WHERE(partial: () -> String): String {
        Condition.WHERE(partial)
    }
    func WHERE(delimiter: String, partial: () -> String): String {
        Condition.WHERE(delimiter, partial)
    }
    func trim(prefix!: String, suffix!: String, partial!: () -> String): String {
        Condition.trim(prefix: prefix, suffix: suffix, partial: partial)
    }
}
