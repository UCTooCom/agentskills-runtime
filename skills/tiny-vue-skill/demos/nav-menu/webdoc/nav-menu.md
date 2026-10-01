# nav-menu Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 通过 <code>data</code> 配置菜单数据。 | nav-menu/basic-usage.vue |
| overflow | 超出显示 | 当一级菜单内容过多溢出时，通过 <code>overflow</code> 配置显示方式，共有 <code>auto</code>、<code>retract</code>、<code>fixed</code>、<code>hidden</code> 4 种方式，默认为 <code>auto</code>。<br>          <div class="tip custom-block"><p class="custom-block-title">overflow 选项说明</p><br><p><br>          auto：菜单栏右侧显示 <code>更多</code> 菜单，鼠标悬停该菜单时，将显示剩余未展示的菜单；<br/><br>          fixed：菜单栏左侧显示 <code>三明治折叠/展开</code> 图标，鼠标悬停该图标时，将显示所有菜单；<br/><br>          retract：菜单栏不显示任何菜单，只显示 <code>三明治折叠/展开</code> 图标，鼠标悬停该图标时，将显示所有菜单；<br/><br>          hidden：剩余未展示的菜单隐藏不显示。</p></div> | nav-menu/overflow.vue |
| slot-toolbar | 定义工具栏 | 通过 <code>toolbar</code> 插槽自定义工具栏。 | nav-menu/slot-toolbar.vue |
| slot-logo | 定义 Logo | 通过 <code>logo</code> 插槽自定义 Logo。 | nav-menu/slot-logo.vue |
| before-skip | 跳转前处理 | 通过 <code>before-skip</code> 钩子函数处理菜单点击跳转前的相关逻辑，返回 <code>false</code> 则无法跳转。 | nav-menu/before-skip.vue |
| before-skip-prevent | 默认服务的跳转前处理 | 若使用默认服务 <code>/workspace/current</code> 获取菜单数据 <code>response.data.leftMenuNode.children</code>，则在使用 <code>before-skip</code> 时，需配合 <code>prevent</code> 为 <code>true</code> 来阻止默认的跳转行为。 | nav-menu/before-skip-prevent.vue |
| selecte | 自定义选中菜单 | 通过 <code>default-active</code> 自定义当前选中的菜单。 | nav-menu/selecte.vue |
| custom-service | 自定义服务 | 通过 <code>fetch-menu-data</code> 自定义菜单服务，若数据中字段并非默认的 <code>title</code> 和 <code>url</code>，则通过 <code>fields</code> 对数据中的字段进行映射。 | nav-menu/custom-service.vue |
| parent-key | 转换树结构数据 | 通过 <code>parent-key</code> 标识的普通数组转换树结构数据。 | nav-menu/parent-key.vue |
| allow-full-url | 支持完整 URL | 通过 <code>allow-full-url</code> 支持数据中包含完整 URL。 | nav-menu/allow-full-url.vue |
