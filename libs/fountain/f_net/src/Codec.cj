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
package f_net

public interface Encoder<EN> where EN <: ProtocolData<EN> {
    func encode(data: EN): Array<Byte>
    /**
     * 如果是无状态的，可以每次调用返回同一个实例，否则需要确保每次调用返回一个新实例
     */
    func encoder(): Encoder<EN>
}

public interface Decoder<DE> where DE <: ProtocolData<DE> {
    /**
     * 当调用本函数若干次后，传入的字节数组可完成解析完成的DE时返回Some，否则返回None。
     */
    func decode(bytes: Array<Byte>): ?DE
    /**
     * 每次调用decode，传入的字节数组不一定刚好解析一个DE，未完成解析的剩余字节和解析中间结果需要保存下来。
     * 如果单例就可以确保不会有并发问题每次调用可以返回同一个实例，否则需要确保每次调用返回一个新实例。
     */
    func decoder(): Decoder<DE>
}

public interface Codec<EN, DE> <: Encoder<EN> & Decoder<DE> where EN <: ProtocolData<EN>, DE <: ProtocolData<DE> {}
