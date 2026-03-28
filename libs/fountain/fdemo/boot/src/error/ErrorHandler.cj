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
package boot.error

import stdx.net.http.HttpContext
import fountain.bean.*
import fountain.bean.macros.*
import fountain.data.*
import fountain.data.macros.*
import fountain.mvc.{ErrorHttpRequestHandler, HttpStatus}

@Bean
@BeanMeta[name: 'NameOf500Handler']
public class Http500Handler <: ErrorHttpRequestHandler {
    public func handle(_: HttpContext, ex: ?Exception): (HttpStatus, Any) {
        if (let Some(e: ValidationException) <- ex) {
            (HttpStatus.INTERNAL_SERVER_ERROR, BaseResponse.error(e.message))
        } else {
            (HttpStatus.OK, BaseResponse.error('error'))
        }
    }
}

@DataAssist[fields]
public open class BaseResponse {
    public var status: Int64 = 0
    public var msg: String = "ok"

    public init() {}
    public init(status: Int64, msg: String) {
        super()
        this.status = status
        this.msg = msg
    }

    public static func success(): BaseResponse {
        BaseResponse(0, "ok")
    }

    public static func success(msg: String): BaseResponse {
        BaseResponse(1, msg)
    }

    public static func error(msg: String): BaseResponse {
        BaseResponse(-1, msg)
    }
}
