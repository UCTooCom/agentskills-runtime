# button-group Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>通过 <code>data</code> 设置按钮组数据，<code>v-model</code> 设置绑定值。</p> | button-group/basic-usage.vue |
| size | 组件尺寸 | <p>通过 <code>size</code> 设置尺寸大小，可选值有 <code>medium</code> 、<code>small</code> 、<code>mini</code> 。</p> | button-group/size.vue |
| disabled | 禁用状态 | <p>通过 <code>disabled</code> 设置按钮组是否禁用，数据项设置 <code>disabled</code> 属性可以禁用单个按钮，数据项设置 <code>tip</code> 属性 (v3.17.0 版本增加此功能) 增加按钮悬浮提示功能。</p> | button-group/disabled.vue |
| plain | 朴素按钮 | <p>通过 <code>plain</code> 设置是否为朴素按钮。</p> | button-group/plain.vue |
| text-value-field | 数据字段映射 | <p>若按钮组数据对象中的字段不是默认的 <code>text</code> 和 <code>value</code> ，则可通过 <code>text-field</code> 、<code>value-field</code> 属性进行映射。</p> | button-group/text-value-field.vue |
| show-more | 显示更多按钮 | <p>通过 <code>show-more</code> 设置显示更多按钮，当按钮数量大于设置值时，将显示更多按钮。</p> | button-group/show-more.vue |
| slot-default | 默认插槽 | <p>使用默认插槽自定义按钮组，使用默认插槽后， <code>button-group</code> 的 <code>data</code> 、<code>text-field</code> 、<code>value-field</code> 、<code>value / v-model</code> 、<code>size</code> 属性对插槽中的按钮将不再生效。</p> | button-group/slot-default.vue |
| slot-empty | 空数据 | <p>当数据为空时，默认会显示"暂无数据"，通过 <code>empty</code> 插槽自定义内容。</p> | button-group/slot-empty.vue |
| button-group-multiple | 多行按钮组 | <p>多行按钮组，当超出最大宽度后，换行显示。</p> | button-group/button-group-multiple.vue |
| sup | 选块角标 | <p>通过 <code>data</code> 的 <code>sup</code> 属性配置选块角标。</p> | button-group/sup.vue |
| change-event | 事件 | <p>当选中按钮发生改变时触发 <code>change</code> 事件。</p> | button-group/change-event.vue |
| display-mode | 按钮组显示模式 | <p>通过 <code>display-mode</code> 属性设置按钮组显示模式，可选值有 <code>default</code>（默认）和 <code>merged</code>（选块合并）。</p> | button-group/display-mode.vue |
