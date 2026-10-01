# color-picker Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 通过引用组件标签，<code>v-model</code>绑定数据即可。 | color-picker/base.vue |
| size | 尺寸设置 | 通过<code>size</code>属性设置<code>large</code><code>medium</code><code>small</code><code>mini</code>四种不同大小尺寸。不设置时为默认尺寸。 | color-picker/size.vue |
| event | 事件触发 | 通过点击确认时触发<code>confirm</code>事件，取消时触发<code>cancel</code>事件。 | color-picker/event.vue |
| enable-alpha | 透明度 | <code>透明度</code>选择。 | color-picker/alpha.vue |
| history | 历史记录 | 当<code>enable-history</code>为<code>true</code>时，将会启用历史记录功能。当用户点击确认时，将会自动将颜色插入到<code>history</code>用户行为会更改历史记录，外部可以更改历史记录。 | color-picker/history.vue |
| predefine | 预定义颜色 | 当<code>enable-predefine-color</code>为<code>时</code>启用预定义颜色功能，通过设置<code>predefine</code>属性来定义预定义颜色值，用户行为不会更改预定义颜色，但外部可以更改。 | color-picker/predefine.vue |
| default-visible | 默认显示 | 当<code>visible</code>为<code>true</code>时，将会默认显示<code>color-select</code>。 <code>visible</code>是响应式的，所以你可以强制控制<code>color-select</code>的状态。当<code>visible</code>切换的时候，会触发<code>cancel</code>事件。 | color-picker/default-visible.vue |
| dynamic-color-change | 颜色动态切换 | 通过动态切换<code>color</code>属性，以满足各种需求。 | color-picker/dynamic-color-change.vue |
| format | 颜色类型 | 通过设置 <code>format</code> 属性，用于设置点击确定后颜色的格式。目前支持<code>hex</code>, <code>hsl</code>, <code>hsv</code>, <code>rgb</code> | color-picker/format.vue |
| color-mode | 颜色模式 | 通过设置 <code>color-mode</code> 属性切换颜色模式。支持 <code>monochrome</code>(单色) 和 <code>linear-gradient</code>(线性渐变) 两种模式。 | color-picker/linear-gradient.vue |
