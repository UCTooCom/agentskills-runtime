# 测试指南

## 运行测试

```bash
# 运行全部测试
cjpm test

# 清理后构建并测试
rm -rf target/release
cjpm test
```

## 测试输出

测试输出类似如下：
```
TCS: AckTestSuite, time elapsed: 2819559 ns, RESULT:
    [PASSED] CASE: testNewAckHandler (491539 ns)
    [PASSED] CASE: testSentPacketDefaults (12961 ns)
    ...
Summary: TOTAL: 619
    PASSED: 619, SKIPPED: 0, FAILED: 0
```

## 编写测试

### 测试结构

测试文件位于 `src/quic_cj/tests/`。每个测试文件：
- 声明 `package quic_cj.tests`
- 导入被测试的模块
- 使用 `@Test` 注解测试类
- 使用 `@TestCase` 注解测试方法
- 使用 `@Assert` 进行断言

### 测试文件模板

```cangjie
package quic_cj.tests

import quic_cj.my_module.{MyClass, myFunction}

@Test
public class MyFeatureTestSuite {
    @TestCase
    public func testBasicBehavior(): Unit {
        let result = myFunction(42)
        @Assert(result, 42)
    }

    @TestCase
    public func testEdgeCase(): Unit {
        let result = myFunction(0)
        @Assert(result, 0)
    }
}
```

### 断言

`@Assert` 是主要的断言宏：

```cangjie
@Assert(actual, expected)               // 相等性判断
@Assert(actual > 0, true)               // 布尔条件判断
```

对于枚举比较（由于不支持 `==`）：
```cangjie
let isCorrect = match (result) {
    case MyEnum.Value => true
    case _ => false
}
@Assert(isCorrect, true)
```

### 测试模式

**1. 往返测试**

```cangjie
let original = MyFrame()
let serialized = appendFrame([], original)
let (parsed, consumed) = parseFrame(serialized)
@Assert(consumed, serialized.size)
@Assert(parsed.getField(), expectedValue)
```

**2. 状态机测试**

```cangjie
let conn = newClientConnection(destId, srcId)
let isInitial = match (conn.getState()) {
    case ConnectionState.Initial => true
    case _ => false
}
@Assert(isInitial, true)
conn.closeWithError(0u64, "test")
// 验证状态转换
```

**3. 错误用例测试**

```cangjie
try {
    // 应该抛出异常的代码
    @Fail("Should have thrown")
} catch (_: Exception) {
    @Assert(true)
}
```

### 测试覆盖率汇总

| 模块 | 文件数 | 测试数 | 覆盖范围 |
|--------|-------|-------|----------|
| 协议 | 8 | 30+ | 类型、版本、流 ID、包编号 |
| 线缆编码 | 8 | 60+ | 帧往返、变长整数、包头 |
| TLS | 9 | 40+ | AEAD、包头保护、加密设置、HKDF |
| ACK | 6 | 20+ | 包追踪、丢包检测、重传队列 |
| 拥塞控制 | 5 | 20+ | CUBIC + NewReno、调节器、Pacer |
| 流量控制 | 1 | 12+ | 窗口管理、阻塞 |
| 流 | 3 | 15+ | 流操作、状态机 |
| 核心引擎 | 5 | 75+ | 包打包/解包、连接生命周期、重传队列、Path Manager |
| DatagramQueue | 1 | 5+ | 不可靠数据队列管理 |
| RetransmissionQueue | 1 | 5+ | 丢包重传排队 |
| PathManager | 1 | 10+ | 连接迁移、路径验证 |
| 错误类型 | 2 | 10+ | QError、TransportError、CryptoError |
| 工具 | 2 | 10+ | RTT 统计、环形缓冲区、错误码 |
| 系统 | 2 | 8+ | 套接字操作、缓冲池 |
| API | 3 | 25+ | 配置、拨号/监听、错误处理 |
| 事件日志（qlog） | 2 | 25+ | QlogEvent 名称映射、Tracer API 调用 |
| **合计** | **64** | **619** | **源码 12395 行 / 测试 7192 行（36.7%）** |

---

## 基准测试

quic_cj 使用仓颉内置的 `@Bench` 注解运行基准测试：

```bash
# 运行全部基准测试
cjpm bench

# 仅运行特定基准测试组
cjpm bench --filter VarintBench

# 生成报告
cjpm bench --report-path ./bench_report
```

### 基准测试覆盖

当前 81 个基准测试覆盖以下模块：

| 模块 | 基准测试数 | 典型延迟 |
|--------|-----------|----------|
| 变长整数（Varint） | 3 | 74.8–406.4 ns |
| 缓冲区操作 | 3 | 180.8 ns–136.5 µs |
| 协议操作 | 3 | 11.7 ns–2.88 µs |
| 帧序列化 | 5 | 99.1 ns–5.52 µs |
| ACK 处理 | 3 | 11.2–22.2 ns |
| CUBIC 拥塞控制 | 6 | 11.3–180.8 ns |
| 流量控制 | 4 | 74.2–299.9 ns |
| 流操作 | 4 | 286.8 ns–71.3 µs |
| 流映射 | 3 | 432.6 ns–1.31 µs |
| 连接 | 3 | 1.53–2.51 ms |
| 配置 | 3 | 146.0–300.6 ns |
| 核心引擎 | 5 | 34.8 ns–2.14 µs |
| 工具 | 4 | 46.2 ns–2.32 µs |
| 密码套件 | 2 | 66.7–83.2 ns |

| DatagramQueue | 10 | 237–542 ns |
| RetransmissionQueue | 8 | 184–640 ns |
| PathManager | 3 | 34.4–117.3 ns |
| Error 类型 | 3 | 39.8–58.5 ns |
| 连接日志 | 5 | 13.8–127.8 ns |
完整的基准测试数据参见 [README.md](../README.md#基准测试)。

