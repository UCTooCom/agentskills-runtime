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
package f_config

import f_data.*

@Annotation[target: [MemberProperty, MemberVariable, Parameter]]
public class DateTimeConfConverter <: AbstractDateTimeConverter {
    public const DateTimeConfConverter(private let conf: String, private let default!: String = 'yyyy-MM-dd HH:mm:ss'){}
    public func convert(data: Data, flag!: DataConversionFlag = DEFAULT_DATA_FLAG): ?DateTime {
        doConvert(data, flag, Config.getString(conf) ?? default)
    }
}
