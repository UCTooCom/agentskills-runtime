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
package f_base

foreign {
    func memcpy(dest: CPointer<Unit>, src: CPointer<Unit>, n: UIntNative): CPointer<Unit>

    func getpagesize(): IntNative
}
/**
 * 当前系统内存页大小
 */
public let MEM_PAGE_SIZE = unsafe { Int64(getpagesize()) }
/**
 * null void*
 */
public let nullptr = unsafe { zeroValue<CPointer<Unit>>() }

/**
 * 简单调用memcpy
 */
public unsafe func mcopy(dest: CPointer<Unit>, src: CPointer<Unit>, n: UIntNative): CPointer<Unit> {
    memcpy(dest, src, n)
}
