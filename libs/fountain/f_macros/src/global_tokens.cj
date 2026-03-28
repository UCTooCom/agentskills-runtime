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

public let `dot` = quote($(Token(DOT))) /**  "." */
public let `comma` = quote($(Token(COMMA))) /**  "," */
public let `lparen` = quote($(Token(LPAREN))) /**  "(" */
public let `rparen` = quote($(Token(RPAREN))) /**  ")" */
public let `lsquare` = quote($(Token(LSQUARE))) /**  "[" */
public let `rsquare` = quote($(Token(RSQUARE))) /**  "]" */
public let `lcurl` = quote($(Token(LCURL))) /**  "{" */
public let `rcurl` = quote($(Token(RCURL))) /**  "}" */
public let `exp` = quote($(Token(EXP))) /**  "**" */
public let `mul` = quote($(Token(MUL))) /**  "*" */
public let `mod` = quote($(Token(MOD))) /**  "%" */
public let `div` = quote($(Token(DIV))) /**  "/" */
public let `add` = quote($(Token(ADD))) /**  "+" */
public let `sub` = quote($(Token(SUB))) /**  "-" */
public let `incr` = quote($(Token(INCR))) /**  "++" */
public let `decr` = quote($(Token(DECR))) /**  "--" */
public let `and` = quote($(Token(AND))) /**  "&&" */
public let `or` = quote($(Token(OR))) /**  "||" */
public let `coalescing` = quote($(Token(COALESCING))) /**  "??" */
public let `pipeline` = quote($(Token(PIPELINE))) /**  "|>" */
public let `composition` = quote($(Token(COMPOSITION))) /**  "~>" */
public let `not` = quote($(Token(NOT))) /**  "!" */
public let `bitand` = quote($(Token(BITAND))) /**  "&" */
public let `bitor` = quote($(Token(BITOR))) /**  "|" */
public let `bitxor` = quote($(Token(BITXOR))) /**  "^" */
public let `bitnot` = quote($(Token(BITNOT))) /**  "~" */
public let `lshift` = quote($(Token(LSHIFT))) /**  "<<" */
public let `rshift` = quote($(Token(RSHIFT))) /**  ">>" */
public let `colon` = quote($(Token(COLON))) /**  ":" */
public let `semi` = quote($(Token(SEMI))) /**  ";" */
public let `assign` = quote($(Token(ASSIGN))) /**  "=" */
public let `add_assign` = quote($(Token(ADD_ASSIGN))) /**  "+=" */
public let `sub_assign` = quote($(Token(SUB_ASSIGN))) /**  "-=" */
public let `mul_assign` = quote($(Token(MUL_ASSIGN))) /**  "*=" */
public let `exp_assign` = quote($(Token(EXP_ASSIGN))) /**  "**=" */
public let `div_assign` = quote($(Token(DIV_ASSIGN))) /**  "/=" */
public let `mod_assign` = quote($(Token(MOD_ASSIGN))) /**  "%=" */
public let `and_assign` = quote($(Token(AND_ASSIGN))) /**  "&&=" */
public let `or_assign` = quote($(Token(OR_ASSIGN))) /**  "||=" */
public let `bitand_assign` = quote($(Token(BITAND_ASSIGN))) /**  "&=" */
public let `bitor_assign` = quote($(Token(BITOR_ASSIGN))) /**  "|=" */
public let `bitxor_assign` = quote($(Token(BITXOR_ASSIGN))) /**  "^=" */
public let `lshift_assign` = quote($(Token(LSHIFT_ASSIGN))) /**  "<<=" */
public let `rshift_assign` = quote($(Token(RSHIFT_ASSIGN))) /**  ">>=" */
public let `arrow` = quote($(Token(ARROW))) /**  "->" */
public let `back_arrow` = quote($(Token(BACKARROW))) /**  "<-" */
public let `double_arrow` = quote($(Token(DOUBLE_ARROW))) /**  "=>" */
public let `rangeop` = quote($(Token(RANGEOP))) /**  ".." */
public let `closedrangeop` = quote($(Token(CLOSEDRANGEOP))) /**  "..=" */
public let `ellipsis` = quote($(Token(ELLIPSIS))) /**  "..." */
public let `hash` = quote($(Token(HASH))) /**  "#" */
public let `at` = quote($(Token(AT))) /**  "@" */
public let `quest` = quote($(Token(QUEST))) /**  "?" */
public let `lt` = quote($(Token(TokenKind.LT))) /**  "<" */
public let `gt` = quote($(Token(TokenKind.GT))) /**  ">" */
public let `le` = quote($(Token(LE))) /**  "<=" */
public let `ge` = quote($(Token(GE))) /**  ">=" */
public let `is` = quote($(Token(IS))) /**  "is" */
public let `as` = quote($(Token(AS))) /**  "as" */
public let `noteq` = quote($(Token(NOTEQ))) /**  "!=" */
public let `equal` = quote($(Token(EQUAL))) /**  "==" */
public let `wildcard` = quote($(Token(WILDCARD))) /**  "_" */
public let `int8` = quote($(Token(INT8))) /**  "Int8" */
public let `int16` = quote($(Token(INT16))) /**  "Int16" */
public let `int32` = quote($(Token(INT32))) /**  "Int32" */
public let `int64` = quote($(Token(INT64))) /**  "Int64" */
public let `intnative` = quote($(Token(INTNATIVE))) /**  "IntNative" */
public let `uint8` = quote($(Token(UINT8))) /**  "UInt8" */
public let `uint16` = quote($(Token(UINT16))) /**  "UInt16" */
public let `uint32` = quote($(Token(UINT32))) /**  "UInt32" */
public let `uint64` = quote($(Token(UINT64))) /**  "UInt64" */
public let `uintnative` = quote($(Token(UINTNATIVE))) /**  "UIntNative" */
public let `float16` = quote($(Token(FLOAT16))) /**  "Float16" */
public let `float32` = quote($(Token(FLOAT32))) /**  "Float32" */
public let `float64` = quote($(Token(FLOAT64))) /**  "Float64" */
public let `rune` = quote($(Token(RUNE))) /**  "Rune" */
public let `boolean` = quote($(Token(BOOLEAN))) /**  "Bool" */
public let `nothing` = quote($(Token(NOTHING))) /**  "Nothing" */
public let `unit` = quote($(Token(UNIT))) /**  "Unit" */
public let `struct` = quote($(Token(STRUCT))) /**  "struct" */
public let `enum` = quote($(Token(ENUM))) /**  "enum" */
public let `varray` = quote($(Token(VARRAY))) /**  "VArray" */
public let `thistype` = quote($(Token(THISTYPE))) /**  "This" */
public let `package` = quote($(Token(PACKAGE))) /**  "package" */
public let `import` = quote($(Token(IMPORT))) /**  "import" */
public let `class` = quote($(Token(CLASS))) /**  "class" */
public let `interface` = quote($(Token(INTERFACE))) /**  "interface" */
public let `func` = quote($(Token(FUNC))) /**  "func" */
public let `macro` = quote($(Token(MACRO))) /**  "macro" */
public let `quote` = quote($(Token(QUOTE))) /**  "quote" */
public let `dollar` = quote($(Token(DOLLAR))) /**  "$" */
public let `let` = quote($(Token(LET))) /**  "let" */
public let `var` = quote($(Token(VAR))) /**  "var" */
public let `const` = quote($(Token(CONST))) /**  "const" */
public let `type` = quote($(Token(TYPE))) /**  "type" */
public let `init` = quote($(Token(INIT))) /**  "init" */
public let `this` = quote($(Token(THIS))) /**  "this" */
public let `super` = quote($(Token(SUPER))) /**  "super" */
public let `if` = quote($(Token(IF))) /**  "if" */
public let `else` = quote($(Token(ELSE))) /**  "else" */
public let `case` = quote($(Token(CASE))) /**  "case" */
public let `try` = quote($(Token(TRY))) /**  "try" */
public let `catch` = quote($(Token(CATCH))) /**  "catch" */
public let `finally` = quote($(Token(FINALLY))) /**  "finally" */
public let `for` = quote($(Token(FOR))) /**  "for" */
public let `do` = quote($(Token(DO))) /**  "do" */
public let `while` = quote($(Token(WHILE))) /**  "while" */
public let `throw` = quote($(Token(THROW))) /**  "throw" */
public let `return` = quote($(Token(RETURN))) /**  "return" */
public let `continue` = quote($(Token(CONTINUE))) /**  "continue" */
public let `break` = quote($(Token(BREAK))) /**  "break" */
public let `in` = quote($(Token(IN))) /**  "in" */
public let `not_in` = quote($(Token(NOT_IN))) /**  "!in" */
public let `match` = quote($(Token(MATCH))) /**  "match" */
public let `where` = quote($(Token(WHERE))) /**  "where" */
public let `extend` = quote($(Token(EXTEND))) /**  "extend" */
public let `with` = quote($(Token(WITH))) /**  "with" */
public let `prop` = quote($(Token(PROP))) /**  "prop" */
public let `static` = quote($(Token(STATIC))) /**  "static" */
public let `public` = quote($(Token(PUBLIC))) /**  "public" */
public let `private` = quote($(Token(PRIVATE))) /**  "private" */
public let `protected` = quote($(Token(PROTECTED))) /**  "protected" */
public let `override` = quote($(Token(OVERRIDE))) /**  "override" */
public let `redef` = quote($(Token(REDEF))) /**  "redef" */
public let `abstract` = quote($(Token(ABSTRACT))) /**  "abstract" */
public let `sealed` = quote($(Token(SEALED))) /**  "sealed" */
public let `open` = quote($(Token(OPEN))) /**  "open" */
public let `foreign` = quote($(Token(FOREIGN))) /**  "foreign" */
public let `inout` = quote($(Token(INOUT))) /**  "inout" */
public let `mut` = quote($(Token(MUT))) /**  "mut" */
public let `unsafe` = quote($(Token(UNSAFE))) /**  "unsafe" */
public let `operator` = quote($(Token(OPERATOR))) /**  "operator" */
public let `spawn` = quote($(Token(SPAWN))) /**  "spawn" */
public let `synchronized` = quote($(Token(SYNCHRONIZED))) /**  "synchronized */
public let `upperbound` = quote($(Token(UPPERBOUND))) /**  "<:" */
public let `main` = quote($(Token(MAIN))) /**  "main" */
public let `identifier` = quote($(Token(IDENTIFIER))) /**  "x" */
public let `package_identifier` = quote($(Token(PACKAGE_IDENTIFIER))) /**  "x" */
public let `integer_literal` = quote($(Token(INTEGER_LITERAL))) /**  e.g. "1" */
public let `rune_byte_literal` = quote($(Token(RUNE_BYTE_LITERAL))) /**  e.g. "b'x'" */
public let `float_literal` = quote($(Token(FLOAT_LITERAL))) /**  e.g. "'1.0'" */
public let `comment` = quote($(Token(COMMENT))) /**  e.g. "/*xx*/" */
public let `nl` = quote($(Token(NL))) /**  newline */
public let `end` = quote($(Token(END))) /**  end of file */
public let `sentinel` = quote($(Token(SENTINEL))) /**  ";" */
public let `true` = quote($(Token(BOOL_LITERAL, "true"))) /**  "true" or "false" */
public let `false` = quote($(Token(BOOL_LITERAL, "false"))) /**  "true" or "false" */
public let `unit_literal` = quote($(Token(UNIT_LITERAL))) /**  "()))" */
public let `dollar_identifier` = quote($(Token(DOLLAR_IDENTIFIER))) /**  e.g. "$x" */
public let `macros` = quote($(Token(ANNOTATION))) /**  e.g. "@when" */
public let `illegal` = quote($(Token(ILLEGAL)))
public let `any` = quote($(Token(IDENTIFIER, "Any")))
public let `array` = quote($(Token(IDENTIFIER, "Array")))
public let `empty_tokens` = quote()
public let `empty_string` = quote($(Token(STRING_LITERAL, String.empty)))
