# float-button Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>通过 <code>type</code> 设置按钮类型， <code>shape</code>设置按钮的形状</p> | float-button/basic-usage.vue |
| reset-time | 防止重复点击 | <p>通过 <code>reset-time</code> 设置单击后按钮禁用的时长，默认禁用时长为 1000 毫秒，可用于防止按钮连续点击出现表单重复提交的问题。</p> | float-button/reset-time.vue |
| icon | 图标按钮 | <p>通过 <code>icon</code> 设置按钮展示图标，接收一个图标组件。</p><div class="tip custom-block"><p class="custom-block-title">Icon 图标用法</p><p>先从 <code>@opentiny/vue-icon</code> 中导入需要的 Icon，执行 Icon 函数得到 Icon 组件。然后在模板中通过 <code>icon</code> 属性进行引用。</p> | float-button/icon.vue |
| trigger | 菜单模式 | <p>设置<code>trigger</code> 属性即可开启菜单模式。设置<code>open</code>为<code>true</code>即可手动打开菜单.</p> | float-button/trigger.vue |
| backTop | 回到顶部 | <p>设置<code>backtop</code> 属性即可实现页面滚回顶部。<code>element</code>赋值为滚动元素。</p> | float-button/backTop.vue |
| jump | 跳转页面 | <p>可以设置<code>href</code>和<code>target</code>两个属性，按钮点击跳转页面。</p> | float-button/jump.vue |
