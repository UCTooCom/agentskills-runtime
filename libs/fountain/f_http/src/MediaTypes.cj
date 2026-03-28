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
package f_http

import std.reflect.ClassTypeInfo
import std.sync.AtomicBool
import f_log.*

public class MediaTypes {
    private static let log = LoggerFactory.getLogger<MediaTypes>()
    private static let mediaTypes = ConcurrentHashMap<String, MediaType>()
    private static let mediaTypeBeansRegistered = AtomicBool(false)
    private init(){}
    static init() {
        register(JsonMediaType.instance)
        register(MultipartMediaType.instance)
        register(PlainTextMediaType.instance)
    }
    public static func register(mediaType: MediaType) {
        log.debug{'MediaTypes.register: ${mediaType} ${ClassTypeInfo.of(mediaType)}'}
        mediaTypes[mediaType.mediaType] = mediaType
    }
    public static func parse(mediaType: String) {
        tryParse(mediaType).getOrThrow {MediaTypeException("${mediaType} is an illegal MediaType string")}
    }
    private static func registerFromBeanFactory() {
        if(mediaTypeBeansRegistered.compareAndSwap(false, true)){
            register(BeanFactory.instance.getList<MediaType>())
        }
    }
    private static func register(mediaTypes: ArrayList<MediaType>) {
        for (m in mediaTypes) {
            register(m)
        }
    }
    private static func doTryParse(mediaType: String): ?MediaType{
        registerFromBeanFactory()
        if (let Some(x) <- mediaTypes.get(mediaType)) {
            log.debug{'MediaTypes.tryParse:${mediaType} ${x} ${ClassTypeInfo.of(x)}'}
            x
        } else {
            let idx = mediaType.indexOf(";") ?? -1
            let mt = if (idx > 0) {
                mediaType[0..idx]
            } else {
                mediaType
            }
            if (let Some(x) <- mediaTypes.get(mt)) {
                log.debug{'MediaTypes.tryParse:${mediaType} ${x} ${ClassTypeInfo.of(x)}'}
                x
            } else {
                log.debug{'MediaTypes.tryParse:${mediaType} None'}
                None<MediaType>
            }
        }?.make(mediaType)
    }
    public static func tryParse(mediaType: String): ?MediaType {
        doTryParse(mediaType)
    }
}
