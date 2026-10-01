# date-picker Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>支持选择日期、日期时间、周、月份、年份。</p> | date-picker/basic-usage.vue |
| date-range | 范围选择 | <p>设置 <code>type</code> 属性为 <code>daterange</code> / <code>datetimerange</code> / <code>monthrange</code> / <code>yearrange</code>，可以设置以日期范围的形式进行选择。</p><br> | date-picker/date-range.vue |
| dates | 多日期选择 | <p>支持选择多个日期和年份。</p> | date-picker/multiple-dates.vue |
| disabled | 禁用状态 | <br>          <p>通过设置 <code>disabled</code> 为 true 后，禁用日期输入框。</p><br>          <p>通过设置 <code>picker-options</code> 的 <code>disabledDate</code> 属性，可以实现部分禁用，此时只能选择一部分日期。</p><br>          <p>日期输入框默认可以输入日期，设置 <code>editable</code> 为 false 后，将不能输入。</p><br>          <p>通过 <code>readonly</code> 属性设置日期组件是否只读。</p><br>         | date-picker/disabled.vue |
| shortcuts | 快捷选项 | <br>          <p>通过在 <code>picker-options</code> 属性中指定 <code>shortcuts</code> 对象数组可以设置快捷选项。</p><br>          <p>通过<code>type: 'startFrom'</code> 设置某日起始，<code>endDate</code> 属性可设置结束日期，<code>endDate</code> 默认为 <code>2099-12-31</code>。</p><br>          <p>通过<code>type: 'endAt'</code> 设置某日为止，<code>startDate</code> 属性可设置开始日期，<code>startDate</code> 默认为 <code>1970-01-01</code>。</p><br>          <p>设置某日起始、某日为止时不用传入 <code>onClick</code> 函数，此函数不会被执行。</p><br>         | date-picker/shortcuts.vue |
| size | 尺寸 | <p>通过 <code>size</code> 属性可以设置日期输入框的尺寸，可选值有 medium、small、mini。</p><br> | date-picker/size.vue |
| clear | 清除输入 | <p>选择日期后，鼠标悬停在输入框时，默认会显示清除图标，单击图标可以清除输入框内容。设置 <code>clearable</code> 属性为 false 后，则不显示清除图标，不可清除。通过 <code>clear-icon</code> 属性可以自定义清除图标。</p> | date-picker/clear.vue |
| format | 格式化 | <br>          <p>通过 <code>format</code> 属性设置输入框中显示的日期格式，<code>time-format</code> 属性设置日期选择面板的时间显示格式，<code>value-format</code> 属性设置绑定值的格式。</p><br>         | date-picker/format.vue |
| default-value | 默认值 | <br>          <p><code>default-value</code> 属性指定日期选择器面板打开时默认显示的日期。</p><br><br>          <p><code>default-time</code> 属性指定时间选择器面板打开时默认显示的时刻，默认值是 00:00:00。<code>default-time</code> 接受一个数组，数组的每一项都为一个字符串，第一项控制起始日期的时刻，第二项控制结束日期的时刻。</p><br><br>         | date-picker/default-value.vue |
| custom-weeks | 周次序号 | <br>          <p>通过设置 <code>show-week-number</code> 属性为 <code>true</code> 显示周次序号，通过<code>format-weeks</code>属性设置周次显示格式，<code>format-weeks</code>函数有两个参数：</p><br>          <ul><br>            <li>customWeeks：自定义周次的序号</li><br>            <li>weekFirstDays：获取每周次中的首个日期</li><br>          </ul><br>          <p>通过 <code>picker-options</code> 的 <code> firstDayOfWeek </code> 属性来设置每周的第一天是星期几，默认值是 7，也就是星期天。</p><br>         | date-picker/custom-weeks.vue |
| filter-mode | 过滤器模式 | <p>通过 <code>shape="filter"</code> 属性切换至过滤器模式。</p><p>过滤器模式下可传入 label 显示标题，tip 显示提示信息，clearable 是否显示清除按钮。</p> | date-picker/filter-mode.vue |
| label-inside | label 内置 | <p>通过 <code>label</code> 属性可以设置日期选择器的 label，使其放置在组件的开始位置。</p><br> | date-picker/label-inside.vue |
| step | 步长 | <br>          <p><code>step</code> 和 <code>time-arrow-control</code> 都是当 type 为 datetime、datetimerange 时使用。</p><br>          <p>通过 <code>step</code> 设置步长，默认值为 <code>{ hour: 1, minute: 1, second: 1 }</code>，其中 <code>hour</code> 的设置范围是 <code>0-23</code>，<code>minute</code>、<code>second</code> 的设置范围是 <code>0-60</code>。可单独设置其中的一项或多项值，未设置的默认值为 <code>1</code>。</p><br>          <p>将 <code>time-arrow-control</code> 设为 true 可以设置通过箭头按钮控制时间选择，默认为通过鼠标滚轮滚动选择时间。</p><br>         | date-picker/step.vue |
| align | 对齐方式 | <p>通过 <code>align</code> 属性可以设置日期选择面板与输入框之间的对齐方式，可选值有 left、right、center，默认为 left 左对齐。</p><br> | date-picker/align.vue |
| custom-suffix-icon | 后置图标 | <br>          <p>通过 <code>suffix-icon</code> 属性设置日期输入框后置图标，从 <code>@opentiny/vue-icon</code> 中导入一个图标并进行初始化后传给 <code>suffix-icon</code>。</p><br>          <p>通过 <code>popper-class</code> 属性可以为 DatePicker 下拉弹框添加 class 类名。</p><br>         | date-picker/custom-suffix-icon.vue |
| unlink-panels | 面板联动 | <p>范围选择时，默认情况下，在开始日期面板中单击上一月或上一年箭头图标时，结束日期面板中日期也联动切换到上一月或上一年。在结束日期面板中切换下一月或下一年时，开始日期面板也随之联动。但若配置 <code>unlink-panels</code> 属性为 true，面板之间就不再联动，切换年月时只对当前面板生效。</p><br> | date-picker/unlink-panels.vue |
| timezone | 时区选择 | <br>          <p>通过 <code>show-timezone</code> 属性可以设置日期选择面板时区选择，同时需要引入 timezoneData 时区数据。</p><br>          <p>通过 <code>isutc8</code> 属性可以设置是否显示为东八区时间。</p><br>         | date-picker/timezone.vue |
| validate-event | 表单校验 | <p>日期选择器在输入时默认会触发表单校验，触发方式有 blur、change。但若设置 <code>validate-event</code> 属性为 false，将不再触发表单校验。</p><br> | date-picker/validate-event.vue |
| now |  “此刻”逻辑定制 | <p>“此刻”配置的时间与用户本地时间设置相关，为保证部分逻辑对服务器时间的要求，组件提供 <code>nowClick</code >函数和 <code>now</code> 插槽两种定制方式，用户可以自定义“此刻”配置的时间。</p> | date-picker/now.vue |
| events | 事件 | <p>支持 <code>focus</code>、<code>blur</code>、<code>change</code>、<code>onPick</code> 事件。<br><code>onPick</code> 代表获取选中日期后执行的回调，需要与 <code>daterange</code> 或 <code>datetimerange</code> 类型配合使用才生效，配置在 <code>picker-options</code> 中。</p> | date-picker/events.vue |
| slot | 插槽 | <p>通过 `#footer` 作用域插槽自定义显示内容。</p> | date-picker/slot.vue |
