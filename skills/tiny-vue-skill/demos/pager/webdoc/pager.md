# pager Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>通过 <code>total</code> 设置总条数。</p> | pager/basic-usage.vue |
| current-page | 当前所在页 | <p>通过 <code>current-page</code> 设置初始加载页码数。</p><br> | pager/current-page.vue |
| page-size | 每页显示数量 | <p>通过 <code>page-size</code> 设置每页显示条目数， <code>page-sizes</code> 设置可选择的 <code>page-size</code> 列表。</p><br> | pager/page-size.vue |
| align | 对齐方式 | <p>通过 <code>align</code> 设置对齐方式。</p><br> | pager/align.vue |
| disabled-and-size | 禁用和尺寸 | <p>通过 <code>disabled</code> 设置分页禁用，通过 <code>size</code> 设置分页尺寸。</p><br> | pager/disabled-and-size.vue |
| custom-layout | 自定义布局和插槽 | <p>通过 <code>layout</code> 设置分页想要显示的子组件和顺序，子组件间用 <code>,</code> 分隔，子组件有 <code>total</code> 总条数、 <code>sizes</code> 分页大小、 <code>prev</code> 上一页、 <code>pager</code> 页码、 <code>next</code> 下一页、 <code>slot</code> 默认插槽、 <code>jumper</code> 页跳转、 <code>current</code> 当前页。</p><br> | pager/custom-layout.vue |
| pager-mode | 分页模式 | <p>通过 <code>mode</code> 设置分页组件组件渲染模式，不同模式是组件内置的 <code>layout</code> 设置， <code>mode</code> 优先级高于 <code>layout</code> 。</p><br> | pager/pager-mode.vue |
| page-count | 总页数 | <p>通过 <code>page-count</code> 设置总页数。</p><br> | pager/page-count.vue |
| popper-append-to-body | 分页下拉框显示位置 | <p>通过 <code>popper-append-to-body</code> 设置分页下拉框元素是否追加到 body 元素节点下。</p> | pager/popper-append-to-body.vue |
| popper-class | 自定义分页下拉框的类名 | <p>通过 <code>popper-class</code> 添加自定义分页下拉框的类名。</p> | pager/popper-class.vue |
| custom-total | 自定义总条数 | <p>通过 <code>custom-total</code> 设置分页总条数显示文本。传值为文本则显示传入的文本，传值为 <code>true</code> 时，<code>0 ～ 99999</code> 显示具体数值， <code>100000 ～ 999999</code> 显示 <code>10 万+</code> 。<code>1000000 ～ 9999999</code> 显示 <code>100 万+</code> 。超过 <code>10000000</code> 显示 <code>1 千万+</code></p> | pager/custom-total.vue |
| show-total-loading | 总条数加载中 | <p>通过 <code>show-total-loading</code> 设置总条数是否加载中。</p> | pager/show-total-loading.vue |
| pager-count | 页码按钮数量 | <p>通过 <code>pager-count</code> 设置页码数量。</p><br> | pager/pager-count.vue |
| hide-on-single-page | 单页时隐藏 | <p>通过 <code>hide-on-single-page</code> 设置当仅有一页时是否隐藏分页组件。</p><br> | pager/hide-on-single-page.vue |
| custom-next-prev-text | 自定义上下页按钮文本 | <p>通过 <code>prev-text</code> , <code>next-text</code> 自定义上下页按钮文本。</p><br> | pager/custom-next-prev-text.vue |
| pager-in-grid | 表格分页 | <p>Grid 表格使用分页组件，该示例中的 <code>services/getGridMockData</code> 服务需要自行实现，示例模拟了远程服务返回的数据。</p><br> | pager/pager-in-grid.vue |
| before-page-change | 分页变更前置处理 | <p>通过 <code>is-before-page-change</code> 开启前置处理特性，翻页或者改变页大小时会触发 <code>before-page-change</code> 事件。调用传参中的 <code>callback</code> 继续变更，调用 <code>rollback</code> 中止变更。</p><br> | pager/before-page-change.vue |
| pager-event | 事件 | <br>        <p> <br>          当前所在页改变后会触发 <code>current-change</code> 事件。<br /><br>          每页展示条目数改变后会触发 <code>size-change</code> 事件。<br /><br>          点击上一页按钮改变当前页后触发 <code>prev-click</code> 事件、下一页触发 <code>next-click</code> 事件。<br /><br>          当在最后一页切换每页条目数时会同时触发 <code>current-change</code> 、<code>size-change</code> 两个事件，如果两个事件调用同一函数（比如后台拉取数据），则需要则做防抖处理。<br /><br>          默认情况下，当手动改变 <code>current-page</code> 或 <code>page-size</code> 的值时，不会触发对应的change事件，设置 <code>change-compat</code> 为 <code>true</code> 以触发对应事件。<br>        </p> | pager/pager-event.vue |
