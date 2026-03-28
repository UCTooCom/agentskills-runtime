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

/**
 * Base64Binary：把配置的文本当作BASE64转成字节数组
 * Text: 把配置的文本当作字符串
 * Bean: 把配置的文本当作IOC Bean名称，得到的应该是一个ErrorHttpRequestHandler类型的实例
 */
public enum FailureMessageKind <: Equatable<FailureMessageKind> & Parsable<FailureMessageKind> & DataParsable<FailureMessageKind> {
    | Base64Binary
    | Text
    | Bean

    public operator func ==(other: FailureMessageKind) {
        match ((this, other)) {
            case (Base64Binary, Base64Binary) | (Text, Text) | (Bean, Bean) => true
            case _ => false
        }
    }
    public static func tryParse(kind: String): ?FailureMessageKind {
        match (kind.toAsciiUpper()) {
            case "BASE64BINARY" => Base64Binary
            case "TEXT" => Text
            case "BEAN" => Bean
            case _ => None<FailureMessageKind>
        }
    }
    public static func parse(kind: String): FailureMessageKind {
        tryParse(kind).getOrThrow {MVCException("unsupported FailureMessageKind ${kind}")}
    }
}
