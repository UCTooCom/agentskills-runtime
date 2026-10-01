# base-select Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>通过 <code>v-model</code> 设置被选中的 <code>tiny-option</code> 的 <code>value</code> 属性值。</p><br> | base-select/basic-usage.vue |
| multiple | 多选 | <br>            通过 <code>multiple</code> 属性启用多选功能，此时 <code>v-model</code> 的值为当前选中值所组成的数组。默认选中值会以标签（Tag 组件）展示。<br><br>            通过 <code>multiple-limit</code> 属性限制最多可选择的个数，默认为 0 不限制。<br><br>            设置 <code>show-limit-text</code> 可展示选中条数和限制总条数的占比，默认为 false 不展示。<br><br>            多选时，通过给 option 标签配置 <code>required</code> 或者在 options 配置项中添加 <code>required</code> 属性，来设置必选选项。<br><br>            通过 <code>dropdown-icon</code> 属性可自定义下拉图标，<code>drop-style</code> 属性可自定义下拉选项样式。<br><br>         | base-select/multiple.vue |
| collapse-tags | 折叠标签 | <p>通过 <code>collapse-tags</code> 属性设置选中多个选项时，多个标签缩略展示。设置 <code>show-proportion</code> 可展示当前选中条数和总条数占比，默认值为 <code>false</code> 。设置 <code>hover-expand</code> 为 <code>true</code> ，默认折叠标签，<code>hover</code> 时展示所有标签。标签内容超长时超出省略，<code>hover</code> 标签时展示 <code>tooltip</code> 。</p><br> | base-select/collapse-tags.vue |
| multiple-mix | 仅显示 | <p>Form 表单内 Select 组件不同尺寸设置 <code>hover-expand</code> 和 <code>display-only</code> 属性的综合应用。</p><br> | base-select/multiple-mix.vue |
| tag-type | 标签类型 | <p>通过 <code>tag-type</code> 属性设置标签类型，同 Tag 组件的 type 属性。可选值：success / info / warning / danger。</p><br> | base-select/tag-type.vue |
| size | 尺寸 | <p>通过 <code>size</code> 属性设置输入框尺寸，可选值：medium / small / mini。</p> | base-select/size.vue |
| disabled | 禁用 | <p>通过 <code>disabled</code> 属性设置下拉或者下拉项的禁用状态。</p><br> | base-select/disabled.vue |
| clearable | 可清除 | <p>通过 <code>clearable</code> 属性启用一键清除选中值的功能。仅适用于单选。</p><br> | base-select/clearable.vue |
| filter-method | 可搜索 | <p>通过 <code>filterable</code> 属性启用搜索功能。<code>filter-method</code> 自定义过滤方法。 <code>no-match-text</code> 属性自定义与搜索条件无匹配项时显示的文字。</p><br> | base-select/filter-method.vue |
| remote-method | 远程搜索 | <p>通过 <code>filterable</code> 和 <code>remote</code> 和 <code>remote-method</code> 这三个属性同时使用设置远程搜索。通过 <code>reserve-keyword</code> 属性设置多选可搜索时，可以在选中一个选项后保留当前的搜索关键词。</p><br><p>通过 <code>trim</code> 属性去除双向数据绑定值空格。</p> | base-select/remote-method.vue |
| searchable | 下拉面板可搜索 | <p>通过 <code>searchable</code> 属性设置下拉面板显示搜索框，默认不显示。</p><br> | base-select/searchable.vue |
| allow-create | 创建条目 | <p>通过 <code>allow-create</code> 和 <code>filterable</code> 属性，设置当搜索字段不在已有选项中时，可创建为新的条目。结合 <code>default-first-option</code> 属性，可以按 Enter 键选中第一个匹配项。</p><br><p>设置 <code>top-create</code> 属性后，Select 下拉框中会显示新增按钮，点击按钮会抛出一个 <code>top-create-click</code> 事件，可以在事件中自定义一些行为。</p> | base-select/allow-create.vue |
| map-field | 映射字段 | 通过 <code>text-field</code> 设置显示文本字段，<code>value-field</code>设置绑定值字段。 | base-select/map-field.vue |
| popup-style-position | 弹框样式与定位 | <p>通过 <code>popper-class</code> 属性设置下拉弹框的类名，可自定义样式。<code>placement</code>设置弹出位置。<code>popper-append-to-body</code> 设置是否将弹框 dom 元素插入至 body 元素，默认为 true。</p><br> | base-select/popup-style-position.vue |
| input-box-type | 输入框类型 | <p>通过 <code>input-box-type</code> 属性设置输入框类型。可选值：input / underline。</p><br> | base-select/input-box-type.vue |
| show-alloption | 不展示全选 | <p>通过 <code>show-alloption</code> 属性设置多选时不展示 <code>全选</code> 选项，默认展示。</p><br> | base-select/show-alloption.vue |
| clear-no-match-value | 自动清除不匹配的值 | <p>通过 <code>clear-no-match-value</code> 属性设置 v-model 的值在 options 中无法找到匹配项的值会被自动清除，默认不清除。 </p><br> | base-select/clear-no-match-value.vue |
| optimization | 虚拟滚动 | <p>通过 <code>optimization</code> 开启大数据虚拟滚动功能。仅配置式（使用 options 属性）时支持。<br>多选模式下，最大选中项数 <code>multiple-limit</code> 默认值为 20，如果选中项比较多，建议开启 <code>collapse-tags</code> 进行折叠显示。</p><br> | base-select/optimization.vue |
| option-group | 分组 | <p>使用 <code>tiny-option-group</code> 组件对备选项进行分组。通过 <code>label</code> 属性设置分组名，<code>disabled</code> 属性设置该分组下所有选项为禁用。</p><br> | base-select/option-group.vue |
| copy-single | 单选可复制 | <p>通过 <code>allow-copy</code> 属性设置单选可搜索时，鼠标可滑动选中并复制输入框的内容。</p><br> | base-select/copy-single.vue |
| copy-multi | 多选可复制 | <p>通过 <code>tag-selectable</code> 属性设置输入框中标签可通过鼠标选择，然后按 Ctrl + C 或右键进行复制。<code>copyable</code> 属性设置启用一键复制所有标签的文本内容并以逗号分隔。</p><br> | base-select/copy-multi.vue |
| native-properties | 原生属性 | <p>通过 <code>name</code> / <code>placeholder</code> / <code>autocomplete</code> 属性设置下拉组件内置 Input 的原生属性。</p><br> | base-select/native-properties.vue |
| binding-obj | 绑定值为对象 | <p>通过 <code>value-key</code> 属性设置 value 唯一标识的键名，绑定值可以设置为对象。</p><br> | base-select/binding-obj.vue |
| no-data-text | 空数据文本 | <p>通过 <code>no-data-text</code> 属性设置选项为空时显示的文本，<code>show-empty-image</code> 属性设置是否显示空数据图片，默认不显示。</p><br> | base-select/no-data-text.vue |
| manual-focus-blur | 手动聚焦失焦 | <p>通过 <code>focus()</code> 方法聚焦，<code>blur()</code>方法失焦。</p><br> | base-select/manual-focus-blur.vue |
| automatic-dropdown | 获焦即弹出 | <p>通过 <code>automatic-dropdown</code> 设置不可搜索的 select 获得焦点并自动弹出选项菜单。</p><br> | base-select/automatic-dropdown.vue |
| is-drop-inherit-width | 继承宽度 | <p>通过 <code>is-drop-inherit-width</code> 属性设置下拉弹框的宽度是否跟输入框保持一致。默认超出输入框宽度时由内容撑开。</p><br> | base-select/is-drop-inherit-width.vue |
| hide-drop | 隐藏下拉 | <p>通过 <code>hide-drop</code> 属性设置下拉列表不显示。</p><br> | base-select/hide-drop.vue |
| filter-mode | 过滤器模式 | <p>通过 <code>shape</code> 属性设置为 <code>filter</code> 切换至过滤器模式。过滤器模式下可传入 label 显示标题，tip 显示提示信息，clearable 是否显示清除按钮，placeholder 显示占位符。</p><br><p>通过 <code>blank</code> 属性将过滤器背景设置为透明。</p> | base-select/filter-mode.vue |
| cache-usage | 自动缓存 | <p>通过 <code>cache-op</code> 开启缓存功能，仅配置式生效。</p><br> | base-select/cache-usage.vue |
| memoize-usage | 手动缓存 | <p>使用 tiny-option 组件，则需要手动加入缓存功能。</p><br> | base-select/memoize-usage.vue |
| slot-default | 选项插槽 | <p>通过 tiny-option 的 <code>default</code> 插槽自定义选项的 HTML 模板。</p><br> | base-select/slot-default.vue |
| slot-footer | 底部插槽 | <p>通过 <code>footer</code> 插槽自定义下拉弹框底部的 HTML 模板。</p><br> | base-select/slot-footer.vue |
| slot-empty | 空数据插槽 | <p>通过 <code>empty</code> 插槽自定义没有选项列表时显示的 HTML 模板。</p><br> | base-select/slot-empty.vue |
| slot-prefix | 输入框前缀插槽 | <p>通过 <code>prefix</code> 插槽自定义输入框前缀的 HTML 模板。</p><br> | base-select/slot-prefix.vue |
| slot-reference | 触发源插槽 | <p>通过 <code>reference</code> 插槽自定义触发源的 HTML 模板。</p><br> | base-select/slot-reference.vue |
| slot-panel | 下拉面板插槽 | <p>通过 <code>panel</code> 插槽自定义下拉面板的内容。</p><br> | base-select/slot-panel.vue |
| slot-label | 标签插槽 | <p>通过 <code>label</code> 插槽自定义多选选中标签的 HTML 模板。</p><br> | base-select/slot-label.vue |
| all-text | 自定义全部文本 | 当下拉中显示全部时，通过<code>all-text</code> 属性自定义全部的显示文本 | base-select/all-text.vue |
| events | 事件 | <div class="tip custom-block"><p class="custom-block-title">事件说明</p><br><p>change：监听 v-model 的值发生变化。</p><br><p>clear：监听单选时，点击清空按钮。</p><br><p>blur：监听 input 失去焦点。</p><br><p>focus：监听 input 获得焦点。</p><br><p>visible-change：监听下拉框可见状态的变化。</p><br><p>remove-tag：监听多选移除选中的标签。</p><br><p>dropdown-click：监听下拉图标的点击事件。</p><br></div><br> | base-select/events.vue |
