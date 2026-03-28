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
macro package f_bean.macros

public macro Value(attr: Tokens, input: Tokens): Tokens {
    func setItem(attr: Tokens, param: FuncParam): Unit {
        var (name, default, dateFormat, delim) = (`empty_tokens`, `empty_tokens`, `empty_tokens`, `comma`)
        var i = 0
        while (i < attr.size) {
            match (attr[i].value) {
                case 'name' =>
                    name = quote($(attr[i + 2]))
                    i += 2
                case 'default' =>
                    default = quote($(attr[i + 2]))
                    i += 2
                case 'dateFormat' =>
                    dateFormat = quote($attr[i + 2])
                    i += 2
                case 'delim' =>
                    delim = quote($attr[i + 2])
                    i += 2
                case _ => i++
            }
        }
        setItem('name', param.identifier.value)
        setItem('cond', match (param.paramType.toTokens()) {
            case x where x.size == 1 && x[0].kind == IDENTIFIER && x[0].value == 'String' => quote(Config.getString($name) ?? ) +
                if (default.size == 0) {
                quote('')
            } else {
                quote($default)
            }
            case x where x.size == 1 && x[0].kind == IDENTIFIER && x[0].value == 'DateTime' => if (dateFormat.size > 0) {
                quote(Config.getDateTime($name, format: $dateFormat))
            } else {
                quote(Config.getDateTime($name))
            } + if (default.size == 0) {
                `empty_tokens`
            } else if (dateFormat.size > 0) {
                quote( ?? DateTime.parse($default, $dateFormat))
            } else {
                quote( ?? DateTime.parse($default))
            }
            case x where x.size == 1 && x[0].kind == IDENTIFIER && x[0].value == 'Duration' => quote(Config.getDuration($name)) +
                if (default.size == 0) {
                `empty_tokens`
            } else {
                quote( ?? Duration.parse($default))
            }
            case x where x[0].kind == IDENTIFIER && x[0].value == 'Option' => match (x[2].value) {
                case 'String' => quote(Config.getString($name)) + if (default.size == 0) {
                    `empty_tokens`
                } else {
                    quote( ?? $default)
                }
                case 'DateTime' => if (dateFormat.size > 0) {
                    quote(Config.getDateTime($name, format: $dateFormat))
                } else {
                    quote(Config.getDateTime($name))
                } + if (default.size == 0) {
                    `empty_tokens`
                } else if (dateFormat.size > 0) {
                    quote( ?? DateTime.parse($default, $dateFormat))
                } else {
                    quote( ?? DateTime.parse($default))
                }
                case 'Duration' => quote(Config.getDuration($name)) + if (default.size == 0) {
                    `empty_tokens`
                } else {
                    quote( ?? Duration.parse($default))
                }
                case _ => quote(Config.getValue<$(x[2])>($name)) + if (default.size == 0) {
                    `empty_tokens`
                } else {
                    quote( ?? $default)
                }
            }
            case x where x[0].kind == QUEST => match (x[1].value) {
                case 'String' => quote(Config.getString($name)) + if (default.size == 0) {
                    `empty_tokens`
                } else {
                    quote( ?? $default)
                }
                case 'DateTime' => if (dateFormat.size > 0) {
                    quote(Config.getDateTime($name, format: $dateFormat))
                } else {
                    quote(Config.getDateTime($name))
                } + if (default.size == 0) {
                    `empty_tokens`
                } else if (dateFormat.size > 0) {
                    quote( ?? DateTime.parse($default, $dateFormat))
                } else {
                    quote( ?? DateTime.parse($default))
                }
                case 'Duration' => quote(Config.getDuration($name)) + if (default.size == 0) {
                    `empty_tokens`
                } else {
                    quote( ?? Duration.parse($default))
                }
                case _ => quote(Config.getValue<$(x[1])>($name)) + if (default.size == 0) {
                    `empty_tokens`
                } else {
                    quote( ?? $default)
                }
            }
            case x where x[0].value == 'Array' => match (x[2].value) {
                case 'String' => quote(Config.getStringArray($name, delim: $delim))
                case 'DateTime' =>
                    if (dateFormat.size > 0) {
                        quote(Config.getDateTimes($name, format: $dateFormat, delim: $delim))
                    } else {
                        quote(Config.getDateTimes($name, delim: $delim))
                    }
                case 'Duration' => quote(Config.getDurations($name, delim: $delim))
                case _ => quote(Config.getValues<$(x[2])>($name, delim: $delim))
            }
            case x => quote(Config.getValue<$(x[0])>($name)) + if (default.size == 0) {
                `empty_tokens`
            } else {
                quote( ?? $default)
            }
        })
    }
    assertParentContext('Constructor')
    match (parseDecl(attr)) {
        case x: FuncParam => setItem(attr, x)
        case x: MacroExpandParam =>
            var d: Decl = x
            while (let mp: MacroExpandParam <- d) {
                d = mp.macroInputDecl
            }
            if (let p: FuncParam <- d) {
                setItem(attr, p)
            } else {
                diagReport(ERROR, input, '${input} must be a FuncParam or a MacroExpandParam', '')
            }
        case _ => diagReport(ERROR, input, '${input} must be a FuncParam or a MacroExpandParam', '')
    }
    input
}
