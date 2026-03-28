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
package f_util

import f_data.Validator

@Annotation[target: [MemberVariable, MemberProperty, Parameter]]
public class IsUUID <: Validator {
    public const init(){}
    public func validate(value: ?String): Bool {
        if(let Some(x) <- value){
            UUID.tryParse(x).isSome()
        }else{
            false
        }
    }
}