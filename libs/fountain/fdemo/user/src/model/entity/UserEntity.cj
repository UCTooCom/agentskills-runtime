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
package user.model.entity

import fountain.jwt.*

import user.util.*

public class UserEntity {
    public UserEntity(private let username: String, private let password: String) {}

    public func makeSession(querier: (String, String) -> ?Int64): ?(Int64, String, Bool) {
        if (let Some(id) <- querier(username, password)) {
            let jwt = UserSessionCache.generate(id)
            (id, jwt, true)
        } else {
            None<(Int64, String, Bool)>
        }
    }
}