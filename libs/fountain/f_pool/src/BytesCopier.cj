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

import std.io.{InputStream, OutputStream}

public interface BytesCopyTo {
    func copy(to!: OutputStream, closeFromOnEnd!: Bool, closeToOnEnd!: Bool): Unit
}
public interface BytesCopyFrom {
    func copy(from!: InputStream, closeFromOnEnd!: Bool, closeToOnEnd!: Bool): Unit
}

public interface BytesCopier <: BytesCopyTo & BytesCopyFrom {}

public struct PooledBufferBytesCopyTo <: BytesCopyTo { 
    public PooledBufferBytesCopyTo(private let input: InputStream,
                                    private let pool: ArrayPool<Byte>){}
    public func copy(to!: OutputStream, closeFromOnEnd!: Bool = true, closeToOnEnd!: Bool = false): Unit {
        func copyTo(buf: Array<Byte>){
            try{
                while(let s <- input.read(buf) && s > 0){
                    to.write(buf[0..s])
                }
            }finally{
                if(closeFromOnEnd && let r: Resource <- input && !r.isClosed()){
                    r.close()
                }
                if(closeToOnEnd && let r: Resource <- to && !r.isClosed()){
                    r.close()
                }
            }
        }
        if(let Some(buf) <- pool.borrow()){
            try{
                copyTo(buf)
            }finally{
                pool.giveBack(buf)
            }
        }else{
            let buf = Array<Byte>(4096, repeat: 0)
            copyTo(buf)
        }
    }
}
public struct PooledBufferedBytesCopyFrom <: BytesCopyFrom {
    public PooledBufferedBytesCopyFrom(private let output: OutputStream,
                                        private let pool: ArrayPool<Byte>,
                                        private let closeOnEnd!: Bool = true){}
    public func copy(from!: InputStream, closeFromOnEnd!: Bool = false, closeToOnEnd!: Bool = true): Unit {
        func copyTo(buf: Array<Byte>){
            try{
                while(let s <- from.read(buf) && s > 0){
                    output.write(buf[0..s])
                }
            }finally{
                if(closeToOnEnd && let r: Resource <- output && !r.isClosed()){
                    r.close()
                }
                if(closeFromOnEnd && let r: Resource <- from && !r.isClosed()){
                    r.close()
                }
            }
        }
        if(let Some(buf) <- pool.borrow()){
            try{
                copyTo(buf)
            }finally{
                pool.giveBack(buf)
            }
        }else{
            copyTo(Array<Byte>(4096, repeat: 0))
        }
    }
}
public struct ChainedBytesCopyTo <: BytesCopyTo {
    public ChainedBytesCopyTo(private let bytes: Array<BytesCopyTo>){}
    public func copy(to!: OutputStream, closeFromOnEnd!: Bool = true, closeToOnEnd!: Bool = false): Unit {
        for(b in bytes){
            b.copy(to: to, closeFromOnEnd: closeFromOnEnd, closeToOnEnd: false)
        }
        if(closeToOnEnd && let r: Resource <- to && !r.isClosed()){
            r.close()
        }
    }
}