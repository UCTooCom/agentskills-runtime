# tag Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <br>          通过默认插槽，可以将文字和图标显示为一个标签。 <br><br>          通过 <code>value</code> 属性，也可以设置标签值。 <br><br>          通过 <code>only-icon</code> 属性，设置标签只有图标。<br>         | tag/basic-usage.vue |
| effect | 主题 | 通过 <code>effect</code> 设置主题，可选值： <code>(dark / light / plain)</code> ； <code>type</code> 设置类型，可选值： <code>(success / info / warning / danger / alerting / error)</code> 。 | tag/effect.vue |
| color-border | 其它颜色 | <br>        通过 <code>color</code> 设置颜色，可使用预设值，也可自定义颜色值；<br><br>        当自定义颜色值为字符串时，则设置背景色；<br><br>        当自定义颜色值为数组则第一个值为背景色，第二个为文本色。<br><br>        <div class="tip custom-block"><br>          避免同时使用  <code>color</code> 和  <code>type</code> <code>effect</code>属性！<br>        </div><br>         | tag/color-border.vue |
| size | 尺寸 | 通过 <code>size</code> 设置尺寸大小，可选值： <code>(medium / small)</code> 。 | tag/size.vue |
| max-width | 最大宽度 | 通过 <code>maxWidth</code> 设置最大宽度 。 | tag/max-width.vue |
| disabled | 禁用 | 通过 <code>disabled</code> 设置禁用。 | tag/disabled.vue |
| delete | 删除操作 | 通过 <code>closable</code> 设置展示关闭按钮， <code>before-delete</code> 设置删除前的操作，可以在此钩子中做提示或确认；<code>close</code> 监听关闭按钮点击事件，做删除操作。 | tag/delete.vue |
| slot-default | 默认插槽 | 通过 <code>default</code> 默认插槽自定义标签内容，生成图标标签。 | tag/slot-default.vue |
| tag-event-click | 点击事件 | 通过 <code>click</code> 监听点击事件。 | tag/tag-event-click.vue |
| rounded | 圆角标签 | 通过使用 <code>round</code> 属性设置圆角标签。 | tag/rounded.vue |
