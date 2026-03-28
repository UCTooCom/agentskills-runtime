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

public abstract class TextMediaType <: MediaType {
    protected TextMediaType(
        mediaType: String,
        public let charset!: Charset = Charsets.UTF8
    ) {
        super(mediaType)
    }
    protected func doMake(mediaType: String, creator: (Charset) -> MediaType): MediaType {
        let tag = '; charset='
        let idx = mediaType.indexOf(tag)
        if(let Some(x) <- idx){
            let cs = mediaType[x + tag.size..]
            let mt = mediaType[0 .. x]
            if(mt == this.mediaType){
                let charset = Charsets.forName(cs)
                if (let Some(c) <- charset) {
                    creator(c)
                } else {
                    throw MediaTypeException('charset in ${mediaType} is not be supported')
                }
            } else {
                throw MediaTypeException("${mediaType} is not ${this.mediaType}")
            }
        } else if (mediaType.startsWith(this.mediaType)) {
            this
        } else {
            throw MediaTypeException('${mediaType} is not ${this.mediaType}')
        }
    }
    public func toString() {
        "${mediaType}; charset=${charset}"
    }
    public operator func ==(other: MediaType) {
        match (other) {
            case x: TextMediaType => refEq(this, other) || (this.hashCode() == other.hashCode() && x.mediaType == this.mediaType && x.charset == this.charset)
            case _ => false
        }
    }
    public func hashCode(): Int64 {
        if (hash == 0) {
            hash = HashBuilder().append(mediaType).append(charset).build()
        }
        hash
    }
}

public class PlainTextMediaType <: TextMediaType {
    public static let instance = PlainTextMediaType()
    init(charset!: Charset = Charsets.UTF8) {
        super("text/plain", charset: charset)
    }
    public func make(mediaType: String): MediaType {
        super.doMake(mediaType){cs => PlainTextMediaType(charset: cs)}
    }
    public func fromData(data: Data): Array<Byte> {
        charset.newEncoder().encode(data.toString())
    }
    public func toData(data: Array<Byte>): Data {
        toData(charset.newDecoder().decode(data))
    }
    public func toData(data: String): Data {
        data.toData()
    }
}
public class JsonMediaType <: TextMediaType {
    public static let instance = JsonMediaType()
    init(charset!: Charset = Charsets.UTF8) {
        super("application/json", charset: charset)
    }
    public func make(mediaType: String): MediaType {
        super.doMake(mediaType){cs => JsonMediaType(charset: cs)}
    }
    public func fromData(data: Data): Array<Byte> {
        fromData((JsonValue.tryFromData(data) as JsonValue).getOrThrow())
    }
    public func fromData(data: JsonValue): Array<Byte> {
        charset.newEncoder().encode(data.toString())
    }
    public func toData(data: Array<Byte>): Data {
        toData(charset.newDecoder().decode(data))
    }
    public func toData(data: String): Data {
        JsonValue.fromStr(data).toData()
    }
}
