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
package f_pool

import std.collection.ArrayList
import std.io.OutputStream

public class BytesListOutputStream <: OutputStream & BytesCopyTo {
    BytesListOutputStream(private let list: ArrayList<Array<Byte>>, private let pool: ArrayListPool<Array<Byte>>){}
    public func write(bytes: Array<Byte>): Unit {
        list.add(bytes)
    }
    public func copy(to!: OutputStream, closeFromOnEnd!: Bool = true, closeToOnEnd!: Bool = false): Unit {
        try{
            for(bytes in list){
                to.write(bytes)
            }
        }finally{
            pool.giveBack(list)
            if(closeToOnEnd && let r: Resource <- to && !r.isClosed()){
                r.close()
            }
        }
    }
    public static func builder(
        initSize!: Int64 = 1024,
        minSize!: Int64 = 1024,
        maxSize!: Int64 = 1024,
        elementLife!: Duration = Duration.Max,
        checkInterval!: Duration = Duration.Max,
        clearOnReturning!: Bool = true,
        capacity!: Int64 = 16
    ): BytesListOutputStreamBuilder {
        BytesListOutputStreamBuilder(initSize, minSize, maxSize, elementLife, checkInterval, clearOnReturning, capacity)
    }
}
public class BytesListOutputStreamBuilder {
    private let pool: ArrayListPool<Array<Byte>>
    init(
        initSize: Int64, minSize: Int64, maxSize: Int64, elementLife: Duration, checkInterval: Duration, clearOnReturning: Bool, capacity: Int64
    ){
        pool = ArrayListPool<Array<Byte>>(
            initSize: initSize,
            minSize: minSize,
            maxSize: maxSize,
            elementLife: elementLife,
            checkInterval: checkInterval,
            clearOnReturning: clearOnReturning)
    }
    public func build(timeout!: Duration = Duration.Max): ?BytesListOutputStream {
        if(let Some(l) <- pool.borrow(timeout: timeout)){
            BytesListOutputStream(l, pool)
        }else{
            None<BytesListOutputStream>
        }
    }
}