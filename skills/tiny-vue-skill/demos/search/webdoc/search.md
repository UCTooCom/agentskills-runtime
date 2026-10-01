# search Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 通过 <code>v-model</code> 设置双向绑定搜索值， <code>placeholder</code> 设置默认占位符文本， <code>input</code>元素的原生属性<code>maxlength</code> 设置输入框最大输入字符长度。 | search/basic-usage.vue |
| clearable | 可清除 | 通过 <code>clearable</code> 设置显示清空图标按钮。 | search/clearable.vue |
| mini-mode | 迷你模式 | 通过 <code>mini</code> 设置为 mini 模式。 | search/mini-mode.vue |
| search-types | 搜索类型 | 通过 <code>search-types</code> 设置可选的搜索类型， <code>type-value</code> 设置搜索类型的默认值。 | search/search-types.vue |
| transparent-mode | 透明模式 | 通过 <code>transparent</code> 设置为透明模式（注： <code>mini</code> 模式下有效）。 | search/transparent-mode.vue |
| custom-search-types | 定义搜索类型下拉项 | 通过 <code>poplist</code> 插槽自定义搜索类型弹出的内容。 | search/custom-search-types.vue |
| show-selected-types | 定义默认搜索类型 | 通过 <code>text</code> 插槽自定义默认搜索类型的内容。 | search/show-selected-types.vue |
| slot-prefix-suffix | 插槽与禁用 | 通过 <code>prefix</code> 插槽自定义左侧内容，通过 <code>suffix</code> 插槽自定义右侧内容，通过 <code>disabled</code> 控制禁用状态。 | search/slot-prefix-suffix.vue |
| events | 事件 | <br>        <div class="tip custom-block">通过 <code>is-enter-search</code> 设置回车触发搜索事件， <code>search</code> 监听搜索事件；<br /><br>              <br>        通过 <code>change</code> 监听输入框失焦时搜索值改变事件，<code>input</code> 监听搜索值实时改变事件；<br /><br>              <br>        通过 <code>select</code> 监听搜索类型选中事件；<br /><br>                <br>        通过 <code>expand</code> 监听 mini 搜索框展开事件；<br /><br>                <br>        通过 <code>collapse</code> 监听 mini 搜索框收起事件。</div> | search/events.vue |
