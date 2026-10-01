# checkbox Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>通过 <code>v-model</code> 设置绑定值，<code>name</code> 设置原生属性。</p> | checkbox/basic-usage.vue |
| disabled | 禁用 | <p>通过 <code>disabled</code> 字段设置当前复选框是否为禁用状态。</p> | checkbox/checkbox-disabled.vue |
| checkbox-group | 复选框组 | <p><code>checkbox-group</code> 可以将多个 <code>checkbox</code> 元素管理为一组，在 <code>checkbox-group</code> 中使用 <code>v-model</code> 绑定选中值。<code>checkbox</code> 的 <code>label</code> 与 <code>checkbox-group</code> 的绑定值相对应，如果存在指定的值则为选中状态，否则为不选中。</p> | checkbox/checkbox-group.vue |
| checkbox-button | 复选框按钮 | <p>通过 <code>checkbox-button</code> 以按钮的形式展示复选框，用法与 <code>checkbox</code> 相似。</p> | checkbox/checkbox-button.vue |
| group-options | 配置式复选框组 | <p>通过 <code>options</code> 配置显示多选框组。使用该属性后，可以不用再在标签中以插槽的形式插入 <code>checkbox</code> 或 <code>checkbox-button</code> 元素。 <code>type</code> 属性配合 <code>options</code> 属性一起使用，将 <code>type</code> 配置为 <code>button</code> ，复选框组将以按钮的形式展示。</p> | checkbox/group-options.vue |
| description | 描述文本 | <p>复选框或复现框按钮的描述文本，有三种方式可以提供，优先级依次为 <code>默认插槽</code> 、<code>text</code> 、<code>label</code> 。</p> | checkbox/description.vue |
| indeterminate | 全选与半选 | <p>在 <code>checkbox</code> 元素中配置 <code>indeterminate</code> 属性为 true 后，勾选框将展示为半选的样式。</p> | checkbox/indeterminate.vue |
| min-max | 可选数量限制 | <p>在 <code>checkbox-group</code> 上可通过 <code>min</code> 、 <code>max</code> 属性指定可勾选项目的最小、最大值。</p> | checkbox/min-max.vue |
| checked | 是否默认勾选 | <p> <code>checkbox-group</code> 上绑定的 <code>v-model</code> 可以配置默认选中， <code>checked</code> 同样可以配置默认选中。</p> | checkbox/checked.vue |
| vertical-checkbox | 垂直布局 | <p>在 <code>checkbox-group</code> 元素上设置 <code>vertical</code> 为 true，则其管理的 <code>checkbox-button</code> 或 <code>checkbox</code> 将展示为垂直布局。</p> | checkbox/vertical-checkbox.vue |
| text | 状态对应的值 | <p>通过 <code>true-label</code> 设置选中的值， <code>false-label</code> 设置未选中的值。</p> | checkbox/text.vue |
| size | 尺寸 | <p>当复选框为按钮形式时， <code>size</code> 属性可以设置尺寸，可选项有 <code>medium</code> 、<code>small</code> 、<code>mini</code>，不设置则为默认样式。</p> | checkbox/size.vue |
| shape | 过滤器模式 | <p>通过 <code>shape</code> 设置过滤器模式。</p> | checkbox/shape.vue |
| custom-color | 自定义颜色 | <p>通过 <code>fill</code> 自定义选中时背景和边框颜色，通过 <code>text-color</code> 自定义选中时的文本颜色。</p> | checkbox/custom-color.vue |
| checkbox-slot | 默认插槽 | <p>通过 <code>default slot</code> 自定义文本内容。</p> | checkbox/checkbox-slot.vue |
| checkbox-button-multiple | 多行按钮 | <p>多行按钮组，超出最大宽度后，换行显示。</p> | checkbox/checkbox-button-multiple.vue |
| dynamic-create-checkbox | 动态生成复选框组 | <p>复选框组所需数据可通过请求服务从后台取得，然后动态生成。</p> | checkbox/dynamic-create-checkbox.vue |
| checkbox-events | 事件 | <p>勾选值改变后将触发 <code>change</code> 事件。</p> | checkbox/checkbox-events.vue |
