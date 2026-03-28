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
package f_http

public class HttpConfig{
    public static const CONF_PREFIX = "http"
    public static const DEFAULT_HALF_BUFFER_SIZE = 2048
    public static const DEFAULT_UPLOAD_STORE_IN_MEMORY = false
    public static const DEFAULT_HTTP_DEBUGGING = false
    public static let HTTP_DEBUGGING = "${CONF_PREFIX}_debugging"
    public static let HALF_BUFFER_SIZE = "${CONF_PREFIX}_halfBufferSize"
    public static let UPLOAD_DIR = "${CONF_PREFIX}_uploadDir"
    public static const DEFAULT_UPLOAD_DIR = "/tmp/fountain/upload"
    public static let UPLOAD_STORE_IN_MEMORY = "${CONF_PREFIX}_uploadStoreInMemory"

    private static prop isHttpDebugging: Bool {
        get() {
            Config.getValue<Bool>(HTTP_DEBUGGING) ?? DEFAULT_HTTP_DEBUGGING
        }
    }

    private static func bufferSize(bufferKey: String, default: Int64) {
        Config.bufferSize(bufferKey, default, isHttpDebugging)
    }
    public static prop halfBufferSize: Int64 {
        get() {
            bufferSize(HALF_BUFFER_SIZE, DEFAULT_HALF_BUFFER_SIZE)
        }
    }
    public static prop uploadDir: String {
        get() {
            Config.getString(UPLOAD_DIR) ?? DEFAULT_UPLOAD_DIR
        }
    }
    public static prop uploadStoreInMemory: Bool {
        get() {
            Config.getValue<Bool>(UPLOAD_STORE_IN_MEMORY) ?? DEFAULT_UPLOAD_STORE_IN_MEMORY
        }
    }
}