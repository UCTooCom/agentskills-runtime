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
package f_data.json

public func toJson<T>(d: T, flag!: DataConversionFlag = DEFAULT_DATA_FLAG): String where T <: ToData {
    JsonValue.tryFromData(d.toData(), flag: flag).toString()
}
public func fromJson<T>(s: String, flag!: DataConversionFlag = DEFAULT_DATA_FLAG): ?T where T <: FromData {
    match(T.tryFromData(JsonValue.fromStr(s).toData(), flag)){
        case x: T => x
        case x: ?T => x
        case _ where (flag & IGNORE_FIELD_NOT_CONVERTABLE) != 0 => None<T>
        case _ => throw DataException('${s} cannot be converted to ${TypeInfo.of<T>()}')
    }
}