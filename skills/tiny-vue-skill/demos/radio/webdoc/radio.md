# radio Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>通过 <code>v-model</code> 绑定变量，变量值对应 <code>label</code> 属性的值。</p><br> | radio/basic-usage.vue |
| radio-group | 单选框组 | <p> <code>radio-group</code> 可以将 <code>radio</code> 或者 <code>radio-button</code> 组合起来，通过 <code>v-modal</code> 绑定选中的值。</p><br> | radio/radio-group.vue |
| group-options | 单选组 | <p>通过 <code>options</code> 配置式渲染单选组。另外还提供 <code>type</code> 属性，配合 <code>options</code> 属性一起使用，默认值为 <code>radio</code> 。可以配置为 <code>button</code> ，配置后单选组将以按钮的形式展示。</p><br> | radio/group-options.vue |
| dynamic-disable | 禁用状态 | <p>通过 <code>disabled</code> 设置是否禁用单选框。</p><br> | radio/dynamic-disable.vue |
| vertical | 垂直布局 | <p>可在 <code>radio-group</code> 组件上设置 <code>vertical</code> 属性，使单选框垂直布局。</p><br> | radio/vertical.vue |
| active-color | 自定义颜色 | <p>通过 <code>text-color</code> 设置单选按钮组激活时的文本颜色，通过 <code>fill</code> 设置填充色和边框色。</p><br> | radio/active-color.vue |
| radio-text | 文字内容 | <p>通过 <code>text</code> 属性或者默认插槽设置文字内容，插槽优先级大于 <code>text</code> 属性。若两者都没有，则使用 <code>label</code> 值作为文字内容。</p><br> | radio/radio-text.vue |
| radio-size | 尺寸 | <p>可对按钮形式的 <code>radio</code> 设置 <code>size</code> 属性，以改变其尺寸，可选值有： <code>medium</code>  、<code>small</code>  、<code>mini</code> 。</p> | radio/radio-size.vue |
| default-slot | 默认插槽 | <p>通过 <code>default</code> 默认插槽自定义描述内容。</p><br> | radio/default-slot.vue |
| radio-events | 单选框事件 | <p>可在 <code>radio</code> 、 <code>radio-group</code> 组件上监听 <code>change</code> 事件，当绑定值变化时触发。</p><br> | radio/radio-events.vue |
| display-only | 只读 | <p>通过给 <code>radio</code> 或者 <code>radio-group</code> 组件添加 <code>display-only</code> 属性实现只读态。</p> | radio/display-only.vue |
