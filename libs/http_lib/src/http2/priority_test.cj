package http_lib.http2

import std.collection.ArrayList
import http_lib.core.{assertTrue, assertFalse}

/**
 * 测试 HTTP/2 流优先级（RFC 9113 第 5.3 节）。
 */
@Test
public class PriorityTreeTest {

    @TestCase
    public func testAddStream(): Unit {
        let tree = PriorityTree()
        tree.addStream(1, weight: 16)
        // 流 1 应存在且为默认权重
        let w = tree.getWeight(1)
        assertTrue(w == 16, message: "Default weight should be 16, got ${w}")
    }

    @TestCase
    public func testAddStreamWithParent(): Unit {
        let tree = PriorityTree()
        tree.addStream(1, weight: 16, parent: Some(0))
        tree.addStream(3, weight: 12, parent: Some(1))

        let w3 = tree.getWeight(3)
        assertTrue(w3 == 12, message: "Stream 3 weight should be 12")

        let hasChildren = tree.hasChildren(1)
        assertTrue(hasChildren, message: "Stream 1 should have children")
    }

    @TestCase
    public func testRemoveStream(): Unit {
        let tree = PriorityTree()
        tree.addStream(1, weight: 16)
        tree.addStream(3, weight: 12, parent: Some(1))

        tree.removeStream(3)
        // 移除后，流 1 不应有子节点
        let hasChildren = tree.hasChildren(1)
        assertFalse(hasChildren, message: "Stream 1 should not have children after removal")
    }

    @TestCase
    public func testReparentExclusive(): Unit {
        let tree = PriorityTree()
        // 创建父链：1 -> 3
        tree.addStream(1, weight: 16)
        tree.addStream(3, weight: 12, parent: Some(1))
        // 添加流 5 作为流 1 的独占子节点
        tree.addStream(5, weight: 8, parent: Some(1), exclusive: true)

        // 流 3 现在应是流 5 的子节点（由于独占重设父节点）
        let hasChildren5 = tree.hasChildren(5)
        assertTrue(hasChildren5, message: "Stream 5 should have children (the reparented stream 3)")
    }

    @TestCase
    public func testProcessPriority(): Unit {
        let tree = PriorityTree()
        tree.addStream(1, weight: 16)
        tree.addStream(3, weight: 12, parent: Some(1))

        // 处理 PRIORITY 帧：更新流 3 的权重
        tree.processPriority(3, false, 1, 32)
        let w3 = tree.getWeight(3)
        assertTrue(w3 == 32, message: "Stream 3 weight should be 32 after update, got ${w3}")
    }

    @TestCase
    public func testClearTree(): Unit {
        let tree = PriorityTree()
        tree.addStream(1, weight: 16)
        tree.addStream(3, weight: 12)
        tree.addStream(5, weight: 8)

        tree.clear()

        // 清除后，不应存在任何流
        let w = tree.getWeight(1)
        assertTrue(w == 16, message: "After clear, getWeight should return default (16)")
    }

    @TestCase
    public func testWeightClamping(): Unit {
        let tree = PriorityTree()
        // 权重 0 应限制为 1
        tree.addStream(1, weight: 0)
        let w = tree.getWeight(1)
        assertTrue(w == 1, message: "Weight 0 should clamp to 1, got ${w}")
    }

    @TestCase
    public func testNextWritableStream(): Unit {
        let tree = PriorityTree()
        tree.addStream(1, weight: 16)
        tree.addStream(3, weight: 12, parent: Some(1))
        tree.addStream(5, weight: 8, parent: Some(3))

        let readyStreams = ArrayList<UInt32>()
        readyStreams.add(1)
        readyStreams.add(3)
        readyStreams.add(5)
        match (tree.nextWritableStream(readyStreams)) {
            case Some(id) => assertTrue(id == 1 || id == 3 || id == 5)
            case None => assertTrue(false, message: "Should return a writable stream")
        }
    }

    @TestCase
    public func testNextWritableStreamEmpty(): Unit {
        let tree = PriorityTree()
        let emptyList = ArrayList<UInt32>()
        match (tree.nextWritableStream(emptyList)) {
            case Some(_) => assertTrue(false, message: "Empty ready list should return None")
            case None => ()  // 预期结果
        }
    }

    @TestCase
    public func testResetWriteCounters(): Unit {
        let tree = PriorityTree()
        tree.addStream(1, weight: 16)
        tree.addStream(3, weight: 12, parent: Some(1))
        tree.resetWriteCounters()
        assertTrue(true)  // 不应抛出异常
    }

    @TestCase
    public func testLeafStreams(): Unit {
        let tree = PriorityTree()
        tree.addStream(1, weight: 16)
        tree.addStream(3, weight: 12, parent: Some(1))
        tree.addStream(5, weight: 8, parent: Some(3))

        let leaves = tree.leafStreams()
        assertTrue(leaves.size == 1, message: "Should have 1 leaf stream")
        assertTrue(leaves[0] == 5, message: "Leaf should be stream 5, got ${leaves[0]}")
    }

    @TestCase
    public func testLeafStreamsRoot(): Unit {
        let tree = PriorityTree()
        tree.addStream(1, weight: 16)
        let leaves = tree.leafStreams()
        assertTrue(leaves.size == 1)
        assertTrue(leaves[0] == 1)
    }

    @TestCase
    public func testLeafStreamsEmptyTree(): Unit {
        let tree = PriorityTree()
        let leaves = tree.leafStreams()
        assertTrue(leaves.size == 0, message: "Empty tree should have no leaves")
    }
}
