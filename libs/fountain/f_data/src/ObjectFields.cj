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

public struct ObjectFields <: Collection<ReadableField> {
    private static let allFields = ConcurrentHashMap<TypeInfo, ObjectFields>()
    private let mutables = HashMap<String, MutableField>()
    private let readables = HashMap<String, ReadableField>()
    private ObjectFields(private let creator: () -> Object){}
    public static func getObjectFields<T>(metas: () -> (Array<ReadableField>, ()->Object)): ObjectFields 
    where T <: ObjectData<T> & DataFields<T> {
        let currentType = (TypeInfo.of<T>() as ClassTypeInfo).getOrThrow()
        allFields.computeIfAbsent(currentType){
            let (fields, creator) = metas()
            let that = ObjectFields(creator)
            func populateField(name: String, field: ReadableField, throwIfDuplicate!: Bool = true) {
                if (that.readables.addIfAbsent(name, field).isSome() && throwIfDuplicate) {
                    throw DataException('duplicate field ${name}}')
                } else if (let x: MutableField <- field) {
                    that.mutables.addIfAbsent(name, x)
                }
            }
            func populateFields(fields: Iterable<ReadableField>, throwIfDuplicate!: Bool = true) {
                for (f in fields) {
                    populateField(f.name, f, throwIfDuplicate: throwIfDuplicate)
                }
            }
            func populateFields(name: String, annotations: Collection<Annotation>) {
                let f = if (let Some(f) <- that.readables.get(name)) {
                    f
                } else {
                    return
                }
                for (annotation in annotations) {
                    if(let x: FieldAlias <- annotation){
                        for (n in x.name.split(',')) {
                            populateField(n, f)
                        }
                    }
                }
            }
            populateFields(fields)
            for (v in currentType.instanceVariables) {
                populateFields(v.name, v.annotations)
            }
            for (p in currentType.instanceProperties) {
                populateFields(p.name, p.annotations)
            }
            if (let Some(superClass) <- currentType.superClass && 
                superClass.isSubtypeOf(TypeInfo.get('f_data.ObjectData<${superClass.qualifiedName}>')) && 
                let f <- superClass.getStaticFunction('dataFields', []) && 
                let sdf: ObjectFields <- f.apply(superClass, [])) {
                populateFields(sdf.readables.values(), throwIfDuplicate: false)                    
            }
            that
        }
    }
    public func create(): Object {
        creator()
    }
    public prop size: Int64 {
        get() {
            readables.size
        }
    }
    public func isEmpty() {
        size == 0
    }
    public func iterator(): Iterator<ReadableField> {
        readables.values().iterator()
    }
    public func mutableFields(): Iterator<MutableField> {
        mutables.values().iterator()
    }
    public func mutableField(name: String): ?MutableField {
        mutables.get(name)
    }
    public func readableField(name: String): ?ReadableField {
        readables.get(name)
    }
}
