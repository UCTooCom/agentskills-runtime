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

abstract sealed class WSDataFrame <: ControllerFuncParam {
    public const WSDataFrame(protected let mediaType: String) {}
    protected func extract<T>(_: String, _: ?AbstractDateTimeConverter, _: HttpContext, _: HttpRequestPathPatterns, _: Validator): ?T where T <: DataFields<T> {
        throw MVCException()
    }
    protected func extract<T>(frame: Array<Byte>): T where T <: DataFields<T>
}

@Annotation[target: [Parameter]]
public class WSTextFrame <: WSDataFrame {
    public const WSTextFrame(mediaType: String, public let charset!: String = 'utf-8') {
        super(mediaType)
    }

    protected func extract<T>(frame: Array<Byte>): T where T <: DataFields<T> {
        let data = Charsets
            .forName(charset)
            .getOrThrow {MediaTypeException('charset ${charset} does not support')}
            .newDecoder()
            .decode(frame)
        if (mediaType == '') {
            if (let x: T <- data) {
                x
            } else {
                throw MediaTypeException('media type is not specified')
            }
        } else {
            MediaTypes.parse(mediaType).toDataFields<T>(data)
        }
    }
}

@Annotation[target: [Parameter]]
public class WSBinaryFrame <: WSDataFrame {
    public const WSBinaryFrame(mediaType: String) {
        super(mediaType)
    }
    protected func extract<T>(frame: Array<Byte>): T where T <: DataFields<T> {
        if (mediaType == '') {
            if (let x: T <- frame) {
                x
            } else {
                throw MediaTypeException('media type is not specified')
            }
        } else {
            MediaTypes.parse(mediaType).toDataFields<T>(frame)
        }
    }
}
