# fluent-editor Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 通过 <code>v-model</code> 设置绑定值，默认数据保存格式为 Delta 数据格式。 | fluent-editor/basic-usage.vue |
| disabled | 禁用状态 | <p>通过属性 <code>disabled</code> 可设置编辑器为不可编辑状态。</p> | fluent-editor/disabled.vue |
| image-upload | 图片上传 | 通过 <code>image-upload</code> 设置图片上传模块的配置项。 | fluent-editor/image-upload.vue |
| options | 编辑器配置 | 通过 <code>options</code> 设置编辑器的配置项，支持的配置项和 Quill 的相同，可参考 <a href="https://quilljs.com/docs/configuration#options" target="_blank">Quill</a> 文档。 | fluent-editor/options.vue |
| data-switch | 数据格式转换 | <p>通过 <code>data-type</code> 指定富文本数据保存的格式。数据默认保存格式为 Delta 形式，若需要将数据保存格式设置为 HTML 形式，并关闭 HTML 格式自动转 Delta 格式，设置 <code>:data-type="false"</code>，<code>:data-upgrade="false"</code>。</p> | fluent-editor/data-switch.vue |
| before-editor-init | 初始化前的钩子 | <p>通过 <code>before-editor-init</code> 设置 FluentEditor 初始化前的钩子函数，主要用于注册 FluentEditor 自定义格式和模块。<br>这个示例增加了两个新的格式：good / bad，并在工具栏增加了对应的图标用于设置这两种格式。<br>选中一段文本，点击点赞图标，会将文本色设置成绿色；点击点踩图标，会将文本色设置成红色。</p> | fluent-editor/before-editor-init.vue |
| before-link-open | 超链接跳转拦截 | <p>通过 <code>before-link-open</code> 拦截富文本中超链接的跳转。该属性接收一个回调函数，点击链接时会传入 <code>url</code>、<code>rawUrl</code>、<code>target</code> 等参数。返回 <code>false</code>（或 Promise resolve false）可拦截跳转，返回 <code>true</code> 或 <code>undefined</code> 继续跳转。<br>本示例使用 <code>TinyModal.confirm</code> 弹出确认框，点击「确定」打开链接，点击「取消」拦截跳转。</p> | fluent-editor/before-link-open.vue |
