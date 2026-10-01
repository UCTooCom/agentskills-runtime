# dropdown Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>使用 tiny-dropdown-item 定义菜单节点。</p><br> | dropdown/basic-usage.vue |
| disabled | 禁用 | <p>通过 <code>disabled</code> 属性设置 菜单 或者 菜单项 为禁用状态。</p><br> | dropdown/disabled.vue |
| placement | 展开位置 | <p>通过 <code>placement</code> 属性设置为 <code>bottom-start</code> 设置右侧展开。默认值为左侧展开。<br> | dropdown/placement.vue |
| size | 尺寸 | <p>通过 <code>size</code> 属性可配置其他尺寸，可选值：<code>medium</code> / <code>small</code> / <code>mini</code>。</p><br> | dropdown/size.vue |
| border | 边框 / 圆角 | <p>通过 <code>border</code> 属性设置是否展示边框，<code>border</code> 为 <code>true</code> 时，通过<code>round</code> 属性设置是否为圆角。</p><br> | dropdown/border.vue |
| show-icon | 图标 | <p>通过 <code>show-icon</code> 属性设置是否显示下拉触发源图标，<code>suffix-icon</code> 设置下拉触发源图标。</p><br> | dropdown/show-icon.vue |
| trigger | 触发方式 | <p>通过 <code>trigger</code> 属性设置触发下拉的方式，默认为 <code>hover</code>。可选值为：<code>click</code> / <code>hover</code> / <code>contextmenu</code>（3.28.0 起支持）。</p><br> | dropdown/trigger.vue |
| visible | 手动控制显隐 | <p>通过 <code>visible</code> 属性手动控制下拉菜单显隐，优先级高于trigger。</p><br> | dropdown/visible.vue |
| tip | 提示信息 | <p>通过 <code>tip</code> 属性设置提示信息，<code>tip-position</code> 属性设置提示信息的位置，<code>tip-effect</code> 属性设置提示信息的主题（light/dark）。</p><br> | dropdown/tip.vue |
| visible-arrow | 显示箭头 | <p>通过 <code>visible-arrow</code> 属性设置下拉弹框是否显示箭头，默认不显示。<code>visible-arrow</code> 为 true 时显示箭头。</p><br> | dropdown/visible-arrow.vue |
| hide-on-click | 点击后收起 | <p>通过 <code>hide-on-click</code> 属性设置点击菜单项后是否收起菜单弹框。默认为 true，点击后收起。</p><br> | dropdown/hide-on-click.vue |
| title | 触发源文本 | <p>通过 <code>title</code> 属性设置触发源的文本，默认为 <code>下拉菜单</code>。</p><br> | dropdown/title.vue |
| check-status | 选中态 | <p>通过 <code>checked-status</code> 属性启用选中态，<code>current-index</code> 属性设置索引值，<code>selected</code> 属性设置是否选中。</p><br> | dropdown/check-status.vue |
| options | 配置式 | <p><code>menu-options</code>属性：只使用 tiny-dropdown 组件配置式时使用。</p><br><p><code>options</code>属性：使用 tiny-dropdown-menu 组件配置式时使用。</p><br><p><code>text-field</code>属性：指定菜单文案显示的字段，默认为 label。 </p><br><p><code>title</code>属性：设置触发源的文本。</p><br> | dropdown/options.vue |
| multi-level | 多级菜单 | <p>通过 <code>children</code> 字段定义多级菜单的子节点，仅配置式时生效。</p><br> | dropdown/multi-level.vue |
| inherit-width | 继承宽度 | <p>通过 <code>inherit-width</code> 属性设置下拉弹框的最小宽度继承触发源的宽度。</p><br> | dropdown/inherit-width.vue |
| slots | 插槽 | <p>通过 <code>default</code> 插槽自定义触发源文本区域。<code>suffix-icon</code> 插槽自定义触发源图标区域。</p><br> | dropdown/slots.vue |
| events | 事件 | <p><code>button-click</code>：按钮类型时，监听左侧按钮点击事件。</p><p><code>item-click</code>：监听点击菜单项事件。</p><p><code>visible-change</code>：监听下拉弹框显示隐藏发生变化。</p><br> | dropdown/events.vue |
| lazy-show-popper | 懒加载菜单和子项 | 通过 <code>lazy-show-popper </code>属性，指定是否懒加载下拉菜单及内部的项 | dropdown/lazy-show-popper.vue |
