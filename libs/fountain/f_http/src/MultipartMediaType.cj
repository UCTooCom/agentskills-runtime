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

/**
 * multipart/form-data, boundary=AaB03x
 */
public class MultipartMediaType <: MediaType {
    private static const MEDIA_TYPE_NAME = "multipart/form-data"
    public static let instance = MultipartMediaType(MEDIA_TYPE_NAME)
    private MultipartMediaType(
        mediaType: String,
        public let boundary!: String = ""
    ) {
        super(mediaType)
    }
    public func toString() {
        "${mediaType}; boundary=${boundary}"
    }
    public operator func ==(other: MediaType) {
        match (other) {
            case x: MultipartMediaType => refEq(this, other) || (this.hashCode() == other.hashCode() && x.mediaType == this.mediaType && x.boundary == this.boundary)
            case _ => false
        }
    }
    public func hashCode(): Int64 {
        if (hash == 0) {
            hash = HashBuilder().append(mediaType).append(boundary).build()
        }
        hash
    }
    public func make(mediaType: String): MediaType {
        if (mediaType.startsWith(MEDIA_TYPE_NAME)) {
            let idx = mediaType.indexOf(", boundary=") ?? -1
            if (idx > 0) {
                MultipartMediaType(mediaType[0..idx], boundary: mediaType[idx + ", boundary=".size..])
            } else if (mediaType == MEDIA_TYPE_NAME) {
                this
            } else {
                throw MediaTypeException("${mediaType} is illegal")
            }
        } else {
            throw MediaTypeException("${mediaType} is not multipart/form-data")
        }
    }

    public func fromData(data: Data): Array<Byte> {
        throw MediaTypeException("${MEDIA_TYPE_NAME} does not support current access")
    }
    public func toData(data: Array<Byte>): Data {
        throw MediaTypeException("${MEDIA_TYPE_NAME} does not support current access")
    }
    public func toData(input: InputStream): Data {
        MultipartFormDataParser(input, boundary).parse()
    }
}
