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
package f_mockdb

public class MockDriver <: Driver {
    private init(){}
    private static const dbname = 'mockdb'
    static init(){
        DriverManager.register(dbname, MockDriver())
    }
    public prop name: String {
        get(){
            dbname
        }
    }
    public prop preferredPooling: Bool {
        get(){
            false
        }
    }
    public prop version: String {
        get(){
            '1.0.0'
        }
    }
    public func open(connectionString: String, opts: Array<(String, String)>): Datasource {
        output.writeln('url: ${connectionString}')
        let ds = MockDatasource()
        for((k, v) in opts){
            ds.setOption(k, v)
        }
        ds
    }
}