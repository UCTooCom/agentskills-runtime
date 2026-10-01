# grid Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| size-fixed-column-width | 列属性宽度 | <p>表格列属性设置 width 固定宽度，支持数值和百分比。</p><br> | grid/size/fixed-column-width.vue |
| size-column-min-width | 总体列宽 | <p>通过属性 <code>column-min-width</code> 设置总体列可以调整到的最小宽度，不设置时默认 72。<br></p><br> | grid/size/column-min-width.vue |
| size-min-width | 本列最小宽度 | <p>通过表格列属性 <code>min-width</code> 设置本列最小宽度；会自动将剩余空间按比例分配。<br></p><br> | grid/size/min-width.vue |
| size-column-width | 所有列宽度 | <p>通过属性 <code>column-width</code> 设置所有列宽度，默认值为均匀分配。<br></p><br> | grid/size/column-width.vue |
| size-fixed-grid-height | 表格属性高度 | <p>表格属性设置 height 固定表格高度。</p><br> | grid/size/fixed-grid-height.vue |
| size-max-min-grid-height | 最大、最小高度 | <p>表格属性设置 minHeight 限制最小高度，maxHeight 限制最大高度。</p><br> | grid/size/max-min-grid-height.vue |
| size-auto-height | 开启响应式表格宽高 | <p>表格属性设置 autoResize 属性开启响应式表格宽高的同时，将高度<code>height</code>设置为<code>auto</code>就可以自动跟随父容器高度。tips:在自动高度场景，请确保表格或其父容器被设置了一个固定的高度。</p><br> | grid/size/auto-height.vue |
| size-resize-column-width | 开启列宽拖拽 | <p>列宽拖拽默认开启，如需禁用需要设置 <code>resizable</code> 为 <code>false</code>。</p><br> | grid/size/resize-column-width.vue |
| size-resize-operation-column-width | 操作列开启列宽拖拽 | <p>列属性 <code>type</code> 为 <code>index</code>, <code>radio</code>, <code>selection</code> 的列默认不可拖动列宽。可以通过表格属性 <code>operation-column-resizable</code> 开启列宽拖拽，默认值是 <code>false</code>。</p><br> | grid/size/resize-operation-column-width.vue |
| size-resizable-config | 列宽拖拽配置 | <p>通过 <code>resizable-config</code> 的 <code>limit</code>, 对拖拽中的列宽加以限制，可控制每列最大最小可拖拽宽度。</p><br> | grid/size/grid-resizable-config.vue |
| size-adaptive-column-width | 列宽自适应撑开 | <p>表格属性设置 fit 自动撑开，默认值为 true 开启自适应撑开，值为 false 时必须设置列宽度，否则表格宽度由单元格内容撑开。</p><br> | grid/size/adaptive-column-width.vue |
| size-recalculate | 重新计算表格 | <p>通过 <code>recalculate()</code> 方法可以重新计算表格，当父容器宽度变化时可通过该方法重新计算表格。</p><br> | grid/size/recalculate.vue |
| size-grid-size | 尺寸 | <p>表格设置 <code>size</code> 属性调整表格尺寸大小。</p><br> | grid/size/grid-size.vue |
