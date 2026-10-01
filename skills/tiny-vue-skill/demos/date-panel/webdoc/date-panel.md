# date-panel Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>支持只使用日期面板、日期区间面板。</p> | date-panel/basic-usage.vue |
| disabled-date | 日期禁用 | <p>通过设置 <code>disabledDate</code> 属性，可以实现部分禁用，此时只能选择一部分日期。</p> | date-panel/disabled-date.vue |
| format | 格式化 | <p>通过 <code>format</code> 属性设置面板选中的日期格式</p> | date-panel/format.vue |
| shortcuts | 快捷选项 | <p>通过指定 <code>shortcuts</code> 对象数组可以设置快捷选项。</p> | date-panel/shortcuts.vue |
| readonly | 只读 | <p>通过指定 <code>readonly</code> 设置只读。</p> | date-panel/readonly.vue |
| custom-weeks | 周次序号 | <br>          <p>通过设置 <code>show-week-number</code> 属性为 <code>true</code> 显示周次序号，通过<code>format-weeks</code>属性设置周次显示格式，<code>format-weeks</code>函数有两个参数：</p><br>          <ul><br>            <li>customWeeks：自定义周次的序号</li><br>            <li>weekFirstDays：获取每周次中的首个日期</li><br>          </ul><br>          <p>通过 <code> firstDayOfWeek </code> 属性来设置每周的第一天是星期几，默认值是7，也就是星期天。</p><br>         | date-panel/custom-weeks.vue |
| unlink-panels | 面板联动 | <p>范围选择时，默认情况下，在开始日期面板中单击上一月或上一年箭头图标时，结束日期面板中日期也联动切换到上一月或上一年。在结束日期面板中切换下一月或下一年时，开始日期面板也随之联动。但若配置 <code>unlink-panels</code> 属性为 true，面板之间就不再联动，切换年月时只对当前面板生效。</p><br> | date-panel/unlink-panels.vue |
| event | 事件 | <p>支持 <code>selectPanelChange</code> 事件。用于获取选中日期后执行的回调。</p> | date-panel/event.vue |
