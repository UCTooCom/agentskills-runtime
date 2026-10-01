# toggle-menu Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 通过<code>:data</code>设置数据源。 | toggle-menu/basic-usage.vue |
| custom-icon | 自定义菜单左侧图标 | <p>通过 <code>icon</code> 属性自定义菜单左侧图标。</p><br> | toggle-menu/custom-icon.vue |
| get-menu-data-sync | 自定义菜单数据 | <p>通过 <code>get-menu-data-sync</code> 自定义菜单数据服务。(deprecated v3.4.0 废弃，v3.16.0 移除；移除原因：如果是同步数据则和:data 功能重复)。</p><br> | toggle-menu/get-menu-data-sync.vue |
| get-menu-data-async | 自定义菜单异步数据服务 | <p>通过 <code>get-menu-data-async</code> 自定义菜单异步数据服务。</p><br> | toggle-menu/get-menu-data-async.vue |
| toggle-props | props 选项映射 | <p>通过<code>props</code>配置选项映射字段该属性的默认值为<code>{children:'children',label:'label',disabled:'disabled'}</code>。</p><br> | toggle-menu/toggle-props.vue |
| slot-node | 自定义节点内容 | <p>通过 <code>node</code> 插槽自定义节点内容。</p><br> | toggle-menu/slot-node.vue |
| default-expand-all | 默认展开所有节点 | <p>通过 <code>default-expand-all</code> 属性设置是否默认展开所有节点，通过 <code>expand-on-click-node</code> 属性设置是否可以通过点击节点，展开/收起菜单。</p><br> | toggle-menu/default-expand-all.vue |
| draggable | 拖拽节点 | <p>通过 <code>draggable</code> 属性设置是否开启拖拽节点的功能，默认值为 <code>false</code>。<br>可通过 <code>ellipsis</code> 属性设置是否开启文本内容超长是省略显示，默认值为 <code>false</code>。</p><br> | toggle-menu/draggable.vue |
| show-filter | 显示过滤搜索框 | <p>通过 <code>show-filter</code> 属性设置是否展示过滤搜索框，默认为 <code>true</code>，可设置为<code>false</code>不展示过滤搜索框。</p><br> | toggle-menu/show-filter.vue |
| automatic-filtering | 自动过滤 | <p>通过 <code>placeholder</code> 属性设置输入框的占位符。通过设置 <code>automatic-filtering</code> 为<code>false</code>关闭输入时自动过滤功能，默认值为<code>true</code>。</p><br> | toggle-menu/automatic-filtering.vue |
| show-filter1 | 内容超出换行 | 通过<code>wrap</code>设置换行。 | toggle-menu/show-filter.vue |
| node-click | 点击节点事件 | <p>通过<code>node-click</code> 点击节点后触发的事件。</p><br> | toggle-menu/node-click.vue |
| node-expand | 展开节点事件 | <p>通过<code>node-expand</code> 展开节点后触发的事件。</p><br> | toggle-menu/node-expand.vue |
| node-collapse | 收缩节点事件 | <p>通过<code>node-collapse</code> 收缩节点后触发的事件。</p><br> | toggle-menu/node-collapse.vue |
| node-drop | 拖放节点事件 | <p>通过<code>node-drop</code> 拖放节点后触发的事件，需要设置 <code>draggable</code> 属性为 <code>true</code>。</p><br> | toggle-menu/node-drop.vue |
| drag-events | 拖拽事件 | <p>通过<code>node-drag-start</code> 拖拽节点后的事件，<code>node-drag-enter</code> 拖拽进入其他节点时触发的事件，<code>node-drag-over</code> 在拖拽节点时触发的事件，<code>node-drag-leave</code> 拖拽离开某个节点时触发的事件，<code>node-drag-end</code> 拖拽结束时触发的事件。</p><br> | toggle-menu/drag-events.vue |
