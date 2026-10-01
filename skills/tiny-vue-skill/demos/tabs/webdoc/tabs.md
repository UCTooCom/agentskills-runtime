# tabs Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <div class="tip custom-block"><code>Tabs</code> ：通过 v-model 设置选中的页签项，对应 TabItem 页签项中 name 属性的值；<br /><br>        <code>TabItem</code> ：通过 title 设置页签项标题，name 设置页签项的值，disabled 设置页签项禁用，默认插槽自定义对应的内容。</div> | tabs/basic-usage.vue |
| tab-style-card | card 类型 | 通过 <code>tab-style="card"</code> 设置风格类型为 <code>card</code> ， <code>active-name</code> 设置初始选中的页签项。 | tabs/tab-style-card.vue |
| tab-style-bordercard | bordercard 类型 | 通过 <code>tab-style="border-card"</code> 设置风格类型为 <code>bordercard</code>， <code>size="small"</code> 设置小尺寸类型。 | tabs/tab-style-bordercard.vue |
| tabs-separator | 分隔符 | <p>通过 <code>separator</code> 设置分隔符。</p><br> | tabs/tabs-separator.vue |
| size | 尺寸 | <p>通过 <code>size</code> 改变尺寸。</p><br> | tabs/size.vue |
| custom-more-icon | 定义'更多'按钮 | 通过 <code>show-more-tabs</code> 设置页签项超出时显示 <code>更多</code> 按钮； <code>moreIcon</code> 插槽自定义 <code>更多</code> 按钮； <code>popper-class</code> 给“更多”下拉框添加自定义类名，可用来自定义样式。 | tabs/custom-more-icon.vue |
| with-add | 添加功能 | 通过 <code>with-add</code> 打开添加按钮，并监听 <code>add</code> 事件自定义实现添加页签项的逻辑。 | tabs/with-add.vue |
| tabs-events-close | 删除 | 通过 <code>with-close</code> 打开关闭按钮，并监听 <code>close</code> 事件自定义实现删除页签项的逻辑。<br>          <code>beforeClose</code> 设置删除前的操作，返回为 false 则取消删除，反之则执行删除。 | tabs/tabs-events-close.vue |
| position | 位置 | 通过 <code>position</code> 设置显示位置，可选值有 <code>top</code> 、 <code>right</code> 、 <code>bottom</code> 、 <code>left</code> ，默认为 <code>top</code> 。 | tabs/position.vue |
| tooltip | 提示 | 通过 <code>tooltip-config</code> 设置 Title 提示。 | tabs/tooltip.vue |
| before-leave | 阻止切换 | 通过 <code>before-leave</code> 钩子函数处理切换页签项前的逻辑，若返回是 <code>false</code> 或 <code>Promise.reject</code> ，则阻止切换，返回 true 则可以切换。 | tabs/before-leave.vue |
| stretch-wh | 自动撑宽 | 通过 <code>stretch</code> 设置页签项的宽度是否自撑开，默认为 false。 | tabs/stretch-wh.vue |
| more-show-all | 超长数据下拉展示 | 通过 <code>more-show-all</code> 设置下拉面板展示全部页签项，<code>panel-max-height</code> 设置面板最大高度； <code>panel-width</code> 设置面板宽度。 | tabs/more-show-all.vue |
| custom-tab-title | 定义页签项标题 | 通过 <code>TabItem</code> 的 <code>title</code> 插槽自定义页签项标题，比如在标题前增加图标。 | tabs/custom-tab-title.vue |
| lazy | 懒加载 | 通过 <code>lazy</code> 设置页签项内容懒加载，默认值为 <code>false</code> 。 | tabs/lazy.vue |
| tabs-second-layer | 多层级 | 通过嵌套使用即可。 | tabs/tabs-second-layer.vue |
| show-different-grid-data | 与 Grid 结合 | Grid 组件需要设置 <code>:auto-resize="true"</code> ，自适应父元素 <code>TabItem</code> 相应变化。 | tabs/show-different-grid-data.vue |
| tabs-draggable | 拖拽 | <div class="tip custom-block"><p><code>drop-config</code> 设置 <code>Sortable</code> 排序插件；<br/><br>          <code>tab-drag-start</code> 监听拖拽开始事件；<br/><br>          <code>tab-drag-over</code> 监听拖拽中事件；<br/><br>          <code>tab-drag-end</code> 监听拖拽结束事件，以此改变页签项顺序。</p></div> | tabs/tabs-draggable.vue |
| tabs-events-click | 点击事件 | 通过 <code>click</code> 监听单击页签项事件。 | tabs/tabs-events-click.vue |
| tabs-events-edit | 编辑事件 | 通过 <code>editable</code> 设置同时显示 <code>删除</code> 和 <code>添加</code> 按钮， <code>edit</code> 监听这两类按钮的点击事件。 | tabs/tabs-events-edit.vue |
| overflow-title | 超出显示 tooltip | 通过 <code>overflow-title</code> 设置标题超出一定长度（默认 256px）时隐藏并显示...，鼠标移到标题上可显示 tooltip，<code>title-width</code>设置标题超出的长度。 | tabs/overflow-title.vue |
| header-only | 仅展示头部 | 通过 <code>header-only</code> 仅展示头部。 | tabs/header-only.vue |
