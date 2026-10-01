# popover Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <br>          通过 <code>reference</code>  插槽来指定一个触发源，通过 <code>content</code> 属性来指定提示内容，点击触发源会弹出内容面板。<br><br>          通过 <code>title</code> 属性来指定标题。<br><br>          通过 <code>width</code>  属性来指定一个弹出面板的宽度。<br><br>          <div class="tip custom-block">reference 插槽是必传插槽，没有它时组件渲染不出来。</div><br>           | popover/basic-usage.vue |
| trigger | 触发方式 | <br>          通过<code>trigger</code> 属性设定弹出框的 4 种触发方式，默认值为 <code> click </code>。<br><br>          当触发方式为<code> manual</code>时，通过设置<code>v-model</code> 属性，动态控制显示和隐藏弹出框。<br>           | popover/trigger.vue |
| content | 弹出层内容 | <br>          通过 <code>content</code> 属性设置要显示的字符串内容。<br><br>          通过 <code>default</code> 插槽，支持自定义复杂的内容结构。<br><br>           | popover/content.vue |
| disabled | 禁用 | <code>disabled</code> 设置是否禁用弹出框。 | popover/disabled.vue |
| offset | 自定义偏移 | <br>          通过<code>arrow-offset</code> 设置箭头的在弹窗层上的偏移量。箭头默认至少会保留 8px 的空间，以保证箭头不会贴在弹窗层两边。<br><br>          通过<code> offset</code> 设置弹框的偏移量，来改变弹框的位置。<br>           | popover/offset.vue |
| custom-popper | 自定义弹出面板 | <br>          通过<code>placement</code> 设置弹出框的的位置。<br><br>          通过<code>visible-arrow</code> 设定是否显示提示框的箭头，默认值为 <code>true</code>。<br><br>          通过<code>popper-class</code> 可配置单个或多个类名，通过类名可以控制弹窗样式。<br>           | popover/custom-popper.vue |
| delay | 延迟控制 | <br>          通过 <code>open-delay</code> 弹出框打开时延迟的时长，默认值为 0，单位为毫秒。<br><br>          通过 <code>close-delay</code> 弹出框关闭时延迟的时长，默认值为 200，单位为毫秒。<br><br>          <div class="tip custom-block">只有在触发方式为 hover 时，延迟控制功能才生效。</div><br>           | popover/delay.vue |
| transition | 自定义渐变动画 | 通过 <code>transition</code> 设置弹框的显示隐藏淡入淡出动画，默认取值 <code>fade-in-linear</code> 。 | popover/transition.vue |
| popper-options | 高级选项 | 通过<code>popper-options</code> 配置弹出框高级选项。 | popover/popper-options.vue |
| ignore-boundaries | 忽略边界判断 | <br>          由于 Popper 会判断是否超出 offsetParent 从而调整弹框弹出的位置，有些时候并不能达到我们想要的效果。<br><br>          因此提供一个在<code>popper-options</code>上新增一个属性<code>ignoreBoundaries: true</code> ，可以让 Popper 忽略边界判断，弹出的位置始终是我们设置的 placement 值。<br>         | popover/ignore-boundaries.vue |
| events | 事件 | <br>          组件支持以下事件：<br><br>          <code>hide</code> 隐藏时触发回调；<br><br>          <code>show</code> 显示时触发回调；<br><br>          <code>after-leave</code> 进入的动画结束后触发回调；<br><br>          <code>after-enter</code> 离开的动画播结束后触发回调；<br> | popover/events.vue |
