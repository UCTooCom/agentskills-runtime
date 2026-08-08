# API 参考

## Chan 类

```cangjie
public class Chan<T>
```

### 构造函数

| 构造函数 | 说明 |
|---------|------|
| `Chan<T>()` | 创建无缓冲通道 |
| `Chan<T>(capacity: Int64)` | 创建有缓冲通道，容量为 capacity（负数等价于 0） |

### 方法列表

#### send

```cangjie
public func send(value: T): Unit
```

阻塞发送。对于无缓冲通道，阻塞直到有接收者就绪；对于有缓冲通道，仅在缓冲区满时阻塞。

- 通道关闭后调用将抛出 `Exception`
- 在通道关闭时阻塞的发送者也将收到异常

---

#### recv

```cangjie
public func recv(): Option<T>
```

阻塞接收。无数据时等待。

- 返回 `Some(value)` 当收到数据时
- 返回 `None` 当通道已关闭且数据已耗尽

---

#### trySend

```cangjie
public func trySend(value: T): Bool
```

非阻塞发送。

- 返回 `true` 发送成功
- 返回 `false` 无法发送（缓冲区满、无接收者、通道已关闭）

---

#### tryRecv

```cangjie
public func tryRecv(): Option<T>
```

非阻塞接收。

- 返回 `Some(value)` 有数据立即可用
- 返回 `None` 无数据

---

#### close

```cangjie
public func close(): Unit
```

关闭通道。

- 唤醒所有阻塞线程
- 待发送队列中的值被丢弃，发送者收到异常
- 接收者耗尽剩余数据后返回 `None`
- 重复关闭抛出 `Exception`

---

#### forEach

```cangjie
public func forEach(action: (T) -> Unit): Unit
```

迭代接收，直到通道关闭且数据耗尽。

---

#### len

```cangjie
public func len(): Int64
```

当前缓冲区中的元素数量。无缓冲通道始终返回 0。

---

#### cap

```cangjie
public func cap(): Int64
```

通道容量（无缓冲通道为 0）。

---

#### isClosed

```cangjie
public func isClosed(): Bool
```

返回通道是否已关闭。

---

## select 函数

```cangjie
public func select<T>(channels: Array<Chan<T>>): (Int64, Option<T>)
```

从多个通道中阻塞读取第一个就绪的数据。等效于 Go 的：

```go
select {
case v := <-ch0:
case v := <-ch1:
}
```

**返回值：**
- `(index, Some(value))`：从第 `index` 个通道收到值
- `(-1, None)`：所有通道均已关闭

---

## selectOr 函数

```cangjie
public func selectOr<T>(
    channels: Array<Chan<T>>,
    defaultAction: () -> Unit,
): (Int64, Option<T>)
```

带默认分支的非阻塞 select。没有通道就绪时执行 `defaultAction`。等效于 Go 的：

```go
select {
case v := <-ch0:
case v := <-ch1:
default:
}
```

**返回值：**
- `(index, Some(value))`：从某个通道收到值
- `(-1, None)`：执行了默认分支
