# 长程任务进度检查点

## 目标
查找去年（2025年）高考数学压轴大题，不抄袭现成答案，独立完整解答，输出自包含 HTML 报告。

## 已完成
- [T1-部分] 官方评析文（gaokao.eol.cn 2025-06-07《2025年高考数学全国卷试题评析》）确认：压轴题为 **全国一卷第19题（三角函数情境·新定义题，17分）**；全国二卷第19题亦为压轴（概率·一簇事件关系，承接2024新定义）。
- [T1-部分] 定位官方试题页：`http://gaokao.eol.cn/shiti/sx/202506/t20250607_2673303.shtml`（全国一卷数学，2025-06-07）。
- [T1-部分] 判定该页为**图片承载**（HTML 168KB → 纯文本 9KB，关键词零命中，含图片直链）→ 符合约束11判据，走图片直链路线。
- [T1-部分] 已下载题图 1 张：`output/executed/t1/img/qg1_00.png`（433262 B）= `https://img.eol.cn/e_images/gk/2025/st/qg1/sx01.png`。
- [T1-部分] 策略切换记录：Bing SERP 抓取（round2~round6）连续失败（压轴命中 0）→ 已弃用该策略，切换为「官方试题页图片直链」。

## 待办
- [T1] 下载并定位 2025 全国一卷第 19 题题图（当前批量探测 sx01..sx30）。
- [T2] 独立解答第 19 题（禁止抄袭，完整推导链）。
- [T3] 自校验（数值代入 / 另法验证）。
- [T4] 生成 `output/brief/gaokao-math-final-2025.html`。
- [T5] 验核 + 交付。

## 失败项
- Bing SERP 抓取：`_round6.json` 全部记录「压轴」命中 0；`bing_s.html` 提示部分结果未显示 → 判定策略失效。
- `file_read` 读中文文本会替换为 `?`（编码降级 bug）→ 改用 `cli_execute + python（UTF-8 + ASCII 转义输出）` 规避。
- 长文本 stdout 会被摘要截断/乱码 → 改为落盘切块 + 小范围打印。

## 下一步
- 运行 `fetch_imgs.py` 批量下载题图 → 用视觉能力直接读第 19 题图片 → 独立解题。

## 关键产物路径
- 目标解析：`output/parsed/goal.json`
- 任务规划：`output/planned/plan.json`
- 素材切块：`output/executed/t1/`
- 题图目录：`output/executed/t1/img/`
- 最终报告：`output/brief/gaokao-math-final-2025.html`（待生成）

## 更新时间
2026-09-16
