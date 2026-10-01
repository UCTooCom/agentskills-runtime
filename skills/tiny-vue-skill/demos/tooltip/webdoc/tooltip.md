# tooltip Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 通过 <code>content</code> 属性指定提示的内容。<br><br>           通过 <code>placement</code> 属性指定提示的显示位置，支持 12 个显示位置。<br><br>           通过 <code>effect</code> 属性指定提示的效果。<br> | tooltip/basic-usage.vue |
| theme | 主题 | <br>            通过 <code>effect</code> 属性设置明暗效果，可选值 <code>dark/light</code> ,默认值为 <code>dark</code>，通常使用<code>effect</code>设置效果。<br><br>            通过 <code>type</code> 属性设置主题，它的优先级大于 <code>effect</code>。 | tooltip/theme.vue |
| control | 控制/禁用提示 | <br>          提示组件默认是监听鼠标移入/移出事件来触发，手动控制提示的出现，有以下方法：<br><br>          1.通过 <code>visible</code> 属性设置是否智能识别溢出后提示，属性取值为 <code> always / auto </code>。当取值为<code>auto</code>时，智能提示是自动识别文字是否有长度溢出，动态的显示提示。<br><br>          2.通过 <code>manual</code> 属性为 true 后，就可以通过设置 <code>v-model</code> 属性，动态控制显示和隐藏。<br><br>          3.通过 <code>disabled</code> 属性，直接禁用提示。<br> | tooltip/control.vue |
| content | 弹出层内容 | <br>          通过 <code>content</code> 属性指定弹出的文本。<br><br>          通过 <code>renderContent</code> 自定义渲染函数，可使用 <code>JSX</code> 返回需要渲染的节点内容。<br><br>          通过 <code>content</code> 插槽，自定义内容，当弹出复杂的内容结构时，推荐使用插槽的方式。<br> | tooltip/content.vue |
| offset | 弹出层的偏移 | 通过 <code>offset</code> 属性设置组件出现位置的偏移量。 | tooltip/offset.vue |
| custom-popper | 弹出层的特性 | <br>          通过 <code> visible-arrow </code> 属性设置是否显示小箭头。<br><br>          通过 <code> enterable </code> 属性设置鼠标是否可进入到 tooltip 中。<br><br>          通过 <code> popper-class </code> 属性设置弹出 dom 的类名，便于用户定制弹出层的样式。<br> | tooltip/custom-popper.vue |
| delay | 延迟控制 | <br>            通过 <code>open-delay</code> 属性设置组件延迟出现的时间，单位毫秒，默认值为 0。<br><br>            通过 <code>close-delay</code> 属性设置 组件延迟关闭的时间，单位毫秒，默认值为 300。<br><br>            通过 <code>hide-after</code> 属性设置组件出现后自动隐藏的时间，单位毫秒，为 0 则不会自动隐藏，默认值为 0。<br><br>           | tooltip/delay.vue |
| popper-options | 高级配置 | 通过 <code>popper-options</code> 属性为组件的弹出层的配置参。 | tooltip/popper-options.vue |
| transition | 自定义渐变动画 | 通过 <code>transition</code> 定义渐变动画，默认选值为 <code>tiny-fade-in-linear</code>。 | tooltip/transition.vue |
| pre | 文本预格式化 | <br>          配置 <code> pre </code>  为  <code> true </code> ，就会预格式化  <code> content </code>  文本。<br><br>          被包围在 <code> pre </code>  标签元素中的文本会保留空格和换行符，文本也会呈现为等宽字体。 | tooltip/pre.vue |
| content-max-height | 内容最大高度 | 配置 <code>content-max-height</code>  设置内容展示的最大高度。 | tooltip/content-max-height.vue |
