# popeditor Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>在弹窗表格/树中选择数据。</p> | popeditor/basic-usage.vue |
| conditions | 自定义查询条件 | <p>通过 <code>conditions</code> 属性可以自定义查询条件，组件内置的输入框支持按回车触发搜索的功能。</p> | popeditor/conditions.vue |
| condition-layout | 布局 | <p>通过 <code>conditions</code> 项目里属性里的 <code>span</code> 配置栅格，<code>labelWidth</code> 配置 label 宽度，<code>component</code>配置自定义组件，并通过 <code>attrs</code> 配置组件属性。<code>lock-scroll</code> 配置弹出窗口时是否禁用滚动条。</p> | popeditor/condition-layout.vue |
| condition-form | 表单中使用 | <p>PopEditor 可以在表单中使用。</p> | popeditor/condition-form.vue |
| draggable | 拖动窗口 | <p>通过 <code>draggable</code> 属性设置弹出窗口拖动特性，默认为 <code>true</code>，表示可在标题栏按住鼠标左键拖动窗口，设置为 <code>false</code> 则固定窗口位置不可拖动。</p> | popeditor/draggable.vue |
| radio-change-close | 单选选中后关闭 | <p>通过 <code>radio-change-close</code> 属性设置单选选中选项后，弹窗是否自动关闭。</p> | popeditor/radio-change-close.vue |
| show-clear-btn | 不可清除 | <p>通过 <code>show-clear-btn</code> 属性设置是否可以清除。</p> | popeditor/show-clear-btn.vue |
| resize | 全屏展示 | <p>通过配置 <code>resize</code> 控制是否全屏展示。</p> | popeditor/resize.vue |
| grid | 表格编辑 | <p>grid-op 当 popseletor 为 grid 时生效，目前支持配置 columns 表格列 和 data 数据源，详细配置项参考 Grid 表格组件，需同时配置 textField、valueField 字段。</p> | popeditor/grid.vue |
| selected-box | 显示为已选栏 | <p>多选场景，设置属性 show-selected-box 为 true，且通过属性 selected-box-op 指定 SelectedBox 组件配置，可以把已选表格显示为已选栏；组件 SelectedBox 的所有插槽也已经透传。</p> | popeditor/selected-box.vue |
| width | 宽度 | <p>通过 <code>width</code> 属性配置宽，通过 <code>dialog-class</code> 自定义配置弹窗类名。</p> | popeditor/width.vue |
| icon | 自定义图标 | <p>通过 <code>icon</code> 属性可以自定义组件图标，需引入对应的 svg 图标。</p> | popeditor/icon.vue |
| multi | 多选 | <p>通过设置 <code>multi</code> 属性为 true 实现多选。通过设置 <code>show-history</code> 当弹出面板配置的是表格时，设置历史记录标签页是否显示表格，默认为 false。</p> | popeditor/multi.vue |
| multi-value-array | 初始数据为数组 | <p>设置 multi 属性为 true，可以配置多选，此时可以设置 v-model 绑定值为一个数组。</p> | popeditor/multi-value-array.vue |
| before-close | 拦截弹窗关闭 | <p>通过 <code>before-close</code> 属性可以配置一个拦截弹窗关闭的方法。如果方法返回 <code>false</code> 值，则拦截弹窗关闭；否则不拦截。</p><br>          <p>可以通过该拦截方法传入的参数获取关闭的操作类型 <code>confirm</code> 弹窗有以下关闭类型：</p><br>          <ul><br>            <li>confirm：点击确认时关闭</li><br>            <li>cancel：点击取消时关闭</li><br>            <li>close：点击关闭按钮时关闭</li><br>          </ul><br>         | popeditor/before-close.vue |
| readonly | 只读 | <p>通过 <code>readonly</code> 属性设置为是否只读。</p> | popeditor/readonly.vue |
| tabindex | 输入框的 tabindex | <p>通过 <code>tabindex</code> 属性设置通过 Tab 键获焦及获焦顺序（<code>readonly</code> 属性设置为 false 时有效）。</p> | popeditor/tabindex.vue |
| before-reset | 重置 | <p>通过 <code>before-reset</code> 属性设置重置前的钩子函数。</p> | popeditor/before-reset.vue |
| slot | 组件查询条件插槽 | <p>通过插槽 <code>search</code> 自定义弹出面板查询结构。</p> | popeditor/slot.vue |
| slot-footer | 自定义弹出框底部 | <p>通过插槽 <code>footer</code> 自定义弹出面板底部按钮栏结构。</p> | popeditor/slot-footer.vue |
| disabled | 禁用 | <p>通过 <code>disabled</code> 属性设置为是否禁用。</p> | popeditor/disabled.vue |
| clearable | 筛选条件支持可清空 | <p><code>clearable</code> 配置是否在搜索表单增加清除按钮。</p> | popeditor/clearable.vue |
| text-field | 显示字段映射 | <p>通过 <code>text-field</code> 属性设置组件显示的字段。</p> | popeditor/textField.vue |
| title1 | 提交字段映射 | <p>通过 <code>value-field</code> 属性设置组件提交给后台的字段。</p> | popeditor/title.vue |
| title | 自定义标题 | <p>通过 <code>title</code> 属性设置弹出窗口标题，支持国际化信息配置。</p> | popeditor/title.vue |
| remote-search | 远程搜索 | <p>通过 <code>remote-search</code> 属性配置远程搜索，在 remote-search 方法里可以把 conditions 搜索条件传给后台，后台处理好数据后就能正常的显示在页面上。</p> | popeditor/remote-search.vue |
| pager | 分页 | <p><code>showPager</code> 属性只有当 <code>popseletor</code> 为 <code>grid</code> 时才能生效，默认值为 <code>false</code> 不启用分页，配置为 <code>true</code> 后还需配置 <code>pager-op</code> 属性；并且需要监听 <code>page-change</code> 事件改变 <code>grid-op</code> 的 <code>data</code> 数据源。</p> | popeditor/pager.vue |
| render-text | 渲染反查 | <p>在组件加载的第一批数据中不含有当前所设置的 <code>value</code> 对应的数据时，可以设置 <code>text-render-source</code> 进行反查。</p> | popeditor/render-text.vue |
| tree | 开启树模式 | <p>通过 <code>popseletor</code> 属性开启树模式，然后 <code>tree-op</code> 属性是 <code>Tree</code> 组件的 <code>op</code>配置方式。</p> | popeditor/tree.vue |
| single-select-radio | 树模式单选 | <p>通过 <code>popseletor</code> 属性开启树模式，然后 <code>tree-op</code> 属性是 <code>Tree</code> 组件的 <code>op</code>配置方式。</p> | popeditor/single-select-radio.vue |
| size | 尺寸 | <p>通过 <code>size</code> 属性设置 PopEditor 编辑框大小，可选值有 <code>medium</code>、<code>small</code>、<code>mini</code>。</p> | popeditor/size.vue |
| show-overflow | 数据超出隐藏 | <p>在数据列上配置 <code>showOverflow</code> 属性用于设置数据超出列宽时的显示和隐藏。值的类型可以为 boolean 和 string，有三个值可以选择，如下所示。默认为换行显示全部内容。</p><br>          <div class="tip custom-block"><br>            <p class="custom-block-title">可选值说明</p><br>            <p>'tooltip'：内容超出部分显示 ...，左侧/右侧弹出提示层显示全部信息。<br>            <p>'title'：和原生标签的 title 属性一致。</p><br>            <p>'ellipsis'：内容超出部分显示 ...，没有提示。</p><br>            <p>boolean：为 true 时，效果和 'tooltip' 一致。</p><br>          </div><br>         | popeditor/show-overflow.vue |
| trigger | 单选时触发勾选的方式 | <p>弹出编辑为单选时，默认只能通过单击单选按钮进行勾选。但也可以通过设置属性 <code>trigger</code> 为 <code>row</code> 实现单击行中任意位置进行勾选。或者设置 <code>trigger</code> 为 <code>cell</code>，单击操作列的单元格上任意位置进行勾选。</p> | popeditor/trigger.vue |
| show-history | 历史记录标签页 | <p>当弹出面板配置的是表格时，通过配置 <code>show-history</code> 设置历史记录标签页是否显示表格，该值默认为 false。</p> | popeditor/show-history.vue |
| auto-lookup | 远程数据请求 | <p>配置 <code>auto-lookup</code> 为 false，设置初始化不请求数据，也可以调用 this.$refs.popeditor.handleSearch() 主动调用请求方法。</p> | popeditor/auto-lookup.vue |
| suggest | 联想查询 | <p>配置 <code>suggest</code> 开启联想功能，输入框输入后自动触发联想查询；该功能需要联合 <code>remoteSearch</code>使用。 | popeditor/suggest.vue |
| auto-reset | 自动重置 | <p>配置 <code>autoReset</code> 开启自动重置筛选项，筛选后点击关闭弹窗即可重置。 | popeditor/auto-reset.vue |
| events | 事件 | <br>          <p><code>popup</code>：弹框打开时触发的事件。</p><br>          <p><code>close</code>：弹框关闭时触发的事件。</p><br>          <p><code>change</code>：Input 框的 change 事件。</p><br>          <p><code>page-change</code>：表格模式带分页切换事件。</p><br>         | popeditor/events.vue |
