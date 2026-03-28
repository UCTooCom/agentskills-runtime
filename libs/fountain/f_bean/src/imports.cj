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
package f_bean

internal import std.collection.{TreeMap, LinkedList, ArrayList, TreeSet, HashSet}
internal import std.collection.concurrent.ConcurrentHashMap
internal import std.convert.*
internal import std.env.*
internal import std.process.Process
internal import std.reflect.*
internal import std.sync.{AtomicInt64, AtomicBool, AtomicOptionReference, Mutex}
internal import f_config.Config
internal import f_data.*
internal import f_regex.*
public import std.collection.{HashMap, ArrayList}
public import std.convert.*
public import f_base.*
public import f_bean.exception.*
public import f_config.*
public import f_data.*

public const SHOULD_INIT_BEAN_CONF_KEY = 'shouldInitBean'
/**
 * 初始化时使用命令行参数--shouldInitBean
 */
internal let shouldInitBean = Config.getValue<Bool>(SHOULD_INIT_BEAN_CONF_KEY) ?? true

public func setShouldInitBean(value: Bool) {
    Config.set<Bool>([(SHOULD_INIT_BEAN_CONF_KEY, value)])
}
