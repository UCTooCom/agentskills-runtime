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
package f_base

import std.env.{getStdOut, getStdIn, ConsoleWriter, ConsoleReader}
public import std.env.ConsoleWriter

public struct Console {
    private init(){}
    private static let output = getStdOut()
    private static let input = getStdIn()
    public static func write<T>(v: T): Unit where T <: ToString {
        output.write<T>(v)
    }
    public static func writeln<T>(v: T): Unit where T <: ToString {
        output.writeln<T>(v)
    }
    public static func write<T>(fn: () -> T): Unit where T <: ToString {
        output.write<T>(fn())
    }
    public static func writeln<T>(fn: () -> T): Unit where T <: ToString {
        output.writeln<T>(fn())
    }
    public static func writeln(): Unit {
        output.writeln()
    }
    public static func read(): ?Rune {
        input.read()
    }
    public static func readUntil(r: Rune): ?String {
        input.readUntil(r)
    }
    public static func readUntil(predicate: (Rune) -> Bool): ?String {
        input.readUntil(predicate)
    }
    public static func readln(): ?String {
        input.readln()
    }
}