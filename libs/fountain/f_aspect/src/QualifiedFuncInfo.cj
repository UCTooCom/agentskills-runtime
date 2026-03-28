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
package f_aspect

public class InvocationFuncInfo {
    public InvocationFuncInfo(
        private let _funcInfo: QualifiedFuncInfo,
        private var _args: Array<Any>
    ) {
    }
    public init(
        typeInfo: TypeInfo,
        funcName: String,
        argTypes: Array<TypeInfo>,
        args: Array<Any>
    ) {
        this(QualifiedFuncInfo(typeInfo, funcName, argTypes), args)
    }
    func setArgs(args: Array<Any>) {
        this._args = args
    }
    public prop args: Array<Any> {
        get() {
            _args
        }
    }
    public prop typeInfo: TypeInfo {
        get() {
            _funcInfo.typeInfo
        }
    }
    public prop funcInfo: InstanceFunctionInfo {
        get() {
            _funcInfo.funcInfo
        }
    }
    public prop qualifiedFuncInfo: QualifiedFuncInfo {
        get() {
            _funcInfo
        }
    }
}

public class QualifiedFuncInfo <: Hashable & Equatable<QualifiedFuncInfo> {
    private let hash: Int64
    public QualifiedFuncInfo(
        public let typeInfo: TypeInfo,
        public let funcInfo: InstanceFunctionInfo
    ) {
        hash = doHash(typeInfo, funcInfo)
    }
    public init(
        typeInfo: TypeInfo,
        funcName: String,
        argTypes: Array<TypeInfo>
    ) {
        this(typeInfo, typeInfo.getInstanceFunction(funcName, argTypes))
    }
    private static func doHash(typeInfo: TypeInfo, funcInfo: InstanceFunctionInfo) {
        HashBuilder().append(typeInfo).append(funcInfo).build()
    }
    public operator func ==(other: QualifiedFuncInfo) {
        refEq(this, other) || (this.typeInfo == other.typeInfo && this.funcInfo == other.funcInfo)
    }
    public func hashCode() {
        hash
    }
}
