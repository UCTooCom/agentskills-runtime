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

import std.sync.{Mutex, AtomicInt64}

@Test
public class Launcher_test {
    private let lock = Mutex()
    private let condition = synchronized(lock) {
        lock.condition()
    }
    private func waitAndShutdown(launcher: Ticktock) {
        synchronized(lock) {
            condition.wait(timeout: 30 * Duration.second)
        }
        launcher.shutdown()
    }

    @TestCase
    public func test0(): Unit {
        let launcher = Ticktock()
        for (i in 0..1000) {
            launcher.addOrReplaceTask(LauncherTestTask0(i), "* * * * * *")
        }
        waitAndShutdown(launcher)
    }
    @TestCase
    public func test1(): Unit {
        let launcher = Ticktock()
        launcher.addOrReplaceTask(LauncherTestTask1_1(), "* * * * * *")
        launcher.addOrReplaceTask(LauncherTestTask1_2(), "0/3 * * * * *")
        waitAndShutdown(launcher)
    }
    // @TestCase
    // public func test2(): Unit {
    //     let currently = TestCurrently(0)
    //     let launcher = Ticktock()
    //     launcher.createYearlyWheel().createWeekDailyWheel().createMonthlyWheel().createMonthDailyWheel().
    //         createHourlyWheel().createMinutelyWheel().createSecondlyWheel(currently)
    //     launcher.addOrReplaceTask(LauncherTestTask2(lock), "3 * * * * *")
    //     currently.cur = 3
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     launcher.shutdown()
    // }
    // @TestCase
    // public func test3(): Unit {
    //     let currently = TestCurrently(0)
    //     let launcher = Ticktock()
    //     launcher.createYearlyWheel().createWeekDailyWheel().createMonthlyWheel().createMonthDailyWheel().
    //         createHourlyWheel().createMinutelyWheel().createSecondlyWheel(currently)
    //     launcher.addOrReplaceTask(LauncherTestTask3(), "1-3 * * * * *")
    //     currently.cur = 1
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     currently.cur = 2
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     currently.cur = 3
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     launcher.shutdown()
    // }
    // @TestCase
    // public func test4(): Unit {
    //     let currently = TestCurrently(0)
    //     let launcher = Ticktock()
    //     launcher.createYearlyWheel().createWeekDailyWheel().createMonthlyWheel().createMonthDailyWheel().
    //         createHourlyWheel().createMinutelyWheel().createSecondlyWheel(currently)
    //     launcher.addOrReplaceTask(LauncherTestTask4(), "1/1 * * * * *")
    //     currently.cur = 1
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     currently.cur = 2
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     currently.cur = 3
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     launcher.shutdown()
    // }
    // @TestCase
    // public func test5(): Unit {
    //     let currently = TestCurrently(0)
    //     let launcher = Ticktock()
    //     launcher.createYearlyWheel().createWeekDailyWheel().createMonthlyWheel().createMonthDailyWheel().
    //         createHourlyWheel().createMinutelyWheel().createSecondlyWheel(currently)
    //     launcher.addOrReplaceTask(LauncherTestTask5(), "1/3 * * * * *")
    //     currently.cur = 1
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     currently.cur = 4
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     currently.cur = 7
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     launcher.shutdown()
    // }
    // @TestCase
    // public func test6(): Unit {
    //     let currently = TestCurrently(0)
    //     let launcher = Ticktock()
    //     launcher.createYearlyWheel().createWeekDailyWheel().createMonthlyWheel().createMonthDailyWheel().
    //         createHourlyWheel().createMinutelyWheel().createSecondlyWheel(currently)
    //     launcher.addOrReplaceTask(LauncherTestTask6(), "*/3 * * * * *")
    //     currently.cur = 0
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     currently.cur = 3
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     currently.cur = 6
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     launcher.shutdown()
    // }
    // @TestCase
    // public func test7(): Unit {
    //     let currently = TestCurrently(0)
    //     let launcher = Ticktock()
    //     launcher.createYearlyWheel().createWeekDailyWheel().createMonthlyWheel().createMonthDailyWheel().
    //         createHourlyWheel().createMinutelyWheel().createSecondlyWheel(currently)
    //     launcher.addOrReplaceTask(LauncherTestTask7(), "1/3-10 * * * * *")
    //     currently.cur = 1
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     currently.cur = 4
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     currently.cur = 7
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     currently.cur = 10
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     currently.cur = 13
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     launcher.shutdown()
    // }
    // @TestCase
    // public func test8(): Unit {
    //     let currently = TestCurrently(0)
    //     let launcher = Ticktock()
    //     launcher.createYearlyWheel().createWeekDailyWheel().createMonthlyWheel().createMonthDailyWheel().
    //         createHourlyWheel().createMinutelyWheel().createSecondlyWheel(currently)
    //     launcher.addOrReplaceTask(LauncherTestTask8(), "*/3-10 * * * * *")
    //     currently.cur = 0
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     currently.cur = 3
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     currently.cur = 6
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     currently.cur = 9
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     currently.cur = 12
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     launcher.shutdown()
    // }
    // @TestCase
    // public func test9(): Unit {
    //     let currently = TestCurrently(0)
    //     let launcher = Ticktock()
    //     launcher.createYearlyWheel().createWeekDailyWheel().createMonthlyWheel().createMonthDailyWheel().
    //         createHourlyWheel().createMinutelyWheel().createSecondlyWheel(currently)
    //     launcher.addOrReplaceTask(LauncherTestTask9(), "L * * * * *")
    //     currently.cur = 59
    //     launcher.emit(DateTime.now())
    //     sleep(Duration.second)
    //     launcher.shutdown()
    // }
    @TestCase
    public func test10(): Unit {
        let launcher = Ticktock()
        let task = LauncherTestTask10()
        try {
            launcher.addOrReplaceTask(task, "-1 * * * * *")
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "60 * * * * *")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "* -1 * * * *")
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "* 60 * * * *")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "* * -1 * * *")
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "* * 60 * * *")
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "* * * -1 * *")
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "* * * 0 * *")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "* * * 32 * *")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "* * * * 0 *")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "* * * * 13 *")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "* * * * * -1")
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "* * * * * 8")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "0/0 * * * * *")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "60/1 * * * * *")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "* 60/1 * * * *")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "* * 24/1 * * *")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        launcher.addOrReplaceTask(task, "* * * 0/1 * *")
        try {
            launcher.addOrReplaceTask(task, "* * * 32/1 * *")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        launcher.addOrReplaceTask(task, "* * * * 0/1 *")
        try {
            launcher.addOrReplaceTask(task, "* * * * 13/1 *")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "* * * * * 8/1")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "* * * * * 1/1-8")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "* * * * * 1-8")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        launcher.addOrReplaceTask(task, "* * * * 0-12 *")
        try {
            launcher.addOrReplaceTask(task, "* * * * 0-13 *")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        launcher.addOrReplaceTask(task, "* * * 0-31 * *")
        try {
            launcher.addOrReplaceTask(task, "* * * 0-32 * *")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        try {
            launcher.addOrReplaceTask(task, "* * 0-60 * * *")
            @Assert(false)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        }
        launcher.shutdown()
    }

    @TestCase
    public func test11(): Unit {
        let launcher = Ticktock()
        launcher.addOrReplaceTask(LauncherTestTask11(), "* * * * * *")
        sleep(Duration.second)
        launcher.shutdown()
    }
    @TestCase
    public func test12(): Unit {
        let launcher = Ticktock()
        launcher.addOrReplaceTask(LauncherTestTask12(), "* * * * * *")
        waitAndShutdown(launcher)
    }
    @TestCase
    public func test13(): Unit {
        let launcher = Ticktock()
        launcher.addOrReplaceTask(LauncherTestTask13(), "3,4,1,2,5 * * * * *")
        waitAndShutdown(launcher)
    }
    // @TestCase
    // public func test14(): Unit {
    //     let sec = TestCurrently(0)
    //     let min = TestCurrently(0)
    //     let hour = TestCurrently(0)
    //     let day = TestCurrently(1)
    //     let month = TestCurrently(1)
    //     let weekday = TestCurrently(1)
    //     let launcher = Ticktock()
    //     launcher.createYearlyWheel().createWeekDailyWheel(weekday).createMonthlyWheel(month).createMonthDailyWheel(day).
    //         createHourlyWheel(hour).createMinutelyWheel(min).createSecondlyWheel(sec)
    //     launcher.addOrReplaceTask(LauncherTestTask14(), "0/5-30 0-5 0/12 0/10 1/4 0")

    //     //                           1  2  3  4  5  6  7  8  9  10 11 12
    //     let monthdaies = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    //     //        weekday.cur=7
    //     //        launcher.emit(DateTime.now())
    //     //        sleep(100 * Duration.millisecond)
    //     //s min h d mo w
    //     for (s in 0..60) {
    //         sec.cur = s
    //         for (mi in 0..60) {
    //             min.cur = mi
    //             for (h in 0..24) {
    //                 hour.cur = h
    //                 for (mo in 0..12) {
    //                     month.cur = mo
    //                     for (d in 1..monthdaies[mo]) {
    //                         day.cur = d
    //                         for (w in 1..7) {
    //                             weekday.cur = w
    //                             launcher.emit(DateTime.now())
    //                             sleep(2 * Duration.millisecond)
    //                         }
    //                     }
    //                 }
    //             }
    //         }
    //     }
    //     launcher.shutdown()
    // }
}

