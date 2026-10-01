# grid Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| row-grouping-row-grouping | 基本用法 | <p>通过 <code>row-group</code> 属性可以配置行分组，行分组会将具有相同值的列进行分组展示。</p><br> | grid/row-grouping/row-grouping.vue |
| row-grouping-row-group-render | 自定义分组 | <br>          <p>配置 <code>rowGroup.render</code> 可以自定义渲染分组列内容。<br /><br>          配置 <code>rowGroup.renderGroupCell</code> 可以自定义渲染非分组列内容。<br /><br>          配置 <code>rowGroup.closeable</code> 可以控制分组行是否可以手动折叠。<br /><br>          配置 <code>rowGroup.activeMethod</code> 可以控制分组生成时是否默认收起。<br /><br>          配置表格事件 <code>toggle-group-change</code> 可监听分组的展开和收起。</p><br> | grid/row-grouping/row-group-render.vue |
| row-group-scroll | 分组表虚拟滚动 | <p>分组表场景适配了表格的行列虚拟滚动。</p><br> | grid/row-grouping/row-group-scroll.vue |
| row-grouping-colspan | 分组行的列合并 | <p>3.17 版本新增：配置 <code>rowGroup.colspan</code> 可以自定义分组行的列合并数量。列合并从 <code>rowGroup.field</code> 所指定的列开始合并。<br /><br>        如果 <code>rowGroup.field</code> 所指定的列不存在或不可见，就从第一个指定了 <code>field</code> 属性的列开始合并，同时 <code>rowGroup.render</code> 指定的是此列的自定义渲染。</p> | grid/row-grouping/row-grouping-colspan.vue |
