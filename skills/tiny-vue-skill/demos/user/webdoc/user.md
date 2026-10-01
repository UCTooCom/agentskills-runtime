# user Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>注意 User 组件请求的是 mock 数据，其他用户查询不了，开发时请用真实服务。</p><br> | user/basic-usage.vue |
| multiple-users | 多用户 | <p>设置 <code>multiple</code> 属性即可启用多用户形式。</p><br> | user/multiple-users.vue |
| multiple-users-tag | 折叠 Tag | <p>设置 <code>multiple</code> 属性即可启用多用户形式。<br>通过 <code>collapse-tags</code> 配置多用户模式下是否展示折叠标签，默认为 false。</p><br> | user/multiple-users-tag.vue |
| hide-selected | 隐藏已选择用户 | <p>设置 <code>hide-selected</code> 属性为 <code>true</code>，过滤搜索结果，已选择的人员不出现在搜索列表中。默认为 <code>false</code>，表示不过滤。</p><br> | user/hide-selected.vue |
| multiple-users-hover-expand | 折叠 Tag，hover 展开 | <p>多选时通过设置 <code>hover-expand</code> 为 true，默认折叠 tag, hover 时展示所有 tag。tag 超出隐藏并展示 tooltip。</p><br> | user/multiple-users-hover-expand.vue |
| allow-copy | 单用户场景支持复制 | <p>通过 <code>allow-copy</code> 设置输入框账号可通过鼠标选中，然后按 Ctrl + C 或右键进行复制。</p><br> | user/allow-copy.vue |
| tag-copy | 多用户场景支持复制 | <p>通过 <code>tag-selectable</code> 输入框中已选择的选项可通过鼠标选择，然后按 Ctrl + C 或右键进行复制。</p><br> | user/tag-copy.vue |
| tag-copy-all | user 选择器选项可一键复制 | <p>设置 <code>copyable</code> 属性后，可以点击复制按钮复制所有的 <code>tag</code> 文本内容以逗号分隔</p><br> | user/tag-copy-all.vue |
| dynamic-disable | 禁用状态 | <p>设置 <code>disabled</code> 属性可禁用 User 组件。</p><br> | user/dynamic-disable.vue |
| collapse-show-overflow-tooltip | 超出提示 | <p>设置 <code>collapse-show-overflow-tooltip</code> 此属性必须设置缓存 <code>cache</code> 为 <code>true</code> 时才会生效。</p><br> | user/collapse-show-overflow-tooltip.vue |
| value-split | 值分隔符 | <p>通过 <code>value-split</code> 属性可指定多用户下获取到的 value 值中不同用户之间的分隔符，默认为 <code>,</code>。<br>通过 <code>text-split</code> 属性可指定多用户模式下输入匹配的文本分隔符，默认为 <code>,</code> ，可选值为 <code>!~%(=+^{/}).!]&lt;-&gt;[\,:*#;</code>。</p><br> | user/value-split.vue |
| value-field | 取值字段映射 | <p>通过 <code>value-field</code> 属性可指定获取到的 value 值的形式，默认为 userId，还包括 userAccount。</p><br> | user/value-field.vue |
| text-field | 显示字段映射 | <p>通过 <code>text-field</code> 属性可指定显示用户的哪个字段信息。</p><br> | user/text-field.vue |
| cache-users | 缓存用户 | <p>通过 <code>cache</code> 属性指定用户数据是否缓存，默认为缓存。<br><br><code>cache-key</code> 属性可以自定义缓存的 key 值，默认为 tiny-user。<br><br><code>cache-fields</code> 属性用于指定缓存哪些用户数据。</p><br> | user/cache-users.vue |
| delay-load | 延时加载 | <p>通过 <code>delay</code> 属性指定延时加载的时间，单位是毫秒。</p><br> | user/delay-load.vue |
| load-after-input-the-length | 输入完指定长度后加载 | <p>通过 <code>suggest-length</code> 属性可指定输入多少个字符后开始请求服务。</p><br> | user/load-after-input-the-length.vue |
| event-change | 值改变事件 | <p>通过 <code>change</code> 事件能获取用户类型。</p><br> | user/event-change.vue |
| event-error | 用户查询错误提示 | <p>通过 <code>error</code> 事件能获取查询失败的输入。</p><br> | user/event-error.vue |
| user-options | 自定义选项文本 | <p>通过 <code>options</code> 插槽设置自定义下拉选项文本。</p><br> | user/user-options.vue |
| no-data-text | 自定义选自定义空数据文本项文本 | <p>通过 <code>no-data-text</code> 设置未查询到数据时的空数据提示。</p><br> | user/no-data-text.vue |
| custom-service | 自定义服务 | <p>通过 <code>service</code> 属性可自定义用户服务，当用户在文本框中输入准确的账号时，会在下拉菜单中出现此用户。<br>通过 <code>sort-by-fetch-data</code> 联想时下拉框的数据顺序和接口返回的数据顺序一致</p><br> | user/custom-service.vue |
| custom-sort | 自定义排序 | <p>通过 <code>sortable</code> 属性引用 <code>sortablejs</code> 进行排序。</p><br> | user/custom-sort.vue |
| user-select-size | 尺寸设置 | <p>通过 <code>size</code> 属性可指定用户输入框的尺寸，包括 medium、small、mini 三个选项。</p><br> | user/user-select-size.vue |
| hidden-tips-disable | 禁用多选不展示用户信息 | <p>设置 <code>show-tips</code> 属性可展示用户信息，默认展示。</p><br><p>设置 <code>max-width</code> 属性可设置 tips 展示信息最大宽度，默认 `200`。</p><br> | user/hidden-tips-disable.vue |
| batch | 合并请求用户信息 | <p>在进行批量发起用户信息查询时，例如同页面使用了多处 user 组件，通过配置 <code>batch</code> 为 <code>true</code> 将用户信息查询进行合并（组件内部会进行请求合并）。</p><br> | user/batch.vue |
| display-only | 只读 | <p>通过 <code>display-only</code> 属性设置只读态。</p><br> | user/display-only.vue |
