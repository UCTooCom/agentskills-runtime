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

import std.collection.concurrent.ConcurrentHashMap

public class TypeMemberInfos {
    private init() {}
    private static let staticPropertyMap = ConcurrentHashMap<TypeInfo, HashMap<String, StaticPropertyInfo>>()
    private static func getStaticPropertyMap(typeInfo: TypeInfo): HashMap<String, StaticPropertyInfo> {
        match (staticPropertyMap.get(typeInfo)) {
            case Some(map) => map
            case _ =>
                let map = HashMap<String, StaticPropertyInfo>()
                staticPropertyMap[typeInfo] = map
                func addProp(ti: TypeInfo){
                    for (p in typeInfo.staticProperties) {
                        map[p.name] = p
                    }
                }
                if(let cti: ClassTypeInfo <- typeInfo){
                    var ti = Some(cti)
                    while(let Some(c) <- ti && c != ClassTypeInfo.of<Object>()){
                        addProp(c)
                        ti = c.superClass
                    }
                }else{
                    addProp(typeInfo)
                }
                map
        }
    }
    public static func staticProperties<T>(): Collection<StaticPropertyInfo> {
        staticProperties(TypeInfo.of<T>())
    }
    public static func staticProperties(typeInfo: TypeInfo): Collection<StaticPropertyInfo> {
        getStaticPropertyMap(typeInfo).values()
    }
    public static func staticProperty<T>(name: String): ?StaticPropertyInfo {
        staticProperty(TypeInfo.of<T>(), name)
    }
    public static func staticProperty(typeInfo: TypeInfo, name: String): ?StaticPropertyInfo {
        getStaticPropertyMap(typeInfo).get(name)
    }

    private static let instancePropertyMap = ConcurrentHashMap<TypeInfo, HashMap<String, InstancePropertyInfo>>()
    private static func getInstancePropertyMap(typeInfo: TypeInfo): HashMap<String, InstancePropertyInfo> {
        match (instancePropertyMap.get(typeInfo)) {
            case Some(map) => map
            case _ =>
                let map = HashMap<String, InstancePropertyInfo>()
                func addProps(ti: TypeInfo){
                    for (p in ti.instanceProperties) {
                        map[p.name] = p
                    }
                }
                if(let cti: ClassTypeInfo <- typeInfo){
                    var ti = Some(cti)
                    while(let Some(c) <- ti && c != ClassTypeInfo.of<Object>()){
                        addProps(c)
                        ti = c.superClass
                    }
                }else{
                    addProps(typeInfo)
                }
                instancePropertyMap[typeInfo] = map
                map
        }
    }
    public static func instanceProperties<T>(): Collection<InstancePropertyInfo> {
        instanceProperties(TypeInfo.of<T>())
    }
    public static func instanceProperties(typeInfo: TypeInfo): Collection<InstancePropertyInfo> {
        getInstancePropertyMap(typeInfo).values()
    }
    public static func instanceProperty<T>(name: String): ?InstancePropertyInfo {
        instanceProperty(TypeInfo.of<T>(), name)
    }
    public static func instanceProperty(typeInfo: TypeInfo, name: String): ?InstancePropertyInfo {
        getInstancePropertyMap(typeInfo).get(name)
    }

    private static let staticFunctionMap = ConcurrentHashMap<TypeInfo, HashMap<FuncMeta, StaticFunctionInfo>>()
    private static func getStaticFunctionMap(typeInfo: TypeInfo): HashMap<FuncMeta, StaticFunctionInfo> {
        match (staticFunctionMap.get(typeInfo)) {
            case Some(map) => map
            case _ =>
                let map = HashMap<FuncMeta, StaticFunctionInfo>()
                staticFunctionMap[typeInfo] = map
                func addFunc(ti: TypeInfo){
                    for (f in typeInfo.staticFunctions) {
                        let params = f.parameters
                        map.addIfAbsent(FuncMeta(f.name, Array<TypeInfo>(params.size) {
                                i => params[i].typeInfo
                            }), f)
                    }
                }
                if(let cti: ClassTypeInfo <- typeInfo){
                    var ti = Some(cti)
                    while(let Some(c) <- ti && c != ClassTypeInfo.of<Object>()){
                        addFunc(c)
                        ti = c.superClass
                    }
                }else{
                    addFunc(typeInfo)
                }
                map
        }
    }
    public static func staticFunctions<T>(): Collection<StaticFunctionInfo> {
        staticFunctions(TypeInfo.of<T>())
    }
    public static func staticFunctions(typeInfo: TypeInfo): Collection<StaticFunctionInfo> {
        getStaticFunctionMap(typeInfo).values()
    }
    public static func staticFunction<T>(name: String, paramTypes: Array<TypeInfo>): ?StaticFunctionInfo {
        staticFunction(TypeInfo.of<T>(), name, paramTypes)
    }
    public static func staticFunction(typeInfo: TypeInfo, name: String, paramTypes: Array<TypeInfo>): ?StaticFunctionInfo {
        getStaticFunctionMap(typeInfo).get(FuncMeta(name, paramTypes))
    }

