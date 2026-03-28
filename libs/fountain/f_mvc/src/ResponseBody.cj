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

public func responseBody<T>(ctx: HttpContext, data: T): Unit where T <: Object & ObjectData<T> {
    let d = data.toData()
    let mediaType = ctx
        .request
        .headers
        .getFirst("Accept")
        .getOrThrow {HttpRequestHeaderException("current request header does not contain Accept")}
    let bytes = MediaTypes.parse(mediaType).fromData(d)
    HttpResponseWriter(ctx).write(bytes)
}
