# HTTP/3 优先级（RFC 9218）

## 概述

HTTP/3 使用 Extensible Priorities（RFC 9218）替代 HTTP/2 的优先级树。
优先级信号通过 `Priority` HTTP 头字段传递。

Priority 头字段格式：

```
Priority: u=<urgency>, i=<incremental>
```

- **urgency**（紧急度）：0-7，值越低优先级越高，默认 3
- **incremental**（增量标记）：`?0`（默认）或 `?1`

## 优先级的解读

| 紧急度 | 含义 |
|--------|------|
| 0 | 最高优先级（关键资源，如首页 HTML） |
| 1-2 | 高优先级（渲染阻塞资源，如 CSS） |
| 3 | 默认优先级 |
| 4-5 | 中优先级（图片、字体） |
| 6-7 | 低优先级（分析脚本、预加载资源） |

## 优先级调度器（PriorityScheduler）

`PriorityScheduler` 维护 8 个优先级队列，从最高（0）到最低（7）依次处理请求。

```cangjie
let scheduler = PriorityScheduler()
scheduler.addStream(1, priority: Http3Priority(urgency: 0, incremental: false))
scheduler.addStream(2, priority: Http3Priority(urgency: 5, incremental: true))

while (scheduler.hasPending()) {
    match (scheduler.nextHighest()) {
        case Some(streamId) => processStream(streamId)
        case None => break
    }
}
```

## 优先级头部解析

```cangjie
// 从请求头部提取优先级
let priority = extractPriorityFromHeaders(request.headers)

// 编码优先级头部
let headerValue = encodePriorityHeader(priority)
// 结果: "u=1, i=?1"

// 解析已存在的 Priority 头部
let parsed = parsePriorityHeader("u=0, i=?1")
```

## 相关文件

| 文件 | 说明 |
|------|------|
| `priority.cj` | Http3Priority 类、解析/编码函数、PriorityScheduler |
| `priority_test.cj` | 优先级单元测试 |

## 参考

- [RFC 9218 — Extensible Prioritization Scheme for HTTP](https://www.rfc-editor.org/rfc/rfc9218)
- [RFC 9218 §3 — Priority Parameters](https://www.rfc-editor.org/rfc/rfc9218#section-3)
- [RFC 9218 §4 — Priority Scheduler](https://www.rfc-editor.org/rfc/rfc9218#section-4)
