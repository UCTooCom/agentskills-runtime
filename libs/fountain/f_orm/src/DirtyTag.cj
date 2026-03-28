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

import std.collection.HashSet
import std.collection.concurrent.ConcurrentHashMap
import std.reflect.TypeInfo

public struct DirtyTag {
    private static let DIRTY_TAGS = ConcurrentHashMap<TypeInfo, DirtyTag>()
    private DirtyTag(
        private let beforeDirty!: Bool = false,
        private let dirtyFields!: ThreadLocal<HashSet<String>> = ThreadLocal<HashSet<String>>()){}
    private static func register<T>(): Unit {
        let typeInfo = TypeInfo.of<T>()
        if(!DIRTY_TAGS.contains(typeInfo)){
            DIRTY_TAGS[typeInfo] = DirtyTag()
        }
    }

    public static func setDirtyField<T>(field: String): Unit {
        if(let Some(tag) <- DIRTY_TAGS.get(TypeInfo.of<T>())){
            if(tag.beforeDirty){
                if(let Some(set) <- tag.dirtyFields.get()){
                    set
                }else{
                    let set = HashSet<String>()
                    tag.dirtyFields.set(set)
                    set
                }.add(field)
            }
        } else {
            register<T>()
            setDirtyField<T>(field)
        }
    }
    static func setBeforeDirty<T>(): Unit {
        let typeInfo = TypeInfo.of<T>()
        if(let Some(tag) <- DIRTY_TAGS.get(typeInfo)){
            DIRTY_TAGS[typeInfo] = DirtyTag(beforeDirty: true, dirtyFields: tag.dirtyFields)
        }else{
            register<T>()
            setBeforeDirty<T>()
        }
    }
    static func getDirtyFields<T>(): HashSet<String> {
        if(let Some(tags) <- DIRTY_TAGS.get(TypeInfo.of<T>()) && let Some(set) <- tags.dirtyFields.get()){
            set
        }else{
            HashSet<String>()
        }
    }
    private static func clear(typeInfo: TypeInfo) {
        if(let Some(tag) <-DIRTY_TAGS.get(typeInfo)){
            tag.dirtyFields.set(None)
            DIRTY_TAGS[typeInfo] = DirtyTag(beforeDirty: false, dirtyFields: tag.dirtyFields)
        }
    }
    static func clear<T>(): Unit {
        clear(TypeInfo.of<T>())
    }
    static func clearAll(): Unit {
        for((typeInfo, tag) in DIRTY_TAGS){
            clear(typeInfo)
        }
    }
}