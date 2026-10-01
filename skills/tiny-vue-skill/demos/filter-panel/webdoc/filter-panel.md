# filter-panel Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 通过 <code>label</code> 设置标题，<code>value</code> 设置标题右侧内容，<code>disabled</code> 设置是否禁用；通过默认插槽自定义过滤面板内容。 | filter-panel/basic-usage.vue |
| popper-class | 自定义下拉面板 | 通过 <code>placement</code> 控制下拉面板的位置， <code>popper-class</code> 设置类名，自定义下拉面板的样式；<code>popper-append-to-body</code> 设置弹下拉面板是否插入至 body 元素。在下拉面板的定位出现问题时，可将其设置为 false。 | filter-panel/popper-class.vue |
| tip | 背景与提示 | 通过 <code>blank</code> 控制过滤器背景是否透明； <code>:clearable='false'</code> 隐藏清空按钮；配合 <code>tip</code> 添加标题右侧提示信息。 | filter-panel/tip.vue |
| size | 尺寸 | 通过 <code>size</code> 设置过滤器面板的尺寸。支持 <code>medium</code> 中等尺寸，不设置则为默认尺寸。 | filter-panel/size.vue |
| manual-hide | 手动隐藏 | 手动调用 <code>hide</code> 实例方法完成收起下拉面板功能。 | filter-panel/manual-hide.vue |
| code | 批量编码 | 通过默认插槽定义下拉框内容。 | filter-panel/code.vue |
| event | 事件 | <code>handle-clear</code> 监听清空按钮点击事件，执行删除操作； <code>visible-change</code> 监听下拉面板的显隐事件。 | filter-panel/event.vue |
