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
package user.model.po

import std.time.DateTime

import fountain.base.unsafeZeroValue
import fountain.data.*
import fountain.data.macros.*
import fountain.orm.*
import fountain.orm.macros.*

@DataAssist[fields tostring]
@QueryMappersGenerator[table: user_info dirty]
public class UserPO {
    @ORMField[true 'id']
    private var id: Int64 = 0
    @ORMField['username']
    private var username: String = ''
    @ORMField['password']
    private var password: String = ''
    @ORMField['save_time']
    private var saveTime: ?DateTime = None<DateTime>
}

@QueryMappersGenerator[classSuffix: 'PO' table: LowerUnderScore tablePrefix: 't_']
public class UserInfoPO {//不要使用这个类，仅用于展示@QueryMappersGenerator的用法
    @ORMField[true 'id']
    private var id: Int64 = 0
    @ORMField['username']
    private var username: String = ''
    @ORMField['password']
    private var password: String = ''
    @ORMField['save_time']
    private var saveTime: ?DateTime = None<DateTime>
}
private let _ = {=>
    println('@@@@@@@@@@@@@@@@@@@@@@@@@@@@ ${UserPO.tableName()}')
    println('@@@@@@@@@@@@@@@@@@@@@@@@@@@@ ${UserInfoPO.tableName()}')
    let user = UserPO()
    user.id = 1
    user.username = 'asdfasdfasdf'
    println('@@@@@@@@@@@@@@@@@@@@@@@@@@@@ ${user}')
}()