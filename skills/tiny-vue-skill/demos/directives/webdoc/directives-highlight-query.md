# directives Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 通过自动高亮搜索字指令，可以自动搜索某个<code>Dom</code>元素内所有匹配的字符，将其高亮。 | directives/highlight-query/basic-usage.vue |
| avoid | 避免场景 | 纯文字节点在<code>Vue</code> 编译时有特殊处理。自动高亮搜索字的指令是直接操作<code>Dom</code>节点的内容，所以要避免纯文本节点。以下 2 个场景会造成<code>Vue</code> 更新机制失败。 | directives/highlight-query/avoid.vue |
