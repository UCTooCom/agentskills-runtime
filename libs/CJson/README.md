## 介绍

Json 序列化/反序列化工具，自动给被标记的类增加fromJson()和toJson()等方法，使其自身具备序列化/反序列化能力

### 特性

- 🚀 只需使用@JsonSerializable宏标记类名，使其具备序列化/反序列化能力

- 🛠️ 支持使用@JsonName(xxxx)标记类成员，定制序列化属性名为xxx

- 🎁 支持使用@JsonIgnore标记类成员，使其被序列化过程忽略

- ⛳ 支持使用默认值，克服json中的缺失值

- ⛳ 支持Option<T> type

- 🛠️ 支持定制类的序列化和反序列化，通过直接实现或使用扩展实现IJsonSerializable<T>

- ⛳ 支持使用@JsonCust定制成员变量的序列化反序列化

- ⛳ 支持自定义Generic T类型，如 ArrayList<MyInstance>, (MyInstance 需要需要手动被标记为@JsonSerializable)
  
### 接口说明
- 使用@JsonSerializable标记被序列化/反序列化对象
- 使用@JsonName["alias"]定制属性的序列化键值
- 使用@JsonIgnore标记需要被忽略的属性
- 使用@JsonCust[ClassName]定制属性的序列换反序列化过程(ClassName <:CustJsonSerializable<T>)

### 编译执行
编译：
```shell
cjpm build
```

单元测试：
```shell
cjpm test
```

运行Demo：
```shell
cjpm run
```

### 如何集成

在您代码仓的 cjpm.toml 文件中，需要新增加如下源码依赖：

 ```shell
[dependencies]
  CJson = {git = "https://gitcode.com/Cangjie-TPC/CJson.git", branch = "master"}
```
  
## 详见 CJson/src/test目录下的测试用例

```swift
package cjsonExample

internal import std.time.DateTime

//1. the following three packages must be imported by decoraetd class/struct, or by it's belonging package
internal import std.collection.HashMap
internal import encoding.json.*
import CJson.jsonmacro.*
import CJson.IJsonSerializable

//2. use @JsonSerializable to decorate target class
@JsonSerializable
public class ExampleOne {
    //3. class properties must be declared with explicit type
    var name: String = "Chrsitmas"
    var time: DateTime = DateTime.now()
}

@JsonSerializable
public class ExampleOne_Init {
    var name: String
    var time: DateTime

    //4. the target class must have a parameter-less contructor
    //try comment out this init method to see compile errors
    //ExampleOne class will work since there it has an equavalent "hidden" parameter-less contructor
    public init() {
        this.name = "Chrsitmas_init"
        this.time = DateTime.parse("2022-12-25T00:00:00+01:00")
    }

    public init(name: String) {
        this.name = name
        this.time = DateTime.parse("2022-12-25T00:00:00+01:00")
    }
}


//struct is also supported
@JsonSerializable
public struct ExampleOneStruct {
    var name: String = "Labor Day"
    var time: DateTime

    public init () {
        this.time = DateTime.now()
    }
}
```
