package http_lib.core

@Test
public class HeadersTest {
    @TestCase
    public func testAddAndGet(): Unit {
        let headers = HttpHeaders()
        headers.add("Content-Type", "application/json")
        headers.add("X-Custom", "value1")
        match (headers.get("Content-Type")) {
            case Some(v) => assertTrue(v == "application/json")
            case None => assertTrue(false)
        }
        match (headers.get("content-type")) {
            case Some(v) => assertTrue(v == "application/json")
            case None => assertTrue(false)
        }
        assertTrue(headers.get("Non-Existent").isNone())
    }

    @TestCase
    public func testSetReplacesValue(): Unit {
        let headers = HttpHeaders()
        headers.set("X-Test", "original")
        headers.set("X-Test", "replaced")
        match (headers.get("X-Test")) {
            case Some(v) => assertTrue(v == "replaced")
            case None => assertTrue(false)
        }
        assertTrue(headers.size == 1)
    }

    @TestCase
    public func testAddAppendsValue(): Unit {
        let headers = HttpHeaders()
        headers.add("X-Test", "value1")
        headers.add("X-Test", "value2")
        let all = headers.getAll("X-Test")
        assertTrue(all.size == 2)
        assertTrue(all[0] == "value1")
        assertTrue(all[1] == "value2")
    }

    @TestCase
    public func testContains(): Unit {
        let headers = HttpHeaders()
        headers.add("Content-Type", "text/html")
        assertTrue(headers.contains("Content-Type"))
        assertTrue(headers.contains("content-type"))
        assertFalse(headers.contains("X-Missing"))
    }

    @TestCase
    public func testRemove(): Unit {
        let headers = HttpHeaders()
        headers.add("X-Test", "value")
        assertTrue(headers.contains("X-Test"))
        headers.remove("X-Test")
        assertFalse(headers.contains("X-Test"))
    }

    @TestCase
    public func testNames(): Unit {
        let headers = HttpHeaders()
        headers.add("A", "1")
        headers.add("B", "2")
        headers.add("C", "3")
        assertTrue(headers.names().size == 3)
    }

    @TestCase
    public func testToBytes(): Unit {
        let headers = HttpHeaders()
        headers.add("Content-Type", "text/plain")
        let bytes = headers.toBytes()
        let str = String.fromUtf8(bytes)
        assertTrue(str.size > 0)
    }

    @TestCase
    public func testEmpty(): Unit {
        let headers = HttpHeaders()
        assertTrue(headers.isEmpty())
        assertTrue(headers.size == 0)
    }

