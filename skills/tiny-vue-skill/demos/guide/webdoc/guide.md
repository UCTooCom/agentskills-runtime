# guide Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基础用法 | <p>通过 <code>dom-data</code> 设置每一个步骤要显示的内容，<code>show-step</code> 设置为 <code>true</code> 即可开启指引。<code>dom-data</code> 详细配置可参考 <a href="#IDomData">IDomData</a> 类型。</p> | guide/basic-usage.vue |
| arrow-position | 箭头位置 | <br>          <p>通过 <code>pop-position</code> 属性设置箭头位置，该属性的可选值可参考 <a href="#IPosition">IPosition</a> 类型。</p><br>          <p>若存在多个步骤，需要单独给每个步骤设置不同的展示位置，可以在 <code>dom-data</code> 里面添加 <code>popPosition</code> 属性并赋值，若存在单独设置的箭头位置，则会覆盖全局的箭头位置。</p><br>         | guide/arrow-position.vue |
| only-content | 纯段落用户引导 | <p>通过添加 <code>only-content</code> 类名实现纯段落用户引导。</p> | guide/only-content.vue |
| highlight-box | 高亮多处 | <p>在 <code>dom-data</code> 里面通过 <code>hightBox</code> 属性添加需要高亮的元素。</p> | guide/highlight-box.vue |
| offset | 引导框偏移量 | <p>通过 <code>main-axis</code> / <code>cross-axis</code> / <code>alignment-axis</code> 设置纵轴、横轴和对齐轴的偏移量。</p> | guide/offset.vue |
| image-text | 图文结合用户引导 | <p>可以在插槽里面添加任何 <code>html</code> 或通过 <code>dom-data</code> 里面的 <code>text</code> 属性实现图文结合用户引导。</p> | guide/image-text.vue |
| size | 自定义宽高 | <p>通过添加 <code>width</code> 和 <code>height</code> 来自定义宽高。</p> | guide/size.vue |
| mask | 弹窗的遮罩层 | <p>通过添加 <code>mask</code> 来自定义是否显示遮罩层。默认值为 <code>false</code> </p> | guide/mask.vue |
| modal-overlay-opening | 模态叠加层开口 | <br>          <p><code>modal-overlay-opening-padding</code>：可以在模态叠加层开口周围添加的填充量，控制引导元素高亮范围。</p><br>          <p><code>modal-overlay-opening-radius</code>：可以在模态叠加层开口周围添加的边界半径量，控制引导元素高亮圆角。</p><br>         | guide/modal-overlay-opening.vue |
| callback | 事件回调 | <p>事件回调在 <code>dom-data</code> 中使用，详情可参考 <a href="#IDomData">IDomData</a> 类型。</p> | guide/callback.vue |
| show-close | 关闭按钮 | <p>通过添加 <code>showClose</code> 来自定义是否显示关闭按钮。默认值为 <code>false</code> </p> | guide/show-close.vue |
