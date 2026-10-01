# time-select Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 详细用法参考如下示例。 | time-select/basic-usage.vue |
| range-placeholder | 固定时间范围 | 如果先选中了开始（或结束）时间，则结束（或开始）时间的状态也将会随之改变。 | time-select/range-placeholder.vue |
| default-value | 设置打开默认时间 | <p>通过 <code>default-value</code> 设置选择器打开显示默认时间。</p><br> | time-select/default-value.vue |
| picker-options | 固定时间点 | <p>提供固定时间点，可通过 picker-options 对象中的 start、end、step、minTime、maxTime 设置起始时间、结束时间、步长、最小有效时间和最大有效时间。</p><br> | time-select/picker-options.vue |
| suffix-icon | 后置图标 | <p>通过 <code>suffix-icon</code> 属性设置时间输入框后置图标。</p><br> | time-select/suffix-icon.vue |
| clear-icon | 清空图标 | <p>通过 <code>clearable</code> 显示清空图标，通过 <code>clear-icon</code> 自定义清空图标，通过 <code>popper-class</code> 属性设置下拉框的类名。</p> | time-select/clear-icon.vue |
| event-blur | 事件 | <p><code>focus</code> input 框聚焦时触发，<code>blur</code> input 框失焦时触发，<code>change</code> input 绑定值改变时触发。</p><br> | time-select/event-blur.vue |
| editable | 文本框不可编辑 | <p>时间输入框默认可以输入时间，设置 <code>editable</code> 为 false 后，将不能输入。</p><br> | time-select/editable.vue |
| size-medium | 尺寸 | 通过修改 size 的属性值可调整输入框尺寸，提供 medium、small、mini 三个固定属性值。 | time-select/size-medium.vue |
| focus | 手动获取焦点 | 通过给组件设置 ref 手动调用触发 focus 事件。 | time-select/focus.vue |
