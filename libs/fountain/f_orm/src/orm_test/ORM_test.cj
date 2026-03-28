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
package f_orm.orm_test

import f_orm.macros.*
import f_orm.*

public class CharaterParam{
    public var id = 0
    public var name = ''
    public var originName = ''
    public var gender = None<String>
}

@DAO
public interface CharacerDAO <: RootDAO {
    // update `character` set `name` = ?, `gender` = ? where `id` = ?
    func updateCharacter(param: CharaterParam)/*: Int64*/ {
        executor.setSql(
        '''
        update `character` 
         ${SET{
            '''
            ${meet(param.name.size > 0, '`name`=').value{param.name}.done()}
            ${meet(param.gender.isSome(), '`gender`=').value{param.gender.getOrThrow()}.done()}
            '''
         }}
         ${WHERE{
            '''
                 `id`=${arg(param.id)}
             and ${meet(param.originName.size > 0, '`name`=').value{param.originName}.done()}
            '''
         }}
        '''
        ).update
    }
}