class LauncherTestTask0 <: TicktockTask {
    public prop name: String {
        get() {
            "LauncherTest0-${c}"
        }
    }
    private let c: Int64
    init(c: Int64) {
        this.c = c
    }
    private var time = DateTime.now()
    private let integer = AtomicInt64(0)
    public func execute(): Unit {
        let now = DateTime.now()
        let elapsed = (now - time).toSeconds()
        time = now
        @Assert(1, elapsed)
        println("${name} ${integer.fetchAdd(1)} ${DateTime.now()} ${elapsed}")
    }
}

class LauncherTestTask1_1 <: TicktockTask {
    public prop name: String {
        get() {
            "LauncherTest-Task1_1"
        }
    }
    private var time = DateTime.now()
    private let integer = AtomicInt64(0)

    public func execute(): Unit {
        let now = DateTime.now()
        var elapsed = (now - time).toSeconds()
        time = now
        @Assert(1, elapsed)
        println("${name} ${integer.fetchAdd(1)} ${DateTime.now()} ${elapsed}")
    }
}

class LauncherTestTask1_2 <: TicktockTask {
    public prop name: String {
        get() {
            "LauncherTest-Task1_2"
        }
    }
    private var time = DateTime.now()
    private let integer = AtomicInt64(0)

    public func execute(): Unit {
        let now = DateTime.now()
        let elapsed = (now - time).toSeconds()
        time = now
        @Assert(3,elapsed)
        println("${name} ${integer.fetchAdd(1)} ${DateTime.now()} ${elapsed}")
    }
}

