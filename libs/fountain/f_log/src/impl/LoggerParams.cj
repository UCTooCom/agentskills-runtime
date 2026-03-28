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
package f_log.impl

public abstract class BaseLoggerParams<T> <: Hashable & Equatable<T> where T <: BaseLoggerParams<T> {
    protected var h: Int64 = 0
    public BaseLoggerParams(
        protected let level: LogLevel,
        protected let pattern: LogPattern
    ){
    }
    public func hashCode(): Int64 {
        h
    }
    private static let mutex = Mutex()
    protected static func newParams(appender: String): T {
        throw LogException('unreachable')
    }
    protected func newAppender(name: String): AbstractLogger 
    static func register(loggerName: String, appenderMap: ConcurrentHashMap<T, AbstractLogger>): Unit {
        LoggerAppenderCreator.register(loggerName) {
            name =>
            let appenders = LoggerConfig.getAppenders(loggerName)
            if (appenders.isEmpty()) {
                [NoneLogAppender.instance]
            } else {
                synchronized(mutex){
                    let appenderHash = HashMap<T, AbstractLogger>()
                    let appenderArray = Array<AbstractLogger>(appenders.size) {
                        i =>
                        let appenderName = appenders[i]
                        let params = T.newParams(appenderName)
                        let appender = 
                        if(let Some(appender) <- appenderMap.get(params)){
                            appender.new(name)
                        }else{
                            params.newAppender(name)
                        }
                        appenderHash[params] = appender
                        appender
                    }
                    appenderMap.removeIf{k, v => 
                        if(appenderHash.contains(k)){
                            false
                        }else{
                            v.closable = true
                            true
                        }
                    }
                    for((k, v) in appenderHash){
                        appenderMap[k] = v
                    }
                    appenderArray
                }
            }
        }
    }
}
