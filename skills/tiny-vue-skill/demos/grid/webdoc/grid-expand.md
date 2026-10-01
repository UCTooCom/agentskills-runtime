# grid Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| expand-has-row-expand | 展开行 | <br>        <p>在 <code>column</code> 标签上配置 <code>type=&quot;expand&quot</code>; 展开行，可以通过 <code>v-slot</code> 插槽插入需要的模板信息</p><br>        <p>通过调用 <code>hasRowExpand(row)</code> 方法可以检查行是否已展开，参数 <code>row</code> 为行数据对象。</p><br>         | grid/expand/has-row-expand.vue |
| expand-trigger-slot | 展开行触发器插槽 | <br>        <p>通过 <code>expand-trigger</code> 插槽可以自定义展开行图标。</p><br>         | grid/expand/expand-trigger-slot.vue |
| expand-expand-config | 展开行配置项 | <br>        <p>表格属性 <code>expand-config</code> 设置展开行配置项。</p><br>        <p>表格属性 <code>expandConfig.activeMethod</code> 配置一个方法控制行是否可展开，参数为 <code>row</code> 和 <code>rowLevel</code>，返回 <code>false</code> 则此行不可展开，且不显示展开图标。</p><br>        <p>表格属性 <code>expandConfig.showIcon</code> 配置是否显示展开图标，默认为 <code>true</code> 表示显示展开图标。<br>         | grid/expand/expand-config.vue |
| expand-nested-grid | 嵌套表格 | <p>通过在默认插槽 <code>default</code>中使用表格组件，实现嵌套表格功能。</p><br> | grid/expand/nested-grid.vue |
| expand-set-row-expansion | 展开行手动操作 | <br>          <p>通过调用 <code>setRowExpansion(rows, checked)</code> 方法可设置展开指定行，第二个参数设置这一行展开与否，展开指定行时，通过调用 clearRowExpand() 方法先，关闭已展开的行。</p><br>          <p>通过调用 <code>setAllRowExpansion(checked)</code> 方法可设置所有行的展开与否。</p><br>          <p>通过调用 <code>toggleRowExpansion(row)</code> 方法可手动切换展开行。</p><br>           | grid/expand/set-row-expansion.vue |
