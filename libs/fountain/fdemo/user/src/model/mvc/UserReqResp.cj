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
package user.model.mvc

import fountain.data.*
import fountain.data.macros.*
import fountain.orm.Pagination
import user.model.po.UserPO

@DataAssist[props fields]
public class UserRequest {
    @CombinedValidator[IsNotBlank(messageIfNotMatch: '请输入用户名') & StringSize(min: 6, max: 50)]
    private var username: String = ''
    @IsNotBlank[messageIfNotMatch: '请输入密码']
    private var password: String = ''
    // @IsIntegerRange[min: 1, max: 100]
    // private var int: Int64 = 0
}

@DataAssist[props fields]
public class UserResponse {
    private var status: Int64 = 0
    private var fields: ?UserSession = None<UserSession>

    public init(){}
    public init(data: ?(Int64, String, Bool)){
        if(let Some((userId, jwt, logged)) <- data){
            status = 1
            fields = UserSession(userId, jwt, logged)
        }
    }
}

@DataAssist[props fields]
public class UserSession {
    private var userId: Int64 = 0
    private var jwt: String = ''
    private var logged: Bool = false
    public init(){}
    public init(userId: Int64, jwt: String, logged: Bool){
        this.userId = userId
        this.jwt = jwt
        this.logged = logged
    }
}
@DataAssist[props fields]
public class UserList {
    public UserList(
        public let status: Int64,
        public let fields: Pagination<UserPO>
    ){}

    public init(){
        this(0, unsafeZeroValue())
    }
}