# time-picker Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>默认是通过滚动的方式选择时间，<code>arrow-control</code> 属性可以设置通过箭头的方式选择时间。</p> | time-picker/basic-usage.vue |
| picker-options | 固定时间范围 | <p>通过<code>picker-options</code> 设置固定时间范围</p> | time-picker/picker-options.vue |
| is-range | 选择时间范围 | <p>通过<code>is-range</code> 设置是否为范围选择，默认为 false，通过<code>range-separator</code>设置范围选择分隔符（为可选值）默认为 '-'。</p> | time-picker/is-range.vue |
| disabled | 禁用状态 | <p>通过设置 <code>disabled</code> 为 true 后，禁用时间输入框。</p><p>通过设置 <code>picker-options</code> 的 <code>selectableRange</code> 属性，可以实现部分禁用，此时只能选择一部分时间。</p> | time-picker/disabled.vue |
| placeholder | 占位符 | <p>通过 <code> placeholder </code> 属性设置时间输入框的占位符，通过 <code> start-placeholder </code> / <code> end-placeholder </code> 设置时间范围输入框的开始和结束时间的占位符。</p> | time-picker/placeholder.vue |
| size | 尺寸 | <p>通过 <code>size</code> 自定义组件尺寸。</p> | time-picker/size.vue |
| step | 步长 | <p>通过 <code>step</code> 设置步长，默认值为 <code>{ hour: 1, minute: 1, second: 1 }</code>，其中 <code>hour</code> 的设置范围是 <code>0-23</code>，<code>minute</code>、<code>second</code> 的设置范围是 <code>0-59</code>。可单独设置其中的一项或多项值，未设置的默认值为 <code>1</code>。</p> | time-picker/step.vue |
| clearable | 清除按钮 | <p>通过 <code>clearable</code> 属性设置是否显示清除按钮，默认值为 true。通过 <code>clear-icon</code> 属性可以自定义清除按钮的图标。</p> | time-picker/clearable.vue |
| format | 时间格式化 | <br>          <p><code>format</code> 时间格式化显示<br><code>timestamp</code> JS 时间戳，仅 value-format 可用；组件绑定值为 number 类型。</p><br>          <p>通过 <code>hh</code> 属性可设置 12 小时制。 <code>HH</code> 属性为 24 小时制，须和 A 或 a 使用。 <code>h</code> 与 <code>H</code> 属性设置不补 0。<br>通过 <code>mm</code> 属性可设置分钟显示格式，例如 01。 <code>m</code> 属性设置不补 0。<br>通过 <code>ss</code> 属性可设置秒的显示格式，例如 01。 <code>s</code> 属性设置不补 0。<br>通过 <code>a</code> 属性可设置显示时间为 am/pm <code>A</code>属性设置显示时间为 AM/PM。</p><br>         | time-picker/format.vue |
| default-value | 默认时间 | <p>通过 <code>default-value</code> 设置选择器打开显示默认时间。</p> | time-picker/default-value.vue |
| name | 原生属性 | <p>通过 <code>name</code> 属性设置默认 name。</p> | time-picker/name.vue |
| suffix-icon | 自定义后置图标 | <p>通过 <code>suffix-icon</code> 属性设置日期输入框后置图标，从 <code>@opentiny/vue-icon</code> 中导入一个图标并进行初始化后传给 <code>suffix-icon</code>。</p> | time-picker/suffix-icon.vue |
| popper-class | 下拉框的类名 | <p>通过 <code>popper-class</code> 属性设置下拉框的类名。通过 <code>popper-append-to-body</code> 属性设置是否将下拉框放到 body 元素上，默认值为 true，下拉框挂在 body 元素上。</p> | time-picker/popper-class.vue |
| editable | 文本框不可输入 | <p>日期输入框默认可以输入日期，设置 <code>editable</code> 为 false 后，将不能输入。</p> | time-picker/editable.vue |
| event | 事件 | <p>当聚焦和失焦时会触发 focus 和 blur 事件，当确定选值时会触发 change 事件。</p> | time-picker/event.vue |
