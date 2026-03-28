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

public class DriverTest <: Driver {
    /**
     * 驱 动 名 称
     */
    public prop name: String {
        get() {
            "test"
        }
    }

    /**
     * 驱 动 版 本
     */
    public prop version: String {
        get() {
            "1.0.0"
        }
    }

    /**
     * 指 示 驱 动 程 序 是 否 与 连 接 池 亲 和 。
     * 如 果 否 ， 则 不 建 议 使 用 连 接 池 。
     * 比 如 sqlite 驱 动 连 接 池 化 的 收 益 不 明 显 ， 不 建 议 使 用 连 接 池
     */
    public prop preferredPooling: Bool {
        get() {
            false
        }
    }

    /**
     * 通 过 connectionString 和 选 项 打 开 数 据 源
     * 参 数 connectionString - 数 据 库 连 接 字 符 串
     * 参 数 opts - key,value 的 tuple 数 组 ， 打 开 数 据 源 的 选 项
     * 返 回 值 Datasource - 数 据 源 实 例
     */
    public func open(connectionString: String, opts: Array<(String, String)>): Datasource {
        DatasourceTest()
    }
}

public class DatasourceCreatorImpl <: DatasourceCreator {
    public func create(): NamedDatasource {
        let driver = DriverTest()
        NamedDatasource(true, driver.name, driver.open(""))
    }
}
