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

package f_orm

public interface RootService {
    func executor(name: String): SqlExecutor {
        if (name.isEmpty()) {
            ORM.executor()
        } else {
            ORM.executor(name)
        }
    }
    func executor(): SqlExecutor {
        ORM.executor()
    }
    func dao<T>(driver: String): T where T <: RootDAO {
        if(let x: T <- executor(driver)){
            x
        }else{
            throw ORMException('${TypeInfo.of<T>()} is not extended to SqlExecutor')
        }
    }
    func dao<T>(): T where T <: RootDAO {
        if(let x: T <- executor()) {
            x
        }else{
            throw ORMException('${TypeInfo.of<T>()} is not extended to SqlExecutor')
        }
    }
}
