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
package f_mvc

struct OverallStopwatch{
    private static let switch = MVCConfig.mvcOverallElapsedSwitch
    private static let log: AbstractLogger
    private static let start: ThreadLocal<(MonoTime, String)>
    static init(){
        (log, start) = if(switch){
            (LoggerFactory.getLogger('MVC.overall'), ThreadLocal<(MonoTime, String)>())
        } else {
            unsafe{
                (zeroValue<AbstractLogger>(), zeroValue<ThreadLocal<(MonoTime, String)>>())
            }
        }
    }
    static func doStart(path: String) {
        if(switch){
            start.set((MonoTime.now(), path))
        }
    }
    static func elapsed(method: String){
        if(switch && let Some((s, path)) <- start.get()){
            start.set(None)
            log.debug{'${method}: ${path}; elapsed: ${MonoTime.now() - s}'}
        }
    }
}