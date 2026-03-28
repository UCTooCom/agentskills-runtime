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
macro package f_data.macros

import std.ast.*
import f_data.exception.DataException
import f_macros.*

/**
 * attrs取值可以是prop hash equal compare tostring field或Prop Hash Equal Compare ToString toString Field
 */
public macro DataExclude(attrs: Tokens, input: Tokens): Tokens {
    assertParentContext('DataAssist')
    let decl = parseDecl(input)
    match (decl) {
        case d: VarDecl where !d.isStatic() => for (attr in attrs) {
            let tag = attr.value.toAsciiLower()
            if (tag == 'field' && !d.isPublic()) {
                diagReport(ERROR, extractDeclSignature(d),
                    'input must be non-static public prop/public mut prop for @DataExclude[field]', '')
            }
            setItem(tag, d.identifier.value)
        }
        case d: PropDecl where !d.isStatic() && d.isPublic() => for (attr in attrs) {
            let tag = attr.value.toAsciiLower()
            if (tag == 'field') {
                setItem(tag, d.identifier.value)
            } else {
                diagReport(WARNING, extractDeclSignature(d),
                    'only @DataExclude[field] can only modify public prop or public mut prop', '')
            }
        }
        case d: MacroExpandDecl => 
            return replaceMacroInputDecl(quote(@DataExclude[$attrs]), d).toTokens()
        case _ => diagReport(ERROR, extractDeclSignature(decl),
            'input must be non-static var decleration for prop hash equal compare tostring or non-static public var/public prop/public mut prop for field',
            '')
            throw DataException()
    }
    input
}

func extractDeclSignature(decl: Decl) {
    quote($(decl.modifiers) $(decl.keyword) $(decl.identifier))
}
