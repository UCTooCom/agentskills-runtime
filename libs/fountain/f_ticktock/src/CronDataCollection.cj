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
import std.collection.HashMap
import f_base.*

public class CronDataCollection <: Hashable & Equatable<CronDataCollection> & ToString{
    public CronDataCollection(private let cron: String) {}
    private var datas = HashMap<TicktockUnit, ArrayList<CronData>>()

    public func toString(): String {
        cron
    }
    public func hashCode() {
        cron.hashCode()
    }
    public operator func ==(other: CronDataCollection) {
        refEq(this, other) || this.cron == other.cron
    }

    public func put(unit: TicktockUnit, data: CronData): Unit {
        if (let Some(l) <- datas.get(unit)) {
            l
        } else {
            let list = ArrayList<CronData>()
            datas[unit] = list
            list
        }.add(data)
    }
    public func put(unit: TicktockUnit, range: Range<Int64>): Unit {
        put(unit, CronData(unit, range))
    }
    public func put(unit: TicktockUnit, value: Int64) {
        put(unit, CronData(unit, value))
    }
    public func putLast(unit: TicktockUnit) {
        put(unit, CronData.createLast(unit))
    }
    public func get(unit: TicktockUnit): Option<Collection<CronData>> {
        if (let Some(list) <- datas.get(unit)) {
            list as Collection<CronData>
        } else {
            None<Collection<CronData>>
        }
    }
    public func matches(date: DateTime) {
        if(datas.isEmpty()){//如果datas是空的，表示cron表达式是* * * * * * *
            return true
        }
        for (crons in datas.values()) {
            var result = false
            for (cron in crons where cron.matches(date)) {
                result = true
                break
            }
            if (!result) {
                return false
            }
        }
        true
    }
}
