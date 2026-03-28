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
package f_random

import std.collection.ArrayList
import stdx.crypto.crypto.SecureRandom
import f_base.*

/*
   Rune 到 UInt32 的转换使用 UInt32(e) 的方式，其中 e 是一个 Rune 类型的表达式， UInt32(e)
   的结果是 e 的 Unicode scalar value 对应的 UInt32 类型的整数值。
   整数类型到 Rune 的转换使用 Rune(num) 的方式，其中 num 的类型可以是任意的整数类型，且仅当
   num 的值落在 [0x0000, 0xD7FF] 或 [0xE000, 0x10FFFF] （即 Unicode scalar value）中时，返
   回对应的 Unicode scalar value 表示的字符，否则，编译报错（编译时可确定 num 的值）或运行时抛
   异常。
 */
public class RandomString {
    private static func concat(arrays: Array<Array<Rune>>) {
        arrays
            .iterator()
            .flatMap {c => c.iterator()}
            .fold<ArrayList<Rune>>(
                ArrayList<Rune>(),
                {
                    acc, e =>
                    acc.add(e);
                    acc
                }
            )
            .toArray()
    }
    private static let LOWER_LETTERS = "abcdefghijklmnopqrstuvwxyz".toRuneArray()
    private static let UPPER_LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".toRuneArray()
    private static let ALL_LETTERS = concat(UPPER_LETTERS, LOWER_LETTERS)
    private static let NUMBERS = "0123456789".toRuneArray()
    private static let LOWER_LETTERS_AND_NUMBERS = concat(LOWER_LETTERS, NUMBERS)
    private static let UPPER_LETTERS_AND_NUMBERS = concat(UPPER_LETTERS, NUMBERS)
    private static let ALL_LETTERS_AND_NUMBERS = concat(ALL_LETTERS, NUMBERS)
    private static let ALL_PRINTABLE_ASCIIS = concat(ALL_LETTERS_AND_NUMBERS,
        "`~!@#$%^&*()-_=+[{]}\\|'\";:/?.>,<".toRuneArray())
    //utf32规范认为0~10ffff足够表示所有字符；d800~dfff不在utf32范围内，这部分是utf16特殊字符，需要前面一半数做高位，后面一半数做低位组合成一个字符，utf32没有使用这一段。
    //已经试过Rune(0xd800u32) Rune(0xdc00u32) Rune((0xd800u32 << 16) | 0xdc00u32)，都会出编译错误
    private static let ALL_CHARS = [(UInt32(0x0000), UInt32(0xD7FF)), (UInt32(0xE000), UInt32(0x10FFFF))]

    public RandomString(private let rand!: SecureRandom = ThreadLocalRandom.current) {}
    public init(priv: Bool) {
        this(rand: SecureRandom(priv: priv))
    }

    public func randomAscii(count: Int64) {
        var builder = StringGenerator()
        for (_ in 0..count) {
            builder.append(Rune(rand.nextUInt32(128)))
        }
        return builder.toString()
    }
    public func randomAscii(min: Int64, max: Int64) {
        randomAscii(rand.nextInt64(min, max, closed: true))
    }
    public func random(count: Int64, source: String) {
        random(count, source.toRuneArray())
    }
    public func random(count: Int64, source: Array<Rune>) {
        var builder = StringGenerator()
        for (_ in 0..count) {
            builder.append(source[rand.nextInt64(source.size)])
        }
        return builder.toString()
    }
    public func random(min: Int64, max: Int64, source: String) {
        random(rand.nextInt64(min, max, closed: true), source)
    }
    public func randomLowerLetters(count: Int64) {
        random(count, LOWER_LETTERS)
    }
    public func randomLowerLetters(min: Int64, max: Int64) {
        randomLowerLetters(rand.nextInt64(min, max))
    }

    public func randomUpperLetters(count: Int64) {
        random(count, UPPER_LETTERS)
    }
    public func randomUpperLetters(min: Int64, max: Int64) {
        randomUpperLetters(rand.nextInt64(min, max))
    }

    public func randomAllLetters(count: Int64) {
        random(count, ALL_LETTERS)
    }
    public func randomAllLetters(min: Int64, max: Int64) {
        randomLowerLetters(rand.nextInt64(min, max))
    }

    public func randomNumbers(count: Int64) {
        random(count, NUMBERS)
    }
    public func randomNumbers(min: Int64, max: Int64) {
        randomNumbers(rand.nextInt64(min, max))
    }

    public func randomLowerLettersNumbers(count: Int64) {
        random(count, LOWER_LETTERS_AND_NUMBERS)
    }
    public func randomLowerLettersNumbers(min: Int64, max: Int64) {
        randomLowerLettersNumbers(rand.nextInt64(min, max))
    }
    public func randomUpperLettersNumbers(count: Int64) {
        random(count, UPPER_LETTERS_AND_NUMBERS)
    }
    public func randomUpperLettersNumbers(min: Int64, max: Int64) {
        randomLowerLettersNumbers(rand.nextInt64(min, max))
    }
    public func randomLettersNumbers(count: Int64) {
        random(count, ALL_LETTERS_AND_NUMBERS)
    }
    public func randomLettersNumbers(min: Int64, max: Int64) {
        randomLowerLettersNumbers(rand.nextInt64(min, max))
    }
    public func randomPrintableAsciis(count: Int64) {
        random(count, ALL_PRINTABLE_ASCIIS)
    }
    public func randomPrintableAsciis(min: Int64, max: Int64) {
        randomPrintableAsciis(rand.nextInt64(min, max))
    }
    public func randomAllChars(count: Int64) {
        var builder = StringGenerator()
        for (_ in 0..count) {
            let idx = rand.nextInt64(2)
            let (start, end) = ALL_CHARS[idx]
            builder.append(Rune(rand.nextUInt32(start, end, closed: true)))
        }
        return builder.toString()
    }
    public func randomAllChars(min: Int64, max: Int64) {
        randomAllChars(rand.nextInt64(min, max))
    }
}
