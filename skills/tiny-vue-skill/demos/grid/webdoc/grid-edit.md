# grid Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| edit-editing | 编辑方式 | <br>          <p>表格属性设置 <code>edit-config</code> 开启编辑模式，然后在该属性对象内设置 <code>mode: 'cell'</code> 或者<code>mode: 'row'</code> 开启单元格编辑或者行编辑，即：<code>:edit-config=&quot;{ mode: 'cell' }&quot;</code>。<br>表格列属性设置 <code>show-icon</code> 设置列头是否显示编辑图标，在编辑时有效。</p><br>           | grid/edit/editing.vue |
| edit-revert-data | 还原更改 | <p>调用方法 <code>revertData(rows, field)</code> 可以还原指定行 row 或者整个表格的数据。rows 为对象则还原一行数据，为数组则还原多行数据，field 可不指定。不指定任何参数时则还原整个表格数据。</p><br> | grid/edit/revert-data.vue |
| edit-has-row-change | 检查数据是否改变 | <p> <code>hasRowChange(row, field)</code> 检查行或列数据是否发生改变，field 可不指定。</p><br> | grid/edit/has-row-change.vue |
| edit-trigger-mode-hm-editing | 手动触发编辑 | <p> <code>setActiveCell(row, field)</code> 方法可激活指定单元格编辑。<code>setActiveRow(row)</code> 方法激活行编辑，如果是 mode=cell 则默认激活第一个单元格。</p><br>          <p>在点击其他行或表格外部时，编辑器会自动关闭。设置 <code>editConfig.autoClear</code> 为 <code>false</code> 可以防止编辑器自动关闭。</p><br>           | grid/edit/trigger-mode-hm-editing.vue |
| edit-custom-editing | 自定义编辑规则 | <p>表格属性设置 <code>edit-config</code> 开启编辑模式，然后在该属性对象内设置 <code>activeMethod</code> 自定义编辑规则。</p><br> | grid/edit/custom-editing.vue |
| edit-editor-is-valid-always | 自定义编辑校验规则 | <p>表格属性设置 <code>edit-config</code> 开启编辑模式，并配置 <code>edit-rules</code> 对象来设置校验对象和校验规则，然后在 <code>editor</code> 对象中设置 <code>isValidAlways</code> 开启编辑实时校验。</p><br> | grid/edit/editor-is-valid-always.vue |
| edit-status-of-editing | 开启和关闭编辑状态 | <p>表格属性设置 <code>edit-config</code> 开启编辑模式，然后在该属性对象内设置 <code>showStatus</code> 开启或关闭单元格更新状态（单元格左上角倒三角形更新标识)，默认值为 <code>true</code> 开启状态。</p><br> | grid/edit/status-of-editing.vue |
| edit-grid-equals | 自定义比较方法 | <p>配置列属性 <code>equals</code> 可实现列值自定义比较。此方法接收字段原始值和当前值等作为参数，期望用户返回布尔结果。返回 <code>false</code> 表示已改变，<code>true</code> 表示未改变，其它值表示使用内部预置比较。表格也支持 <code>equals</code> 属性，用于定义所有字段的比较方法，使用参数 <code>field</code> 区分具体的字段，此方式的影响范围是整个表格，需要谨慎使用。</p> | grid/edit/grid-equals.vue |
| edit-trigger-mode-for-editing | 触发编辑方式 | <p>表格属性设置 <code>edit-config</code> 开启编辑模式，然后在该属性对象内设置 <code>trigger</code> 修改触发方式。可选值有 <code>点击触发（click）/ 双击触发（dblclick）/ 手动触发（manual）</code>，默认值为 <code>click 点击触发</code>。</p><br> | grid/edit/trigger-mode-for-editing.vue |
| scrollbar-not-blur | 行编辑滚动不失焦 | <br>          <p>配置 <code>edit-config</code> 的<code>blurOutside</code>自定义编辑态的退出逻辑。</p><br>           | grid/edit/scrollbar-not-blur.vue |
