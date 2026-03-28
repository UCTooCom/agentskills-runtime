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
package boot

import stdx.encoding.json.*
import fountain.mvc.MediaType
import fountain.base.*
import fountain.bean.*
import fountain.bean.macros.*
import fountain.data.*
import fountain.log.*

@Bean
public class LogTextMediaType <: MediaType {
    private static let log = LoggerFactory.getLogger<LogTextMediaType>()
    public init() {
        super('application/json+log')
    }
    public func make(mediaType: String): MediaType {
        this
    }
    private static func info(prefix: String, json: String) {
        log.info{'${prefix}:${json}'}
    }
    public func toString() {
        mediaType
    }
    public operator func ==(other: MediaType) {
        match (other) {
            case x: LogTextMediaType => refEq(this, other) || (this.hashCode() == other.hashCode() && x.mediaType == this.mediaType)
            case _ => false
        }
    }
    public func hashCode(): Int64 {
        if (hash == 0) {
            hash = HashBuilder().append(mediaType).build()
        }
        hash
    }
    public func fromData(data: Data): Array<Byte> {
        fromData((JsonValue.tryFromData(data) as JsonValue).getOrThrow())
    }
    public func fromData(data: JsonValue): Array<Byte> {
        let json = data.toString()
        info('fromData',json)
        json.unsafeBytes()
    }
    public func toData(data: Array<Byte>): Data {
        let json = String.fromUtf8(data)
        info('toData', json)
        toData(json)
    }
    public func toData(data: String): Data {
        JsonValue.fromStr(data).toData()
    }
}