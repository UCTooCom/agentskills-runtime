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
import fountain.data.*
import fountain.mvc.*
import fountain.mvc.macros.*
import user.service.UserService
import user.model.po.*
import user.model.mvc.*

@Controller
public class UserController {
    private let userService = lookup<UserService>()

    @GetMapping[path:'/api/user/{id}', 
                produces:'application/json', 
                consumes:'application/x-www-form-urlencoded']
    public func queryUser(@PathVariable id: Int64): JsonValue {
        println('get user by id: ${id}')
        let user = userService.queryUser(id)
        let json = '''
        {
            "status":1, 
            "fields": {
                "id": ${user.id},
                "username": "${user.username}",
                "password": "${user.password}",
                "registerTime": "${user.saveTime}"
            }
        }
        '''
        println('/api/user${id} ${json}')
        JsonValue.fromStr(json)
    }
    @GetMapping[path:'/api/users', 
                produces:'application/json', 
                consumes:'application/x-www-form-urlencoded']
    public func listUsers(): UserList {
        // let v1 = Some(1234)
        // println(v1 ?? 0)
        // let v2 = None<Int64>
        // println(v2 ?? 1)
        userService.listUsers()
    }
    // @GetMapping[path:'/api/users', 
    //             produces:'application/json', 
    //             consumes:'application/x-www-form-urlencoded']
    // public func listUsers2(): UserList {
    //     userService.listUsers()
    // }
    @DeleteMapping[path:'/api/user/{id}', 
                   produces:'application/json', 
                   consumes:'application/x-www-form-urlencoded']
    public func deleteUser(@PathVariable id: Int64): JsonValue {
        println('delete user id is ${id}')
        let deleted = userService.deleteUser(id)
        let json = '''
        {
            "status": 1,
            "fields": {
                "deleted": ${deleted}
            }
        }'''
        JsonValue.fromStr(json)
    }
}