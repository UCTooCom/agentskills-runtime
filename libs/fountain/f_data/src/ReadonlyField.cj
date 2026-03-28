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
package f_data

public class ReadonlyField <: ReadableField {
    public init(name: String, classTypeInfo: ClassTypeInfo, fieldTypeInfo: TypeInfo, getter: (Any) -> Data) {
        super(name, classTypeInfo, fieldTypeInfo, getter)
    }

    public static func new<O, F>(name: String, getter: (O) -> F): ReadonlyField where O <: ObjectData<O>,
        F <: DataFields<F> {
        ReadonlyField(name, ClassTypeInfo.of<O>(), TypeInfo.of<F>(), newGetter<O, F>(getter))
    }
}
