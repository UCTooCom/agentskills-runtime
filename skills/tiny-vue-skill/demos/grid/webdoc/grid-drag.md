# grid Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| drag-row-drag | 行拖拽 | <p>通过设置 <code>drop-config</code> 的 <code>row</code> 属性控制行拖拽，默认为开启行拖拽，行拖拽事件有 <code>@row-drop-start</code>、<code>row-drop-move</code>、<code>row-drop-end</code>。可以通过设置 <code>dropConfig.rowHandle</code> 为 <code>'index'</code> 开启序号列作为拖拽区域，不影响行字段的复制。</p> | grid/drag/row-drag.vue |
| drag-row-drag-ctrl | 拖拽控制 | <p>通过设置 <code>drop-config</code> 的 <code>onBeforeMove</code> 事件控制行拖动，配置<code>drop-config</code> 的 <code>trigger</code> 来指定拖拽的触发源（一般是 <code>class</code> 类名），也可以配置<code>drop-config</code> 的 <code>filter</code> 与自定义样式结合使用来限制拖动。</p><br> | grid/drag/row-drag-ctrl.vue |
| drag-column-drag | 列拖拽 | <p>通过设置 <code>drop-config</code> 的 <code>column</code> 属性控制列拖拽，默认为开启列拖拽，列拖拽事件有 <code>@column-drop-start</code>、<code>column-drop-move</code>、<code>column-drop-end</code>。</p><br> | grid/drag/column-drag.vue |
| multi-header-drag | 多级表头拖拽 | <p>设置表格属性 <code>columnKey</code> 和 <code>dropConfig</code>。在设置 <code>dropConfig.scheme</code> 为 v2 且设置 <code>dropConfig.column</code> 为 <code>true</code> 时，开启多表头列拖拽。<br>          其它属性 <code>dropConfig.columnGroup</code>，<code>dropConfig.columnBeforeDrop</code> 和 <code>dropConfig.columnDropClass</code>，参考示例配置：</p><br> | grid/drag/multi-header-drag.vue |
