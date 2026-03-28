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
package boot

import std.collection.*
import std.env
import opengauss.driver.*
import opengauss.slog
import fountain.bean.*
import fountain.bean.macros.*
import fountain.data.*
import fountain.data.macros.*
import fountain.log.LoggerFactory
import fountain.mockdb.*
import fountain.orm.* // orm初始化不要再导入这个包，会在首个DAO初始化时自动初始化orm

private let _ = {=>
    try{
        let logger = LoggerFactory.getLogger("opengauss")
        slog.setDefault(logger)//必须初始化opengauss，否则无法启动，因为配置项orm_drivers指定了opengauss
        // let url = env.getVariable('POSTGRES') ?? ''
        let driverName = 'mockdb'
        let driver = ORM.getDriver(driverName)
        // ORM.register(driver)
        // ORM.register('opengauss')
        //下面的代码不用池，启用下面的代码boot.sh的池配置环境变量会被忽略。代码初始化数据库的优先级高于环境变量
        let ds = driver.open('mockdb://')
        ORM.register(NamedDatasource(false, driverName, ds))
        lookup<MockdbDialect>().mock = 'opengauss'
        println(lookup<OpenGaussDialect>().dialect)
    }catch(e: Exception){
        e.printStackTrace()
        throw e 
    }
}()

///////////////////////////////////////////////////////////////////////////////
/**这一行往下单纯只是为了演示实例复制和类实例与json互相转换的功能*******************/
@DataAssist[equal hash tostring props fields]
public open class TestData1 {
    private var a: Int64 = 1
    private var b: String = 'asfd'
    private var c: Bool = true
    private var d: Float64 = 3.1415926
}
@DataAssist[equal hash tostring props fields]
public class TestData2 <: TestData1 {
    private var e: DateTime = DateTime.now()
    private var f: Array<Int64> = [1, 2, 3, 4, 5]
    private var g: ArrayList<String> = ArrayList<String>(['a','b','c','d','e'])
    private var m1: HashMap<String, Int64> = HashMap<String, Int64>([('a', 1),('b',2),('c',3)])
    private var m2: HashMap<String, DataAny> = {=>
        let map = HashMap<String, DataAny>()
        map.addData('a', 1)
        map.addData('b', true)
        map.addData('c', 'asdf')
        map
    }()
}

@DataAssist[equal hash tostring props fields]
public class TestData3 {
    private var a: Int64 = 0
    private var b: ?String = ''
    private var c: Bool = false
    private var d: Float64 = 0.0
    private var e: ?DateTime = None<DateTime>
    private var f: Array<Int64> = []
    private var g: ArrayList<String> = ArrayList<String>()
    private var m1: HashMap<String, Int64> = HashMap<String, Int64>()
    private var m2: HashMap<String, DataAny> = HashMap<String, DataAny>()
}
private let _ = {=>
    try{
        var data2 = TestData2()
        var data3 = DataObject<TestData3>.populate(data2).getOrThrow()
        //忽略验证：
        // data3 = DataObject<TestData3>.populate(data2, flag: DEFAULT_DATA_FLAG | IGNORE_VALIDATION).getOrThrow()
        //忽略验证失败：
        // data3 = DataObject<TestData3>.populate(data2, flag: DEFAULT_DATA_FLAG | IGNORE_NOT_MATCHED_VALIDATION).getOrThrow()
        println('AAAAAAAAAAAAAAAAAAAAAAAAAAAAA ${data2}')
        println('BBBBBBBBBBBBBBBBBBBBBBBBBBBBB ${data3}')
        let dobj = DataObject<TestData2>(data2)
        let json = JsonValue.tryFromData(dobj)
        println('CCCCCCCCCCCCCCCCCCCCCCCCCCCCC ${json}')
        let data = json.toData()
        data3 = DataObject<TestData3>.populate(data2).getOrThrow()
        println('DDDDDDDDDDDDDDDDDDDDDDDDDDDDD ${data3}')
        data2.b=''
        data2 = DataObject<TestData2>.populate(data3).getOrThrow()
        println('EEEEEEEEEEEEEEEEEEEEEEEEEEEEE ${data2} ${data2.b}')
        let map = HashMap<String, Int64>()
        map['0'] = 0
        map['1'] = 1
        map['2'] = 2
        let data4 = map.toData()
        println('FFFFFFFFFFFFFFFFFFFFFFFFFFFFF ${JsonValue.tryFromData(data4)}')
        let s = toJson(data2)//把仓颉对象转成JSON串
        let d = fromJson<TestData2>(s)//把JSON串转成仓颉类对象
        println('GGGGGGGGGGGGGGGGGGGGGGGGGGGGG ${s}')
        println('HHHHHHHHHHHHHHHHHHHHHHHHHHHHH ${d.toData()}')
    }catch(e: Exception){
        e.printStackTrace()
        throw e
    }
}()
