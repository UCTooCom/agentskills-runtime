# area Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>通过 <code>v-model / value</code> 属性设置默认值。</p><br> | area/basic-usage.vue |
| custom-service | 自定义服务 | <p>通过 <code>fetch-jcr</code> 可以自定义服务用于获取片区 JCR 数据，<code>fetch-rigion</code> 用于获取地区部 Region 的数据，<code>fetch-rep</code> 用于获取代表处 Rep 的数据，<code>fetch-office</code> 用于获取办事处 Office 的数据。同时 当数据字段为非默认的 <code>name_cn</code> <code>org_id</code> 时，可以通过 <code>props</code> 属性设置数据的映射字段。</p><br> | area/custom-service.vue |
| size | 设置组件大小 | <p>可选值为：<code>medium</code>，<code>small</code>，<code>mini</code></p><br> | area/size.vue |
| disabled | 禁用 | <p>通过 <code>disabled</code> 设置组件禁用默认值为 false。</p><br> | area/disabled.vue |
| area-events | 事件 | <p>Region 下拉框的值改变时触发 <code>change-region</code> 事件，Rep 下拉框的值改变时触发 <code>change-rep</code> 事件，Office 下拉框的值改变时触发 <code>change-office</code> 事件。</p><br> | area/area-events.vue |
