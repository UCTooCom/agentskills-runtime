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

public class MultipartMedia <: Multipart & Data & DataFields<MultipartMedia> {
    public MultipartMedia(
        contentDisposition: ContentDisposition,
        public let mediaType: ?MediaType,
        public let bytes: Array<Byte>
    ) {
        super(contentDisposition)
    }
    public func toData(): Data {
        match (mediaType) {
            case Some(x) => x.toData(bytes)
            case _ => toString().toData()
        }
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
    public func toDataFields<T>(): T where T <: DataFields<T> {
        (mediaType?.toDataFields<T>(bytes)).getOrThrow()
    }
    public func toString(): String {
        let charset = contentDisposition.getCharset() ?? Charsets.UTF8
        charset.newDecoder().decode(bytes)
    }
    public static func parse(string: String): Data {
        tryParse(string).getOrThrow()
    }
    public static func tryParse(string: String): ?Data {
        throw MediaTypeException('Not Supported')
    }
    public func to<T>(): ?T where T <: Parsable<T> {
        T.tryParse(toString())
    }
}
