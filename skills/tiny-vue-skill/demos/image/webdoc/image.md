# image Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 通过 <code>src</code> 设置图片路径。<br> 通过 <code>fit</code> 属性确定图片如何适应到容器框，同原生 css 的 object-fit 属性。<br><p class="custom-block-title">object-fit 说明</p><p>fill：被替换的内容将被缩放，以在填充元素的内容框时保持其宽高比<br>contain：被替换的内容大小可以填充元素的内容框<br>cover：被替换的内容大小保持其宽高比，同时填充元素的整个内容框<br>none：被替换的内容尺寸不会被改变<br>scale-down：内容的尺寸就像是指定了 none 或 contain，取决于哪一个将导致更小的对象尺寸。 | image/basic-usage.vue |
| custom-placeholder | 占位内容 | 通过 <code>slot = placeholder</code> 自定义占位内容。 | image/custom-placeholder.vue |
| lazy | 懒加载 | 通过 <code>lazy</code> 开启懒加载功能，当图片滚动到可视范围内才会加载。<br>通过 <code>scroll-container</code> 来设置滚动容器，若未定义，则为最近一个 <code>overflow</code> 值为 <code>auto</code> 或 <code>scroll</code> 的父元素。<p>lazy 懒加载的图片必须是远程的图片，不支持静态图片懒加载。</p> | image/lazy.vue |
| preview | 预览大图 | 通过 <code>preview-src-list</code> 属性，传入一组图片 url 的数组，点击图片后，会进入预览大图的模式。<br>通过 <code>z-index</code> 设置预览图片的元素的 z-index。<br>通过添加 <code>show-index</code> 开启图片序号展示。<br> | image/preview.vue |
| keep-style | 保持图片样式属性 | 通过 <code>keep-style</code> 属性可以让图片切换时样式保持一致，图片的缩放、旋转、边距等状态不重置。 | image/keep-style.vue |
| index-change | 图片切换事件 | 图片切换时触发 <code>change-index</code> 事件，参数返回当前图片的 index。 | image/index-change.vue |
| count-slot | 图片计数插槽 | 通过 <code>count</code> 设置图片计数插槽。 | image/count-slot.vue |
| preview-in-dialog | 对话框中预览图片 | 在 <code>dialog-box</code> 元素中嵌入 <code>image</code> 进行图片预览。 | image/preview-in-dialog.vue |
| slot | 插槽 | 通过 <code> placeholder</code> 插槽，定义图片在加载中时的占位内容。通常由于图片加载快，会看不到这个插槽的出现，只有大图片时，会看到加载中的插槽。 <br> 通过 <code> error </code> 插槽，定义图片在加载失败后的占位内容。 | image/slot.vue |
| events | 事件 | <code>load</code> 事件：图片加载成功触发。<br><code>error</code> 事件：图片加载失败触发。 | image/events.vue |
