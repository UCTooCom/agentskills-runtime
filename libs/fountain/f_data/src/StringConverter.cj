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

public abstract class DataConverter<T> {
    public const init(){}
    public func convert(data: Data, flag!: DataConversionFlag): ?T 
}

public abstract class AbstractDateTimeConverter <: DataConverter<DateTime> {
    public const init(){}
    protected func doConvert(data: Data, flag: DataConversionFlag, format: String): ?DateTime {
        try{
            DateTime.parse(data.toString(), format)
        } catch(e: Exception) {
            if((flag & IGNORE_FIELD_NOT_CONVERTABLE) == 0){
                throw e
            }
            None<DateTime>
        }
    }
}
@Annotation[target: [MemberProperty, MemberVariable, Parameter]]
public class DateTimeConverter <: AbstractDateTimeConverter {
    public const DateTimeConverter(private let format: String){}
    public func convert(data: Data, flag!: DataConversionFlag = DEFAULT_DATA_FLAG): ?DateTime {
        doConvert(data, flag, format)
    }
}
