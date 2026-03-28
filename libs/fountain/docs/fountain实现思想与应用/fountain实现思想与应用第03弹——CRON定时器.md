# fountain实现思想与应用第三弹

##### ——ticktock

先上项目链接 https://gitcode.com/Cangjie-SIG/fountain

### 实现原理

这是定时器的类图

![CRON](.assets/fountain%E5%AE%9E%E7%8E%B0%E6%80%9D%E6%83%B3%E4%B8%8E%E5%BA%94%E7%94%A8%E7%AC%AC03%E5%BC%B9%E2%80%94%E2%80%94CRON%E5%AE%9A%E6%97%B6%E5%99%A8/CRON.jpg)

Ticktock是定时器的核心，它负责解析CRON表达式、维护并执行定时任务。下面是定时器执行流程图。

![CRON流程图](.assets/fountain%E5%AE%9E%E7%8E%B0%E6%80%9D%E6%83%B3%E4%B8%8E%E5%BA%94%E7%94%A8%E7%AC%AC03%E5%BC%B9%E2%80%94%E2%80%94CRON%E5%AE%9A%E6%97%B6%E5%99%A8/ticktock流程图.jpg)

Chrono是Ticktock的成员，每秒钟启动新线程并向Ticktock发送一次DateTime，Ticktock接收到时间遍历所有定时任务并为每个定时任务启动新线程检查当前的DateTime是否满足CRON表达式，如果满足就执行这个定时任务。而且Ticktock还支持一次性的延迟任务DelayedCronTicktockTask，定时器会把这种任务的延迟时间包装成CRON表达式。

CRON表达式的每一个时间单位都会被解析为`start..=end:step`，

-   对于所有被判定为当前时间单位的每个时点都满足的情况，解析器会忽略这个时间单位。
-   每个时间单位支持用`L`表示当前单位的最后一个时点。比如每月最后一天可以这样表示：`* * * L`。
-   每个时间单位可以使用`,`分割多个表示式，比如每分钟1秒、2到30秒每2秒、40到55秒每三秒可以这样表示：`1,2/2-30,40/3-55`。

CRON表达式的每个时间单位都会被解析为以下类的实例：

```cj
public class CronData <: ToString & Hashable & Equatable<CronData> {
    private let unit_: TicktockUnit//这个类型是封闭类，表示时间单位，一共有秒分时天月年六个时间单位实例，这些实例也是TicktockUnit的成员。
    private let range_: Range<Int64>
    private let last_: Bool//表示是不是当前单位的最后一个时点
    private let hash: Int64
    //下面是当前时间是否满足当前时间单位的CRON表达式
    public func matches(date: DateTime) {
        if (last && unit.last(date)) { //这一部分不能省，因为不同月份的最后一天不一样
            return true;
        }
        let current = unit.current(date)//获得当前时间在当前单位的值
        (current > start && current <= end && (duration == 1 || ((current - start) % duration == 0))) || current == start//current == start是发生情况最少的所以放到最后面判断，
     //而它们相等的时候表达式在当前时点一定成立，也就不用做步长等判断，
     //所以前面只需要判断current > start，这个判断不成立时不必再做后面的判断，立即判断二者是否相等
    }
}
```

可以用以下方式声明一个定时任务，进程初始化时，Ticktock会从IOC获取所有CronTicktockTask和DelayedCronTicktockTask实例。

```cj
import fountain.bean.*
import fountain.bean.macros.*

@Bean
public class CronTask <: CronTicktockTask {
   public prop cron: String{
     get(){
       '*'//这里定义CRON表达式，如果希望每秒钟执行可以只用一个*，除此之外所有CRON表达式尾部的*都可以省略。
     }
   }
   public prop once: Bool {
     get(){
       false//这个属性决定定时任务是否只执行一次，默认就是false。
     }
   }
   public prop concurrentable: Bool {
     get(){
       false//这个属性决定定时任务是否可以并发执行，
       //如果这个属性返回true，上次定时周期的任务还没有结束，下次周期的时间又到了，上次的执行不会影响新的执行周期
       //如果返回false，任意时刻最多只有一次执行
     }
   }
   public prop name: String{
     get(){
       'task-name'//定时任务名称，默认是当前的类全限定名
     }
   }
   public func execute(): Unit {
     //定时任务逻辑
   }
}
```

