# layout Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <br>            通过在<code>Layout </code> 组件嵌套使用 <code>Row</code> , <code>Col</code> 组件，来实现对一个区域进行 12/24 栅格布局。<br><br>            通过<code>Layout </code> 组件的<code> cols </code> 属性来指定布局的总栅格栏数，组件库默认为 12 栅格栏；<br><br>            通过 <code>Col</code> 组件的 <code>span</code> 属性指定每栏所占栅格数。当一行的栅格数之和大于总栅格栏数时，布局会自动换行显示。<br><br>           | layout/basic-usage.vue |
| responsive-layout | 响应式布局 | <br>            在<code>Col</code> 组件预设了五个响应尺寸：<code>xs</code>、<code>sm</code>、<code>md</code>、<code>lg</code> 和 <code>xl</code>，<br>            来指定在每一个媒介查询尺寸时，该列应该占用的栅格数。组件库默认媒介查询的断点位置为<code>768 / 992 / 1200 / 1920</code><br><br>            请改变浏览器窗口的大小，观察下面示例中，各列所占栅格的变化。<br>           | layout/responsive-layout.vue |
| order | Col 排序 | <br>            在启用<code>Row</code> 组件的 <code>flex</code> 布局时，可通过设置它的 <code>order</code> 属性值为：<code>asc 或 desc</code>，给<code>Col</code> 组件排序。<br><br>            待排序的列需指定 <code>no</code> 属性为数字值，属性的默认值为 0。<br>           | layout/order.vue |
| alignment | 对齐方式 | <br>            通过<code>Row</code> 组件的 <code>flex</code> 属性设置为 <code>true</code> 来启用 flex 布局，<br>            并通过 <code>justify</code> 来指定主轴方向的对齐方式，通过 <code>align</code> 属性指定副轴的对齐方式。<br><br>           | layout/alignment.vue |
| offset | 偏移 | 通过设置 <code>Col</code> 组件的 <code>offset</code> 属性来指定当前列偏移的栏数。 | layout/offset.vue |
| gutter | 栅格间隔 | <br>            通过使用 <code>Row</code> 组件的 <code>gutter</code> 属性实现栅格间隔。<br><br>            不设置 <code>gutter</code> 时，组件会默认为 <code>Col</code> 设置<code> 左右 10px </code>的 padding 值<br><br>            通过 <code>noSpace</code> 属性，让子项间没有间距。<br>           | layout/gutter.vue |
| tag | 自定义元素标签 | <br>            通过使用 <code>Layout / Row / Col </code> 组件的 <code>tag</code> 属性实现自定义元素标签，可选任意标签。默认使用 <code>div</code> <br>           | layout/tag.vue |
