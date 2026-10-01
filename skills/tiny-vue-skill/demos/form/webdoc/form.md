# form Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 常用表单 | <p>在 <code>Form</code> 组件中，每一个表单域由一个 <code>form-item</code> 组件构成，表单域中可以放置各种类型的表单控件，包括 <code>Input</code> 、 <code>Select</code> 、 <code>Checkbox</code> 、 <code>Radio</code> 、 <code>Switch</code> 、 <code>DatePicker</code> 、 <code>TimePicker</code> 等。</p> | form/basic-usage.vue |
| form-in-row | 行内表单 | <p>通过 <code>inline</code> 设置行内表单，当垂直方向空间受限且表单较简单时，可以在一行内放置表单项。 <code>label-suffix</code> 设置表单标签后缀。</p> | form/form-in-row.vue |
| label-position | 标签宽度与标签位置 | <p>通过 <code>label-width</code> 设置标签宽度，<code>label-position</code> 设置文本标签的位置。</p> | form/label-position.vue |
| label-align | 必填星号文本对齐 | <p>当 <code>label-position</code> 为 <code>left</code> 时，通过 <code>label-align</code> 设置必填星号出现时标签文本是否对齐。</p> | form/label-align.vue |
| overflow-title | 标签超长显示提示 | <p>通过 <code>overflow-title</code> 设置标签超长时鼠标移动到标签上可显示 <code>tooltip</code> 提示，若使用 <code>label</code> 插槽，需自行实现。</p> | form/overflow-title.vue |
| form-validation | 表单校验、移除校验 | <p>通过 <code>rules</code> 设置校验规则，<br>          调用 <code>clearValidate</code> 方法移除表单项的校验结果。传入待移除的表单项的 <code>prop</code> 属性或者 <code>prop</code> 组成的数组，如不传则移除整个表单的校验结果，<br>          调用 <code>resetFields</code> 方法重置表单并移除校验结果<br>          </p> | form/form-validation.vue |
| form-validate-field | 特定表单项校验 | <p>通过 <code>validateField</code> 方法对特定表单项进行校验， <code>clearValidate</code> 方法移除特定表单项校验， <code>resetField</code> 重置表单项并移除校验。</p> | form/form-validate-field.vue |
| custom-validation-rule | 自定义校验规则 | <p>通过 <code>rules</code> 的 <code>validator</code> 选项进行自定义校验，校验方法中 <code>callback</code> 必须被调用。通过 <code>validate-on-rule-change</code> 设置是否在 <code>rules</code> 属性改变后立即触发一次验证。</p> | form/custom-validation-rule.vue |
| custom-validation-string-length | 自定义字符串长度 | <p>通过 <code>rules</code> 的 <code>regular</code> 进行自定义字符串长度</p> | form/custom-validation-string-length.vue |
| validation-position | 校验提示位置 | <p>通过 <code>validate-position</code> 可自定义错误提示出现的位置，在 <code>form</code> 组件上设置后，子组件 <code>form-item</code> 会继承父组件设置。单独在 <code>form-item</code> 组件上进行设置优先级高于在 <code>form</code> 上的设置。</p> | form/validation-position.vue |
| novalid-tip | 隐藏表单项校验提示 | <p>通过 <code>show-message</code> 设置是否显示校错误提示信息。</p> | form/novalid-tip.vue |
| validate-type | 校验提示的形式 | <p>通过 <code>validate-type</code> 设置校验提示信息是以 <code>text</code> 文本显示还是以 <code>tip</code> 提示框的形式显示，也可直接配置在某一个 <code>form-item</code> 上控制某一项的校验提示形式。</p> | form/validate-type.vue |
| message-type | 文本类型错误提示位置 | <p>当 <code>validate-type</code> 为 <code>text</code> 时，通过 <code>message-type</code> 设置文本类型错误提示位置，不设置则为 <code>absolute</code> 定位。</p> | form/message-type.vue |
| validate-debounce | 校验防抖处理 | <p>通过 <code>validate-debounce</code> 设置校验防抖，在连续输入的情况下，会在最后一次输入结束时才开始校验。</p> | form/validate-debounce.vue |
| size | 表单尺寸 | <p>通过 <code>size</code> 设置表单内组件尺寸。注意：表单中设置的 size 优先级高于数据录入组件（ <code>input</code> 、<code>select</code> 等）设置的 <code>size</code> 。</p> | form/size.vue |
| slot-label | 标签文本插槽 | <p>通过 <code>label</code> 插槽，自定义标签文本的内容。</p> | form/slot-label.vue |
| form-disabled | 表单禁用 | <p>通过 <code>disabled</code> 设置表单是否禁用，默认为 <code>false</code> 。</p> | form/form-disabled.vue |
| display-only | 表单仅展示 | <p>通过 <code>display-only</code> 配置表单是否开启仅展示模式。</p> | form/display-only.vue |
| form-row-col | 复杂布局 | <p>通过配合 <code>row</code> 和 <code>col</code> 组件来实现复杂布局。</p> | form/form-row-col.vue |
| group-form | 分组表单 | <p>将多个表单组合在一起。</p> | form/group-form.vue |
| hide-required | 必填项红色星号 | <p>通过 <code>hide-required-asterisk</code> 设置是否隐藏标签前的红色星号，默认为 <code>false</code> 。</p> | form/hide-required.vue |
| popper-options | 错误提示跟随页面 | <p>通过 <code>popper-options</code> 设置<code>tip</code>类型错误提示，例如：当表单父元素是滚动元素，且页面滚动后，提示会错位，将 <code>bubbling</code> 属性设置为 <code>true</code>可解决此问题。</p> | form/popper-options.vue |
| error-slot | 错误提示插槽 | <p>通过 <code>error</code> 插槽，自定义标签文本的内容。</p> | form/error-slot.vue |
| extra-tip | 额外提示信息 | <p>通过 <code>extra</code> 配置额外提示信息。</p> | form/extra-tip.vue |
| events | 表单事件 | <p>任一表单项被校验后触发 <code>validate</code>事件。</p> | form/events.vue |
