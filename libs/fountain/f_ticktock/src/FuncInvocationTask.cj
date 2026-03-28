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
package f_ticktock

public open class FuncInvocationTask <: TicktockTask {
    private var name_: String
    private var concurrentable_ = false
    private var once_ = false
    protected var function: () -> Unit

    public init(name: String, function: () -> Unit) {
        this.name_ = name
        this.function = function
    }

    public func setName(name: String) {
        this.name_ = name
    }
    public func setConcurrentable(concurrentable: Bool) {
        this.concurrentable_ = concurrentable
    }
    public func setOnce(once: Bool) {
        this.once_ = once
    }
    public func setFunction(function: () -> Unit) {
        this.function = function
    }
    public prop name: String {
        get() {
            name_
        }
    }
    public override prop concurrentable: Bool {
        get() {
            concurrentable_
        }
    }
    public override prop once: Bool {
        get() {
            once_
        }
    }
    public func execute(): Unit {
        function()
    }
}

public open class FuncInvocationCronTask <: FuncInvocationTask {
    private var cron_: String

    public init(name: String, cron: String, function: () -> Unit) {
        super(name, function)
        this.cron_ = cron
    }
    public prop cron: String {
        get() {
            cron_
        }
    }
}
