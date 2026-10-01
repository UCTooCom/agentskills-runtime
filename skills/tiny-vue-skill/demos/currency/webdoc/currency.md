# currency Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 详细用法参考如下示例 | currency/basic-usage.vue |
| disable-currency | 禁用 | <p>通过 <code>disabled</code> 属性设置组件是否禁用，默认值为 false。</p><br> | currency/disable-currency.vue |
| custom-service | 自定义服务 | <p>通过 <code>fetch-currency</code> 属性可以指定一个方法，在方法中可实现请求自定义的服务。<br>通过 <code>clearable</code> 属性设置是否可以清空，默认值为 true。</p><br> | currency/custom-service.vue |
| size | 设置组件大小 | <p>可设置为：<code>medium</code>，<code>small</code>，<code>mini</code></p><br> | currency/size.vue |
| filter | 过滤器模式 | <p>通过 filter 属性切换至过滤器模式。过滤器模式下可传入 label 显示标题，tip 显示提示信息，clearable 是否显示清除按钮。</p> | currency/filter.vue |
| set-default | 设置默认币种 | 通过 <code>set-default</code> 属性设置组件是否使用设置默认币种功能。<code>v-model</code>和默认币种值同时存在，以默认币种值优先 | currency/set-default.vue |
| set-default-custom-service | 自定义默认币种服务 | 通过 <code>fetch-default-currency</code> 和 <code>set-default-currency</code> 自定义默认币种查询和保存服务 | currency/set-default-custom-service.vue |
