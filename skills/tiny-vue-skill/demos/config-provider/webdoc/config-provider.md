# config-provider Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| base | 基本使用 | 通过 <code>design</code> 属性可以自定义不同设计规范的图标和逻辑。从 3.23.0 版本开始，支持全局配置组件的任意 <code>props</code> 属性（仅支持双层组件），例如：可以全局配置 Form 组件必填项星号的默认显示状态、Button 组件的点击防抖时间以及是否默认显示圆角等。 | config-provider/base.vue |
| text-direct | 改变文字方向 | 可通过<code>direction="ltr"</code>属性设置文字对齐方向，<code>ltr</code>为左对齐，<code>rtl</code>为右对齐。 | config-provider/text-direct.vue |
| tag | 自定义标签 | 可通过<code>tag</code>属性设置自定义容器标签。 | config-provider/tag.vue |
| theme | 自定义主题色 | 可通过<code>theme</code>属性设置自定义主题色常量。 | config-provider/theme.vue |
