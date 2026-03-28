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
package f_base

public enum GrownArrayNewValue<T>{
    | First
    | Last
    | ZeroValue
    | Repeat
    | Other(T)
}
public interface ExtendArray<T>{
    prop size: Int64
    /**
     * 扩容数组，如果新的size小于当前数组大小会抛出IllegalArgumentException
     * 如果新的size等于当前数组大小仅仅是复制当前数组
     * 如果新的size大于当前数组大小，扩容的新值是new，默认是泛型实参的零值
     */
    func grow(size: Int64, new!: GrownArrayNewValue<T>): Array<T>
    /**
     * expandSize + size == grow的size参数
     */
    func expand(expandSize: Int64, new!: GrownArrayNewValue<T>): Array<T>{
        grow(expandSize + size, new: new)
    }
    /**
     * 扩容数组，如果新的size小于当前数组大小会抛出IllegalArgumentException
     * 如果新的size等于当前数组大小仅仅是复制当前数组
     * 如果新的size大于当前数组大小，扩容的新值是new(i)，调用new的第一个i是数组的size，第二个是size + 1，...。
     */
    func grow(size: Int64, new: (Int64) -> T): Array<T>
    /**
     * expandSize + size == grow的size参数，grow的new闭包参数 - size是expand的new闭包参数。
     */
    func expand(expandSize: Int64, new: (Int64) -> T): Array<T> {
        let s = size
        grow(expandSize + s){i => new(i - s)}
    }
    operator func *(repeat: Int64): Array<T>
}
extend<T> Array<T> <: ExtendArray<T> {
    private func check(size: Int64){
        if(size < this.size){
            throw IllegalArgumentException('new size must be greater than old, but new size is ${size} and current size is ${this.size}')
        }
    }
    public func grow(size: Int64, new!: GrownArrayNewValue<T> = ZeroValue): Array<T> {
        check(size)
        let s = this.size
        let newval = match(new){
            case First => this[0]
            case Last => this[this.size - 1]
            case ZeroValue => unsafe{zeroValue<T>()}
            case Other(v) => v
            case Repeat => return if(s == 1){
                let v = this[0]
                Array<T>(size){_ => v}
            }else{
                Array<T>(size){i => this[i % s]}
            }
        }
        Array<T>(size){i =>
            if(i < s){
                this[i]
            }else{
                newval
            }
        }
    }
    public func grow(size: Int64, new: (Int64) -> T): Array<T> {
        check(size)
        let s = this.size
        Array<T>(size){i => 
            if(i < s){
                this[i]
            }else{
                new(i)
            }
        }
    }
    public operator func *(repeat: Int64): Array<T>{
        grow(this.size * repeat, new: Repeat)
    }
}