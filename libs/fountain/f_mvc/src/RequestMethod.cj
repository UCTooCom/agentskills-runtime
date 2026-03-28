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

public enum RequestMethod <: Hashable & Equatable<RequestMethod> & ToString & Parsable<RequestMethod> & DataParsable<RequestMethod> & Comparable<RequestMethod> {
    | GET
    | POST
    | PUT
    | DELETE
    | PATCH
    | OPTIONS
    | HEAD
    | WS

    public func hashCode(): Int64 {
        toString().hashCode()
    }

    public operator func ==(other: RequestMethod) {
        match ((this, other)) {
            case (GET, GET) | (POST, POST) | (PUT, PUT) | (DELETE, DELETE) | (PATCH, PATCH) | (OPTIONS, OPTIONS)
                | (HEAD, HEAD) => true
            case _ => false
        }
    }
    public operator func !=(other: RequestMethod) {
        !(this == other)
    }
    public func toString() {
        match (this) {
            case GET => "GET"
            case PUT => "PUT"
            case POST => "POST"
            case DELETE => "DELETE"
            case PATCH => "PATCH"
            case OPTIONS => "OPTIONS"
            case HEAD => "HEAD"
            case WS => "WS"
        }
    }
    public static func tryParse(value: String): ?RequestMethod {
        match (value.toAsciiUpper()) {
            case "GET" => GET
            case "PUT" => PUT
            case "POST" => POST
            case "DELETE" => DELETE
            case "PATCH" => PATCH
            case "OPTIONS" => OPTIONS
            case "HEAD" => HEAD
            case "WS" => WS
            case _ => None
        }
    }
    public func compare(other: RequestMethod): Ordering {
        this.toString().compare(other.toString())
    }
    public static func parse(value: String): RequestMethod {
        tryParse(value).getOrThrow {IllegalArgumentException("${value} is an illegal http request method")}
    }
}
