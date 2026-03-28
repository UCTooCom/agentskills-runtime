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
package boot

import fountain.bean.*
import fountain.bean.macros.*
import fountain.log.*
import fountain.orm.*

@Bean
public class TransactionHookImpl <: TransactionHook {
    private let log = LoggerFactory.getLogger('TransactionHook')
    public func beforeTx(): Unit {
        log.info('beforeTx')
    }
    public func beforeCommit(readOnly: Bool): Unit {
        log.info('beforeCommit')
    }
    public func afterCommit(): Unit {
        log.info('afterCommit')
    }
    public func afterThrowing(e: Exception): Unit {
        log.info('afterThrowing')
    }
    public func beforeRollback(e: Exception): Unit {
        log.info('beforeRollback')
    }
    public func afterRollback(e: Exception): Unit {
        log.info('afterRollback')
    }
    public func afterComplete(status: TransactionStatus): Unit {
        log.info('afterComplete')
    }
}
