# cascader Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>通过 <code>options</code> 属性指定选项数组即可渲染出一个级联选择器。</p><br> | cascader/basic-usage.vue |
| expand-trigger | hover 触发子菜单 | <p>通过 <code>props.expandTrigger</code> 可以指定展开子级菜单的触发方式为 <code>hover</code>，默认为 <code>click</code> 。</p><br> | cascader/expand-trigger.vue |
| disabled-items | 禁用选项 | <p><br>            <div>通过在数据源<code>option</code>中设置 <code>disabled</code> 字段来声明该选项是禁用的，在默认情况下，Cascader 会检查数据中每一项的 <code>disabled</code> 字段是否为 <code>true</code>。</div><br>            <div>也可以通过直接设置 <code>disabled</code> 可以禁用组件。</div><br>          </p> | cascader/disabled-items.vue |
| clearable | 可清空 | <p>通过 <code>clearable</code> 属性设置输入框可清空。</p><br> | cascader/clearable.vue |
| clearable1 | 分隔符 | <p>通过 <code>separator</code> 属性设置分隔符。</p><br> | cascader/clearable.vue |
| size | 尺寸 | <p>通过 <code>size</code> 属性设置尺寸。</p><br> | cascader/size.vue |
| default-multiple | 多选 | <p>通过 <code>props.multiple = true</code> 来开启多选模式。</p><br> | cascader/default-multiple.vue |
| filter-mode | 过滤器模式 | <p><br>          <p>通过 shape='filter' 属性切换至过滤器模式。</p><br>          <p>过滤器模式下可传入 label 显示标题，tip 显示提示信息，clearable 是否显示清除按钮，placeholder 显示占位符，blank 背景为透明。</p><br>        </p> | cascader/filter-mode.vue |
| auto-size | 自适应高度 | <p>通过 auto-size 属性指定下拉弹框是否根据内容自适应高度。 </p> | cascader/auto-size.vue |
| collapse-tags | 折叠展示 Tag | <p>在开启多选模式后，默认情况下会展示所有已选中的选项的 Tag，可以使用 <code>collapse-tags</code> 来折叠 Tag。</p> | cascader/collapse-tags.vue |
| check-strictly | 父子级不相关联 | <p>通过 <code>props.checkStrictly = true</code> 来设置父子节点取消选中关联，从而达到选择任意一级选项的目的。默认单选模式下，只能选择叶子节点。</p><br> | cascader/check-strictly.vue |
| check-strictly-multiple | 多选选择任意一级选项 | <p>在多选模式下同时取消父子节点关联，选择任意一级选项。</p><br> | cascader/check-strictly-multiple.vue |
| auto-load | 动态加载 | <br>          <p><br>            <div>当选中某一级时，动态加载该级下的选项。</dvi><br>            <div>通过 <code>props</code> 属性中的 <code>lazy</code> 开启动态加载，并通过 <code>lazyload</code> 来设置加载数据源的方法。</div><br>            <div><code>lazyload</code> 方法有两个参数，第一个参数 node 为当前点击的节点，第二个 resolve 为数据加载完成的回调 (必须调用)。</div><br>            <p><br>              <div>为了更准确的显示节点的状态，默认地（默认指没有设置<code>props.leaf</code>）可以使用<code>leaf</code>字段。</div><br>              <div>表明此节点是否为叶子节点，否则会简单地以有无子节点来判断是否为叶子节点。</div><br>            </p><br>          </p><br>         | cascader/auto-load.vue |
| auto-load-checkStrictly | 动态加载且父子级不相关联 | <p>当选中某一级时，动态加载该级下的选项。通过 <code>props</code> 属性中的 <code>lazy</code> 开启动态加载，并通过 <code>lazyload</code> 来设置加载数据源的方法。通过 <code>props</code> 属性中的 <code>checkStrictly</code> 开启父子级不相关联。</p><br> | cascader/auto-load-checkStrictly.vue |
| props-children | 指定选项 | <p><br>          <div>通过 <code>props.children</code> 指定选项的子选项，默认为 'children' 。</div><br>          <div>通过 <code>props.value</code> 指定指定选项的 value 值，默认为 'value' 。</div><br>          <div>通过 <code>props.label</code> 指定选项标签，默认为 'label' 。</div><br>        <p/> | cascader/props-children.vue |
| filterable | 可搜索 | <p><br>            将 <code>filterable</code> 赋值为 <code>true</code> 即可打开搜索功能，默认会匹配节点的 <code>label</code> 或所有父节点的 <code>label</code> (由 <code>show-all-levels</code> 决定) 中包含输入值的选项。</br><br>            使用<code>empty</code> 插槽设置无匹配选项时显示的内容，使用<code>debounce</code>设置搜索延迟。<br>          </p> | cascader/filterable.vue |
| filterable-multiple | 多选可搜索 | <p>多选模式下开启搜索功能。</p><br> | cascader/filterable-multiple.vue |
| filter-method | 自定义搜索逻辑 | <p><code>filter-method</code> 自定义搜索逻辑，第一个参数是节点 node，第二个参数是搜索关键词 keyword，通过返回布尔值表示是否命中，如果需要搜索到父级，通过 props.checkStrictly = true 来设置父子节点取消选中关联，从而达到选择任意一级选项的目的。默认单选模式下，只能选择叶子节点。</p><br> | cascader/filter-method.vue |
| show-all-levels | 仅显示最后一级 | <p>属性 <code>show-all-levels</code> 定义了是否显示完整的路径，将其赋值为 <code>false</code> 则仅显示最后一级，默认为 <code>true</code> ，显示选中项所在的完整路径。</p><br> | cascader/show-all-levels.vue |
| events | 事件 | <p><br>            Cascader 级联选择器的事件有：<code>change</code>、<code>expand-change</code>、<code>blur</code>、<code>focus</code>、<code>visible-change</code>。<br>            <div>使用 <code>props.emitPath</code> 能设置节点的返回类型。</div><br>          </p> | cascader/events.vue |
| slot | 插槽 | <br>          通过 <code>default</code> 插槽，自定义级联节点。<br><br>          通过 <code>no-data</code> 插槽设置没有数据时显示的内容。<br>         | cascader/slot.vue |
