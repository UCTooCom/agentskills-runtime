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
package f_data

import stdx.net.http.*
import stdx.encoding.url.*

public interface DummyDataFields<T> <: DataFields<T> where T <: DummyDataFields<T> {
    func toData(): Data {
        throw UnsupportedException()
    }
    static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        throw UnsupportedException()
    }
}
extend HttpContext <: DummyDataFields<HttpContext> {}
extend HttpRequest <: DummyDataFields<HttpRequest> {}
extend HttpHeaders <: DummyDataFields<HttpHeaders> {}
extend HttpResponseBuilder <: DummyDataFields<HttpResponseBuilder> {}
extend Form <: DummyDataFields<Form> {}