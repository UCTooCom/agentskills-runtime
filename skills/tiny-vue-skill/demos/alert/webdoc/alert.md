# alert Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>通过 <code>description</code> 属性或者 <code>description</code> 插槽来设置提示内容。<br> 通过 <code>type</code> 属性，设置不同的类型。</p> | alert/basic-usage.vue |
| size | 尺寸模式 | <br>          通过 <code>size</code> 设置不同的尺寸模式，可选值： <code>small</code> 、<code>medium</code> 、<code>normal</code> 、<code>large</code> 。<br><br>          <div class="tip custom-block"><br>            <p class="custom-block-title"> 尺寸模式区别 </p><br>            <ul><br>              <li> <code>small</code> 、<code>medium</code> 、<code>normal</code> 模式下，不会显示标题和交互操作的区域，相当于简单模式。</li> <br>              <li> <code>large</code> 模式下，显示全部元素，相当于完整模式。</li> <br>            </ul><br>          </div><br>         | alert/size.vue |
| title | 自定义标题 | 当 <code>size</code> 为 <code>large</code> 时，通过 <code>title </code>属性或 <code>title </code>插槽，可以自定义组件的标题 ，通过 <code> show-title </code>属性控制标题是否显示<br><br>           如果未自定义标题，会根据对应的 <code>type</code> 显示相应的默认标题。 | alert/title.vue |
| center | 内容居中 | <p>通过 <code>center</code> 设置内容显示居中。</p> | alert/center.vue |
| icon | 自定义警告图标 | 通过 <code>icon </code> 属性设置自定义图标，如果未自定义图标，默认会根据不同的 <code>type</code> 的值自动使用对应图标。 | alert/icon.vue |
| slot-default | 自定义交互操作 | <p>当 <code>size</code> 为 <code>large</code> 时，通过默认插槽自定义交互操作区域，显示在  <code>description</code> 值的下方。</p> | alert/slot-default.vue |
| show-icon | 是否显示图标 | 通过 <code>show-icon</code> 属性，设置左侧图标是否显示。 | alert/show-icon.vue |
| custom-close | 自定义关闭按钮 | <br>          通过 <code>closable</code> 属性，启用内置的关闭图标，默认值为 <code>true</code>。<br /><br>          通过 <code>close-text</code> 设置关闭按钮显示为文本，仅当<code>closable</code>为<code>true</code>时生效。<br /><br>          将 <code>closable</code> 设置为 <code>false</code> 时，取消内置的关闭功能。此时可通过 <code>close</code> 插槽，完全自定义关闭按钮区域的展示。<br>          <div class="tip custom-block"><br>            <p class="custom-block-title"> 组件关闭或隐藏时，会有渐隐动画，详见示例！ </p><br>          </div><br>         | alert/custom-close.vue |
| custom-class | 自定义类名 | <p>通过 <code>custom-class</code> 设置自定义类名。</p> | alert/custom-class.vue |
