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

import f_base.*

public func extractProps(decls: ArrayList<Decl>, extractPublic!: Bool = true): ArrayList<PropDecl> {
    let list = ArrayList<PropDecl>()
    for (decl in decls where decl is PropDecl && (!extractPublic || isPublic(decl))) {
        list.add((decl as PropDecl).getOrThrow())
    }
    list
}

public func extractMutProps(decls: ArrayList<Decl>, extractPublic!: Bool = true, extractStatic!: Bool = false): ArrayList<PropDecl> {
    let list = ArrayList<PropDecl>()
    for (decl in decls where decl is PropDecl && (!extractPublic || isPublic(decl)) && (!extractStatic || isStatic(decl)) &&
        isMut(decl)) {
        let propDecl = (decl as PropDecl).getOrThrow()
        list.add(propDecl)
    }
    list
}

public func extractReadOnlyProps(decls: ArrayList<Decl>, extractPublic!: Bool = true): ArrayList<PropDecl> {
    let list = ArrayList<PropDecl>()
    for (decl in decls where decl is PropDecl && (!extractPublic || isPublic(decl)) && !isMut(decl)) {
        let propDecl = (decl as PropDecl).getOrThrow()
        list.add(propDecl)
    }
    list
}
