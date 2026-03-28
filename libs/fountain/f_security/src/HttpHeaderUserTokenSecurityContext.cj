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


public class HttpHeaderUserTokenSecurityContext<U> <: SecurityContext<String, U, UserTokenPrincipal<String>, Unit> where U <: BaseUserData<U>{
    private let userIdHeader: String
    private let tokenHeader: String
    public init(
        userIdHeader: String,
        tokenHeader: String,
        store: PrincipalStore<String, UserTokenPrincipal<String>>,
        principalMaker: (U) -> ?UserTokenPrincipal<String>
    ){
        super(store, principalMaker){_ => 
            let headers = CurrentHttpContext.instance.request.headers
            if(let Some(token) <- headers.getFirst(tokenHeader) && let Some(p) <- getPricinpal(userIdHeader, tokenHeader, store) && p.token == token){
                true
            }else{
                false
            }
        }
        this.userIdHeader = userIdHeader
        this.tokenHeader = tokenHeader
    }
    private static func getPricinpal(userIdHeader: String, tokenHeader: String, store: PrincipalStore<String, UserTokenPrincipal<String>>): ?UserTokenPrincipal<String> {
        let headers = CurrentHttpContext.instance.request.headers
        if(let Some(uid) <- headers.getFirst(userIdHeader) && let Some(token) <- headers.getFirst(tokenHeader)){
            store.get(uid)
        }else{
            None
        }
    }
    public func checkAndGet(_: Unit): ?UserTokenPrincipal<String> {
        checkAndGet()
    }
    public func checkAndGet(): ?UserTokenPrincipal<String> {
        if(check(())){
            let headers = CurrentHttpContext.instance.request.headers
            if(let Some(uid) <- headers.getFirst(userIdHeader)){
                return get(uid)
            }
        }
        None
    }
}