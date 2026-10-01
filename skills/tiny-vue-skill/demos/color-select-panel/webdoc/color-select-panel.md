# color-select-panel Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 通过<code>visible</code>设置显示色彩选择面板。 | color-select-panel/base.vue |
| linear-gradient | 线性渐变 | 通过<code>color-mode</code>设置显示色彩选择的色彩模式。 | color-select-panel/linear-gradient.vue |
| alpha | 透明度 | 通过<code>alpha</code>设置透明度选择。 | color-select-panel/alpha.vue |
| event | 事件触发 | 通过点击确认时触发<code>confirm</code>事件，取消时触发<code>cancel</code>事件。 | color-select-panel/event.vue |
| history | 历史记录 | 当<code>enable-history</code>为<code>true</code>时，将会启用历史记录功能。当用户点击确认时，将会自动将颜色插入到<code>history</code>用户行为会更改历史记录，外部可以更改历史记录。 | color-select-panel/history.vue |
| predefine | 预定义颜色 | 当<code>enable-predefine-color</code>为<code>时</code>启用预定义颜色功能，通过设置<code>predefine</code>属性来定义预定义颜色值，用户行为不会更改预定义颜色，但外部可以更改。 | color-select-panel/predefine.vue |
| colorUpdate | 颜色修改事件 | 通过<code>@color-update</code>来监听颜色修改事件，注意：只在颜色修改时会触发改事件，例如拖拽光标或修改色相、透明度时 | color-select-panel/color-update.vue |
| format | 颜色类型 | 通过设置 <code>format</code> 属性，用于设置点击确定后颜色的格式。目前支持<code>hex</code>, <code>hsl</code>, <code>hsv</code>, <code>rgb</code> | color-select-panel/format.vue |
