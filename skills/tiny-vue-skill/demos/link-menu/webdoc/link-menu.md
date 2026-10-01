# link-menu Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| data-resource | 菜单设置 | <p>通过 <code>data</code> 属性设置菜单的数据源，同时在数据对象中可通过 <code>disabled</code> 设置该节点是否可被勾选。</p><br><br>          <p>通过 <code>title</code> 属性定义收藏菜单标题。</p><br><br>          <p>通过 <code>wrap</code> 属性设置菜单内容超长时换行显示。</p><br> | link-menu/data-resource.vue |
| menu-items | 可收藏栏目数 | <p>通过 <code>max-item</code> 属性指定可勾选并收藏的栏目数。指定 <code>default-expand-all</code> 为 false 时，打开菜单弹窗时所有节点为折叠状态。</p><br> | link-menu/menu-items.vue |
| get-menu-data-sync | 自定义菜单数据服务 | <p>通过 <code>get-menu-data-sync</code> 自定义菜单数据服务。</p><br> | link-menu/get-menu-data-sync.vue |
| custom-icon | 图标及内容设置 | <p>通过 <code>icon</code> 属性自定义折叠展开图标。通过 <code>search-icon</code> 属性自定义搜索图标。<code>ellipsis</code> 属性设置菜单内容超长时省略显示。</p><br> | link-menu/custom-icon.vue |
| custom-foot | 自定义菜单弹窗底部 | <p>通过 <code>foot</code> 插槽自定义菜单弹窗的底部内容。<code>sureNodevalue</code> 方法用于获取选中的菜单节点并关闭菜单弹窗，同时展示选中的菜单。<code>hideDialog</code> 方法用于关闭弹窗。插槽可结合这两个方法一起使用。</p><br> | link-menu/custom-foot.vue |
