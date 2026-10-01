# grid Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| large-data-virtual-rolling | 虚拟滚动 | <br>        <p>虚拟滚动配置步骤：1、表格属性设置 <code>height</code> 固定高度；2、表格属性设置 <code>optimization</code> 开启虚拟滚动。</p><br>        <div class="tip custom-block"><br>          <p class="custom-block-title">optimization(object) 配置说明：</p><br>          <ul><br>            <li><code>delayHover</code>：当表格发生拖动、滚动...等行为时，至少多少毫秒之后才允许触发 hover 事件 默认 250ms</li><br>            <li><code>scrollX</code>：横向 X 虚拟滚动配置（用于特殊场景手动调优）例如：{ gt: 100 }</li><br>            <li><code>scrollY</code>：纵向 Y 虚拟滚动配置（用于特殊场景手动调优）例如：{ gt: 500 }</li><br>          </ul><br>        </div><br>        <div class="tip custom-block"><br>          <p class="custom-block-title">开启虚拟滚动注意事项</p><br>          <p>1、开启虚拟滚动的前提是需要保证每列的宽度一样，可以通过在 <code>&lt;tiny-grid&gt;</code> 标签上的 <code>column-width</code> 属性配置统一的宽度。<br>2、开启虚拟滚动将会禁用列宽调整功能，因为列拖拽会改变列宽度，导致虚拟滚动渲染的列数计算有误从而引起表格样式错乱，所以禁止列拖拽。</p><br><br>        </div><br>       | grid/large-data/virtual-rolling.vue |
| large-data-grid-large-tree-data | 树表虚拟滚动 | <br>        <p>通过 <code>optimization</code> 属性配置树表虚拟滚动执行方式，具体参考类型：<code>IOptimizationConfig</code> 。</p> <br>         | grid/large-data/grid-large-tree-data.vue |
| large-data-full-data-loading | 全量加载 | <p>当表格数据过多时会有性能问题，用户可通过 <code>$refs</code> 获取表格对象，设置表格对象的 <code>loadData</code> 方法启用全量加载来优化性能。</p><br> | grid/large-data/full-data-loading.vue |
| large-data-load-column | 生成 1000 列 | <p>通过 <code>loadColumn(columns)</code> 方法可以加载列配置，对于需要重新加载列的场景下可能会用到。</p><br> | grid/large-data/load-column.vue |
| large-data-scroll-to | 滚动到指定位置 | <div class="tip custom-block"><p class="custom-block-title">方法说明</p><br><p> <code>scrollTo(scrollLeft, scrollTop)</code>：滚动到对应的位置<br><code>scrollToRow(row)</code>：滚动到对应的行<br><code>scrollToColumn(column)</code>：手滚动到对应的列。</p><br></div><br> | grid/large-data/scroll-to.vue |
| large-data-column-anchor | 表格列锚点 | <p>通过 <code>column-anchor</code> 设置表格列锚点，点击可快速滚动至对应列，表格初始化时，默认滚动到锚点第一项。</p> | grid/large-data/column-anchor.vue |
| column-anchor-clear-active | 再次加载数据时清除活跃列锚点 | <p>当使用 <code>fetch-data</code> 加载数据时，再次加载数据时会清除活跃列锚点。</p> | grid/large-data/column-anchor-clear-active.vue |
