/**
 * Copyright 2024 Beijing Baolande Software Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Runtime Library Exception to the Apache 2.0 License:
 *
 * As an exception, if you use this Software to compile your source code and
 * portions of this Software are embedded into the binary product as a result,
 * you may redistribute such product without providing attribution as would
 * otherwise be required by Sections 4(a), 4(b) and 4(d) of the License.
 */
package activemq_client_unit_test

@Test
public class UsageTest {
    @TestCase
    public func testPercentUsageNeedsNoThread(): Unit {
        let usage = Usage()
        usage.limit = 10
        usage.start()
        usage.increaseUsage(1)
        @Assert(10, usage.getPercentUsage())
    }

    @TestCase
    public func testLimitedWaitFail(): Unit {
        let usage = Usage()
        usage.limit = 10
        usage.start()
        usage.increaseUsage(11)

        @Assert(false, usage.waitForSpace(Duration.millisecond * 500))
    }

    @TestCase
    public func testDecreaseUsage(): Unit {
        let usage = Usage()
        usage.limit = 10
        usage.start()
        usage.increaseUsage(11)
        @Assert(110, usage.getPercentUsage())

        spawn {
            usage.decreaseUsage(3)
        }

        usage.waitForSpace()
        @Assert(80, usage.getPercentUsage())
    }
}
