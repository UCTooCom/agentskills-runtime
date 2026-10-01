# slider Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 |  | slider/basic-usage.vue |
| vertical-mode | 竖向模式 | <p>通过设置<code>vertical</code> 属性来展示滑块竖向模式（不设置，默认为横向模式）<br>竖向模式可以通过 <code>height</code> 设置组件高度。</p><br> | slider/vertical-mode.vue |
| marks | 标记 | 使用 marks 属性，给滑杆的值添加标记。 | slider/marks.vue |
| max-min | 最大最小值 | <p>通过设置<code>min</code> <code>max</code> 来设置滑块取值范围。</p> | slider/max-min.vue |
| format-tooltip | 提示当前值 | <p>通过设置<code>format-tooltip</code> 来格式化提示值。</p> | slider/format-tooltip.vue |
| range-select | 范围选择 | <p>通过<code>v-model</code> 为数组 设定初始范围选择。</p> | slider/range-select.vue |
| show-input | 输入框模式 | <p>通过配置<code>show-input</code>，开启滑块输入框模式。可以通过配置<code>unit</code>来决定输入框后面显示的单位。</p> | slider/show-input.vue |
| shortcut-operation | 快捷键操作 | <p>通过设置<code>num-pages</code>总步数，即按快捷键 PageDown/PageUp 时，每次移动的距离是 "⌈(max-min)/num-pages⌉"。</p> | slider/shortcut-operation.vue |
| dynamic-disable | 禁用 | <p>通过设置属性<code>disabled</code> ,设置滑动滑块禁止滑动。</p> | slider/dynamic-disable.vue |
| show-tip | 提示 | <p>通过设定<code>:show-tip=&quot;false&quot;</code>，关闭滑块提示。(默认开启)。</p> | slider/show-tip.vue |
| about-step | 步长 | <p>通过设置<code>step</code>来配置滑块滑动的步长。</p> | slider/about-step.vue |
| slider-slot | 自定义插槽 | 显示滑块值的插槽。 | slider/slider-slot.vue |
| slider-event | 事件 | <p>change、start、stop 事件。</p> | slider/slider-event.vue |
