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
package user.util.cron

import std.time.*
import fountain.ticktock.*
import fountain.bean.*
import fountain.bean.macros.*
import fountain.log.LoggerFactory

@Bean
public class TickTockTaskImpl <: CronTicktockTask {
    private static let log = LoggerFactory.getLogger<TickTockTaskImpl>()
    public prop cron: String {
        get() {
            '1/3-45'//cron表达式末尾的*可以省略
        }
    }
    public func execute(): Unit {
        log.info('TickTockTaskImpl is executing')
    }
}