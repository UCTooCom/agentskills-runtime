# 长程任务检查点 (Checkpoint)

## 目标
查找 2025 年高考物理压轴大题、核实原文、独立求解、自检验核、输出 HTML 报告。

## 任务 ID
a298ea47-8af2-4432-8180-21f62c2b8b72

## 环境能力记录
- web_fetch 工具：TLS 握手失败（Bing），被服务端按客户端指纹拒绝。
- python 环境：**无 requests 库**（报 requests not installed），改用标准库 urllib + 关闭 SSL 校验。
- duckduckgo：连接超时（10060）。
- 可用检索通道：Baidu（HTTP 200，返回 AI 摘要 + 结果列表）。

## 已获取线索（Round 1）
通过 Baidu AI 摘要获得 2025 全国卷物理压轴题模型描述：
- 新课标卷（适用新疆、西藏）：力学综合题。物块 P 固定在水平面，上有 1/4 圆弧轨道，右端连接可滑动薄板 Q，Q 上固定轻弹簧；小球从上方自由下落，经圆弧轨道后与弹簧接触；接触时速度减小为接触前 1/3，此时弹簧弹性势能 2mgR；随后断开 P、Q 连接，Q 从静止滑动。
  - 4 问：(1) 重力做功；(2) 接触时速度大小及下落点与接触点距离；(3) 使弹簧最大弹性势能为 2.2mgR 求 Q 质量；(4) 使 Q 最终动能最大求 Q 质量。
- 新课标 II 卷（黑吉辽内）：电磁学综合（洛伦兹力 + 库仑力 + 开普勒定律）。

## 待办
- [ ] 检索并核实压轴题题干原文与权威来源链接
- [ ] 独立推导求解（不抄袭现成答案）
- [ ] 自我验核（量纲/单位/数量级/极限情形）
- [ ] 生成 HTML 报告（MathJax）

## 产物路径
- 输出目录：D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\agentskills-runtime/skills/long-running-task/output/rounds/a298ea47-8af2-4432-8180-21f62c2b8b72
