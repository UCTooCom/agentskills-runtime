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
package user.util

import std.convert.*
import fountain.base.*
import fountain.jwt.JWT
import fountain.mvc.CurrentHttpContext
import fountain.security.*
import fountain.util.UUID

public class UserSessionCache {
    private static let context = JWTSecurityContext<String>(JWTHeapCacheStore(Duration.hour),{id => 
        JWTPrincipal<String>(id, '', UUID.random().toHexString())
    }){verifier, principal => 
        hmacKey(verifier, principal)
    }
    private static func keyId(principal: JWTPrincipal<String>){
        principal.key.unsafeBytes()
    }
    private static func hmacKey<T>(jwt: T, principal: JWTPrincipal<String>): T where T <: JWT {
        hmacKey(jwt, keyId(principal))
    }
    private static func hmacKey<T>(jwt: T, key: Array<Byte>): T where T <: JWT {
        jwt.hmacMD5(key)
    }
    private static let expire = Duration.hour
    private init(){}
    public static func generate(userId: Int64): String {
        let uids = userId.toString()
        let principal = context.login(uids).getOrThrow{SecurityException()}
        hmacKey(JWT.encoder(), principal).keyId(uids).expire(expire).sign()
    }

    public static func verify(): Bool {
        let v = context.check(())
        v
    }
}