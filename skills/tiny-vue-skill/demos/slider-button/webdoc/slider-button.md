# slider-button Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 通过 <code>v-model</code> 绑定变量，设置的变量值为默认选中的 <code>Button</code> ，变量值对应 <code>label</code> 属性的值。通过 <code>text</code> 也可以配置显示文本，与默认插槽配置纯文本的结果一致 | slider-button/basic-usage.vue |
| slider-button-type | 类型设置 | <p>通过 <code>type</code> 属性设置按钮展示类型，可选值为 <code>text</code> (默认)、<code>icon</code>  </p><br> <p>可在 <code>SliderButton</code> 、 <code>SliderButtonGroup</code>  组件上设置 <code>change</code> 事件，当绑定值变化时触发，回调函数为选中的 <code>SliderButton label</code> 值</p> | slider-button/slider-button-type.vue |
| slider-button-size | 尺寸设置 | 可对按钮形式的 <code>SliderButton</code> 或带有边框的 <code>SliderButton</code> 设置 <code>size</code> 属性，以改变其尺寸，包括 <code>small</code> (默认)、<code>large</code> 两个尺寸选项。当插入的是图标类型时，还可配置 <code>medium</code> 尺寸。 | slider-button/slider-button-size.vue |
| custom-content | 自定义内容 | <p>通过 <code>label</code> 或者 <code>text</code> 属性可以设置 <code>Button</code> 的内容</p> | slider-button/custom-content.vue |
| slider-button-options | 支持数据渲染 | <p>可在 <code>SliderButtonGroup</code> 组件上设置 <code>options</code> 属性，可循环配置 <code>SliderButton</code> </p> | slider-button/slider-button-options.vue |
| page-turn | 左右翻页 | <p>通过设置 <code>page-turn</code> 属性开启左右翻页</p> | slider-button/page-turn.vue |
| slider-disabled | 禁用 | <p>通过设置 <code>disabled</code> 属性开启禁用态</p> | slider-button/slider-disabled.vue |
