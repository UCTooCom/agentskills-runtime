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

func parseValue<T>(value: ?String, converter: ?AbstractDateTimeConverter): ?T {
    let none = None<T>
    if (let None <- value) {
        return none
    }
    let val = value.getOrThrow()
    let any: Any = match (none) {
        case _: ?String => val
        case _: ?Bool => Bool.tryParse(val)
        case _: ?Int8 => Int8.tryParse(val)
        case _: ?Int16 => Int16.tryParse(val)
        case _: ?Int32 => Int32.tryParse(val)
        case _: ?Int64 => Int64.tryParse(val)
        case _: ?Float64 => Float64.tryParse(val)
        case _: ?Float32 => Float32.tryParse(val)
        case _: ?Float16 => Float16.tryParse(val)
        case _: ?UInt8 => UInt8.tryParse(val)
        case _: ?UInt16 => UInt16.tryParse(val)
        case _: ?UInt32 => UInt32.tryParse(val)
        case _: ?UInt64 => UInt64.tryParse(val)
        case _: ?BigInt => BigInt.tryParse(val)
        case _: ?Decimal => Decimal.tryParse(val)
        case _: ?Duration => Duration.tryParse(val)
        case _: ?DateTime => if(let Some(c) <- converter){
            c.convert(val.toData(), flag: DEFAULT_DATA_FLAG)
        }else{
            DateTime.tryParse(val)
        }

        case _: ??String => val
        case _: ??Bool => Bool.tryParse(val)
        case _: ??Int8 => Int8.tryParse(val)
        case _: ??Int16 => Int16.tryParse(val)
        case _: ??Int32 => Int32.tryParse(val)
        case _: ??Int64 => Int64.tryParse(val)
        case _: ??Float64 => Float64.tryParse(val)
        case _: ??Float32 => Float32.tryParse(val)
        case _: ??Float16 => Float16.tryParse(val)
        case _: ??UInt8 => UInt8.tryParse(val)
        case _: ??UInt16 => UInt16.tryParse(val)
        case _: ??UInt32 => UInt32.tryParse(val)
        case _: ??UInt64 => UInt64.tryParse(val)
        case _: ??BigInt => BigInt.tryParse(val)
        case _: ??Decimal => Decimal.tryParse(val)
        case _: ??Duration => Duration.tryParse(val)
        case _: ??DateTime => if(let Some(c) <- converter){
            c.convert(val.toData(), flag: DEFAULT_DATA_FLAG)
        }else{
            DateTime.tryParse(val)
        }

        case _: ?Array<String> => val.split(",")
        case _: ?Array<Bool> =>
            let array = val.split(',')
            Array<Bool>(array.size) {
                i => Bool.parse(array[i])
            }
        case _: ?Array<Byte> =>
            let array = val.split(',')
            Array<Byte>(array.size) {
                i => Byte.parse(array[i])
            }
        case _: ?Array<Int8> =>
            let array = val.split(',')
            Array<Int8>(array.size) {
                i => Int8.parse(array[i])
            }
        case _: ?Array<Int16> =>
            let array = val.split(',')
            Array<Int16>(array.size) {
                i => Int16.parse(array[i])
            }
        case _: ?Array<Int32> =>
            let array = val.split(',')
            Array<Int32>(array.size) {
                i => Int32.parse(array[i])
            }
        case _: ?Array<Int64> =>
            let array = val.split(',')
            Array<Int64>(array.size) {
                i => Int64.parse(array[i])
            }
        case _: ?Array<UInt8> =>
            let array = val.split(',')
            Array<UInt8>(array.size) {
                i => UInt8.parse(array[i])
            }
        case _: ?Array<UInt16> =>
            let array = val.split(',')
            Array<UInt16>(array.size) {
                i => UInt16.parse(array[i])
            }
        case _: ?Array<UInt32> =>
            let array = val.split(',')
            Array<UInt32>(array.size) {
                i => UInt32.parse(array[i])
            }
        case _: ?Array<UInt64> =>
            let array = val.split(',')
            Array<UInt64>(array.size) {
                i => UInt64.parse(array[i])
            }
        case _: ?Array<Float64> =>
            let array = val.split(',')
            Array<Float64>(array.size) {
                i => Float64.parse(array[i])
            }
        case _: ?Array<Float32> =>
            let array = val.split(',')
            Array<Float32>(array.size) {
                i => Float32.parse(array[i])
            }
        case _: ?Array<Float16> =>
            let array = val.split(',')
            Array<Float16>(array.size) {
                i => Float16.parse(array[i])
            }
        case _: ?Array<BigInt> =>
            let array = val.split(',')
            Array<BigInt>(array.size) {
                i => BigInt.parse(array[i])
            }
        case _: ?Array<Decimal> =>
            let array = val.split(',')
            Array<Decimal>(array.size) {
                i => Decimal.parse(array[i])
            }
        case _: ?Array<Duration> => 
            let array = val.split(',')
            Array<Duration>(array.size){i => Duration.parse(array[i])}
        case _ => throw MVCException('${value} cannot be parsed to ${TypeInfo.of<T>()}')
    }
    match (any) {
        case x: T => Some(x)
        case x: ?T => x
        case _ => None<T>
    }
}
