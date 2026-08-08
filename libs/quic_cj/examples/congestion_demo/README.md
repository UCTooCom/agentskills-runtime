# CUBIC 拥塞控制演示
 
 演示 CUBIC 拥塞控制的实现（RFC 9438）。
 展示数据传输过程中拥塞窗口的变化。
 
 ## 关键组件
 
 - `CubicSender` — CUBIC 拥塞控制发送器
 - `Pacer` — 令牌桶调速器
 - `bandwidthFromDelta` — 带宽估算
 
 ## 运行
 
 ```bash
 cjpm run
 ```
