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

public func extractFirstTokenToStringLiteral(tokens: Tokens, default!: Token = `empty_string`[0]): Token {
    if (tokens.size == 0) {
        return default
    }
    match (tokens[0].kind) {
        case IDENTIFIER => Token(STRING_LITERAL, tokens[0].value)
        case STRING_LITERAL | SINGLE_QUOTED_STRING_LITERAL => tokens[0]
        case _ => throw MacroFragmentException("first attr must be an IDENTIFIER or a STRING_LITERAL")
    }
}

public func extractFirstTokenToIdentifier(tokens: Tokens): Token {
    match (tokens[0].kind) {
        case IDENTIFIER => tokens[0]
        case STRING_LITERAL | SINGLE_QUOTED_STRING_LITERAL => Token(IDENTIFIER, tokens[0].value)
        case _ => throw MacroFragmentException("first attr must be an IDENTIFIER or a STRING_LITERAL")
    }
}
