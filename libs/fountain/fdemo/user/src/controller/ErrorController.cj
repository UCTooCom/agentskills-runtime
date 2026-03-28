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

import fountain.mvc.*
import fountain.mvc.macros.*

@Controller
public class ErrorController {
    @GetMapping[path:"/api/error", produces:'application/json']
    @IgnoreSecurity
    public func error(): JsonValue {
        throw Exception()
    }
}