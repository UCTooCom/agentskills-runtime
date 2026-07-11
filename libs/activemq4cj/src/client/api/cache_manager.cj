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
package activemq4cj.client.api

public class CacheManager {
    private var nextMarshallCacheIndex: Int16 = 0
    private var nextMarshallCacheEvictionIndex: Int16 = 0
    private var marshallCacheMap: ConcurrentHashMap<?DataStructure, Int16> = ConcurrentHashMap<?DataStructure, Int16>()
    private var marshallCache: ?Array<?DataStructure> = None
    private var unmarshallCache: ?Array<?DataStructure> = None
    private let MARSHAL_CACHE_FREE_SPACE: Int64 = 100

    private let marshallCacheMutex: ReentrantMutex = ReentrantMutex()
    private let unmarshallCacheMutex: ReentrantMutex = ReentrantMutex()

    public init(cacheSize: Int64) {
        //初始化缓存
        var size = cacheSize
        if (cacheSize < MARSHAL_CACHE_FREE_SPACE) {
            size = MARSHAL_CACHE_FREE_SPACE
        }
        marshallCache = Array<?DataStructure>(size, repeat: None)
        unmarshallCache = Array<?DataStructure>(size, repeat: None)
        nextMarshallCacheIndex = 0
        nextMarshallCacheEvictionIndex = 0
    }

    public func runMarshallCacheEvictionSweep(): Unit {
        // 清理缓存
        if (let Some(marshallCache) <- marshallCache) {
            while (marshallCacheMap.size > marshallCache.size - MARSHAL_CACHE_FREE_SPACE) {
                let cacheObject = marshallCache[Int64(nextMarshallCacheEvictionIndex)]
                marshallCacheMap.remove(cacheObject)
                marshallCache[Int64(nextMarshallCacheEvictionIndex)] = None

                nextMarshallCacheEvictionIndex++
                if (Int64(nextMarshallCacheEvictionIndex) >= marshallCache.size) {
                    nextMarshallCacheEvictionIndex = 0
                }
            }
        }
    }

    /**
     * 获取缓存索引
     */
    public func getMarshallCacheIndex(object: ?DataStructure): ?Int16 {
        return marshallCacheMap.get(object)
    }

    /**
     * 命令添加到缓存
     */
    public func addToMarshallCache(object: ?DataStructure): Int16 {
        synchronized(marshallCacheMutex) {
            let i: Int16 = nextMarshallCacheIndex
            nextMarshallCacheIndex++
            if (let Some(marshallCache) <- marshallCache) {
                if (nextMarshallCacheIndex >= Int16(marshallCache.size)) {
                    nextMarshallCacheIndex = 0
                }

                if (marshallCacheMap.size < marshallCache.size) {
                    marshallCache[Int64(i)] = object
                    marshallCacheMap.add(object, i)
                    return i
                }
            }
        }
        //表示未缓存该值
        return -1
    }

    public func setInUnmarshallCache(index: Int16, object: ?DataStructure): Unit {
        if (index == -1) {
            return
        }
        synchronized(unmarshallCacheMutex) {
            if (let Some(unmarshallCache) <- unmarshallCache) {
                unmarshallCache[Int64(index)] = object
            }
        }
    }

    public func getFromUnmarshallCache(index: Int16): ?DataStructure {
        synchronized(unmarshallCacheMutex) {
            if (let Some(unmarshallCache) <- unmarshallCache) {
                return unmarshallCache[Int64(index)]
            }
        }
        return None
    }
}
