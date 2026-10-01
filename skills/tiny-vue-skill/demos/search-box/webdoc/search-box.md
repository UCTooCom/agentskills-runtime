# search-box Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基础用法 |  通过 items 配置搜索数据项。  | search-box/basic-usage.vue |
| append-to-body | 挂载到 body |  通过 append-to-body 配置将下拉面板挂载到 body。  | search-box/append-to-body.vue |
| panel-max-height | 面板最大高度 |  通过 panel-max-height 配置下拉面板最大高度。  | search-box/panel-max-height.vue |
| split-input-value | 切分输入值 |  通过 split-input-value='\|' 将输入值按字符 \| 分成多个关键字，一次性输入生成多个标签，默认 , 分隔。  | search-box/split-input-value.vue |
| default-field | 自定义默认搜索项 |  通过  default-field  配置按照可用地区进行搜索。  | search-box/default-field.vue |
| v-model | 默认包含筛选项 |  通过 model-value 配置默认选中标签项。  | search-box/v-model.vue |
| empty-placeholder | 没有筛选项时的占位文本 |  通过 empty-placeholder 配置筛选项为空时占位文本。  | search-box/empty-placeholder.vue |
| id-map-key | 指定筛选项的ID键取值 |  通过 id-map-key 配置用来识别筛选项的 id 键取值来源，默认取自 items 的 id 键，<br>                一般用于接口返回的 items 数据字段不匹配，但是又需要其中一个键值来识别筛选项的情况。  | search-box/id-map-key.vue |
| potential-options | 潜在匹配项 |  通过 potential-options 配置潜在匹配项。  | search-box/potential-match.vue |
| group-key | 自定义属性分组 |  通过  item.groupKey   自定义一级下拉框属性分组。  | search-box/group-key.vue<br>search-box/group-key-data.ts |
| help | help 提示场景 |  通过 show-help 控制帮助图标显隐，使用 help 事件回调自定义弹窗提示内容。  | search-box/help.vue |
| editable | 可编辑 |  标签支持可编辑功能，通过  editable   打开编辑功能，（注：map 类型不支持编辑）。  | search-box/editable.vue<br>search-box/editable-data.ts |
| item-placeholder | 数据项占位文本 |  通过   item.placeholder  设置占位文本，  item.editAttrDisabled  设置编辑状态下此属性类型不可切换。  | search-box/item-placeholder.vue |
| auto-match | 自动匹配 |  内置自动匹配功能，通过 :show-no-data-tip="false" 隐藏面板的无数据提示，通过 search 监听搜索事件， change 监听搜索值变化事件。  | search-box/auto-match.vue |
| merge-tag | 合并多选标签 |  通过  mergeTag   合并多选标签，（注：仅多选标签支持合并功能）。  | search-box/merge-tag.vue |
| max-length | 输入长度限制 |  通过  maxlength   原生属性限制输入不超过8个字符长度，配合  exceed  监听输入超出限定长度的事件。  | search-box/max-length.vue |
| max-time-length | 时间长度限制 |  通过  maxTimeLength   传入某段时间的值（毫秒数），来限制可选择的时间跨度，常用于防止请求时间跨度过大的情形。  | search-box/max-time-length.vue |
| custom-panel | 自定义二级下拉面板 |  通过  item.type = 'custom'   开启自定义二级下拉面板功能，并在 item.slotName  自定义对应的二级面板插槽名，对应的编辑态自定义面板插槽名为 `${item.slotName}-edit` 。  | search-box/custom-panel.vue |
| events | 事件 |  通过  first-level-select   监听第一层级选择事件。  | search-box/events.vue |
| suffix-icon | 后缀图标 |  通过  suffix-icon   配置后缀图标。  | search-box/suffix-icon.vue |
