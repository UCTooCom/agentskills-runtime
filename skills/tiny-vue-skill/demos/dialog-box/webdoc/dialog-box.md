# dialog-box Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 可通过<code>visible</code>属性设置控制弹窗显示。 | dialog-box/basic-usage.vue |
| secondary-dialog | 二级弹窗 | <p>可通过<code>#default</code>默认插槽和底部操作区按钮设置实现二级弹窗。设置<code>append-to-body</code>属性后，二级弹窗的实体<code>DOM</code>结构将追加到<code>body</code>元素上。</p><br> | dialog-box/secondary-dialog.vue |
| custom-dialog-title | 自定义标题 | <p>可通过<code>title</code> 或者<code>#title</code>插槽设置弹窗标题内容。</p><br> | dialog-box/custom-dialog-title.vue |
| custom-dialog-content | 自定义内容 | <p>可通过<code>#default</code>默认插槽设置自定义弹窗主体部分的内容。</p><br> | dialog-box/custom-dialog-content.vue |
| custom-dialog-footer | 自定义底部 | <p>可通过<code>#footer</code> 插槽设置自定义弹窗底部操作区内容。</p><br> | dialog-box/custom-dialog-footer.vue |
| hidden-close-buttons | 隐藏关闭按钮 | <p>可通过<code>show-close</code>属性设置<code>false</code>后，隐藏关闭图标，默认弹窗右上角显示关闭图标。底部<code>click</code>按钮事件可切换<code>visible</code>属性值设置弹窗显示。</p><br> | dialog-box/hidden-close-buttons.vue |
| close-on-press-escape | 禁用 ESC 关闭 | <p>可通过<code>close-on-press-escape</code>属性设置<code>false</code>后可禁用按下<code>Esc</code>键关闭弹窗。</p><br> | dialog-box/close-on-press-escape.vue |
| dialog-top-height | 弹窗距离顶部的高度 | <p>可通过<code>top</code>属性设置指定弹窗距离窗口顶部的高度，默认为屏高的 15% 。</p><br> | dialog-box/dialog-top-height.vue |
| dialog-width | 弹窗的宽度和最大高度 | <p>可通过<code>width</code>属性设置指定弹窗的宽度，<code>max-height</code>属性设置窗口最大高度。</p><br> | dialog-box/dialog-width.vue |
| close-on-click-modal | 点击遮罩时不关闭弹窗 | <p>可通过<code>close-on-click-modal</code>属性设置<code>false</code>后可禁用单击遮罩层关闭弹窗。</p><br> | dialog-box/close-on-click-modal.vue |
| no-modal | 不启用遮罩层 | <p>可通过<code>modal</code>属性设置<code>false</code>不启用遮罩层。无遮罩层时，单击弹窗外部区域仍然可以关闭弹窗。</p><br> | dialog-box/no-modal.vue |
| right-dialog | 右侧弹窗 | <p>可通过<code>right-slide</code>属性为设置<code>true</code>，弹窗将从窗口右侧弹出。<code>modal-append-to-body</code> 属性默认<code>true</code>遮罩层应用在<code>body</code>。</p><br> | dialog-box/right-dialog.vue |
| double-dialog-height | 右侧双层弹框 | 右侧弹窗分两种情况，父级弹框自动缩进，子级弹框高度撑满。父级弹框不缩进，子级弹框高度自适应。 | dialog-box/double-dialog-height.vue |
| hidden-header | 隐藏标题区域 | <p>可通过<code>show-header</code>属性设置<code>false</code>，将隐藏标题区域。</p><br> | dialog-box/hidden-header.vue |
| lock-scroll | 弹出时禁用滚动 | <p>可通过<code>lock-scroll</code>属性设置<code>true</code>,允许滚动遮罩内容，禁止滚动背景内容，单击遮罩层可关闭弹窗。设置<code>lock-scroll</code>为<code>false</code>,允许滚动遮罩内容、背景内容。</p><br> | dialog-box/lock-scroll.vue |
| center | 头部和底部水平居中 | <p>可通过<code>center</code>属性设置<code>true</code>头部标题居中显示。(默认显示在区域左侧)</p><br> | dialog-box/center.vue |
| draggable | 可拖拽的弹窗 | <p>可通过<code>draggable</code>属性设置<code>true</code>，鼠标点击标题区域拖拽；通过<code>drag-outside-window</code>属性设置<code>true</code>，将弹窗拖出窗口。具体事件：<code>@drag-start</code><code>@drag-move</code><code>@drag-end</code>。</p><br> | dialog-box/draggable.vue |
| fullscreen | 全屏弹窗 | <br>          可通过<code>fullscreen</code>属性设置弹窗是否为全屏状态，默认值 为 <code>false</code>。<br><br>          可通过<code>resize</code>属性设置弹窗是否有切换全屏的功能，默认值 为 <code>false</code>。<br><br>          可通过<code>resize</code>事件，监听弹窗切换全屏的事件。<br><br>           | dialog-box/fullscreen.vue |
| form-in-dialog | 弹窗表单 | <p>可通过<code>is-form-reset</code>属性设置<code>false</code>,关闭弹窗不重置数据，<code>resize</code>属性设置窗口最大化。</p> | dialog-box/form-in-dialog.vue |
| destroy-on-close | 关闭时销毁主体元素 | <p>可通过<code>destroy-on-close</code>属性设置<code>true</code>在关闭弹窗时销毁<code>Dialog-box</code>对话框内的所有元素，默认值为<code>false</code>。</p> | dialog-box/destroy-on-close.vue |
| open-close-events | 弹出与关闭事件 | <p>可通过设置事件<code>@open</code>：对话框打开时触发，<code>@opened</code>：对话框打开动画结束时触发，<code>@close</code>：对话框关闭时触发，<code>@closed</code>：对话框关闭动画结束时触发。</p><br> | dialog-box/open-close-events.vue |
| before-close | 关闭前拦截 | <br>          可通过设置属性<code>before-close</code>,设置对话框关闭前时触发的拦截函数。<br>          也可以通过绑定事件<code>before-close</code>,但它们的用法有细微差异，详见下面示例 | dialog-box/before-close.vue |
| transition-effect | 启用弹出动效 | <p>可通过配置 <code>dialog-transition</code> 属性为 <code>enlarge</code>，可启用 <code>DialogBox</code> 打开时逐渐放大的动效。</p> | dialog-box/transition-effect.vue |
