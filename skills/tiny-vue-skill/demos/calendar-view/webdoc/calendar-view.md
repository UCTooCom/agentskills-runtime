# calendar-view Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>默认以月的形式展示当月的每一天。</p><br> | calendar-view/basic-usage.vue |
| calendar-mode | 显示模式 | <p>通过 <code>mode</code> 属性指定以年的形式显示，将展示当年的每个月份。可选值有 <code>month</code> / <code>timeline</code> / <code>schedule</code>。</p><br> | calendar-view/calendar-mode.vue |
| calendar-disabled-day | 日期禁用 | <p>通过 <code>disabled</code> 回调函数来禁用某些日期。</p><br> | calendar-view/calendar-disabled-day.vue |
| calendar-schedule-slot | 日程模式插槽 | <p>日程模式下内容区提供 weekday1-weekday7 这 7 个插槽，方便用户自定义日程展示。</p><br> | calendar-view/calendar-schedule-slot.vue |
| calendar-timeline-slot | 时间线插槽 | <p>时间下模式下提供 timeline1-timeline7 这 7 个插槽，方便用户自定义日程展示。</p><br> | calendar-view/calendar-timeline-slot.vue |
| calendar-timeline-range | 时间线范围配置 | <p>通过 dayTimes 属性配置时间线模式下所展示的时间范围，默认为 [8,18]，可配范围 [0,23]。</p><br> | calendar-view/calendar-timeline-range.vue |
| multi-select | 日期多选 | <p>设置 mult-select = true 属性后，可开启日期多选。</p><br> | calendar-view/multi-select.vue |
| calendar-day-mark | 日期标记 | <p>通过 showMark 回调函数来标记某些日期，markColor 属性设置标记的颜色，此功能只在时间线模式和日程模式生效。markColor 可选颜色同 theme</p><br> | calendar-view/calendar-day-mark.vue |
| custom-header | 自定义头部显示 | <p>通过作用域插槽 header 自定义需要显示的头部区域。</p><br> | calendar-view/custom-header.vue |
| custom-calendar-toolbar | 自定义工具栏 | <p>通过作用域插槽 tool 自定义需要的工具栏。</p><br> | calendar-view/custom-calendar-toolbar.vue |
| custom-day-bg-color | 自定义单元格背景色 | <p>自定义日期单元格背景色。</p><br><p>目前支持预置的颜色，可选颜色 blue、green、red、yellow、purple、cyan、grey 和使用十六进制、rgb、rgba 的是自定义颜色</p><br> | calendar-view/custom-day-bg-color.vue |
| set-working-day | 设置工作日或节假日 | <p>可以结合日期多选，自定义背景色，工具栏插槽等功能实现设置工作日或节假日的功能。</p><br> | calendar-view/set-working-day.vue |
| calendar-event | 事件 | <p>日历抛出的事件有以下这些：</p><br><p>date-click：日期点击事件</p><br><p>new-schedule：新增日程按钮点击事件</p><br><p>selected-date-change：选中日期改变事件</p><br><p>prev-week-click：上一周按钮点击事件</p><br><p>next-week-click：下一周按钮点击事件</p><br><p>week-change：周改变事件</p><br><p>year-change：年改变事件</p><br><p>month-change：月改变事件</p><br><p>mode-change：模式切换事件</p> | calendar-view/calendar-event.vue |
