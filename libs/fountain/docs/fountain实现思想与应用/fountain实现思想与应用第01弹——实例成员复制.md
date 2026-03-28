# fountain实现思想与应用第一弹

##### ——实例成员复制

参加仓颉编程语言内测已经是第四个年头了，在这几年我利用业余时间使用仓颉开发了一个服务器应用开发工具库——fountain（https://gitcode.com/Cangjie-SIG/fountain ），如今也在社区的帮助下获得了第一个种子项目。感谢CSDN的陈玉龙老师，现在已经有一个医疗项目使用它开发并进入了测试阶段。项目团队也在开发过程中提出了很多建设性的意见，丰富了工具库的功能。

接下来几周，我要用一系列文章介绍这个工具库的几个主要功能的实现思想以及如何使用它实际开发应用项目。

下面进入正题，首先介绍仓颉类实例成员复制。这个功能算不上工具库的核心模块，却是整个工具库当中最复杂代码量最多的一个模块，而且好几个功能都依赖它，没有它很多功能就不完善，也做不到简单易用，于是我决定首先介绍这个功能。

这个功能的核心是两个接口——`Data`和`DataFields<T>` ，所有类型都有一个对应的包装类型，这些包装类型都实现了`Data`，包括集合类型和自定义的类也都有相应的包装类型，这些包装类型仅仅对原类型包装了一层没有任何功能；而所有类型都扩展了`DataFields<T>`，这些扩展实现了原生类型跟Data之间的互相转换。如果待转换的Data与要转换的目标类型不符，转换逻辑可以按照参数决定是立即抛出异常还是尽量完成转换。

另外为类的实例成员声明了`ReadableField`类型，每一个公共实例成员的访问都包装在它和它的子类型`MutableField`实例当中，宏展开的代码会把取值和赋值的代码包装成闭包作为它们的构造函数参数，每一个类的所有公共实例成员的包装类型又都是`ObjectFields`类的成员。类的包装类型`DataObject<T>`除了是类实例的包装类型，它还声明了获取`ObjectFields`的函数。

![DataAssist](.assets/fountain%E5%AE%9E%E7%8E%B0%E6%80%9D%E6%83%B3%E4%B8%8E%E5%BA%94%E7%94%A8%E7%AC%AC%E4%B8%80%E5%BC%B9%E2%80%94%E2%80%94%E5%AE%9E%E4%BE%8B%E6%88%90%E5%91%98%E5%A4%8D%E5%88%B6/DataAssist.jpg)

这是实例成员复制的类图，左边Data开头的几个类是几个包装类。另外也为JSON类型声明了包装类以及扩展接口，可以实现类的实例之间、类实例与字符串做KEY的Map实例之间、类实例与JSON之间的互相转换。下面是一个简单例子：

```cj
import fountain.data.*
import fountain.data.macros.*

//@DataAssist的fields宏会把公共实例成员包装成ReadableField，
//equal hash tostring compare 分别为被它修饰的类实例Equtable Hashable ToString Comparable
//props 会将被它修饰的类非公共的实例成员变量包装为公共实例成员属性
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
}

@DataAssist[equal hash tostring props fields]
public class TestData3 {
    private var a: Int64 = 0
    private var b: String = ''
    private var c: Bool = false
    private var d: Float64 = 0.0
    private var e: ?DateTime = None<DateTime>
    private var f: Array<Int64> = []
    private var g: ArrayList<String> = ArrayList<String>()
}

private let _ = {=>
    let data2 = TestData2()
    //被@DataAssist[fields]修饰的类可以作为DataObject的实参，调用它的populate函数将一个类的实例复制到另一个类的实例。
    var data3 = DataObject<TestData3>.populate(data2).getOrThrow()
    println('AAAAAAAAAAAAAAAAAAAAAAAAAAAAA ${data2}')
    println('AAAAAAAAAAAAAAAAAAAAAAAAAAAAA ${data3}')
    let dobj = DataObject<TestData2>(data2)
    //DataObject的实例也是Data类型，它可以转换为JsonValue
    let json = JsonValue.tryFromData(dobj)
    println('AAAAAAAAAAAAAAAAAAAAAAAAAAAAA ${json}')
    let data = json.toData()//JsonValue也可以转成Data类型
    data3 = DataObject<TestData3>.populate(data2).getOrThrow()
    println('AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA ${data3}')
}()
```

