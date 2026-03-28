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
package f_http

public class MultipartFile <: Multipart & InputStream & Resource & DataFields<MultipartFile> & Data {
    MultipartFile(
        contentDisposition: ContentDisposition,
        public let content: InputStream,
        private let charset!: Charset = Charsets.UTF8
    ) {
        super(contentDisposition)
    }
    ~init() {
        doClose(content, toThrow: false)
    }
    public func toData(): Data {
        this
    }
    public func toString(): String {
        throw MediaTypeException('Not Supported')
    }
    public static func fromData(data: Data){
        fromData(data, DEFAULT_DATA_FLAG)
    }
    public static func tryFromData(data: Data){
        tryFromData(data, DEFAULT_DATA_FLAG)
    }
    public static func fromData(data: Data, flag: DataConversionFlag): Any {
        tryFromData(data, flag)
    }
    public static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        throw MediaTypeException('Not Supported')
    }
    public static func parse(string: String): Data {
        tryParse(string).getOrThrow()
    }
    public static func tryParse(string: String): ?Data {
        throw MediaTypeException('Not Supported')
    }
    public prop empty: Bool {
        get() {
            size == 0
        }
    }
    func setType(`type`: String): Unit {
        contentDisposition.setType(ContentDispositionType.tryParse(`type`).getOrThrow())
    }
    public prop isAttachment: Bool {
        get() {
            contentDisposition.isAttachment
        }
    }
    public prop isInline: Bool {
        get() {
            contentDisposition.isInline
        }
    }
    public prop isFormData: Bool {
        get() {
            contentDisposition.isFormData
        }
    }
    public func getType(): ContentDispositionType {
        contentDisposition.getType()
    }
    func setFilename(filename: String): Unit {
        contentDisposition.setFilename(filename)
    }
    public prop filename: String {
        get() {
            contentDisposition.getFilename()
        }
    }
    func setSize(size: Int64): Unit {
        contentDisposition.setSize(size)
    }
    public prop size: Int64 {
        get() {
            contentDisposition.getSize()
        }
    }

    public func read(buffer: Array<Byte>): Int64 {
        content.read(buffer)
    }
    public func copyTo(output: OutputStream): Unit {
        try {
            match (content) {
                case input: ByteBuffer => copy(input, to: output)
                case file: File => copy(file, to: output)
                case _ =>
                    let buffer = Array<Byte>(4096, repeat: 0)
                    while (true) {
                        let len = content.read(buffer)
                        if (len > 0) {
                            output.write(buffer.slice(0, len))
                        } else {
                            return
                        }
                    }
            }
        } finally {
            close()
        }
    }
    public func bytes(): Array<Byte> {
        try {
            match (content) {
                case input: ByteBuffer => input.bytes()
                case _ =>
                    let buffer = ByteBuffer()
                    copyTo(buffer)
                    buffer.bytes()
            }
        } finally {
            close()
        }
    }
    prop directory: ?Path {
        get() {
            match (content) {
                case file: File => (file.info.parentDirectory?.path) ?? Path('/')
                case _ => None
            }
        }
    }
    public prop reader: TextReader {
        get() {
            TextReader(content, charset: charset)
        }
    }
    public func isClosed(): Bool {
        (content as Resource)?.isClosed() ?? false
    }
    public func close(): Unit {
        doClose(content)
    }
    private static func doClose(input: InputStream, toThrow!: Bool = true) {
        match (input) {
            case x: File =>
                try {
                    x.close()
                } catch (e: Exception) {
                    if (toThrow) {
                        throw e
                    }
                }
                try {
                    removeIfExists(x.info.path, recursive: false)
                } catch (e: Exception) {
                    if (toThrow) {
                        throw e
                    }
                }
                try {
                    if (Directory.isEmpty(x.info.path.parent)) {
                        removeIfExists(x.info.path.parent, recursive: true)
                    }
                } catch (e: Exception) {
                    if (toThrow) {
                        throw e
                    }
                }
            case x: Resource => x.close()
            case _ => ()
        }
    }
}
