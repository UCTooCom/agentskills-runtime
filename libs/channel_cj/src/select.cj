package channel_cj

/**
 * 阻塞式 select：从第一个有数据的通道接收。
 *
 * 每个通道按轮询顺序尝试。当没有通道有数据且至少有一个通道仍打开时，
 * 循环会让出 CPU 给运行时，避免忙等。
 *
 * 等效于 Go 的：
 *   select {
 *   case v := <-ch0:
 *   case v := <-ch1:
 *   ...
 *   }
 *
 * @param channels  要接收的通道数组（元素类型相同）
 * @return (索引, Some(值)) 表示从第 index 个通道收到值；
 *         (-1, None) 表示所有通道都已关闭且数据耗尽
 */
public func select<T>(channels: Array<Chan<T>>): (Int64, Option<T>) {
    var result: (Int64, Option<T>) = (-1, Option<T>.None)
    var done = false
    while (!done) {
        for (i in 0..channels.size) {
            let r = channels[i].tryRecv()
            if (r.isSome()) {
                result = (i, r)
                done = true
                break
            }
        }
        if (done) { break }
        var anyOpen = false
        for (ch in channels) {
            if (!ch.isClosed()) {
                anyOpen = true
                break
            }
        }
        if (!anyOpen) {
            done = true
        }
    }
    return result
}

/**
 * 带默认分支的非阻塞 select。
 *
 * 等效于 Go 的：
 *   select {
 *   case v := <-ch0:
 *   case v := <-ch1:
 *   default:
 *     ...
 *   }
 *
 * @param channels       要接收的通道数组
 * @param defaultAction  当没有通道就绪时调用的默认分支
 * @return (索引, Some(值)) 当某个通道有数据时；
 *         (-1, None) 当执行了默认分支时
 */
public func selectOr<T>(
    channels: Array<Chan<T>>,
    defaultAction: () -> Unit,
): (Int64, Option<T>) {
    for (i in 0..channels.size) {
        let r = channels[i].tryRecv()
        if (r.isSome()) {
            return (i, r)
        }
    }
    defaultAction()
    return (-1, Option<T>.None)
}
