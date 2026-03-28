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

abstract sealed class Help {
    public static func convert<T>(options: Array<?T>): ?T {
        for (o in options where o.isSome()) {
            return o
        }
        return None
    }
    public static func convert<T>(options: Array<?String>): String {
        for (o in options) {
            match (o) {
                case Some(x) where x.size > 0 => return x
                case _ => continue
            }
        }
        ''
    }
    public static func convert<T, C>(collections: Array<C>): ?C where C <: Collection<T> {
        for (c in collections where c.size > 0) {
            return c
        }
        return None
    }
    public static func convert(strings: Array<String>): String {
        for (s in strings where s.size > 0) {
            return s
        }
        return ""
    }
}
