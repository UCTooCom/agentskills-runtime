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

public class Collections {
    public static func addAll<T>(src: Collection<T>, dest: LinkedList<T>) {
        for (element in src) {
            dest.addLast(element)
        }
    }

    /**
     * 对LinekedList元素进行洗牌,返回一个新的LinkedList实例
     */
    public static func shuffle<T>(list: LinkedList<T>): LinkedList<T> {
        let rnd = Random()
        let arr = list.toArray()

        // Shuffle array
        var i = arr.size
        while (i > 1) {
            swap(arr, i - 1, rnd.nextInt64(i))
            i--
        }
        return LinkedList<T>(arr)
    }

    private static func swap<T>(arr: Array<T>, i: Int64, j: Int64) {
        var tmp = arr[i]
        arr[i] = arr[j]
        arr[j] = tmp
    }

    public static func contains<T>(list: LinkedList<T>, value: T): Bool where T <: Equatable<T> {
        var iterator = list.iterator()
        while (true) {
            if (let Some(next) <- iterator.next()) {
                if (next == value) {
                    return true
                }
            } else {
                break
            }
        }
        return false
    }
}
