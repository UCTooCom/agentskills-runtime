# tag-group Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 通过 <code>data</code> 属性设置标签组的数组数据。 <br><br>          每一项标签数据，可以通过标签数据的<code>name</code> 属性设置对应标签名；<br><br>          通过标签数据的 <code>type</code> 属性可以为标签设置相应的类型，可选值 <code>(success / warning / info / danger  )</code>；<br><br>          | tag-group/basic-usage.vue |
| tag-group-effect | 主题 | <p>可通过 <code>effect</code> 设置 TagGroup 标签组 标签主题，可选值 <code>dark / light / plain</code>，默认值为 <code>light</code> 。</p> | tag-group/tag-group-effect.vue |
| tag-group-size | 尺寸 | <p>可通过 <code>size</code> 设置标签组标签大小，可选值 <code>medium / small / mini</code>，默认值为 <code>medium</code>。</p> | tag-group/tag-group-size.vue |
| more | 显示更多 | 标签组会自动识别子项的长度，当子项超出一行显示时，未尾自动显示更多的图标，鼠标悬浮会提示剩余子项。 | tag-group/more.vue |
| tag-group-event | 事件 | <p>TagGroup 标签组提供了 <code>item-click</code>事件，<code>item-click</code> 事件默认提供的参数有 <code>item,index,event</code> 。</p> | tag-group/tag-group-event.vue |
