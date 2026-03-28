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
package f_log.output

import std.collection.concurrent.ArrayBlockingQueue
import f_io.*

@When[os == "Linux"]
protected class RotatableMMapFile <: OutputStream & Resource {
    private let q = ArrayBlockingQueue<Unit>(1)
    RotatableMMapFile(
        private let file: RotatableFile,
        private var mmap_: MMapFile
    ){
        spawn{
            while(let _ <- q.remove()){
                mmap_.flush()
            }
        }
    }
    func setLength(){
        mmap.setLength()
    }
    mut prop mmap: MMapFile {
        get(){
            mmap_
        }
        set(value){
            mmap_ = value
        }
    }
    protected prop path: String {
        get() {
            mmap.info.path.toString()
        }
    }
    public func isClosed() {
        file.isClosed()
    }
    public func close() {
        file.close()
    }
    public func write(buffer: Array<UInt8>): Unit {
        file.rotateFileIfNeed(buffer.size)
        mmap.write(buffer)
        q.tryAdd(())
    }
}