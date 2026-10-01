# select Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>通过 <code>v-model</code> 设置被选中的 <code>tiny-option</code> 的 <code>value</code> 属性值。</p><br> | select/basic-usage.vue |
| multiple | 多选 | <br>            通过 <code>multiple</code> 属性启用多选功能，此时 <code>v-model</code> 的值为当前选中值所组成的数组。默认选中值会以标签（Tag 组件）展示。<br><br>            通过 <code>multiple-limit</code> 属性限制最多可选择的个数，默认为 0 不限制。<br><br>            设置 <code>show-limit-text</code> 可展示选中条数和限制总条数的占比，默认为 false 不展示，非saas属性。<br><br>            多选时，通过给 option 标签配置 <code>required</code> 或者在 options 配置项中添加 <code>required</code> 属性，来设置必选选项。<br><br>            通过 <code>dropdown-icon</code> 属性可自定义下拉图标，<code>drop-style</code> 属性可自定义下拉选项样式。<br><br>         | select/multiple.vue |
| collapse-tags | 折叠标签 | <p>通过 <code>collapse-tags</code> 属性设置选中多个选项时，多个标签缩略展示。设置 <code>show-proportion</code> 可展示当前选中条数和总条数占比，默认值为 <code>false</code>，非saas属性 。设置 <code>hover-expand</code> 为 <code>true</code> ，默认折叠标签，<code>hover</code> 时展示所有标签。标签内容超长时超出省略，<code>hover</code> 标签时展示 <code>tooltip</code> 。</p><br> | select/collapse-tags.vue |
| multiple-mix | 仅显示 | <br>            通过<code>display-only</code> 属性，设置组件只显示文字。仅展示时，如果组件的选项要通过<code>options</code> 属性传入，可以优化组件加载速度。<br>  <br>            通过 <code>hover-expand</code> 设置多选时，鼠标移入触发标签的自动展开。<br>           | select/multiple-mix.vue |
| tag-type | 标签类型 | <p>通过 <code>tag-type</code> 属性设置标签类型，同 Tag 组件的 type 属性。可选值：success / info / warning / danger。</p><br> | select/tag-type.vue |
| size | 尺寸 | <p>通过 <code>size</code> 属性设置输入框尺寸，可选值：medium / small / mini。</p> | select/size.vue |
| disabled | 禁用 | <p>通过 <code>disabled</code> 属性设置下拉或者下拉项的禁用状态。</p><br> | select/disabled.vue |
| clearable | 可清除 | <p>通过 <code>clearable</code> 属性启用一键清除选中值的功能。仅适用于单选。</p><br> | select/clearable.vue |
| filter-method | 可搜索 | <br>          通过 <code>filterable</code> 属性，启用搜索功能。<br><br>          通过 <code>filter-method</code> 方法属性，自定义过滤方法。 <br><br>          通过 <code>no-match-text</code> 属性，自定义与搜索条件无匹配项时显示的文字。<br><br>          <div class="danger custom-block"><br>           在<code>filter-method</code>方法属性中，禁止通过修改组件的 <code>options</code>的个数，去控制过滤下拉列表选项。这样不匹配的<code>Option</code>组件会卸载，造成<code>Select</code>组件引用到被卸载的选项值时引发错误。正确的过滤函数应该参考本示例的用法。<br>          </div><br>           | select/filter-method.vue |
| remote-method | 远程搜索 | <p>通过 <code>filterable</code> 和 <code>remote</code> 和 <code>remote-method</code> 这三个属性同时使用设置远程搜索。通过 <code>reserve-keyword</code> 属性设置多选可搜索时，可以在选中一个选项后保留当前的搜索关键词。</p><br><p>通过 <code>trim</code> 属性去除双向数据绑定值空格。</p> | select/remote-method.vue |
| searchable | 下拉面板可搜索 | <p>通过 <code>searchable</code> 属性设置下拉面板显示搜索框，默认不显示。</p><br> | select/searchable.vue |
| allow-create | 创建条目 | <p>通过 <code>allow-create</code> 和 <code>filterable</code> 属性，设置当搜索字段不在已有选项中时，可创建为新的条目。结合 <code>default-first-option</code> 属性，可以按 Enter 键选中第一个匹配项。</p><br><p>设置 <code>top-create</code> 属性后，Select 下拉框中会显示新增按钮，点击按钮会抛出一个 <code>top-create-click</code> 事件，可以在事件中自定义一些行为。</p> | select/allow-create.vue |
| map-field | 映射字段 | 通过 <code>text-field</code> 设置显示文本字段，<code>value-field</code>设置绑定值字段。 | select/map-field.vue |
| popup-style-position | 弹框样式与定位 | <p>通过 <code>popper-class</code> 属性设置下拉弹框的类名，可自定义样式。<code>placement</code>设置弹出位置。<code>popper-append-to-body</code> 设置是否将弹框 dom 元素插入至 body 元素，默认为 true。</p><br> | select/popup-style-position.vue |
| input-box-type | 输入框类型 | <p>通过 <code>input-box-type</code> 属性设置输入框类型。可选值：input / underline。</p><br> | select/input-box-type.vue |
| show-alloption | 不展示全选 | <p>通过 <code>show-alloption</code> 属性设置多选时不展示 <code>全选</code> 选项，默认展示。</p><br> | select/show-alloption.vue |
| clear-no-match-value | 自动清除不匹配的值 | <p>通过 <code>clear-no-match-value</code> 属性设置 v-model 的值在 options 中无法找到匹配项的值会被自动清除，默认不清除。 </p><br> | select/clear-no-match-value.vue |
| optimization | 虚拟滚动 | <p>通过 <code>optimization</code> 开启大数据虚拟滚动功能。仅配置式（使用 options 属性）时支持。<br>多选模式下，最大选中项数 <code>multiple-limit</code> 默认值为 20，如果选中项比较多，建议开启 <code>collapse-tags</code> 进行折叠显示。</p><br> | select/optimization.vue |
| option-group | 分组 | <p>使用 <code>tiny-option-group</code> 组件对备选项进行分组。通过 <code>label</code> 属性设置分组名，<code>disabled</code> 属性设置该分组下所有选项为禁用。</p><br> | select/option-group.vue |
| copy-single | 单选可复制 | <p>通过 <code>allow-copy</code> 属性设置单选可搜索时，鼠标可滑动选中并复制输入框的内容。</p><br> | select/copy-single.vue |
| copy-multi | 多选可复制 | <p>通过 <code>tag-selectable</code> 属性设置输入框中标签可通过鼠标选择，然后按 Ctrl + C 或右键进行复制。<code>copyable</code> 属性设置启用一键复制所有标签的文本内容并以逗号分隔。</p><br> | select/copy-multi.vue |
| native-properties | 原生属性 | <p>通过 <code>name</code> / <code>placeholder</code> / <code>autocomplete</code> 属性设置下拉组件内置 Input 的原生属性。</p><br> | select/native-properties.vue |
| binding-obj | 绑定值为对象 | <p>通过 <code>value-key</code> 属性设置 value 唯一标识的键名，绑定值可以设置为对象。</p><br> | select/binding-obj.vue |
| no-data-text | 空数据文本 | <p>通过 <code>no-data-text</code> 属性设置选项为空时显示的文本，<code>show-empty-image</code> 属性设置是否显示空数据图片，默认不显示，非saas属性。</p><br> | select/no-data-text.vue |
| manual-focus-blur | 手动聚焦失焦 | <p>通过 <code>focus()</code> 方法聚焦，<code>blur()</code>方法失焦。</p><br> | select/manual-focus-blur.vue |
| automatic-dropdown | 获焦即弹出 | <p>通过 <code>automatic-dropdown</code> 设置不可搜索的 select 获得焦点并自动弹出选项菜单。</p><br> | select/automatic-dropdown.vue |
| is-drop-inherit-width | 继承宽度 | <p>通过 <code>is-drop-inherit-width</code> 属性设置下拉弹框的宽度是否跟输入框保持一致。默认超出输入框宽度时由内容撑开。</p><br> | select/is-drop-inherit-width.vue |
| hide-drop | 隐藏下拉 | <p>通过 <code>hide-drop</code> 属性设置下拉列表不显示。</p><br> | select/hide-drop.vue |
| filter-mode | 过滤器模式 | <p>通过 <code>shape</code> 属性设置为 <code>filter</code> 切换至过滤器模式。过滤器模式下可传入 label 显示标题，tip 显示提示信息，clearable 是否显示清除按钮，placeholder 显示占位符。</p><br><p>通过 <code>blank</code> 属性将过滤器背景设置为透明。</p> | select/filter-mode.vue |
| cache-usage | 自动缓存 | <p>通过 <code>cache-op</code> 开启缓存功能，仅配置式生效。</p><br> | select/cache-usage.vue |
| memoize-usage | 手动缓存 | <p>使用 tiny-option 组件，则需要手动加入缓存功能。</p><br> | select/memoize-usage.vue |
| nest-tree | 下拉树 | <p>通过 <code>render-type</code> 设置渲染为树类型，<code>tree-op</code> 设置树组件配置。</p> | select/nest-tree.vue |
| nest-grid | 下拉表格 | <p>通过 <code>render-type</code> 设置渲染为表格类型，<code>grid-op</code>设置表格配置。</p> | select/nest-grid.vue |
| nest-grid-disable | 下拉表格禁用选项 | <p>通过 <code>select-config</code> （多选）或 <code>radio-config</code> （单选）属性的 <code>checkMethod</code> 自定义禁用逻辑，返回 true (启用) / false (禁用)。配置 {trigger: "row"} 可以设置点击行选中数据。</p><br> | select/nest-grid-disable.vue |
| nest-grid-remote | 下拉表格远程搜索 | <p>同时使用 <code>remote</code> 和 <code>remote-method</code> 和 <code>filterable</code> 3 个属性开启远程搜索。通过 <code>remote-config</code> 设置自动搜索和显示展开按钮。</p><br>          <p>在多选模式下，可通过 <code>reserve-keyword</code>设置选中一个选项后依然保留搜索关键字。</p> | select/nest-grid-remote.vue |
| nest-grid-init-query | 下拉表格初始化查询 | <p><code>remote</code> 为 <code>true</code> 时，可设置 <code>init-query</code> 用于初始化列表数据，并可使用 <code>v-model</code> 绑定数据回显同时，可配置 <code>remote-method</code> 方法进行搜索。</p><br> | select/nest-grid-init-query.vue |
| extra-query-params | 下拉表格初始化查询传参 | <p><code>remote</code> 为 <code>true</code> 时，可设置 <code>extra-query-params</code> 传递额外的参数，用于 <code>init-query</code> 和 <code>remote-method</code> 方法的查询。</p><br> | select/extra-query-params.vue |
| nest-radio-grid-much-data | 下拉表格大数据 | 表格数据量很大时，会自动启用虚拟滚动，同 Grid 组件。 | select/nest-radio-grid-much-data.vue |
| init-label | 远程搜索设置初始化 label 值 | 通过<code>init-label</code>属性设置远程搜索或者嵌套树懒加载数据未获取到时显示的初始化 label 值。 | select/init-label.vue |
| slot-default | 选项插槽 | <p>通过 tiny-option 的 <code>default</code> 插槽自定义选项的 HTML 模板。</p><br> | select/slot-default.vue |
| slot-header-footer | 下拉框顶部和底部插槽 | <p>通过 <code>footer</code> 插槽自定义下拉弹框底部的 HTML 模板。通过 <code>dropdown</code> 插槽自定义下拉弹框顶部的 HTML 模板。</p><br> | select/slot-header-footer.vue |
| slot-empty | 空数据插槽 | <p>通过 <code>empty</code> 插槽自定义没有选项列表时显示的 HTML 模板。</p><br> | select/slot-empty.vue |
| slot-prefix | 输入框前缀插槽 | <p>通过 <code>prefix</code> 插槽自定义输入框前缀的 HTML 模板。</p><br> | select/slot-prefix.vue |
| slot-reference | 触发源插槽 | <p>通过 <code>reference</code> 插槽自定义触发源的 HTML 模板。</p><br> | select/slot-reference.vue |
| slot-label | 标签插槽 | <p>通过 <code>label</code> 插槽自定义多选选中标签的 HTML 模板。</p><br> | select/slot-label.vue |
| all-text | 自定义全部文本 | <br>          通过<code>all-text</code> 属性自定义下拉面板中，全部选中的自定义文字。<br><br>          通过<code>show-all-text-tag</code> 属性设置为 <code> true </code> 时，勾选全部后，输入框只显示 <code>all-text</code> 属性的指定的 Tag。该属性默认为 <code>false</code>。<br>         | select/all-text.vue |
| events | 事件 | <div class="tip custom-block"><p class="custom-block-title">事件说明</p><br><p>change：监听 v-model 的值发生变化。</p><br><p>clear：监听单选时，点击清空按钮。</p><br><p>blur：监听 input 失去焦点。</p><br><p>focus：监听 input 获得焦点。</p><br><p>visible-change：监听下拉框可见状态的变化。</p><br><p>remove-tag：监听多选移除选中的标签。</p><br><p>dropdown-click：监听下拉图标的点击事件。</p><br></div><br> | select/events.vue |
