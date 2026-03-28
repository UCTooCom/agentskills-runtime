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

import std.convert.*
import std.math.numeric.{BigInt, Decimal}

public interface DataParsable<T> where T <: DataParsable<T> {
    static func parse(s: String): T
    static func tryParse(s: String): ?T
}

extend Duration <: DataParsable<Duration> {
    public static func parse(s: String): Duration {
        tryParse(s).getOrThrow {DataParsableException('${s} cannot be parsed to ${TypeInfo.of<Duration>()}')}
    }
    public static func tryParse(s: String): ?Duration {
        let bytes = ArrayList<Byte>()
        var duration = Duration.Zero
        var i = 0
        while (i < s.size) {
            let r = s[i]
            i++
            duration += match (r) {
                case x where x == b'-' || (x >= b'0' && x <= b'9') =>
                    bytes.add(x)
                    i++
                    continue
                case b'd' => Duration.day
                case b'h' => Duration.hour
                case b'm' =>
                    if (s[i] == b's') {
                        i++
                        Duration.millisecond
                    } else {
                        Duration.minute
                    }
                case b's' => Duration.second
                case b'u' where s[i] == b's' =>
                    i++
                    Duration.microsecond
                case b'n' where s[i] == b's' =>
                    i++
                    Duration.nanosecond
                case _ => throw DataParsableException('${s} cannot be parsed to Duration')
            } *
                Int64
                .tryParse(String.fromUtf8(bytes.unsafeData()))
                .getOrThrow {DataParsableException('${s} cannot be parsed to Duration')}
        }
        duration
    }
}

extend Int64 <: DataParsable<Int64> {}

extend UInt64 <: DataParsable<UInt64> {}

extend Int32 <: DataParsable<Int32> {}

extend UInt32 <: DataParsable<UInt32> {}

extend Int16 <: DataParsable<Int16> {}

extend UInt16 <: DataParsable<UInt16> {}

extend Int8 <: DataParsable<Int8> {}

extend UInt8 <: DataParsable<UInt8> {}

extend Float64 <: DataParsable<Float64> {}

extend Float32 <: DataParsable<Float32> {}

extend Float16 <: DataParsable<Float16> {}

extend Bool <: DataParsable<Bool> {}

extend BigInt <: DataParsable<BigInt> {}

extend Decimal <: DataParsable<Decimal> {}
