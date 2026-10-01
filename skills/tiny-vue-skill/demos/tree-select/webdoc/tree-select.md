# tree-select Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>最基础的用法，通过 <code>tree-op</code> 设置下拉树的数据源，<code>v-model</code> 设置绑定值。</p> | tree-select/basic-usage.vue |
| multiple | 多选 | 通过 <code>multiple</code> 属性启用多选功能，此时 <code>v-model</code> 的值为当前选中值所组成的数组，默认选中值会以标签形式展示。<br> | tree-select/multiple.vue |
| collapse-tags | 折叠标签 | <p>通过 <code>collapse-tags</code> 属性设置选中多个选项时，多个标签缩略展示。设置 <code>hover-expand</code> 为 <code>true</code> ，默认折叠标签，<code>hover</code> 时展示所有标签。标签内容超长时超出省略，<code>hover</code> 标签时展示 <code>tooltip</code> 。</p><br> | tree-select/collapse-tags.vue |
| size | 尺寸 | <p>通过 <code>size</code> 属性设置输入框尺寸，可选值：medium / small / mini。</p> | tree-select/size.vue |
| disabled | 禁用 | <p>通过 <code>disabled</code> 属性设置禁用状态。</p><br> | tree-select/disabled.vue |
| lazy | 懒加载 | 通过 <code>lazy</code> 属性，启用懒加载模式。<br>通过 <code>load</code> 函数属性，触发加载，初始会执行一次。<br>通过 <code>after-load</code> 函数属性，监听下级节点加载完毕的事件。 | tree-select/lazy.vue |
| map-field | 映射字段 | 通过 <code>text-field</code> 设置显示文本字段，<code>value-field</code>设置绑定值字段。 | tree-select/map-field.vue |
| reference-style | 触发源样式 | <p>通过 <code>dropdown-icon</code> 属性可自定义下拉图标，<code>drop-style</code> 属性可自定义下拉选项样式，<code>tag-type</code> 属性设置标签类型（同 Tag 组件的 type 属性），<code>input-box-type</code> 属性设置输入框类型。</p><br> | tree-select/reference-style.vue |
| panel-style | 下拉面板样式 | <p>通过 <code>popper-append-to-body</code> 设置是否将弹框 dom 元素插入至 body 元素，默认为 true，<code>popper-class</code> 属性设置下拉弹框的类名，可自定义样式，<code>placement</code>设置弹出位置。</p><br> | tree-select/panel-style.vue |
| copy | 可复制 | <p>通过 <code>copyable</code> 设置启用一键复制所有标签的文本内容并以逗号分隔，<code>text-split</code> 自定义复制文本的分隔符。</p><br> | tree-select/copy.vue |
| native-properties | 原生属性 | <p>通过 <code>name</code> / <code>placeholder</code> / <code>autocomplete</code> 属性设置下拉组件内置 Input 的原生属性。</p><br> | tree-select/native-properties.vue |
