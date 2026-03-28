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

public class JWTSecurityContext<U> <: SecurityContext<String, U, JWTPrincipal<String>, Unit> where U <: BaseUserData<U> {
    public init(
        store: PrincipalStore<String, JWTPrincipal<String>>,
        principalMaker: (U) -> ?JWTPrincipal<String>,
        keySetter: (JWTVerifier, JWTPrincipal<String>) -> JWTVerifier
    ){
        super(store, principalMaker){_ =>
            let headers = CurrentHttpContext.instance.request.headers
            let jwt = if(let Some(header) <- headers.getFirst('Authorization')){
                if(header.startsWith('Bearer ')){
                    header['Bearer '.size ..]
                }else{
                    header
                }
            }else{
                ''
            }
            if(jwt.size > 0){
                let verifier = JWT.verifier(jwt)
                if(let Some(userId) <- verifier.getKeyId() && userId.size > 0 && 
                let Some(principal) <- store.get(userId)){
                    return keySetter(verifier, principal).verify()
                }
            }
            false
        }
    }
    private static func getPricinpal(store: PrincipalStore<String, JWTPrincipal<String>>): ?JWTPrincipal<String> {
        let headers = CurrentHttpContext.instance.request.headers
        let jwt = if(let Some(header) <- headers.getFirst('Authorization')){
            if(header.startsWith('Bearer ')){
                header['Bearer '.size ..]
            }else{
                header
            }
        }else{
            ''
        }
        if(jwt.size > 0){
            let verifier = JWT.verifier(jwt)
            if(let Some(userId) <- verifier.getKeyId() && userId.size > 0){
                return store.get(userId)
            }
        }
        None
    }
    public func checkAndGet(_: Unit): ?JWTPrincipal<String> {
        checkAndGet()
    }
    public func checkAndGet(): ?JWTPrincipal<String> {
        if(check(())){
            return getPricinpal(store)
        }
        None
    }
}
