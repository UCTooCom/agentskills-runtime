# calendar Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>默认以月的形式展示当月的每一天。</p><br> | calendar/basic-usage.vue |
| calendar-mode | 显示模式 | <p>通过 <code>mode</code> 属性指定以年的形式显示，将展示当年的每个月份。可选值有 year、month。</p><br> | calendar/calendar-mode.vue |
| show-selected-date | 显示选中日期 | <p>以月的形式展示时，指定 show-selected 属性后，单击日期单元格，将会在日历框上方展示当前选中的日期。</p><br> | calendar/show-selected-date.vue |
| calendar-year-month | 指定年月 | <p>通过 <code>year</code> 属性指定年份，通过 <code>month</code> 属性指定月份。</p><br> | calendar/calendar-year-month.vue |
| custom-day-cell | 自定义日期单元格 | <p>通过作用域插槽 day 自定义日期单元格。</p><br> | calendar/custom-day-cell.vue |
| custom-calendar-toolbar | 自定义工具栏 | <p>通过作用域插槽 tool 自定义需要的工具栏。</p><br> | calendar/custom-calendar-toolbar.vue |
| dynamic-add-schedule | 添加日程事件 | <p>通过 events 属性可以指定事件列表，它是一个对象数组，对象中包含如下字段：</p><br><div class="tip custom-block"><p class="custom-block-title">events 说明</p><br><p>time：指定需要展示事件的日期<br>title：指定事件标题<br>content：指定事件的具体内容 type：指定当鼠标悬停在事件标题上时，弹出的展示事件具体内容的提示框的主题，包括 warning、error、info、success</p><br></div><br> | calendar/dynamic-add-schedule.vue |
