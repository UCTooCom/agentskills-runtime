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
package user.controller

import std.reflect.*
import stdx.encoding.json.*
// import fountain.aspect.*
// import fountain.aspect.macros.*
// import fountain.bean.*
// import fountain.bean.macros.*
import fountain.mvc.*
import fountain.mvc.macros.*
import user.service.UserService
import user.model.po.*
import user.model.mvc.*

/**
 * 把UserController CurrentUserController合并成一个，加载时会抛出异常。
 * 分开两个类就能正常加载
 */
@WeavedController
@BeanMeta[scope: BeanScope.prototype]//此类不需要prototype，仅做演示，BeanMeta必须在@WeavedController下面，或者不用这个注解
public class CurrentUserController { 
    private let userService = lookup<UserService>()

    public init(){
        println('CurrentUserController init 这一行可以证明这个类是prototype的，多次访问本类的controller映射这一行每次都会输出')
    }

    @PostMapping[path:'/api/user/register', 
                 consumes:'application/x-www-form-urlencoded', produces:'text/plain',
                 ignoreAuth: true, ignorePrivilege: true]
    public func register(@RequestParam username: String, @RequestParam password: String): String {
        let id = userService.register(username, password).toString()
        // let json = JsonObject()
        // json.put('username', JsonString(username))
        // json.put('password', JsonString(password))
        // println(json)
        // println(JsonString(username))
        // let u = 'username'
        // println(JsonString(u))
        // json
        '''
        {
            "id": ${id},
            "username": "${username}",
            "password": "${password}"
        }
        '''
    }
    @PutMapping[path:'/api/user/changePassword', 
                consumes:'application/x-www-form-urlencoded', 
                produces:'text/plain']
    public func changePassword(@RequestParam username: String, @RequestParam password: String): String {
        let count = userService.changePassword(username, password).toString()
        '''
        {
            "count": ${count},
            "username": "${username}",
            "password": "${password}"
        }
        '''
    }
    
    @PostMapping[path:'/api/user/sessionLog', 
                consumes:'application/json+log', 
                produces:'application/json+log',
                ignoreAuth: true]
    public func loginLog(@RequestBody user: UserRequest): UserRequest {
        userService.userSessionLog(user.username, user.password)
        user
    }
    @PostMapping[path:'/api/user/session', 
                consumes:'application/json', 
                produces:'application/json',
                ignoreAuth: true]
    public func login(@RequestBody user: UserRequest): UserResponse {
        // let user = parser.parse<UserRequest>('parser')
        let data = userService.userSession(user.username, user.password)
        UserResponse(data)
    }
    @PostMapping[path:'/api/user/echo', 
                consumes:'application/x-www-form-urlencoded', 
                produces:'application/json',
                ignoreAuth: true]
    public func echo(@RequestParamObject user: UserRequest): UserRequest {
        user
    }
    @PostMapping[path:'/api/user/echo2', 
                consumes:'application/x-www-form-urlencoded', 
                produces:'application/json',
                ignoreAuth: true]
    public func echo2(@RequestParam[default: ''] username: String, @RequestParam[default: ''] password: String): UserRequest {
        let user = UserRequest()
        user.username = username
        user.password = password
        user
    }
    
    @DeleteMapping[path:'/api/user/session', 
                consumes:'application/x-www-form-urlencoded', 
                produces:'application/json']
    public func echoSession(@RequestHeader userId: Int64, @RequestHeader token: String): JsonValue {
        let json = '''
        {
            "status": 1,
            "fields": {
                "userId": ${userId},
                "token": "${token}"
            }
        }'''
        JsonValue.fromStr(json)
    }
}