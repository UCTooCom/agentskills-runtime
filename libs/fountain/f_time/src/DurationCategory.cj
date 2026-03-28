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
package f_time

public interface DurationCategory {
    prop nanoseconds: TimeDuration
    prop nanosecond: TimeDuration
    prop microseconds: TimeDuration
    prop microsecond: TimeDuration
    prop milliseconds: TimeDuration
    prop millisecond: TimeDuration
    prop seconds: TimeDuration
    prop second: TimeDuration
    prop minutes: TimeDuration
    prop minute: TimeDuration
    prop hours: TimeDuration
    prop hour: TimeDuration
    prop days: TimeDuration
    prop day: TimeDuration
    prop weeks: TimeDuration
    prop week: TimeDuration
}

extend Int64 <: DurationCategory {
    public prop nanoseconds: TimeDuration {
        get() {
            return TimeDuration(this, NANOSECOND)
        }
    }
    public prop nanosecond: TimeDuration {
        get() {
            return nanoseconds
        }
    }

    public prop microseconds: TimeDuration {
        get() {
            return TimeDuration(this, MICROSECOND)
        }
    }
    public prop microsecond: TimeDuration {
        get() {
            return microseconds
        }
    }

    public prop milliseconds: TimeDuration {
        get() {
            return TimeDuration(this, MILLISECOND)
        }
    }
    public prop millisecond: TimeDuration {
        get() {
            return milliseconds
        }
    }

    public prop seconds: TimeDuration {
        get() {
            return TimeDuration(this, SECOND)
        }
    }
    public prop second: TimeDuration {
        get() {
            return seconds
        }
    }

    public prop minutes: TimeDuration {
        get() {
            return TimeDuration(this, MINUTE)
        }
    }
    public prop minute: TimeDuration {
        get() {
            return minutes
        }
    }

    public prop hours: TimeDuration {
        get() {
            return TimeDuration(this, HOUR)
        }
    }
    public prop hour: TimeDuration {
        get() {
            return hours
        }
    }

    public prop days: TimeDuration {
        get() {
            return TimeDuration(this, DAY)
        }
    }
    public prop day: TimeDuration {
        get() {
            return days
        }
    }
    public prop weeks: TimeDuration {
        get() {
            return TimeDuration(this, WEEK)
        }
    }
    public prop week: TimeDuration {
        get() {
            return weeks
        }
    }
}
