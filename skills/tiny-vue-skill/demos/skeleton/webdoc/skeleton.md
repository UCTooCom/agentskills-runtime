# skeleton Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| base | 基本用法 | <p>基础的骨架效果。</p><br> | skeleton/base.vue |
| size | 尺寸 | <p>通过 <code>size</code>  属性可以控制骨架屏的尺寸。</p><br> | skeleton/size.vue |
| complex-demo | 头像模式 | <p>通过 <code>avatar</code> 属性控制骨架段落左侧出现头像占位。</p><br> | skeleton/complex-demo.vue |
| custom-rows | 段落行数 | <p>段落默认渲染 4 行，通过 <code>rows</code> 属性控制段落行数，显示的数量会比传入的数量多 1，首行会被渲染一个长度 40% 的段首，末行会被渲染一个长度 60% 的段尾。</p><br> | skeleton/custom-rows.vue |
| custom-paragraph-width | 段落宽度 | <p>通过 <code>rows-width</code> 属性可以段落宽度。</p><br> | skeleton/custom-paragraph-width.vue |
| custom-layout | 样式 | <p>通过 <code>class</code> 和 <code>style</code> 可自定义样式结构。</p><br> | skeleton/custom-layout.vue |
| loading-completed | 加载完成 | <p>通过 <code>loading</code> 属性的值来表示是否加载完成。可以通过具名插槽 <code>default</code> 来构建 <code>loading</code> 结束之后需要展示的真实 DOM 元素结构。</p><br> | skeleton/loading-completed.vue |
| animation | 动画效果 | <p>通过 <code>animated</code> 属性设置是否开启动画。</p><br> | skeleton/animation.vue |
| fine-grained-mode | 形态 | <p>通过 <code>variant</code> 属性可以控制 <code>skeleton-item</code> 的形态。</p><br> | skeleton/fine-grained-mode.vue |
