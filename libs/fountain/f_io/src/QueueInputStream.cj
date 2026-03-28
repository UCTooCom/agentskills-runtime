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
package f_io

sealed abstract class QueueInputStream <: InputStream {
    protected let queue: ArrayBlockingQueue<InputStream>

    public QueueInputStream(size: Int64, protected let closeOnEnd!: Bool = true){
        queue = ArrayBlockingQueue<InputStream>(size)
    }
    public func add(stream: InputStream){
        queue.add(stream)
    }
    public func add(bytes: Array<Byte>){
        add(ByteBuffer(bytes))
    }
}
public class NonblockingQueueStream <: QueueInputStream {
    public init(size: Int64, closeOnEnd!: Bool = true) {
        super(size, closeOnEnd: closeOnEnd)
    }
    public func read(buffer: Array<Byte>): Int64 {
        while (let Some(q) <- queue.peek() && let s <- q.read(buffer)) {
            if (s == 0) {
                if(closeOnEnd && let r: Resource <- queue.remove() && !r.isClosed()) {
                    r.close()
                }
                continue
            }
            return s
        }
        0
    }
}
public class BlockingQueueStream <: QueueInputStream {
    private var current = None<InputStream>
    public init(size: Int64, closeOnEnd!: Bool = true) {
        super(size, closeOnEnd: closeOnEnd)
    }
    public func read(buffer: Array<Byte>): Int64 {
        while (true) {
            if (let Some(input) <- current) {
                if(let s <- input.read(buffer) && s > 0){
                    return s
                }else if(closeOnEnd && let r: Resource <- input && !r.isClosed()) {
                    r.close()
                }
            }
            current = queue.remove()
        }
        0
    }
}