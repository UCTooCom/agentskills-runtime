# progress Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 通过 <code>percentage</code> 设置进度值， <code>stroke-width</code> 设置进度条的宽度，单位 px。 | progress/basic-usage.vue |
| custom-color | 定义颜色 | 通过 <code>color</code> 设置进度条颜色；会覆盖 <code>status</code> 状态颜色。 | progress/custom-color.vue |
| format-text | 文字的显隐和位置 | 通过 <code>show-text</code> 设置文字显隐； <code>text-inside</code> 设置文字内置在进度条内显示（只在 type=line 时可用）， <code>format</code> 自定义进度条的文字。 | progress/format-text.vue |
| progress-status | 状态 | 通过 <code>status</code> 设置当前状态，可选值： <code>(success/exception/warning)</code> 。 | progress/progress-status.vue |
| slot-icon-status | 图标状态插槽 | 通过插槽自定义状态图标。 | progress/slot-icon-status.vue |
| custom-status | 自定义状态场景 | 用法如下。 | progress/custom-status.vue |
| progress-type-circle | 环形 | 通过 <code>type="circle"</code> 设置为圆环类型，<code>type="dashboard"</code> 则为 C 型圆环类型; <code>width</code> 设置环形进度条画布宽度，默认值为 126px。 | progress/progress-type-circle.vue |
