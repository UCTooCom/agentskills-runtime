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

import std.io.{OutputStream, StringWriter, ByteBuffer}
import std.collection.ArrayList

public func printStackTrace(exception: Exception, output: OutputStream): Unit {
    printStackTrace(output) {
        buf =>
        buf.write("An exception has occured:${OS.current.nextLine}${exception}${OS.current.nextLine}".unsafeBytes())
        for (stack in exception.getStackTrace()) {
            buf.write(
                "         at ${stack.declaringClass}.${stack.methodName}(${stack.fileName}: ${stack.lineNumber})${OS.current.nextLine}"
                    .unsafeBytes())
        }
    }
}

private func printStackTrace(output: OutputStream, callee: (ByteBuffer) -> Unit) {
    if (let buffer: ByteBuffer <- output) {
        callee(buffer)
    } else {
        let buffer = ByteBuffer()
        callee(buffer)
        output.write(buffer.bytes())
        output.flush()
    }
}

public open class BaseException <: Exception {
    private var caused_ = None<Exception>
    private var suppressed_ = ArrayList<Exception>()

    public init() {}

    public init(message: String) {
        super(message)
    }
    public init(caused: Exception) {
        caused_ = caused
    }
    public init(message: String, caused: Exception) {
        this(message)
        caused_ = caused
    }

    public func addSuppressed(suppressed: Exception): Unit {
        this.suppressed_.add(suppressed)
    }
    public prop caused: Option<Exception> {
        get() {
            caused_
        }
    }
    public prop suppressed: ArrayList<Exception> {
        get() {
            suppressed_
        }
    }
    public func printStackTrace(output: OutputStream): Unit {
        printStackTrace(output) {
            w =>
            printStackTrace(this, w)
            if (let Some(c) <- caused) {
                w.write("Caused by: ".unsafeBytes())
                printStackTrace(c, w)
            }
            if (!suppressed.isEmpty()) {
                w.write("Suppressed: ".unsafeBytes())
                for (s in suppressed) {
                    printStackTrace(s, w)
                }
            }
        }
    }
}
