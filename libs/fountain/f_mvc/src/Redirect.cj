/*
Copyright (c) 2026 WuJingrun（吴京润）

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

/**
 * 重定向类型，controller函数返回本类型的实例即可实现重定向
 */
public struct Redirect {
    private Redirect(
        public let status: HttpStatus,
        public let location: String
    ) {}
    /**
     * 302
     */
    public static func found(location: String): Redirect {
        Redirect(HttpStatus.FOUND, location)
    }
    /**
     * retain是false，301；否则是308
     */
    public static func permanently(location: String, retain!: Bool = false): Redirect {
        Redirect(if (!retain) {
            HttpStatus.MOVED_PERMANENTLY
        } else {
            HttpStatus.PERMANENT_REDIRECT
        }, location)
    }
    /**
     * retain是false, 302; 否则是307
     */
    public static func temporarily(location: String, retain!: Bool = false): Redirect {
        Redirect(if (!retain) {
            HttpStatus.MOVED_TEMPORARILY
        } else {
            HttpStatus.TEMPORARY_REDIRECT
        }, location)
    }
}
