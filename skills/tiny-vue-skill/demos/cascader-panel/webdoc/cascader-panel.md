# cascader-panel Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>通过 <code>options</code> 来指定选项，也可通过 <code>props</code> 来设置多选、动态加载等功能，具体详情见下方 API 表格。</p><br> | cascader-panel/basic-usage.vue |
| custom-option-content | 自定义节点内容 | <p><br>            <div>可以通过 <code>scoped slot</code> 对级联面板的备选项的节点内容进行自定义。</div><br>            <div><code>scoped slot</code> 会传入两个字段 <code>node</code> 和 <code>data</code>，分别表示当前节点的 Node 对象和数据。</div><br>          </p> | cascader-panel/custom-option-content.vue |
| multiple | 多选 | <p>通过 <code>props.multiple = true</code> 来开启多选模式。</p><br> | cascader-panel/multiple.vue |
| cascader-panel-props | Props 选项 | <p><br>              <div>通过 <code>children</code> 指定子级选项，默认值为 'children'。</div><br>              <div>通过 <code>emitPath</code> 是否返回由该节点所在的各级菜单的值所组成的数组。</div><br>              <div>通过 <code>label</code> 指定显示选项 label 值，默认为 'label'。</div><br>              <div>通过 <code>value</code> 指定值选项 value 值，默认为 'value'。</div><br>            </p> | cascader-panel/cascader-panel-props.vue |
| change | 事件与方法 | <p><br>            <div>通过 <code>change</code> 点击节点后触发的事件，回调参数为"选中节点的值"。</div><br>            <div>通过 <code>clearCheckedNodes</code> 清除选中的节点。</div><br>            <div>通过 <code>getCheckedNodes</code> 获取选中的节点。</dic><br>          </p> | cascader-panel/change.vue |
