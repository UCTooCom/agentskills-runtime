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

public class UserTokenSecurityContext<ID, U> <: SecurityContext<ID, U, UserTokenPrincipal<ID>, (ID, String)> where ID <: Hashable & Equatable<ID>, U <: BaseUserData<U>{
    public init(
        store: PrincipalStore<ID, UserTokenPrincipal<ID>>,
        principalMaker: (U) -> ?UserTokenPrincipal<ID>
    ){
        super(store, principalMaker){tpl => 
            if(let Some(p) <- store.get(tpl[0]) && p.token == tpl[1]){
                true
            }else{
                false
            }
        }
    }
    public func checkAndGet(s: (ID, String)): ?UserTokenPrincipal<ID> {
        checkAndGet(s[0], s[1])
    }
    public func checkAndGet(id: ID, token: String): ?UserTokenPrincipal<ID> {
        if(check((id, token))){
            get(id)
        }else{
            None
        }
    }
}