# locales Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>配置 <code>local</code> 属性后，不会自动调用服务，仅用做当前语言切换，不会刷新页面。</p><br> | locales/basic-usage.vue |
| custom-service | 自定义服务 | <p><code>get-locale</code> 可用于自定义获取所有语言。<code>get-current-locale</code> 用于获取当前语言。<code>get-change-locale-url</code> 用于获取改变语言后的 URL，参数为切换后的语言。</p><br> | locales/custom-service.vue |
| change-lang | 语言切换 | <p>提供 <code>change-lang</code> 函数用于自定义语言切换的逻辑，不设置则使用内置的切换方法。</p><br> | locales/change-lang.vue |
