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

public class MutableField <: ReadableField {
    public MutableField(name: String, classTypeInfo: ClassTypeInfo, fieldTypeInfo: TypeInfo, getter: (Any) -> Data,
        private let setter: (Any, Data, UInt64) -> Bool) {
        super(name, classTypeInfo, fieldTypeInfo, getter)
    }

    public func set(instance: Any, data: Data, flag!: DataConversionFlag = DEFAULT_DATA_FLAG): Bool {
        if ((flag & IGNORE_VALIDATION) == 0 && let Some(validator) <- tryGetAnnotation<Validator>(classTypeInfo, name) &&
            let x: DataString <- data && !validator.validate(x.data)) {
            if ((flag & IGNORE_NOT_MATCHED_VALIDATION) == 0) {
                throw ValidationException(if (validator.messageIfNotMatch.size > 0) {
                    validator.messageIfNotMatch
                } else {
                    'Invalid data for field ${name}: ${fieldTypeInfo} of ${classTypeInfo} with data ${x.data}.'
                })
            } else {
                return false
            }
        }
        setter(instance, data, flag)
    }

    public static func new<O, F>(name: String, getter: (O) -> ?F, setter: (O, ?F) -> Unit): MutableField where O <: ObjectData<O>,
        F <: DataFields<F> {
        let fieldType = TypeInfo.of<F>()
        let classTypeInfo = ClassTypeInfo.of<O>()
        func doSet(o: Any, v: ?F) {
            match (o) {
                case x: O => setter(x, v)
                case _ =>
                    let x: Any = o
                    throw DataException(
                        "type of current instance does not match, expected ${classTypeInfo}, but receives ${TypeInfo.of(x)}")
            }
            true
        }
        MutableField(name, classTypeInfo, fieldType, newGetter<O, F>(getter), {
            o, data, flag => if (data is DataNone) {
                if ((flag & IGNORE_NONE) != 0) {
                    false
                } else {
                    doSet(o, None<F>)
                }
            } else if (let Some(v: F) <- convert<F>(data, flag: flag)) {
                doSet(o, v)
            } else if (let Some(converter) <- ReadableField.tryGetAnnotation<DataConverter<F>>(classTypeInfo, name) &&
                let Some(v: F) <- converter.convert(data, flag: flag)) {
                doSet(o, v)
            } else if ((flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0) {
                throw DataException("data ${data} cannot be converted to ${fieldType}")
            } else {
                true
            }
        })
    }
    public static func new<O, F>(name: String, getter: (O) -> F, setter: (O, F) -> Unit): MutableField where O <: ObjectData<O>,
        F <: DataFields<F> {
        let fieldType = TypeInfo.of<F>()
        MutableField(name, ClassTypeInfo.of<O>(), fieldType, newGetter<O, F>(getter), {
            o, data, flag => if (data is DataNone) {
                if ((flag & IGNORE_NONE) == 0) {
                    throw DataException('data none for field ${name} of ${TypeInfo.of<O>()}')
                } else {
                    false
                }
            } else if (let Some(v: F) <- convert<F>(data, flag: flag)) {
                match (o) {
                    case x: O =>
                        setter(x, v)
                        true
                    case _ =>
                        let x: Any = o
                        throw DataException(
                            "type of current instance does not match, expected ${TypeInfo.of<O>()}, but receives ${TypeInfo.of(x)}")
                }
            } else if ((flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0) {
                throw DataException("data ${data} cannot be converted to ${fieldType}")
            } else {
                true
            }
        })
    }
}
