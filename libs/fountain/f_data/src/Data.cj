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

public interface Data <: FromToData & ToString & DataParsable<Data> {
    func toData(): Data {
        return this
    }
    static func fromData(data: Data, flag: DataConversionFlag): Any{
        data
    }
    static func tryFromData(data: Data, flag: DataConversionFlag): Any {
        data
    }
}

func extractPureString(data: String) {
    if ((data.startsWith('"') && data.endsWith('"')) || (data.startsWith("'") && data.endsWith("'"))) {
        data[1..data.size - 1]
    } else {
        data
    }
}
