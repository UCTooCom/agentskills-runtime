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

import f_base.*

struct AnnotationTag <: Hashable & Equatable<AnnotationTag> {
    private let h: Int64
    AnnotationTag(private let annotationType: TypeInfo, private let typeInfo: ClassTypeInfo, private let name: String){
        h = HashBuilder().append(annotationType).append(typeInfo).append(name).build()
    }
    public func hashCode(): Int64 {
        h
    }
    public operator func ==(other: AnnotationTag){
        this.h == other.h && this.annotationType == other.annotationType && this.typeInfo == other.typeInfo && this.name == other.name
    }
}
abstract sealed class ReadableField {
    private static let annotations = ConcurrentHashMap<AnnotationTag, ?Annotation>()
    public let name: String
    public ReadableField(
        name: String,
        public let classTypeInfo: ClassTypeInfo,
        public let fieldTypeInfo: TypeInfo,
        private let getter: (Any) -> Data
    ) {
        this.name = if (name[0] == b'`') {
            name[1..name.size - 1]
        } else {
            name
        }
    }
    public static func tryGetAnnotation<A>(classTypeInfo: ClassTypeInfo, name: String): ?A where A <: Annotation {
        let annotationType = TypeInfo.of<A>()
        let tag = AnnotationTag(annotationType, classTypeInfo, name)
        let annotation = annotations.computeIfAbsent(tag){
            func getAnnotation(name: String): ?Annotation {
                if (let Some(x) <- TypeMemberInfos.instanceProperty(classTypeInfo, name)){
                    x.findAnnotation<Annotation>()
                } else if (let Some(x) <- TypeMemberInfos.instanceVariable(classTypeInfo, name)) {
                    x.findAnnotation<Annotation>()
                } else {
                    None<Annotation>
                }
            }
            if(let Some(x) <- getAnnotation(name)){
                x
            }else{
                getAnnotation('`${name}`')
            }
        }
        match(annotation){
            case Some(a: A) => a
            case _ => None<A>
        }
    }
    public func tryFindAnnotation<A>(): ?A where A <: Annotation {
        tryGetAnnotation<A>(classTypeInfo, name)
    }
    public prop validator: Validator {
        get(){
            tryFindAnnotation<Validator>() ?? DummyValidator.instance
        }
    }
    public func get(instance: Any): Data {
        getter(instance)
    }
    protected static func newGetter<O, F>(fn: (O) -> F): (Any) -> Data where O <: ObjectData<O>, F <: DataFields<F> {
        {
            o => match (o) {
                case x: O => fn(x).toData()
                case _ =>
                    let x: Any = o
                    throw DataException(
                        "type of current instance does not match, expected ${TypeInfo.of<O>()}, but receives ${TypeInfo.of(x)}")
            }
        }
    }
    protected static func newGetter<O, F>(fn: (O) -> ?F): (Any) -> Data where O <: ObjectData<O>, F <: DataFields<F> {
        {
            o => match (o) {
                case x: O => fn(x).toData()
                case _ =>
                    let x: Any = o
                    throw DataException(
                        "type of current instance does not match, expected ${TypeInfo.of<O>()}, but receives ${TypeInfo.of(x)}")
            }
        }
    }
}
