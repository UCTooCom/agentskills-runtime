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

import std.time.Month
import std.time.DateTime

public abstract class DelayedTicktockTask <: CronTicktockTask {
    public prop delayedPeriodic: DelayedPeriodic 
    public prop immediate: Bool 
    public prop delay: Duration 
    
    public prop cron: String {
        get() {
            let t = DateTime.now() + delay
            "${t.second} ${t.minute} ${t.hour} ${t.dayOfMonth} ${t.month.toInteger()} ${t.dayOfWeek.toInteger()} ${t.year}"
        }
    }
    
    protected func run(): Unit {
        func nextCall(): Unit {
            if(!once){
                Ticktock.instance.addOrReplaceTask(this)
            }
        }
        func call(){
            match(delayedPeriodic){
                case FixedDelay => 
                    try{
                        execute()
                    }finally{
                        nextCall()
                    }
                case FixedRate => 
                    nextCall()
                    execute()
            }
        }
        let currentStamp = stamped.fetchAdd(1) + 1
        func doExec() {
            try{
                call()
            }finally{
                reset(currentStamp)
            }
        }
        if (executing(currentStamp)) {
            if (concurrentable && !this.once) {
                doExec()
            } else {
                nextCall()
            }
        }else{
            doExec()
        }
    }
}
