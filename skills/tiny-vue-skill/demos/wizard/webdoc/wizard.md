# wizard Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 通过 <code>data</code> 设置流程节点信息，如：设置节点名称和状态；<code>node-click</code> 监听节点点击事件。 | wizard/basic-usage.vue |
| page-guide | 页向导模式 | 通过 <code>page-guide</code> 设置页向导模式，包含流程图区域、页面展示区域、功能按钮区域，用于导航当前页面与上一页面、下一页面的前后关系。 | wizard/page-guide.vue |
| vertical | 垂直模式 | 通过 <code>vertical</code> 设置垂直模式，竖向显示流程节点信息及节点间关系，节点信息包含节点名称、内容、状态、完成时间。 | wizard/vertical.vue |
| time-line-flow | 时间线 | 通过 <code>time-line-flow</code> 设置时间线，以时间点的方式竖向显示流程节点处理信息，包含节点名称、状态、完成时间、用户信息。 | wizard/time-line-flow.vue |
| slot-base | 基本插槽 | 通过 <code>base</code> 作用域插槽自定义节点的名称。 | wizard/slot-base.vue |
| slot-step-button | 步骤插槽 | 通过 <code>stepbutton</code> 插槽自定义页向导模式的步骤按钮和内容。 | wizard/slot-step-button.vue |
| btn-events | 按钮事件 | 页向导模式下：通过 <code>btn-prev</code> 监听"上一步"按钮点击事件；<br /> <br>        <code>btn-next</code> 监听"下一步"按钮点击事件；<br /><br>        <code>btn-save</code> 监听"保存"按钮点击事件；<br /><br>        <code>btn-submit</code> 监听"提交"按钮点击事件，流程需要走到最后一步才会显示此按钮。<br /> | wizard/btn-events.vue |
