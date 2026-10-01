# grid-select Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本下拉表格 | <p>通过 <code>grid-op</code> 设置表格列与数据，<code>v-model</code> 绑定选中值。</p> | grid-select/basic-usage.vue |
| config | 禁用选项 | <p>通过 <code>radio-config</code> / <code>select-config</code> 的 <code>checkMethod</code> 控制某些行不可选，并支持 <code>trigger: row</code> 开启整行点击。</p> | grid-select/config.vue |
| remote | 远程搜索 | <p>配合 <code>remote</code>、<code>remote-method</code> 与 <code>reserve-keyword</code> 实现远程搜索，并分别展示单选与多选场景。</p> | grid-select/remote.vue |
| init-query | 表格初始化查询 | <p>利用 <code>init-query</code> 在远程模式下初始化表格数据，并展示单选与多选的默认值回显。</p> | grid-select/init-query.vue |
| extra-query-params | 表格初始化查询传参 | <p>通过 <code>extra-query-params</code> 将父级选择结果传递给子级下拉表格，实现级联查询与选项联动。</p> | grid-select/extra-query-params.vue |
| radio-bigdata | 下拉表格大数据 | <p>一次性加载数百条记录，结合 Grid 的虚拟滚动仍可保持顺畅的选择体验。</p> | grid-select/radio-bigdata.vue |
