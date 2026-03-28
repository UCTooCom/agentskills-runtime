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
package f_macros

import std.reflect.{ClassTypeInfo, TypeInfo}

public func withAnnotation<T>(decl: Decl): Bool where T <: Annotation {
    match (decl) {
        case d: MacroExpandDecl =>
            for (a in TypeInfo.of<T>().annotations where ClassTypeInfo.of(a).name == d.fullIdentifier.value) {
                return true
            }
            false
        case _ => false
    }
}

public func withMacro(decl: Decl, macroName: String): Bool {
    match (decl) {
        case d: MacroExpandDecl => d.fullIdentifier.value == macroName
        case _ => false
    }
}