    @TestCase
    public func testCaseInsensitiveGet(): Unit {
        let headers = HttpHeaders()
        headers.set("Content-Type", "application/json")
        match (headers.get("CONTENT-TYPE")) {
            case Some(v) => assertTrue(v == "application/json")
            case None => assertTrue(false)
        }
        match (headers.get("content-type")) {
            case Some(v) => assertTrue(v == "application/json")
            case None => assertTrue(false)
        }
        match (headers.get("Content-type")) {
            case Some(v) => assertTrue(v == "application/json")
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testRemoveNonExistent(): Unit {
        let headers = HttpHeaders()
        headers.set("X-Exists", "value")
        headers.remove("X-Missing")
        assertTrue(headers.size == 1)
    }

    @TestCase
    public func testAddMultipleValuesGetFirst(): Unit {
        let headers = HttpHeaders()
        headers.add("Accept", "text/html")
        headers.add("Accept", "application/json")
        // get() 应返回拼合后的值
        match (headers.get("accept")) {
            case Some(v) => assertTrue(v.contains("text/html"))
            case None => assertTrue(false)
        }
    }

    @TestCase
    public func testSetOverwritesAllValues(): Unit {
        let headers = HttpHeaders()
        headers.add("X-Multi", "val1")
        headers.add("X-Multi", "val2")
        headers.set("X-Multi", "newval")
        let all = headers.getAll("X-Multi")
        assertTrue(all.size == 1)
        assertTrue(all[0] == "newval")
    }

    @TestCase
    public func testToBytesEmpty(): Unit {
        let headers = HttpHeaders()
        let bytes = headers.toBytes()
        assertTrue(bytes.size == 0)
    }

    @TestCase
    public func testEntries(): Unit {
        let headers = HttpHeaders()
        headers.add("Content-Type", "application/json")
        headers.add("X-Custom", "value1")
        let entries = headers.entries()
        assertTrue(entries.size == 2)
        // entries 保留原始大小写的响应头名称
        var foundContentType = false
        var foundCustom = false
        for ((name, value) in entries) {
            if (name == "Content-Type" && value == "application/json") { foundContentType = true }
            if (name == "X-Custom" && value == "value1") { foundCustom = true }
        }
        assertTrue(foundContentType)
        assertTrue(foundCustom)
    }

    @TestCase
    public func testForEach(): Unit {
        let headers = HttpHeaders()
        headers.add("A", "1")
        headers.add("B", "2")
        // 使用 entries() 验证迭代计数
        let entries = headers.entries()
        assertTrue(entries.size == 2)
        // 验证 forEach 不会崩溃
        headers.forEach({name, value => ()})
        assertTrue(true, message: "forEach should complete without error")
    }

    @TestCase
    public func testClear(): Unit {
        let headers = HttpHeaders()
        headers.add("Content-Type", "text/html")
        headers.add("X-Custom", "value")
        assertTrue(headers.size == 2)
        headers.clear()
        assertTrue(headers.isEmpty())
        assertTrue(headers.size == 0)
        assertTrue(headers.contains("Content-Type") == false)
    }
}


// ======== HttpHeaders 克隆/复制/合并/重置测试 ========

@Test
public class HttpHeadersCloneCopyTest {

    @TestCase
    public func testClone(): Unit {
        let original = HttpHeaders()
        original.set("Content-Type", "application/json")
        original.set("X-Custom", "value1")
        let cloned = original.clone()
        assertTrue(cloned.get("content-type") == original.get("content-type"),
            message: "Cloned headers should have same values")
        assertTrue(cloned.get("x-custom") == original.get("x-custom"),
            message: "X-Custom should match in clone")
    }

    @TestCase
    public func testCloneIsIndependent(): Unit {
        let original = HttpHeaders()
        original.set("Content-Type", "application/json")
        let cloned = original.clone()
        cloned.remove("content-type")
        // After removing from clone, original should still have it
        match (original.get("content-type")) {
            case Some(v) => assertTrue(v == "application/json",
                message: "Original should retain value after clone modification")
            case None => assertTrue(false, message: "Original should still have content-type")
        }
    }

    @TestCase
    public func testCopyFrom(): Unit {
        let dest = HttpHeaders()
        dest.set("X-Existing", "stay")
        let src = HttpHeaders()
        src.set("Content-Type", "text/html")
        src.set("X-Custom", "value2")
        dest.copyFrom(src)
        // Existing header should still be present
        assertTrue(dest.get("x-existing") == Some("stay"),
            message: "Existing headers should be preserved")
        // Copied headers should be present
        assertTrue(dest.get("content-type") == Some("text/html"),
            message: "Copied content-type should be present")
        assertTrue(dest.get("x-custom") == Some("value2"),
            message: "Copied X-Custom should be present")
    }

    @TestCase
    public func testGetCombined(): Unit {
        let headers = HttpHeaders()
        headers.add("Set-Cookie", "a=1")
        headers.add("Set-Cookie", "b=2")
        match (headers.getCombined("set-cookie")) {
            case Some(combined) =>
                assertTrue(combined.size > 0, message: "Combined should not be empty")
                assertTrue(combined.contains("a=1"), message: "Combined should include 'a=1'")
                assertTrue(combined.contains("b=2"), message: "Combined should include 'b=2'")
            case None =>
                assertTrue(false, message: "Combined should be present")
        }
    }

    @TestCase
    public func testGetOriginalName(): Unit {
        let headers = HttpHeaders()
        headers.set("Content-Type", "application/json")
        let origName = headers.getOriginalName("content-type")
        match (origName) {
            case Some(n) => assertTrue(n == "Content-Type",
                message: "Original name should preserve case")
            case None => assertTrue(false, message: "Should find original name")
        }
    }

    @TestCase
    public func testGetOriginalNameUnknown(): Unit {
        let headers = HttpHeaders()
        let origName = headers.getOriginalName("non-existent")
        match (origName) {
            case Some(_) => assertTrue(false, message: "Unknown header should return None")
            case None => assertTrue(true)
        }
    }

    @TestCase
    public func testReset(): Unit {
        let headers = HttpHeaders()
        headers.set("Content-Type", "application/json")
        headers.set("X-Custom", "value")
        assertTrue(headers.size > 0, message: "Should have headers before reset")
        headers.reset()
        assertTrue(headers.size == 0, message: "Should have 0 headers after reset")
        match (headers.get("content-type")) {
            case Some(_) => assertTrue(false, message: "Headers should be empty after reset")
            case None => assertTrue(true)
        }
    }
}

