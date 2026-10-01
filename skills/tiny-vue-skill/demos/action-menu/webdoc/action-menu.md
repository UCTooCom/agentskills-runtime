# action-menu Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 使用 <code>options</code> 属性配置菜单内容，<code>label</code> 定义节点的显示文本。 | action-menu/basic-usage.vue |
| disabled | 禁用 | <p>通过 <code>disabled</code> 字段设置当前下拉选项是否为禁用状态。</p> | action-menu/disabled.vue |
| icon | 图标 | 通过 <code>icon</code> 属性设置菜单项的图标，<code>suffix-icon</code> 设置下拉触发源图标，<code>show-icon</code> 设置是否显示下拉触发源图标。 | action-menu/icon.vue |
| text-field | 映射字段 | <p>通过 <code>text-field</code> 属性设置菜单项文本的键值，默认为 label。</p> | action-menu/text-field.vue |
| more-text | 下拉按钮文本 | <p>通过 <code>more-text</code> 属性设置下拉按钮文本，默认为 <code>更多</code>。</p> | action-menu/more-text.vue |
| spacing | 间距 | <p>通过 <code>spacing</code> 属性设置菜单按钮之间的间距，默认为 <code>5px</code>。</p> | action-menu/spacing.vue |
| card-mode | 菜单模式 | <p>通过 <code>mode</code> 属性设置菜单模式以适配在不同场景中能够使用，例如：菜单按钮在卡片中使用，可以配置为 <code>card</code>，卡片模式字体为黑色，间距为 10px。  <code>mode</code> 默认为值<code>default</code>。</p> | action-menu/card-mode.vue |
| popper-class | 弹框样式 | <p>通过 <code>popper-class</code> 属性设置下拉面板的类名，自定义样式。</p> | action-menu/popper-class.vue |
| max-show-num | 个数限制 | <p>通过 <code>max-show-num</code> 属性设置最多显示菜单按钮的个数，默认为 2。</p> | action-menu/max-show-num.vue |
| slot-item | 菜单项插槽 | <p>通过 <code>item</code> 插槽自定义下拉选项的 HTML 模板。</p> | action-menu/slot-item.vue |
| events | 事件 | <div class="tip custom-block"><p class="custom-block-title">事件说明</p><br><p>item-click：监听菜单项的点击事件。</p><br><p>more-click：监听下拉按钮的点击事件。trigger 为 click 时生效。</p><br><p>visible-change：监听下拉弹框的显示或隐藏状态变化。</p><br></div><br> | action-menu/events.vue |