    private static let instanceFunctionMap = ConcurrentHashMap<TypeInfo, HashMap<FuncMeta, InstanceFunctionInfo>>()
    private static func getInstanceFunctionMap(typeInfo: TypeInfo): HashMap<FuncMeta, InstanceFunctionInfo> {
        match (instanceFunctionMap.get(typeInfo)) {
            case Some(map) => map
            case _ =>
                let map = HashMap<FuncMeta, InstanceFunctionInfo>()
                func addFunc(ti: TypeInfo){
                    for (f in ti.instanceFunctions) {
                        let params = f.parameters
                        map.addIfAbsent(FuncMeta(f.name, Array<TypeInfo>(params.size) {
                                i => params[i].typeInfo
                            }), f)
                    }
                }
                if(let cti: ClassTypeInfo <- typeInfo){
                    var ti = Some(cti)
                    while(let Some(c) <- ti && c != ClassTypeInfo.of<Object>()){
                        addFunc(c)
                        ti = c.superClass
                    }
                }else{
                    addFunc(typeInfo)
                }
                instanceFunctionMap[typeInfo] = map
                map
        }
    }
    public static func instanceFunctions<T>(): Collection<InstanceFunctionInfo> {
        instanceFunctions(TypeInfo.of<T>())
    }
    public static func instanceFunctions(typeInfo: TypeInfo): Collection<InstanceFunctionInfo> {
        getInstanceFunctionMap(typeInfo).values()
    }
    public static func instanceFunction<T>(name: String, paramTypes: Array<TypeInfo>): ?InstanceFunctionInfo {
        instanceFunction(TypeInfo.of<T>(), name, paramTypes)
    }
    public static func instanceFunction(typeInfo: TypeInfo, name: String, params: Array<TypeInfo>): ?InstanceFunctionInfo {
        getInstanceFunctionMap(typeInfo).get(FuncMeta(name, params))
    }

    private static let staticVariableMap = ConcurrentHashMap<TypeInfo, HashMap<String, StaticVariableInfo>>()
    private static func getStaticVariableMap(typeInfo: TypeInfo): Map<String, StaticVariableInfo> {
        match (staticVariableMap.get(typeInfo)) {
            case Some(map) => map
            case _ => match (typeInfo) {
                case x: StructTypeInfo =>
                    let map = HashMap<String, StaticVariableInfo>()
                    for (v in x.staticVariables) {
                        map[v.name] = v
                    }
                    staticVariableMap[typeInfo] = map
                    map
                case x: ClassTypeInfo =>
                    let map = HashMap<String, StaticVariableInfo>()
                    var cti = Some(x)
                    while(let Some(c) <- cti && c != ClassTypeInfo.of<Object>()){
                        for (v in c.staticVariables) {
                            map[v.name] = v
                        }
                        cti = c.superClass
                    }
                    staticVariableMap[typeInfo] = map
                    map
                case _ => EmptyMap<String, StaticVariableInfo>.INSTANCE()
            }
        }
    }
    public static func staticVariables<T>(): Collection<StaticVariableInfo> {
        staticVariables(TypeInfo.of<T>())
    }
    public static func staticVariables(typeInfo: TypeInfo): Collection<StaticVariableInfo> {
        getStaticVariableMap(typeInfo).values()
    }
    public static func staticVariable<T>(name: String): ?StaticVariableInfo {
        staticVariable(TypeInfo.of<T>(), name)
    }
    public static func staticVariable(typeInfo: TypeInfo, name: String): ?StaticVariableInfo {
        getStaticVariableMap(typeInfo).get(name)
    }

    private static let instanceVariableMap = ConcurrentHashMap<TypeInfo, HashMap<String, InstanceVariableInfo>>()
    private static func getInstanceVariableMap(typeInfo: TypeInfo): Map<String, InstanceVariableInfo> {
        match (instanceVariableMap.get(typeInfo)) {
            case Some(map) => map
            case _ => match (typeInfo) {
                case x: StructTypeInfo =>
                    let map = HashMap<String, InstanceVariableInfo>()
                    for (v in x.instanceVariables) {
                        map[v.name] = v
                    }
                    instanceVariableMap[typeInfo] = map
                    map
                case x: ClassTypeInfo =>
                    let map = HashMap<String, InstanceVariableInfo>()
                    var cti = Some(x)
                    while(let Some(c) <- cti && c != ClassTypeInfo.of<Object>()){
                        for (v in x.instanceVariables) {
                            map[v.name] = v
                        }
                        cti = c.superClass
                    }
                    instanceVariableMap[typeInfo] = map
                    map
                case _ => EmptyMap<String, InstanceVariableInfo>.INSTANCE()
            }
        }
    }
    public static func instanceVariables<T>(): Collection<InstanceVariableInfo> {
        instanceVariables(TypeInfo.of<T>())
    }
    public static func instanceVariables(typeInfo: TypeInfo): Collection<InstanceVariableInfo> {
        getInstanceVariableMap(typeInfo).values()
    }
    public static func instanceVariable<T>(name: String): ?InstanceVariableInfo {
        instanceVariable(TypeInfo.of<T>(), name)
    }
    public static func instanceVariable(typeInfo: TypeInfo, name: String): ?InstanceVariableInfo {
        getInstanceVariableMap(typeInfo).get(name)
    }
}

class FuncMeta <: Hashable & Equatable<FuncMeta> {
    private let hash: Int64
    FuncMeta(private let name: String, private let param: Array<TypeInfo>) {
        hash = HashBuilder().append(name).append(param).build()
    }
    public operator func ==(other: FuncMeta) {
        refEq(this, other) || (hash == other.hash && name == other.name && param == other.param)
    }
    public func hashCode(): Int64 {
        hash
    }
}
