# time-line Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>通过 <code>data</code> 属性设置时间线的节点数据；<code>active</code> 属性设置当前节点，<code>click</code> 监听单节点的点击事件。</p><br> | time-line/basic-usage.vue |
| timeline-item | 时间线节点组件 | <p>通过时间线节点组件 <code>timeline-item</code> 自定义单个节点的属性、事件和插槽。</p><br> | time-line/timeline-item.vue |
| vertical-timeline | 竖向时间线 | <p>通过 <code>vertical</code> 属性设置为竖直方向时间线，<code>reverse</code> 设置是否逆序展示数据。</p><br> | time-line/vertical-timeline.vue |
| status | 节点状态 | <p>通过指定时间线节点的 <code>autoColor</code> 或 <code>type</code> 属性指定其状态；同时 <code>disabled</code> 属性可设置是否禁用。</p> | time-line/status.vue |
| text-position | 节点名称位置 | <p>通过 <code>text-position</code> 属性设置节点名称位置，仅适用于横向时间线。</p> | time-line/text-position.vue |
| shape | 圆点外观 | <p>通过 <code>shape</code> 属性设置竖向时间线节点的外观风格。</p> | time-line/shape.vue |
| set-node-width | 宽度 | <p>通过 <code>space</code> 属性设置节点的宽度。</p><br> | time-line/set-node-width.vue |
| custom-icon | 自定义图标 | <p>通过 <code>auto-color</code> 属性可自定义节点图标。</p> | time-line/custom-icon.vue |
| custom-field | 自定义字段 | <p>通过 <code>name-field</code> 属性设置节点信息中名称对应的字段名；<code>time-field</code> 属性设置节点时间信息对应的字段名；<code>auto-color-field</code> 属性设置节点图标对应的字段名。</p> | time-line/custom-field.vue |
| set-start-value | 序号起始值 | <p>通过 <code>start</code> 属性设置时间线序号起始值。</p><br> | time-line/set-start-value.vue |
| show-divider | 底部指示三角 | 通过 <code>show-divider</code> 属性设置是否显示底部的指示三角，仅当节点文本内容位于序号右边时生效。 | time-line/show-divider.vue |
| custom-horizontal-timeline | 自定义横向时间线 | <p>通过 <code>top</code> 插槽可以自定义时间线顶部内容，<code>bottom</code> 插槽自定义时间线底部内容。</p><br> | time-line/custom-horizontal-timeline.vue |
| custom-vertical-timeline | 自定义竖向时间线 | <p>通过 <code>left</code> 插槽自定义时间线左侧内容，<code>right</code> 插槽自定义时间线右侧内容。</p><br> | time-line/custom-vertical-timeline.vue |
| slot-description | 节点描述插槽 | <p>通过 <code>description</code> 插槽添加单个节点的描述信息。</p> | time-line/slot-description.vue |
| slot-default | 默认插槽 | 组件默认插槽 | time-line/slot-default.vue |
