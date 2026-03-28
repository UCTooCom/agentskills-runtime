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
macro package f_base.macros

import std.ast.*
/**
 * @nameof(name) 展开是'name'
 * @nameof(object.name) 展开是'name'
 */
public macro nameof(input: Tokens): Tokens {
    quote(@nameValue($input)[0])
}
/**
 * @nameValueOf(name) 展开是元组('name', /*name变量的值*/)
 * @nameValueOf(object.name) 展开是元组('name', /*object.name的值*/)
 */
public macro nameValueOf(input: Tokens): Tokens {
    if (input.size == 0) {
        diagReport(ERROR, input, 'macro nameof do not accept empty input', '')
        throw IllegalArgumentException()
    }
    let last = input[input.size - 1]
    let identifier = match (last.kind) {
        case IDENTIFIER where input.size == 1 || input[input.size - 2].kind == DOT => last.value
        case _ =>
            diagReport(ERROR, input, 'the kind of last token in parameter of macro nameof must be IDENTIFIER', '')
            throw IllegalArgumentException()
    }
    quote(($identifier, $input))
}
