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
package f_log.output

import std.unittest.*
import std.unittest.testmacro.*
import stdx.compress.zlib.*
import f_time.TimeUnit as TU

@Test
public class RotatableFileTest {
    @TestCase
    public func test(): Unit {
        let param = RotatableFileParams()
        param.compress = LogFileCompressFormat.GZip(CompressLevel.DefaultCompression)
        param.fileSize = 0
        param.timeunit = TU.SECOND
        param.path = '/tmp/test.log'
        let file = RotatableFile(param)
        spawn {
            while (true) {
                file.write('hello\n'.toArray())
                sleep(Duration.millisecond * 100)
            }
        }
        sleep(Duration.second * 5)
        // throw Exception()
    }
}
