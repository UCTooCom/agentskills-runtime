/*
Copyright (c) 2026 WuJingrun（吴京润）

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

import std.unittest.*
import std.unittest.testmacro.*
import std.database.sql.*
import std.reflect.*
import std.time.MonoTime
import f_mockdb.*

@Test
public class DatabasePoolTest {
    @TestCase
    public func testDatabasePool(): Unit {
        MOCKDB.execution = {_, _ => 
            MOCKDB.addQueryResultColumnInfo(name: '1', nullable: false, typeName: 'SqlBigInt')
            MOCKDB.addQueryResultRow([1])
        }
        let driver: Driver = DriverManager.getDriver('mockdb').getOrThrow()
        let ds = driver.open('mockdb://')
        let pool = DatabasePool(driver: driver, initSize:1, minSize: 1, maxSize:1, creator: {=>ds.connect()}, connectTimeout: Duration.millisecond * 50)
        for(_ in 0 .. 10){
            spawn{
                while(true){
                    println('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA 1')
                    let start = MonoTime.now()
                    try(c = pool.connect()){
                        println('AAAAAAAAAAAAAAAAAAAAAAAAA 2 ${TypeInfo.of(c)}')
                    }
                    println('AAAAAAAAAAAAAAAAAAAAAAAAA 3 ${MonoTime.now() - start}')
                }
            }
        }

        // let c = pool.connect()
        // println(TypeInfo.of(c))
        // c.close()
        sleep(Duration.second * 30)
    }
}
