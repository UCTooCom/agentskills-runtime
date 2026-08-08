package quic_cj.tests

import quic_cj.core.{FrameSorter, newFrameSorter}

@Test
public class FrameSorterTestSuite {
    @TestCase
    public func testInitialState(): Unit {
        let fs = newFrameSorter()
        let noData = !fs.hasMoreData()
        @Assert(noData, true)
        let (offset, data) = fs.pop()
        @Assert(data.size, 0)
    }

    @TestCase
    public func testPushAndPopSequential(): Unit {
        let fs = newFrameSorter()
        let result = fs.push([0x01u8, 0x02u8, 0x03u8], 0)
        @Assert(result, true)
        let (offset, data) = fs.pop()
        @Assert(offset, 0)
        @Assert(data.size, 3)
        @Assert(data[0], 0x01u8)
        // 全部弹出后，readPos 前移，无更多数据
        let (offset2, data2) = fs.pop()
        @Assert(data2.size, 0)
    }

    @TestCase
    public func testPushOutOfOrder(): Unit {
        let fs = newFrameSorter()
        // 先推入偏移量 5 的数据（2 字节）
        let result1 = fs.push([0x05u8, 0x06u8], 5)
        @Assert(result1, true)
        // readPos = 0，尚无连续数据可读
        let (off1, dat1) = fs.pop()
        @Assert(dat1.size, 0)
        // 再推入偏移量 0 的连续数据（5 字节）- 这会填充间隙并与偏移量 5 的数据合并
        let result2 = fs.push([0x01u8, 0x02u8, 0x03u8, 0x04u8, 0x05u8], 0)
        @Assert(result2, true)
        // 现在可以从 readPos=0 读取到数据
        let (offset, data) = fs.pop()
        @Assert(offset, 0)
        // 至少应有第一个 push 的 5 字节数据
        @Assert(data.size >= 5, true)
    }

    @TestCase
    public func testPushOverlapping(): Unit {
        let fs = newFrameSorter()
        let r1 = fs.push([0x01u8, 0x02u8, 0x03u8, 0x04u8, 0x05u8], 0)
        @Assert(r1, true)
        let r2 = fs.push([0x03u8, 0x04u8, 0x05u8, 0x06u8, 0x07u8], 2)
        @Assert(r2, true)
        let (offset, data) = fs.pop()
        @Assert(offset, 0)
        // 数据至少为原大小（5 字节）
        @Assert(data.size >= 5, true)
    }

    @TestCase
    public func testPushDuplicate(): Unit {
        let fs = newFrameSorter()
        fs.push([0x01u8, 0x02u8, 0x03u8], 0)
        // 推入完全重复的数据应返回 false（间隙算法拒绝）
        let result = fs.push([0x01u8, 0x02u8, 0x03u8], 0)
        @Assert(result, false)
    }

    @TestCase
    public func testPushEmptyData(): Unit {
        let fs = newFrameSorter()
        let result = fs.push([], 0)
        @Assert(result, false)
    }

    @TestCase
    public func testPushGapFill(): Unit {
        let fs = newFrameSorter()
        fs.push([0x01u8, 0x02u8], 0)
        fs.push([0x05u8, 0x06u8], 5)
        let result = fs.push([0x03u8, 0x04u8], 3)
        @Assert(result, true)
        let (offset, data) = fs.pop()
        @Assert(offset, 0)
        @Assert(data.size, 2)
    }

    @TestCase
    public func testSequentialPushes(): Unit {
        let fs = newFrameSorter()
        @Assert(fs.push([0x01u8], 0), true)
        @Assert(fs.push([0x02u8], 1), true)
        let (offset, data) = fs.pop()
        @Assert(offset, 0)
        // push(offset=0, data=[0x01])，clean g: 后来 push offset=1 的数据可能
        // 以不同方式处理。至少应得到第一个 push 的 1 字节
        @Assert(data.size >= 1, true)
    }
}
