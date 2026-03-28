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

package f_ticktock

import std.collection.ArrayList
import std.collection.concurrent.ConcurrentHashMap
import std.env
import std.sync.{AtomicOptionReference, Mutex}
public import std.time.DateTime
import f_bean.BeanFactory
import f_log.impl.LoggerFactory

/**
 * 本类对象能接收的cron表达式，简单说明如下：
 * 多个表达式可以用|分隔
 * 包含用空格分隔的六部分，从左至右依次是秒 分 时 日 月 星期
 * 每一部分可以用*表示每时间单位
 * 每一部分可以用m/n表示在上级时间单位的一个周期内，从当前时间单位的第m单位开始每n个单位触发一次，n是0的，抛出异常
 * 每一部分可以用英文逗号分隔表示当前时间单位可以有多个值
 * 每一部分可以用-分隔表示范围取值，eg. 1-7表示取值是从1到7，m-n必须满足m<n，1,3,4-8,11，表示取值是 1 3 4 5 6 7 8 11
 *
 * - 可以结合使用，0/5-30表示取值范围是0 5 10 15 20 25 30
 * 星号和/一起使用时，*会替换为当前时间单位的最小值
 * 大写L可以在任意时间单位，表示它所占时间单位的最大值
 *
 * 秒 分 时的取值范围是[0,59]
 *
 * 日的取值范围是[1,31]，对于不足31天的月份，程序会自动处理，当月没有那一天的任务会被跳过，大写L表示指定月份的最后一天
 * 0/2 的取值范围分别是2 4 6 8 10 12 14 16 18 20 22 24 26 28 30
 * 月的取值范围是[1,12]，0/2的取值范围是2 4 6 8 10 12
 *
 * 星期的取值范围是[0,7]，如果星期单取0，会自动转换为7；
 * 对于取值包含符号-的，如果取值是0-7，会转换为1-7，如果取值是0-n，1 <= n < 7，会转换为1-n,7
 * 对于包含符号/的，如果取值是0/n，1<= n <=7，会转换为n/n,7
 * 对于星期，这么考虑0的目的是为了有些人会把星期日当作一周的第一天，星期日是0；有些人会把星期日当作一周的最后一天，星期日是7
 * 本时间轮实现把星期日当作一周的最后一天，所以做以上转换
 *
 * eg. 0/5-30 0-5 1/2 L * 1
 * 上面的表达式意思是每月最后一天如果刚好是周一就从1点整开始每两小时，0到5分钟内，0到30秒内每5秒执行一次
 */
public class Ticktock <: Emitter {
    private static let LOGGER = LoggerFactory.getLogger<Ticktock>()
    private static let mutex = Mutex()
    private static let instance_ = AtomicOptionReference<Ticktock>()

    /**
     * 等价于getInstance(anyway: true)
     */
    public static prop instance: Ticktock {
        get(){
            getInstance(anyway: true).getOrThrow()
        }
    }
    public static func loadTasks(): Unit {
        getInstance(anyway: false)
    }
    /**
     * 如果需要调用此函数后并注册定时任务,anyway必须是true。
     * 如果只是想从IOC获得定时任务初始化，如果IOC内没有注册定时任务就不初始化，此时anyway应该是false，
     * anyway是false且IOC没有注册过定时任务将返回None<Ticktock>。
     */
    public static func getInstance(anyway!: Bool = true): ?Ticktock {
        if(let Some(x) <- instance_.load()){
            return x
        }
        synchronized(mutex){
            if (let Some(x) <- instance_.load()) {
                return x
            }
            func swapIfNone() {
                let instance = instance_.load()
                if (let Some(tt) <- instance) {
                    tt
                } else {
                    let tt = Ticktock()
                    if (instance_.compareAndSwap(instance, tt)) {
                        tt
                    } else {
                        tt.shutdown()
                        instance_.load().getOrThrow()
                    }
                }
            }
            func doRegister<T>(taskGetter: () -> ArrayList<T>, register: (Ticktock, T) -> Unit) where T <: TicktockTask{
                if(let list <- taskGetter() && list.size > 0){
                    let tt = swapIfNone()
                    for(task in list){
                        register(tt, task)
                    }
                    return tt
                }
                None<Ticktock>
            }
            var tt = doRegister(getTasksFromBeanFactory){tt, task => tt.addOrReplaceTask(task)}
            tt = doRegister(getDelayedTasksFromBeanFactory){tt, task => tt.addOrReplaceDelayTask(task)}
            if (anyway && tt.isNone()) {
                swapIfNone()
            } else {
                tt
            }
        }
    }

    private let tasks = ConcurrentHashMap<String, (TicktockTask, Collection<CronDataCollection>)>()
    private let ticktock = Chrono()
    private init() {
        ticktock.start(this)
        env.atExit(shutdown)
    }

    public func removeTask(task: TicktockTask) {
        removeTask(task.name)
    }

    public func removeTask(name: String): Unit {
        tasks.remove(name)
    }

    public func addOrReplaceDelayTask(task: DelayedTicktockTask) {
        addOrReplaceDelayTask0(task)
    }
    private func addOrReplaceDelayTask0(task: DelayedTicktockTask): Unit {
        if (task.immediate) {
            spawn {
                task.execute()
            }
            if (task.once) {
                return
            }
        }else{
            addOrReplaceTask(task, task.cron)
        }
    }
    private static func getTasksFromBeanFactory() {
        BeanFactory.instance.getList<CronTicktockTask>()
    }
    private static func getDelayedTasksFromBeanFactory(){
        BeanFactory.instance.getList<DelayedTicktockTask>()
    }
    
    public func addOrReplaceTask(task: CronTicktockTask) {
        addOrReplaceTask(task, task.cron)
    }
    public func addOrReplaceTask(
        taskName!: String,
        taskCron!: String,
        execOnce!: Bool = false,
        concurrenctly!: Bool = false,
        executor!: () -> Unit,
        isExecuting!: (Int64) -> Bool = {stamp => DefaultTicktockTaskExecuting.executing(taskName, stamp)},
        toReset!: (Int64) -> Unit = {stamp => DefaultTicktockTaskExecuting.reset(taskName, stamp)}
    ) {
        addOrReplaceTask(
            FuncCronTicktockTask(
                taskName: taskName,
                taskCron: taskCron,
                execOnce: execOnce,
                concurrenctly: concurrenctly,
                executor: executor,
                isExecuting: isExecuting,
                toReset: toReset
            )
        )
    }

    /**
     * 添加任务
     * @param task
     * @param cronExpr 关于表达式的解释请见{@code CronCompiler}
     */
    public func addOrReplaceTask(task: TicktockTask, cronExpr: String) {
        tasks.add(task.name, (task, CronCompiler.compile(cronExpr)))
    }

    public func emit(now: DateTime): Unit {
        for ((name, (task, crons)) in tasks) {
            spawn {
                var emitted = false
                var once = false
                try {
                    for (cron in crons where cron.matches(now)) {
                        task.run()
                        once = task.once
                        if (once) {
                            this.removeTask(task)
                        }
                        emitted = true
                        break
                    }
                    let (n, e, o) = (name, emitted, once)
                    LOGGER.debug{"Ticktock.emit:${n}; ${e}; ${o}"}
                } catch (e: Exception) {
                    let (n, em, o) = (name, emitted, once)
                    LOGGER.warn("Ticktock.emit:${n}; ${em}; ${o}", e)
                }
            }
        }
    }

    public func shutdown() {
        ticktock.shutdown()
    }
}
