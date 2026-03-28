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
package f_orm

import f_orm.exception.ORMException

public struct ORMConverter {
    private init(){}
    public static func convert<T>(value: Any): T {
        convertNullable<T>(value).getOrThrow {ORMException('value is none')}
    }
    public static func convertNullable<T>(value: Any): ?T {
        match (value) {
            case x: T => x
            case x: ?T => x
            case x: ToString => match (x.toString()) {
                case x: T => x
                case _ => throw ORMException("type of param does not match generic type")
            }
            case _ => throw ORMException("type of param does not match generic type")
        }
    }
}
