# grid Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| sort-default-sort | 默认排序 | <p>通过表格列设置 <code>sortable</code> 属性开启该列排序功能。</p><br> | grid/sort/default-sort.vue |
| sort-combinations-sort | 多字段组合排序 | <p>通过表格列设置 <code>sortable</code> 属性开启该列排序功能，然后设置 <code>sort-by</code> 属性实现多字段组合排序，数组列表就是排序的字段列表。</p><br> | grid/sort/combinations-sort.vue |
| sort-custom-sort | 自定义排序 | <p>通过表格列设置 <code>sortable</code> 属性开启该列排序功能，然后设置 <code>sort-method</code> 方法实现自定义排序。</p><br> | grid/sort/custom-sort.vue |
| sort-sort | 手动排序 | <p>通过 <code>sort(field, order)</code> 方法可手动对表格进行排序（如果 order 为空则自动切换排序）。</p><br> | grid/sort/sort.vue |
| sort-server-sort | 表格服务端排序 | <p>通过表格列设置 <code>sortable</code> 属性开启该列排序功能，然后表格设置 <code>remote-sort</code> 方法开启服务端排序。<br>该示例中的 <code>services/getGridMockData</code> 服务需要自行实现，示例模拟了远程服务返回的数据。</p><br> | grid/sort/server-sort.vue |
