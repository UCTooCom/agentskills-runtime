# milestone Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 通过 <code>data</code> 设置每个节点的标题、日期、和状态； <code>milestones-status</code> 设置每种状态对应的颜色值；前者的 <code>status</code> 字段对应后者的键值。 | milestone/basic-usage.vue |
| flag-before | 旗子数据来源 | 通过 <code>flag-before</code> 设置旗子的数据来源，是来自前面还是后面的节点，默认为 <code>false</code> 取后面节点上的数据。 | milestone/flag-before.vue |
| line-style | 线条颜色和间距 | 通过 <code>line-style</code> 设置线条颜色， <code>space</code> 设置节点间距。 | milestone/line-style.vue |
| show-number | 序号 | 通过 <code>show-number</code> 设置未完成状态的节点是否显示序号；默认为 <code>true</code> 显示； <code>start</code> 设置节点的序号起始值，默认为 <code>-1</code> 。 | milestone/show-number.vue |
| solid-style | 实心显示 | 通过 <code>solid</code> 设置已完成状态的节点是否实心显示，实心显示则光晕不透明；默认为 <code>false</code> 不显示。 | milestone/solid-style.vue |
| data-field-mapping | 数据字段映射 | <br>          <div class="tip custom-block"><p class="custom-block-title"><br>          自定义 <code>data</code> 属性的键名和键值：<br/> </p><br>          <code>completed-field</code> 设置完成状态对应的键值，默认为 <code>completed</code> ；<br/><br>          <code>flag-field</code> 设置旗子信息数组对应的键名，默认为 <code>flags</code> ；<br/><br>          <code>flag-content-field</code> 设置旗子描述对应的键名，默认为 <code>content</code> ；<br/><br>          <code>flag-name-field</code> 设置旗子标题对应的键名，默认为 <code>name</code> ；<br/><br>          <code>flag-status-field</code> 设置旗子状态对应的键名，默认为 <code>status</code> ；<br/><br>          <code>name-field</code> 设置节点名称对应的键名，默认为 <code>name</code> ；<br/><br>          <code>status-field</code> 设置节点状态对应的键名，默认为 <code>status</code> ；<br/><br>          <code>time-field</code> 设置节点时间对应的键名，默认为 <code>time</code> 。</div> | milestone/data-field-mapping.vue |
| custom-icon-slot | 定义图标 | 通过 <code>icon</code> 作用域插槽自定义节点的图标。 | milestone/custom-icon-slot.vue |
| custom-bottom-top | 定义上下方内容 | 通过 <code>bottom</code> 作用域插槽自定义节点下方的内容；<br/> 通过 <code>top</code> 作用域插槽自定义节点上方的内容。 | milestone/custom-bottom-top.vue |
| custom-flag | 定义旗帜内容 | 通过 <code>flag</code> 作用域插槽自定义节点旗子的内容。 | milestone/custom-flag.vue |
| milestone-events | 事件 | 通过 <code>click</code> 监听单击节点事件， <code>flag-click</code> 监听单击旗子事件。 | milestone/milestone-events.vue |
