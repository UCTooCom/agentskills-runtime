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

struct AcceptQueue {
    private static let log = LoggerFactory.getLogger<AcceptQueue>()
    private let priority = PriorityQueue<(Float64, Int64, String)>({
        t1, t2 => if (let cmp <- t1[0].compare(t2[0]) && cmp != EQ) {
            cmp
        } else {
            t1[1].compare(t2[1])
        }
    })
    init(accept: String) {
        if (let Some(idx) <- accept.indexOf(',')) {
            var start = 0
            var end = Some(idx)
            while (true) {
                let mt = accept[start..if (let Some(e) <- end) {
                        e
                    } else {
                        accept.size
                    }]
                let (q, e) = if (let Some(idx) <- mt.lastIndexOf(';q=') && let qi <- idx + 3) {
                    let e = if (let Some(e) <- mt.indexOf(';', qi)) {
                        e
                    } else {
                        mt.size
                    }
                    (-Float64.parse(mt[qi..e]), idx)
                } else {
                    (-1.0f64, mt.size)
                }
                let s = priority.size
                let submt = mt[0..e]
                log.debug {'RequestMeta.checkProduces.addAccept:${q};${s};${submt}'}
                priority.add((q, s, submt))
                start += mt.size + 1
                if (start >= accept.size) {
                    break
                }
                end = accept.indexOf(',', start)
            }
        }
    }
    func remove(): ?(Float64, Int64, String){
        priority.remove()
    }
}
