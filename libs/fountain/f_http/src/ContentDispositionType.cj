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

public enum ContentDispositionType <: Equatable<ContentDispositionType> & Hashable & ToString & Parsable<ContentDispositionType> {
    | attachment
    | formData
    | inline
    | none

    public func toString(): String {
        match (this) {
            case attachment => "attachment"
            case formData => "form-data"
            case inline => "inline"
            case none => ""
        }
    }
    public func hashCode(): Int64 {
        toString().hashCode()
    }
    public prop isAttachment: Bool {
        get() {
            this == attachment
        }
    }
    public prop isFormData: Bool {
        get() {
            this == formData
        }
    }
    public prop isInline: Bool {
        get() {
            this == inline
        }
    }
    public prop isNone: Bool {
        get() {
            this == none
        }
    }
    public operator func ==(other: ContentDispositionType) {
        match ((this, other)) {
            case (attachment, attachment) | (formData, formData) | (inline, inline) | (none, none) => true
            case _ => false
        }
    }
    public static func tryParse(value: String): Option<ContentDispositionType> {
        match (value) {
            case "attachment" => attachment
            case "formData" | "form-data" => formData
            case "inline" => inline
            case "none" | "" | "None" | "NONE" => none
            case _ => None<ContentDispositionType>
        }
    }
    public static func parse(value: String): ContentDispositionType {
        match (tryParse(value)) {
            case Some(v) => v
            case _ => throw IllegalArgumentException(
                "argument must be one of \"attachment\" \"formData\" \"form-data\" \"inline\" \"none\" \"None\" \"NONE\" \"\", but it is \"${value}\"")
        }
    }
}
