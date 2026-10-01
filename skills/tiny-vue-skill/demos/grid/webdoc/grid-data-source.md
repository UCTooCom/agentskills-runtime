# grid Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| data-source-static-data | 绑定静态数据 | <p>表格属性设置 <code>data</code> 开启双向绑定静态数据。</p><br> | grid/data-source/static-data.vue |
| data-source-request-service | 开启服务请求 | <p>表格属性设置 fetch-data 开启服务请求。表格首次加载服务数据的时机默认是在 mounted 阶段，如果开了 prefetch 开关就在 created 阶段开始加载。可以设置 prefetch 为数组，指定后端排序字段参数，作为数据接口方法参数 sortBy。例如：[{ property: 'name', order: 'desc' }]，参考示例：</p><br> | grid/data-source/request-service.vue |
| data-source-auto-load | 自动加载数据 | <p>表格属性 <code>auto-load</code> 设置是否开启自动请求服务，配置 fetch-data 时有效。如下示例设置 <code>auto-load</code> 为 false 后，就不会自动加载数据。</p><br> | grid/data-source/auto-load.vue |
| data-source-columns | 表格列的配置信息 | <p>通过表格属性 <code>columns</code> 设置表格列的配置信息。</p><br> | grid/data-source/columns.vue |
| data-source-column-asyn-rendering | 开启异步渲染 | <p>异步渲染配置步骤：<br>1、表格属性设置 <code>is-async-column</code> 开启异步渲染；<br>2、表格列设置 <code>format-config</code> 开启该列数据异步渲染。</p><br> | grid/data-source/column-asyn-rendering.vue |
| data-source-defslot-protochain-fetch | 插槽中使用复杂数据 | <p>兼容低版本的复杂数据访问（例如：row.attr1.attr2.attr3），参考示例。<br>在列初始化过程中，使用 `skip` 插槽参数可以跳过默认插槽内容的执行，参考示例。<br>在表格渲染过程中，没有提供这个参数，始终不会跳过默认插槽内容的执行。</p><br> | grid/data-source/defslot-protochain-fetch.vue |
| undefined-field-defalut-value | 缺省数据的默认值 | <br>        <p>在可编辑表格组件中，当编辑器检测到当前数据行缺少对应字段时，会自动创建该字段。字段的初始化值遵循以下规则：</p><br>        <p>1. 若配置了 <code>editor.defaultValue</code>，则使用该值作为初始值</p><br>        <p>2.若未配置 <code>editor.defaultValue</code>，则默认使用 <code>null</code>作为初始值</p> | grid/data-source/undefined-field-defalut-value.vue |
