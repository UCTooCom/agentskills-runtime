# grid Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| toolbar-insert-delete-update | 基本用法 | <br>        <div class="tip custom-block"><br>          <p class="custom-block-title">工具栏配置步骤：</p><br>          <ul><br>            <li>1、表格以插槽方式引入表格工具栏组件 <code>GridToolbar</code>，并设置工具栏组件属性 <code>slot=&quot;toolbar&quot;</code> 。</li><br>            <li>2、设置工具栏组件属性 <code>buttons</code> 进行按钮组相关配置。</li><br>            <li>3、表格事件设置 <code>@toolbar-button-click</code> 获取工具栏 <code>buttons</code> 的事件，用户可自定义实现增删改操作的业务逻辑。</li><br>          </ul><br>        </div><br>        <div class="tip custom-block"><br>          <p class="custom-block-title">新增的行需要标记新增状态的样式时需要配置 edit-config 的 markInsert 项为 true。</p><br>        </div> | grid/toolbar/insert-delete-update.vue |
| toolbar-cancel-delete | 取消删除 | <p>在工具栏中配置 <code>mark_cancel</code> 的 code，勾选数据后，单击 <code>删除/取消删除</code> 按钮，勾选的数据将标记删除线。再单击 <code>保存</code> 按钮请求服务删除标记的数据。已标记删除线的数据勾选后再次单击 <code>删除/取消删除</code> 按钮，会取消删除线。<br> 需要配置 fetch-data 请求服务时才有标记删除线和取消删除线的效果。<br></p><br> | grid/toolbar/cancel-delete.vue |
| toolbar-clear-data | 清空数据 | <p>clearData 方法手动清空单元格内容，如果不传参数，则清空整个表格内容。如果传了行则清空指定行内容，如果传了指定字段，则清空该字段内容。具体参考下面示例。</p><br> | grid/toolbar/clear-data.vue |
| toolbar-insert-remove-rows | 插入或删除指定行 | <p>通过 <code>insertAt(records, row)</code> 方法可以在指定行插入一行或多行数据。<code>remove(rows)</code> 方法可以删除指定一行或多行数据，rows 为对象则是一行，数组则是多行数据，为空则删除所有数据。</p><br> | grid/toolbar/insert-remove-rows.vue |
| toolbar-save-data | 服务端数据保存和删除 | <p>通过表格属性 <code>save-data</code> 服务端数据保存方法。<br>通过表格属性 <code>delete-data</code> 服务端数据删除方法。</p><br> | grid/toolbar/save-data.vue |
| toolbar-copy-row-data | 工具栏尺寸大小 | <p>通过 <code>size</code> 属性设置工具栏尺寸大小，包括 large、medium、small、mini 四种不同大小。不设置时为默认尺寸。</p> | grid/toolbar/copy-row-data.vue |
| toolbar-refresh-grid | 开启表格刷新功能 | <br>        <p>设置工具栏组件属性 <code>refresh</code> 开启表格刷新功能。</p><br>        <ul><br>          <li>设置表格属性 <code>loading</code> 开启/关闭加载中。自定义实现刷新时直接调用<code>handleFetch('reload')</code>。</li><br>        </ul> | grid/toolbar/refresh-grid.vue |
| toolbar-grid-full-screen | 开启表格全屏功能 | <p>设置工具栏组件属性 <code>full-screen</code> 开启表格全屏功能。</p><br> | grid/toolbar/grid-full-screen.vue |
| toolbar-grid-full-screen-height | 全屏时改变表格高度 | <p>通过表格属性 <code>height</code> 在全屏是动态改变表格高度。</p> | grid/toolbar/grid-full-screen-height.vue |
| toolbar-grid-full-screen-teleport | 推荐基于 Teleport 的全屏方案 | <p>通过 <code>teleport</code> 实现表格全屏。</p> | grid/toolbar/grid-full-screen-teleport.vue |
| toolbar-custom-toolbar | 工具栏自定义插槽 | <p>通过工具栏组件的插槽 <code>#buttons</code> 自定义内容。</p> | grid/toolbar/custom-toolbar.vue |
| toolbar-toolbar-op-config | 配置式工具栏写法 | <p>通过 <code>v-bind</code> 绑定一个对象来实现配置式。在绑定的对象中 <code>toolbar</code> 字段用于工具栏配置，可配合 <code>events</code> 字段对工具栏中按钮进行 <code>toolbarButtonClick</code> 事件配置。另外，<code>pager</code> 字段用于分页配置，<code>fetchData</code> 字段用于请求服务。</p><br> | grid/toolbar/toolbar-op-config.vue |
| toolbar-toolbar-op-config-slots | 配置式工具栏插槽 | <p>通过表格属性 <code>toolbar.slots</code> 配置工具栏插槽 <code>buttons</code> 和 <code>tools</code>。</p> | grid/toolbar/toolbar-op-config-slots.vue |
