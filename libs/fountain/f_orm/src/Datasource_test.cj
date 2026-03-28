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
package f_orm

public class DatasourceTest <: Datasource {
    /**
     * 设 置 连 接 选 项
     */
    public func setOption(key: String, value: String): Unit {
    }
    public func isClosed(): Bool {
        false
    }
    public func close(): Unit {}

    /**
     * 返 回 一 个 可 用 的 连 接
     * 返 回 值 Connection - 数 据 库 连 接 实 例
       (续下页)
       567
       版权所有，禁止扩散
       (接上页)
     */
    public func connect(): Connection {
        ConnectionTest()
    }
}
