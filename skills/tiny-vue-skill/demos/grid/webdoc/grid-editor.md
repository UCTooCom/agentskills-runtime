# grid Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| editor-inner-editor | 内置编辑器 | <br>        <p>通过在 <code>grid</code> 标签上配置 <code>edit-config</code>。在 <code>grid-column</code> 列配置 <code>editor</code> 对象， <code>component</code> 渲染内置编辑组件，<code>attrs</code>配置组件的属性， <code>events</code> 配置组件事件。</p><br>        <div class="tip custom-block"><br>          <p class="custom-block-title">特别说明：</p><br>          <p>内置编辑器只支持 <code>Input</code> 和 <code>Select</code> 组件且均为浏览器原生组件并非 TinyVue 组件，需要使用其他组件可参考自定义编辑器。</p><br>        </div><br>         | grid/editor/inner-editor.vue |
| editor-custom-editor-select | 自定义编辑器 | <br>        <p> <code>grid</code> 标签上配置 <code>edit-config</code>。<br>在 <code>grid-column</code> 列配置 <code>editor</code> 对象， <code>component</code> 渲染自定义编辑组件或者 TinyVue 提供的组件。<code>attrs</code>配置组件的属性， <code>events</code> 配置组件事件。</p><br>         | grid/editor/custom-editor-select.vue |
| editor-mutil-render | 下拉多选 | <p>配置列为下拉多选时，单元格渲染需要自行实现，如下例中使用<code>format-text</code>渲染多个枚举值。也可以使用<code>renderer</code>自己实现自定义的组件去渲染。</p><br> | grid/editor/mutil-render.vue |
| editor-popeditor-in-grid-remote-search | 弹窗编辑 | <p>在 <code>grid-column</code> 列元素上配置 <code>editor</code> 属性，该对象中可以指定 <code>component</code> 为 <code>Popeditor</code>、<code>attrs</code> 为 Popeditor 组件的属性。需要注意的是，引入 Popeditor 组件后，需要在 <code>data()</code> 中进行实例化。</p><br> | grid/editor/popeditor-in-grid-remote-search.vue |
| editor-editor-bg | 维护编辑状态 | <p>假设 <code>名称字段</code> 和 <code>id 为 '3' 的行</code> 不可编辑，可以通过 <code>editConfig.activeMethod</code> 设置其单元格不可进入编辑，通过 <code>cellClassName</code> 设置其单元格的背景底色。</p> | grid/editor/editor-bg.vue |
| active-strictly | 行编辑禁用特定列 | <p>当 <code>editConfig.mode</code> 为'row'时，行编辑激活状态下默认会忽略 <code>editConfig.activeMethod</code> ，配置 <code>editConfig.activeStrictly</code> 为 true 使其生效 | grid/editor/active-strictly.vue |
| editor-custom-edit | 多行编辑 | <p>表格编辑器场景，在表格内部维护编辑状态，只能使整行或单个单元格处于编辑状态。如果需要使多行处于编辑状态，需要使用渲染器自行实现，在自定义编辑状态时，表格内置的一些编辑行为，例如表头是否显示必填星号、编辑规则等将不可用，需要自行实现，参考示例：</p> | grid/editor/custom-edit.vue |
