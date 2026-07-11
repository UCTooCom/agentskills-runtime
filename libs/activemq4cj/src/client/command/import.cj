/**
 * Copyright 2024 Beijing Baolande Software Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Runtime Library Exception to the Apache 2.0 License:
 *
 * As an exception, if you use this Software to compile your source code and
 * portions of this Software are embedded into the binary product as a result,
 * you may redistribute such product without providing attribution as would
 * otherwise be required by Sections 4(a), 4(b) and 4(d) of the License.
 */
package activemq4cj.client.command

internal import stdx.compress.zlib.CompressOutputStream
internal import stdx.compress.zlib.DecompressOutputStream
internal import stdx.encoding.json.JsonValue
internal import stdx.encoding.json.ToJson
internal import stdx.encoding.url.URL
internal import stdx.serialization.serialization.*
internal import std.collection.LinkedList
internal import std.collection.HashMap
internal import std.collection.HashSet
internal import std.convert.Parsable
internal import std.io.ByteBuffer as ByteArrayStream
internal import std.reflect.TypeInfo
internal import std.sync.AtomicInt64
internal import std.sync.ReentrantMutex
internal import std.time.DateTime
internal import activemq4cj.client.api.*
internal import activemq4cj.client.util.Convert
internal import activemq4cj.client.util.ExceptionHelper
internal import activemq4cj.client.util.MarshallingSupport
internal import activemq4cj.client.util.TypeConversionSupport
internal import activemq4cj.client.util.URLSupport
internal import activemq4cj.cjms.BytesMessage
internal import activemq4cj.cjms.CJMSException
internal import activemq4cj.cjms.Destination
internal import activemq4cj.cjms.DeliveryMode
internal import activemq4cj.cjms.Message as CJMSMessage
internal import activemq4cj.cjms.MapMessage
internal import activemq4cj.cjms.MessageEOFException
internal import activemq4cj.cjms.MessageFormatException
internal import activemq4cj.cjms.MessageNotReadableException
internal import activemq4cj.cjms.MessageNotWriteableException
internal import activemq4cj.cjms.ObjectMessage
internal import activemq4cj.cjms.Queue
internal import activemq4cj.cjms.StreamMessage
internal import activemq4cj.cjms.TextMessage
internal import activemq4cj.cjms.Topic
internal import activemq4cj.cjms.TemporaryQueue
internal import activemq4cj.cjms.TemporaryTopic
internal import hyperion.buffer.ByteBuffer
