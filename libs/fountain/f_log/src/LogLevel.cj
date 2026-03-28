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
package f_log

import stdx.log.LogLevel

public interface ExtendLogLevel {
    prop text: String
}

extend LogLevel <: ExtendLogLevel {
    public prop text: String {
        get() {
            if (this == FATAL) {
                'FATAL'
            } else if (this == ERROR) {
                'ERROR'
            } else if (this == WARN) {
                'WARN'
            } else if (this == INFO) {
                'INFO'
            } else if (this == DEBUG) {
                'DEBUG'
            } else {
                this.toString()
            }
        }
    }
}
