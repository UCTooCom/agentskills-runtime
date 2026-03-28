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
package f_util

import std.unittest.*
import std.unittest.testmacro.*
import std.convert.*

@Test
public class PathPattern_test {
    private let p = PathPattern()

    private func matches(pattern: String, path: String, prefix: Bool, expected: Bool) {
        p.compile(pattern)
        if (prefix) {
            @Assert(expected,p.matchesPrefix(path))
        } else {
            @Assert(expected,p.matches(path))
        }
    }

    @TestCase
    public func test0(): Unit {
        let path = "/a/b/helloworld/c/d/e"
        let prefix = "/a/b"
        let oneStar = "/a/b/*/c/d/e"
        let wildcard = "/a/b/hell*w*rld/c/d/e"
        let doubleStar = "a/b/**/e"
        let empty = "/"
        matches(prefix, path, true, true)
        matches(oneStar, path, false, true)
        matches(wildcard, path, false, true)
        matches(prefix, "/a/b", false, true)
        matches(prefix, "/a/b/", false, true)
        matches(prefix, "/a/b/c", false, false)
        matches(prefix, "/a/", false, false)
        matches(empty, empty, false, true)
        matches(empty, "/a", false, false)
        matches(doubleStar, path, false, true)
    }
    @TestCase
    public func test1(): Unit {
        let pattern = "/pr?f*x/{id:\\d{4}}/{name:.+}"
        let path = "/prefix/1234/test"
        matches(pattern, path, false, true)
    }
    @TestCase
    public func testRegex(): Unit {
        let pattern = "/{#regex:\\d+}"
        matches(pattern, "/2341", false, true)
        matches(pattern, "/2341/abc", true, true)
    }
    @TestCase
    public func testPlaceholder(): Unit {
        let pattern = "/api/user/action/sequence/{projectId}/{userId}/{eventName}/{timeRange}/{direction}/{lastMillis}"
        let path = "/api/user/action/sequence/1234/2342/eventName/2019-06-27+00:00:00,2019-06-27+23:59:00/before,after/234235241"
        matches(pattern, path, false, true)
    }
    @TestCase
    public func testPlaceholder2(): Unit {
        let pattern = p
        pattern.compile("/a/b/{c}/d/e")
        pattern.compile("/a/{b}/{c}/test/{d}/e")
        pattern.matches("/a/b/c/d/e")
        pattern.matches("/a/b/c/test/d/e")
        pattern.compile(
            "/api/user/action/sequence/{projectId}/{userId}/{eventName}/{timeRange}/{direction}/{lastMillis}")
        let path = "/api/user/action/sequence/1234/2342/eventName/2019-06-27+00:00:00,2019-06-27+23:59:00/before,after/234235241"
        let result = pattern.extractVariablesInPath(path)
        @Assert(6,result.size)
        @Assert("1234", result.get("projectId"))
        @Assert("2342", result.get("userId"))
        @Assert("eventName", result.get("eventName"))
        @Assert("2019-06-27+00:00:00,2019-06-27+23:59:00", result.get("timeRange"))
        @Assert("before,after", result.get("direction"))
        @Assert("234235241", result.get("lastMillis"))
    }
    @TestCase
    public func test3(): Unit {
        let pattern = p
        pattern.compile(
            "/api/user/action/sequence/{projectId}/{userId}/{eventName}/{timeRange:\\d{4}-\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2},\\d{4}-\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2}}/{direction:(before|after|before,after)}/{lastMillis:\\d+}")
        pattern.compile(
            "/api/user/action/sequence/{projectId}/{userId}/{eventName}/{timeRange:\\d{4}-\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2},\\d{4}-\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2}}/{direction:(before|after|before,after)}")
        pattern.compile(
            "/api/user/action/sequence/{projectId}/{userId}/{timeRange:\\d{4}-\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2},\\d{4}-\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2}}/{direction:(before|after|before,after)}/{lastMillis:\\d+}")
        pattern.compile(
            "/api/user/action/sequence/{projectId}/{userId}/{timeRange:\\d{4}-\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2},\\d{4}-\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2}}/{direction:(before|after|before,after)}")
        pattern.compile(
            "/api/user/action/sequence/{projectId}/{userId}/{timeRange:\\d{4}-\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2},\\d{4}-\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2}}/{lastMillis:\\d+}")
        pattern.compile(
            "/api/user/action/sequence/{projectId}/{userId}/{timeRange:\\d{4}-\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2},\\d{4}-\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2}}")
        var path = "/api/user/action/sequence/29/1/CustomizedClick/2019-06-28 00:00:00,2019-06-28 23:59:00/before,after/0"
        @Assert(true, pattern.matches(path))
        path = "/api/user/action/sequence/29/1/CustomizedClick/2019-06-28 00:00:00,2019-06-28 23:59:00/before,after"
        @Assert(true, pattern.matches(path))
        @Assert(29i64, pattern.extractParsableVariableInPath<Int64>(path,"projectId").getOrThrow())
        path = "/api/user/action/sequence/29/1/2019-06-28 00:00:00,2019-06-28 23:59:00/before,after"
        @Assert(true, pattern.matches(path))
        path = "/api/user/action/sequence/29/1/2019-06-28 00:00:00,2019-06-28 23:59:00/before"
        @Assert(true, pattern.matches(path))
    }
    @TestCase
    public func test4(): Unit {
        let pattern = p
        pattern.compile("/api/event/user/{eventId}/{projectId}/{userId}")
        pattern.compile("/api/event/user/{projectId}")
        var path = "/api/event/user"
        @Assert(false, pattern.matches(path))
        path = path + "/47"
        @Assert(true, pattern.matches(path))
        @Assert(47i64,pattern.extractParsableVariableInPath<Int64>(path, "projectId").getOrThrow())
    }

    @TestCase
    public func testComplex(): Unit {
        let pattern = p
        pattern.compile("/api/event{eventId}/{projectId}/user{userId}")
        let path = "/api/event59/36/user88"
        @Assert(true, pattern.matches(path))
        let datas = pattern.extractVariablesInPath(path)
        @Assert(Some("59"), datas.get("eventId"))
        @Assert(Some("36"), datas.get("projectId"))
        @Assert(Some("88"), datas.get("userId"))
    }

    @TestCase
    public func testPlaceholder3(): Unit {
        let pattern = p
        pattern.compile("/api/profile/segmentation/{projectId}/{segmentationId}/{page}/{pageSize}")
        pattern.compile("/api/profile/segmentation/{projectId}/{segmentationId}/{baseTime}/{version}/{page}/{pageSize}")
        let path = "/api/profile/segmentation/18/72/2021-10-18+00:00:00/0/1/15"
        @Assert(true, pattern.matches(path))
    }
}
