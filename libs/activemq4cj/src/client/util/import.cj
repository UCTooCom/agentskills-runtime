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
package activemq4cj.client.util

internal import stdx.encoding.url.URL
internal import stdx.encoding.url.UrlSyntaxException
internal import std.collection.EquatableCollection
internal import std.collection.HashMap
internal import std.collection.HashMapIterator
internal import std.collection.Map
internal import std.collection.LinkedList
internal import std.collection.MapEntryView
internal import std.convert.Parsable
internal import std.io.IOException
internal import std.random.Random
internal import std.reflect.*
internal import std.sort.sort
internal import std.sync.AtomicBool
internal import std.sync.AtomicInt32
internal import std.sync.AtomicInt64
internal import std.sync.ReentrantReadWriteMutex
internal import std.time.DateTime
internal import activemq4cj.cjms.MessageEOFException
internal import hyperion.buffer.ByteBuffer
internal import hyperion.transport.TransportException
internal import std.posix.*
