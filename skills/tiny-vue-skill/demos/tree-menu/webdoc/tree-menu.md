# tree-menu Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>通过 <code>data</code> 属性设置静态数据。</p><br> | tree-menu/basic-usage.vue |
| data-resource | 服务端数据 | <p>通过 <code>get-menu-data-sync</code> 设置服务端数据，直接返回数据源。</p><br> | tree-menu/data-resource.vue |
| current-node | 当前节点 | <p>通过 <code>setCurrentKey</code> 或 <code>setCurrentNode</code>方法设置当前节点，结合 <code>default-expanded-keys</code> 属性设置展开当前节点。<code>getCurrentKey</code> 方法获取当前节点的唯一标识， <code>getCurrentNode</code> 方法获取当前节点的数据。</p> | tree-menu/current-node.vue |
| text-ellipsis | 文字超长 | <p>通过 <code>ellipsis</code> 属性设置菜单文字过长时显示成省略号，<code>wrap</code> 属性设置文字过长换行显示。</p><br> | tree-menu/text-ellipsis.vue |
| default-expanded-keys | 默认展开 | <p>通过 <code>default-expanded-keys</code> 设置初始化时默认展开某一节点。</p><br> | tree-menu/default-expanded-keys.vue |
| default-expanded-keys-highlight | 默认高亮 | <p>通过 <code>default-expanded-keys-highlight</code> 属性设置已展开的节点高亮，配合 <code>default-expanded-keys</code> 属性使用。</p> | tree-menu/default-expanded-keys-highlight.vue |
| default-expand-all | 默认全部展开 | <p>通过 <code>default-expand-all</code> 属性设置初始化时展开全部菜单。</p><br> | tree-menu/default-expand-all.vue |
| show-checkbox | 可勾选 | <p>通过 <code>show-checkbox</code> 属性设置节点是否可勾选。<code>check-strictly</code> 属性设置可勾选节点的父级和子级是否相关联。<code>default-checked-keys</code> 属性设置默认勾选的节点，注意配合 <code>node-key</code> 属性同时使用。</p><br> | tree-menu/show-checkbox.vue |
| draggable | 可拖拽 | <p>通过 <code>draggable</code> 属性启用拖拽节点的功能。</p><br> | tree-menu/draggable.vue |
| menu-collapsible | 侧边折叠按钮 | <p>通过 <code>menu-collapsible</code> 属性设置是否可以折叠。侧边显示折叠按钮。</p><br> | tree-menu/menu-collapsible.vue |
| show-expand | 底部折叠按钮 | <p>通过 <code>show-expand</code> 属性设置是否可以折叠。底部显示折叠按钮。注意：配合 <code>customIcon</code> 属性定义节点图标使用，纯文本菜单不支持此功能。</p><br> | tree-menu/show-expand.vue |
| custom-icon | 自定义图标 | <p>通过 <code>search-icon</code> 属性设置自定义搜索图标。</p><br> <p>通过 <code>suffix-icon</code> 属性全局设置带图标树形菜单。</p><br> | tree-menu/custom-icon.vue |
| props | 字段映射 | <p>通过 <code>props</code> 属性设置字段映射。 </p><br> | tree-menu/props.vue |
| empty-text | 空数据文本 | <p>通过 <code>empty-text</code> 属性配置空数据显示文本。</p><br> | tree-menu/empty-text.vue |
| show-number | 显示数字 | <p>通过 <code>show-number</code> 属性设置是否将右侧下拉图标区域显示为 number 属性配置的数字内容，建议不超过 4 个字符。<code>collapsible</code> 属性设置是否允许展开后的节点收起，未和 <code>show-number</code> 配套使用时可点击图标收起。<code>node-height</code> 属性设置节点的高度。</p><br> | tree-menu/show-number.vue |
| lazy-load | 懒加载 | <p>通过 <code>lazy</code> 启用懒加载，并用 <code>load</code> 属性定义懒加载子节点的方法。</p><br> | tree-menu/lazy-load.vue |
| show-filter | 节点过滤 | <p>通过 <code>show-filter</code> 属性设置是否显示搜索框， <code> highlight-query </code> 属性设置是否在匹配的节点中高亮搜索文字 ,<code>show-title</code> 属性设置节点是否有原生 title 属性提示。</p><br> | tree-menu/show-filter.vue |
| filter-node-method | 节点过滤规则 | <p>通过 <code>filter-node-method</code> 属性自定义搜索的方法，默认为模糊匹配，以下示例是精确配置。</p><br> | tree-menu/filter-node-method.vue |
| only-check-children | 父级只能展开 | <p>通过 <code>only-check-children</code> 属性设置父级不可选，只能展开/收起，不能跳转。 </p><br> | tree-menu/only-check-children.vue |
| expand-on-click-node | 点击节点即展开 | <p>通过 <code>expand-on-click-node</code> 属性设置是否能点击节点即展开/收起。配置为 fasle 则只能点击下拉图标展开/收起。 </p><br> | tree-menu/expand-on-click-node.vue |
| indent | 水平缩进 | <p>通过 <code>indent</code> 属性设置子级相对于父级菜单的水平缩进距离，单位 px。</p><br> | tree-menu/indent.vue |
| accordion | 手风琴 | <p>通过 <code>accordion</code> 属性设置手风琴效果（只能展开一个同级别的节点）。</p><br> | tree-menu/accordion.vue |
| tree-menu-slot | 插槽 | <p>通过默认插槽 <code>#default</code> 自定义节点内容。</p><br> | tree-menu/tree-menu-slot.vue |
| with-icon | 节点配置带图标 | <p>通过在 <code>data</code> 里面配置 <code>customIcon</code> 属性进行图标组件传值，设置带图标树形菜单。</p><br> | tree-menu/with-icon.vue |
| event-allow-draggable | 拖拽事件 | <div class="tip custom-block"><p class="custom-block-title">事件说明</p><br><p>node-drag-start：监听节点开始拖拽的事件。</p><br><p>node-drag-end：监听节点结束拖拽的事件。</p><br><p>allow-drag：自定义节点是否允许拖拽的方法。</p><br><p>allow-drop：自定义节点是否允许放置到某节点的方法。</p><br></div><br> | tree-menu/event-allow-draggable.vue |
| events | 事件 | <div class="tip custom-block"><p class="custom-block-title">事件说明</p><br><p>node-click：监听节点被点击时的事件。</p><br><p>current-change：监听当前选中节点发生变化的事件。</p><br><p>node-expand：监听节点展开的事件。</p><br><p>node-collapse：监听节点收起的事件。</p><br><p>check-change：可勾选时，监听勾选节点变化的事件。</p><br><p>input-change：输入框输入值时触发的事件。</p></div><br> | tree-menu/events.vue |
| clearable | 搜索框是否可清空 | 通过设置<code>clearable</code>属性来标明是否允许显示搜索框清空按钮 | tree-menu/clearable.vue |
| width-adapt | 宽度自适应 | 通过 <code> widthAdapt </code> 属性，是否让组件宽度自适应父容器。默认为 <code> false </code> | tree-menu/width-adapt.vue |
