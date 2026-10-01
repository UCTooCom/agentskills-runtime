# exception Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 |  | exception/basic-usage.vue |
| page-empty | 页面级异常 | <p>通过添加`page-empty`属性展示页面级异常，其中 type 类型有`pagenoperm`、 `pageweaknet`、 `pagenothing`、 `pageservererror`<br> 对应场景：<br>`pagenoperm` ：无访问权限<br>`pageweaknet` ：网络异常<br>`pagenothing` ：你访问的页面不存在<br>`pageservererror`：服务器异常 </p> | exception/page-empty.vue |
| component-page | 组件级异常 | <p>通过添加`component-page`属性展示组件级异常，其中 type 类型有`noperm`、 `nodata`、 `weaknet`、 `noresult`、 `nonews`<br> 对应场景：<br>`noperm` ：无访问权限<br>`nodata` ：暂无数据<br>`weaknet` ：网络不给力<br>`noresult`：无相关搜索结果<br>`nonews`：暂无最新消息<br></p> | exception/component-page.vue |
| sub-message | 自定义二级标题内容 | <p>通过`sub-message`自定义二级标题</p> | exception/sub-message.vue |
| button-text | 自定义按钮文本 | <p>已去除`button-text`自定义按钮文本，直接可以通过插槽自定义</p> | exception/button-text.vue |
| slot | 插槽 | <p>通过命名插槽 `content`，自定义内容区</p> | exception/slot.vue |
