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
package f_orm.wrap

public class NamedDatasource <: Datasource & Resource {
    public NamedDatasource(
        optionSpecified: Bool,
        public let driverName: String,
        private let datasource: Datasource
    ) {
        if (!optionSpecified) {
            for ((k, v) in ORMConfig.getAllConfigs(driverName: driverName) where k.contains('_option_')) {
                setOption(k[k.indexOf('_option_').getOrThrow() + '_option_'.size .. ], v)
            }
        }
    }
    public init(driver: Driver, url: String, options: Array<(String, String)>){
        this(options.size > 0, driver.name, match (driver.open(url, options)) {
            case x: PooledDatasource => x
            case x where driver.preferredPooling =>
                if (ORMConfig.getNoPool(driverName: driver.name)) {
                    x
                } else if (ORMConfig.getUseStdPool(driverName: driver.name)) {
                    let p = PooledDatasource(x)
                    if (let Some(x) <- ORMConfig.getStdPoolConnectionTimeout(driverName: driver.name)) {
                        p.connectionTimeout = x
                    }
                    if (let Some(x) <- ORMConfig.getStdPoolIdleTimeout(driverName: driver.name)) {
                        p.idleTimeout = x
                    }
                    if (let Some(x) <- ORMConfig.getStdPoolKeepaliveTime(driverName: driver.name)) {
                        p.keepaliveTime = x
                    }
                    if (let Some(x) <- ORMConfig.getStdPoolMaxLifeTime(driverName: driver.name)) {
                        p.maxLifeTime = x
                    }
                    if (let Some(x) <- ORMConfig.getStdPoolMaxIdleSize(driverName: driver.name)) {
                        p.maxIdleSize = x
                    }
                    if (let Some(x) <- ORMConfig.getStdPoolMaxSize(driverName: driver.name)) {
                        p.maxSize = x
                    }
                    p
                } else {
                    DatabasePool(driver)
                }
            case x => x
        })
    }
    public init(driver: Driver, options: Array<(String ,String)>) {
        this(driver, getUrl(driver), options)
    }
    public init(driver: Driver, url: String){
        this(driver, url, getOptions(driver))
    }
    public init(driver: Driver){
        this(driver, getUrl(driver), getOptions(driver))
    }
    private static func getUrl(driver: Driver){
        ORMConfig.getUrl(driverName: driver.name)
    }
    private static func getOptions(driver: Driver){
        ORMConfig.getAllConfigTuples(driverName: driver.name)
    }
    
    public func connect(): Connection {
        ConnectionWrap(driverName, datasource.connect())
    }
    public func isClosed(): Bool {
        datasource.isClosed()
    }
    public func close(): Unit {
        datasource.close()
    }
    public func setOption(key: String, value: String): Unit {
        datasource.setOption(key, value)
    }
}
