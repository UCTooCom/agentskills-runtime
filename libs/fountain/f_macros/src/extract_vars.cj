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

public func extractAllVars(decls: Array<Decl>): ArrayList<VarDecl> {
    let list = ArrayList<VarDecl>()
    for (decl in decls where decl is VarDecl) {
        list.add((decl as VarDecl).getOrThrow())
    }
    list
}

public func extractVars(decls: ArrayList<Decl>, extractPublic!: Bool = true, extractVar!: Bool = true,
    extractStatic!: Bool = false): ArrayList<VarDecl> {
    let list = ArrayList<VarDecl>()
    for (decl in decls where decl is VarDecl && (!extractPublic || isPublic(decl)) && (!extractStatic || isStatic(decl))) {
        let varDecl = (decl as VarDecl).getOrThrow()
        if (!extractVar || varDecl.isVar()) {
            list.add(varDecl)
        }
    }
    list
}
