# autocomplete Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基础用法 | <p>通过设置 <code>fetch-suggestions</code> 方法设置输入建议。</p> | autocomplete/basic-usage.vue |
| disabled | 禁用 | <p>通过 <code>disabled</code> 属性可以设置为禁用状态。</p><br> | autocomplete/disabled.vue |
| size | 尺寸 | <p>可选择值为<code>medium</code>，<code>default</code>，<code>small</code>，<code>mini</code>，不传递就是默认尺寸。</p> | autocomplete/size.vue |
| clearable | 可清除 | <p>配置 <code>clearable</code> 属性后，输入内容后会显示清除图标，单击可以清除输入框内容。</p><br> | autocomplete/clearable.vue |
| slot | 插槽 | <p>分别配置 <code>prepend</code>、<code>append</code>、<code>prefix</code>、<code>suffix</code>、<code>default</code> 插槽。</p> | autocomplete/slot.vue |
| custom-icon | 图标 | <p>配置 <code>prefix-icon</code> 和 <code>suffix-icon</code> 属性可分别自定义输入框前后置图标。</p><br> | autocomplete/custom-icon.vue |
| debounce | 去抖延时 | <p>通过 <code>debounce</code> 属性可以设置获取输入建议的去抖延时，默认值为 300 毫秒。</p><br> | autocomplete/debounce.vue |
| hide-loading | 加载图标 | <p>设置 <code>hide-loading</code> 属性为 true ,可以隐藏加载图标。</p><br> | autocomplete/hide-loading.vue |
| display-only | 只读 | <p>通过 <code> display-only </code>属性添加只读状态</p> | autocomplete/display-only.vue |
| remote-search | 远程搜索 | <p>通过 <code>fetch-suggestions</code> 属性设置远程搜索。</p><br> | autocomplete/remote-search.vue |
| value-key | 显示的键名 | <p>输入内容后，建议列表中默认显示输入建议对象中 value 键名对应的值，若对象中没有 value 键名，就可以通过 <code>value-key</code> 属性指定显示的键名。</p><br> | autocomplete/value-key.vue |
| popper-class | 列表样式 | <p><code>popper-class</code> 属性可指定一个样式类名，可自定义建议列表的样式。<br><code>popper-append-to-body</code> 属性可设置是否将下拉列表插入至 body 元素。在下拉列表的定位出现问题时，可将该属性设置为 false。</p><br> | autocomplete/popper-class.vue |
| placement | 菜单弹出位置 | <p><code>placement</code> 属性可以设置菜单弹出位置，默认为 <code>bottom-start</code>。</p><br> | autocomplete/placement.vue |
| highlight-first-item | 第一项高亮 | <p>设置 <code>highlight-first-item</code> 属性为 true ,可以突出显示远程搜索建议中的第一项。</p><br> | autocomplete/highlight-first-item.vue |
| no-trigger-on-focus | 触发 | <p>默认输入框聚焦就会显示全部的建议列表，但设置 <code>trigger-on-focus</code> 属性为 false 后只有在匹配到输入建议后才会显示匹配到的建议列表。</p><br> | autocomplete/no-trigger-on-focus.vue |
| select-event | 事件 | <p>Autocomplete 组件提供 <code>select</code> 事件，点击选中建议项时触发，回调参数为选中建议项。<br>通过 <code>select-when-unmatched</code> 设置在输入联想没有匹配值时，按 Enter 键时是否触发 select 事件，默认值为 false。</p><br> | autocomplete/select-event.vue |
