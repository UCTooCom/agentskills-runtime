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
package f_security

public struct HeapCacheStore<ID, P> <: PrincipalStore<ID, P> where ID <: Hashable & Equatable<ID> & ToString, P <: Object & Principal<ID, P> {
    private let cache: HeapCache<P>
    public init(maxLife: Duration){
        cache = HeapCache<P>(maxLife: maxLife)
    }
    public func store(principal: P): Unit {
        cache.set(principal.id.toString(), principal)
    }
    public func get(id: ID): ?P {
        cache.get(id.toString())
    }
    public func remove(id: ID): ?P {
        cache.remove(id.toString())
    }
}
public type JWTHeapCacheStore = HeapCacheStore<String, JWTPrincipal<String>>

public struct UserTokenHeapCacheStore<ID> <: PrincipalStore<ID, UserTokenPrincipal<ID>> where ID <: Hashable & Equatable<ID> & ToString {
    private let store_: HeapCacheStore<ID, UserTokenPrincipal<ID>>
    public init(maxLife: Duration){
        store_ = HeapCacheStore<ID, UserTokenPrincipal<ID>>(maxLife)
    }
    public func store(principal: UserTokenPrincipal<ID>): Unit {
        store_.store(principal)
    }
    public func get(id: ID): ?UserTokenPrincipal<ID> {
        store_.get(id)
    }
    public func remove(id: ID): ?UserTokenPrincipal<ID> {
        store_.remove(id)
    }
}
type StringUserTokenHeapCacheStore = UserTokenHeapCacheStore<String>