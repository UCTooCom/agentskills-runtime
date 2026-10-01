# breadcrumb Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| base | 基本用法 | <code>Breadcrumb</code>：通过 <code>select</code> 监听面包屑选中事件。<br/><br>                  <code>BreadcrumbItem</code>：通过 <code>to</code> 设置选项路由跳转对象，<code>label</code> 设置选项名称，<code>select</code> 监听选项选中事件。 | breadcrumb/base.vue |
| size | 尺寸设置 | 通过 <code>size</code> 自定义尺寸，仅支持 <code>medium</code> 尺寸。 | breadcrumb/size.vue |
| slot-default | 定义节点 | <code>BreadcrumbItem</code>：通过默认插槽自定义节点内容；<code>replace</code> 设置不向浏览器历史添加新记录。 | breadcrumb/slot-default.vue |
| separator | 定义分隔符 | <code>Breadcrumb</code>：通过 <code>separator</code> 或 <code>separator-icon</code> 自定义分隔符。 | breadcrumb/separator.vue |
| options | 配置式 | 通过 <code>options</code> 配置每个 <code>BreadcrumbItem</code>；<code>text-field</code> 指定显示键值，默认显示键值为 <code>label</code>。 | breadcrumb/options.vue |
