# steps Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| line-horizontal | 横向单链型 | <p>通过添加 <code>line</code> 用作横向单链型步骤条，<code>visible-num</code> 控制信息可见的节点数。</p> | steps/line-horizontal.vue |
| line-vertical | 垂直单链型 | <p>使用 <code>line</code> 与 <code>vertical</code> 设置为条形步骤条。</p><br> | steps/line-vertical.vue |
| line-dot | 垂直点状型 | <p>使用 <code>dot</code> 与 <code>vertical</code> 设置为垂直点状形。</p><br> | steps/line-dot.vue |
| advanced-steps | 条形步骤条 | <p>默认显示为条形步骤条。</p><br> | steps/advanced-steps.vue |
| content-center | 内容居中 | <p>添加 <code>content-center</code> 使步骤条内容默认居中显示。</p> | steps/content-center.vue |
| size | 尺寸 | <p>步骤条两种模式支持 <code>size</code> 设置尺寸：</p><br>        <p>1. <code>line</code> 单链型模式支持 <code>mini</code>、<code>small</code>、<code>medium</code>、<code>large</code> 4 种尺寸，默认值为 <code>medium</code>。</p><br>        <p>2. <code>advanced</code> 高级向导模式支持 <code>medium</code>、<code>large</code> 2 种尺寸，默认值为 <code>medium</code>。</p> | steps/size.vue |
| node-width | 节点宽度 | <p>使用 <code>space</code> 配置步骤条节点的宽度。</p><p>通过 <code>flex</code> 开启总宽度自适应，节点等宽，撑满父容器，节点名称超出省略。</p> | steps/node-width.vue |
| duration | 节点滚动时间 | <p>通过 <code>duration</code> 设置节点左右滚动的持续时间，默认值为 300（单位 ms），设置 0 则无滚动动画，仅开启 advanced 高级向导模式有效。</p> | steps/duration.vue |
| custom-steps-item | 自定义字段 | <p>可以通过以下属性自定义数据项字段：<br /><code>name-field</code>：设置节点信息中名称对应的字段名，默认为 'name'  <br /><code>count-field</code>：设置条形步骤条里徽标计数对应的字段名，默认为 'count' 。<br /><code>status-field</code>：设置数据状态对应的字段名，默认为 'status' 。</p><br> | steps/custom-steps-item.vue |
| slot-icon | 图标插槽 | <p>通过插槽 <code>icon</code> 自定义单链型节点图标。</p><br> | steps/slot-icon.vue |
| slot-item | item 插槽 | <p>通过插槽 <code>item</code> 自定义节点内容。</p><br> | steps/slot-item.vue |
| slot-item-footer | itemFooter 插槽 | <p>通过插槽 <code>itemFooter</code> 自定义节点底部内容为链接按钮。</p> | steps/slot-item-footer.vue |
| click | 点击事件 | <p>点击节点时触发 <code>click</code> 事件。</p><br> | steps/click.vue |
