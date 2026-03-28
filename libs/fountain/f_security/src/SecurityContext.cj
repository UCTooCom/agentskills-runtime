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

public abstract class SecurityContext<ID, U, P, S> where ID <: Hashable & Equatable<ID>, U <: BaseUserData<U>, P <: Principal<ID, P> {
    public SecurityContext(
        protected let store: PrincipalStore<ID, P>,
        private let principalMaker: (U) -> ?P,
        public let check: (S) -> Bool
    ){}
    public func login(data: U): ?P {
        if(let Some(principal) <- principalMaker(data)){
            store.store(principal)
            principal
        }else{
            None<P>
        }
    }

    public func get(id: ID): ?P {
        store.get(id)
    }
    public func checkAndGet(s: S): ?P
}