class LauncherTestTask2 <: TicktockTask {
    private let condition: Condition
    LauncherTestTask2(let lock: Mutex) {
        synchronized(lock) {
            condition = lock.condition()
        }
    }
    public prop name: String {
        get() {
            "LauncherTest-Task2"
        }
    }
    public func execute(): Unit {
        println("${name} ${DateTime.now()}")
        synchronized(lock) {
            condition.notifyAll()
        }
    }
}

class LauncherTestTask3 <: TicktockTask {
    public prop name: String {
        get() {
            "LauncherTest-Task3"
        }
    }
    private let integer = AtomicInt64(0)

    public func execute(): Unit {
        println("${name} ${integer.fetchAdd(1)} ${DateTime.now()}")
    }
}

class LauncherTestTask4 <: TicktockTask {
    public prop name: String {
        get() {
            "LauncherTest-Task4"
        }
    }
    private let integer = AtomicInt64(0)

    public func execute(): Unit {
        println("${name} ${integer.fetchAdd(1)} ${DateTime.now()}")
    }
}

class LauncherTestTask5 <: TicktockTask {
    public prop name: String {
        get() {
            "LauncherTest-Task5"
        }
    }
    private let integer = AtomicInt64(0)

    public func execute(): Unit {
        println("${name} ${integer.fetchAdd(1)} ${DateTime.now()}")
    }
}

class LauncherTestTask6 <: TicktockTask {
    public prop name: String {
        get() {
            "LauncherTest-Task6"
        }
    }
    private let integer = AtomicInt64(0)

    public func execute(): Unit {
        println("${name} ${integer.fetchAdd(1)} ${DateTime.now()}")
    }
}

class LauncherTestTask7 <: TicktockTask {
    public prop name: String {
        get() {
            "LauncherTest-Task7"
        }
    }
    private let integer = AtomicInt64(0)

    public func execute(): Unit {
        println("${name} ${integer.fetchAdd(1)} ${DateTime.now()}")
    }
}

class LauncherTestTask8 <: TicktockTask {
    public prop name: String {
        get() {
            "LauncherTest-Task8"
        }
    }
    private let integer = AtomicInt64(0)

    public func execute(): Unit {
        println("${name} ${integer.fetchAdd(1)} ${DateTime.now()}")
    }
}

class LauncherTestTask9 <: TicktockTask {
    public prop name: String {
        get() {
            "LauncherTest-Task9"
        }
    }

    public func execute(): Unit {
        println("${name} ${DateTime.now()}")
    }
}

class LauncherTestTask10 <: TicktockTask {
    public prop name: String {
        get() {
            "LauncherTest-Task10"
        }
    }

    public func execute(): Unit {}
}

class LauncherTestTask11 <: TicktockTask {
    public prop name: String {
        get() {
            "LauncherTest-Task11"
        }
    }
    public func execute(): Unit {
        println("${name} ${DateTime.now()}")
    }

    public prop once: Bool {
        get() {
            return true
        }
    }
}

class LauncherTestTask12 <: TicktockTask {
    private var executed = 0

    public prop name: String {
        get() {
            "AlwaysThrowsException"
        }
    }

    public func execute(): Unit {
        executed++
        println("${name} ${DateTime.now()}")
        throw Exception()
    }
}

class LauncherTestTask13 <: TicktockTask {
    private var executed = 0

    public prop name: String {
        get() {
            "SecondsNotInOrder"
        }
    }

    public func execute(): Unit {
        executed++
        println("executed: ${name}-${executed}-DateTime.now()")
    }
}

class LauncherTestTask14 <: TicktockTask {
    public prop name: String {
        get() {
            "LauncherTest11"
        }
    }

    public func execute(): Unit {
        println("${name} ${DateTime.now()}")
    }
}
