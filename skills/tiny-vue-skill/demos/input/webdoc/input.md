# input Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>详细用法参考如下示例。</p> | input/basic-usage.vue |
| clearable | 一键清空 | <p>可通过 <code>clearable</code> 属性设置输入框显示清空图标按钮。</p> | input/clearable.vue |
| disabled | 禁用 | <p>可通过 <code>disabled</code> 属性设置输入框的禁用状态。</p> | input/disabled.vue |
| show-password | 密码框 | <p>当 <code>type</code> 为 <code>password</code> 时，可通过 <code>show-password</code> 属性设置输入框显示密码显示/隐藏切换图标按钮。</p><br> | input/show-password.vue |
| show-tooltip | 只读态悬浮提示 | <p>通过 <code>show-tooltip</code> 配置当文本超长时，是否显示悬浮提示。</p><br> | input/show-tooltip.vue |
| size | 尺寸 | <p>可通过 <code>size</code> 属性设置尺寸大小，可选值：<code>medium / small / mini</code>。注意：只在 <code>type!="textarea"</code> 时有效。</p><br> | input/size.vue |
| methods | 实例方法 | 可使用组件的实例方法。 | input/methods.vue |
| input-icon | 图标 | <p>可通过 <code>prefix-icon, suffix-icon</code> 属性设置输入框头部、尾部图标。</p><br> | input/input-icon.vue |
| slot | 插槽 | <p>配置 <code>prepend, append, prefix, suffix</code> slot，设置输入框前置、后置、头部、尾部内容，注意：只对 <code>type=text</code> 有效。</p> | input/slot.vue |
| mask | 掩码 | <p><br>          <p>可通过 mask 属性启用掩码功能，只在 disabled 和 display-only 状态下生效。</p><br>          <p>注意：不要与 type="password" 和 show-password 一同使用</p><br>        </p> | input/mask.vue |
| rows | 文本域行数与宽 | <br>          <p>可通过 <code>rows</code> 属性设置文本域显示行数。注意：只在 <code>type="textarea"</code> 时有效。</p><br>          <p>可通过 <code>cols</code> 属性设置文本域显示宽度。注意：只在 <code>type="textarea"</code> 时有效。</p><br>         | input/rows.vue |
| resize | 可缩放文本域 | <p>可通过 <code>resize</code> 属性设置文本域的缩放。可选值：<code>none / both / horizontal / vertical</code>。注意：只在 <code>type="textarea"</code> 时有效。</p><br> <p>可通过 <code>autosize</code> 属性设置文本域自适应内容高度。可传入对象，如<code>{ minRows: 2, maxRows: 6 }</code>。注意：只对 <code>type="textarea"</code> 有效。</p><br><p>可通过 <code>hover-expand</code> 属性设置文本域鼠标悬浮展开/收起，只对 <code>type=textarea</code> 有效，最好搭配 <code>autosize</code> 一起使用<p> | input/resize.vue |
| show-word-limit | 输入字数统计 | <p>可通过 <code>show-word-limit</code> 属性设置是否显示输入字数统计，只在 type = "text" 或 type = "textarea" 时有效。</p> | input/show-word-limit.vue |
| counter | 计数器 | <p>可通过 <code>counter</code> 属性设置显示输入框字符计数器。</p><br> | input/counter.vue |
| validate-event | 表单校验 | <p>可通过 <code>validate-event</code> 属性设置输入时触发表单校验。通过 <code>trigger</code> 配置触发校验规则的方式，为 <code>change</code> 时，当输入框值改变即触发校验，为 <code>blur</code> 时则失焦后触发校验。</p><br> | input/validate-event.vue |
| display-only | 内容只读 | <p>可通过 <code>display-only</code> 或<code>display-only-content</code> 属性设置只读态。</p> | input/display-only.vue |
| method-addMemory | 记忆历史输入 | <p>通过组件实例方法 <code> addMemory </code> 添加历史输入数据，输入完成后，输入会被记住。通过 <code> memory-space </code> 属性配置最多可以被记录的条数。</p> | input/method-addMemory.vue |
| type | 类型 | <p>通过对应的 <code>type</code> 属性，可以设置为对应的类型。默认为 text，可选值为 text，textarea 和其他 原生 input 的 type 值。</p><br> | input/type.vue |
| native | 原生属性 | <br>        <p>可设置 <code>name</code>  <code>disabled</code> <code>readonly</code>等原生属性。</p><br>         <div class="tip custom-block"><br>            <p class="custom-block-title"> 温馨提示： </p><br>            <p>原生属性是透传给 <code> input </code>原生标签的，功能和使用原生标签等同。</p><br>          </div><br>         | input/native.vue |
| display-only-popup-more | 文本域只读超出显示更多按钮 | 在只读的基础上增加<code>popup-more</code>属性，可使文本域超出显示更多按钮，点击更多按钮可以查看详细信息。 | input/display-only-popup-more.vue |
| input-box-type | 边框模式 | 通过 <code>input-box-type</code>属性，设置边框模式，可取值为 <code>"normal" \| "underline"</code> 。 | input/input-box-type.vue |
| event | 事件 | <br>          输入框的事件，包括:<br><br>            <code>input</code>(输入值时触发), <br><br>            <code>blur</code>(失去焦点时触发), <br><br>            <code>focus</code>(获取焦点时触发), <br><br>            <code>change</code>(值改变时触发), <br><br>            <code>clear</code>(清除按钮时触发)。 | input/event.vue |
