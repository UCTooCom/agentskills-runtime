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
package f_mvc

public class FileDownload {
    private static let random = RandomString()
    private let responseBuilder: HttpResponseBuilder
    private let writer: HttpResponseWriter
    private let built = AtomicBool(false)
    private let boundary = "----${random.randomLettersNumbers(32)}"
    public FileDownload(private let ctx: HttpContext, private let multi!: Bool = false,
        private let contentType!: String = "application/octet-stream") {
        responseBuilder = ctx.responseBuilder
        writer = HttpResponseWriter(ctx)
    }
    public func noContent(): Unit {
        let status = HttpStatus.NO_CONTENT
        responseBuilder.status(status.value).body(status.reasonPhrase).build()
    }
    public func write(file: File): Unit {
        let info = file.info
        if (info.isRegular()) {
            write(info.path.fileName, file, length: info.size)
        } else {
            throw HttpResponseException("${info.path} is not a file")
        }
    }
    public func write(filename: String, input: InputStream, length!: Int64 = -1) {
        if (!built.load()) {
            if (multi) {
                responseBuilder.header("Content-Type", "multipart/x-mixed-replace; boundary=${boundary}")
                responseBuilder.build()
                write("--${boundary}\r\n")
            } else {
                responseBuilder.header("Content-Disposition", attachment(filename))
                responseBuilder.header("Content-Type", contentType)
                if (length >= 0) {
                    responseBuilder.header("Content-Length", length.toString())
                }
                responseBuilder.build()
            }
            built.store(true)
        }
        func write() {
            let buf = Array<Byte>(MVCConfig.downloadBufferSize, repeat: 0)
            while (let len <- input.read(buf)) {
                if (len > 0) {
                    writer.write(buf[0..len])
                } else {
                    break
                }
            }
        }

        if (multi) {
            write("Content-Disposition: ${attachment(filename)}\r\n")
            if (length >= 0) {
                write("Content-Length: ${length}\r\n")
            }
            write("Content-Type: ${contentType}\r\n\r\n")
            write()
            write("\r\n--${boundary}\r\n")
        } else {
            write()
            end()
        }
    }
    public func end() {
        if (multi) {
            write("--${boundary}--")
        }
    }
    private func attachment(filename: String) {
        "attachment, filename=\"${filename}\""
    }
    private func write(header: String) {
        writer.write(header.unsafeBytes())
    }
}
