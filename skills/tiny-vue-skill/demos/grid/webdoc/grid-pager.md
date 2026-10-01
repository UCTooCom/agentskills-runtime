# grid Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| pager-inner-default-pager | 使用默认分页组件 | <p>如果不配置 <code>{component: Pager}</code> 则默认使用内置的分页组件。</p><br> | grid/pager/inner-default-pager.vue |
| pager-inner-pager | 使用第三方分页组件 | <p><br>        <div class="tip custom-block"><br>          <p class="custom-block-title">第三方分页组件配置步骤：</p><br>          <ul><br>            <li> 1、<code>import</code> 引入自定义的分页组件（这里使用官方的分页组件示范） <code>Pager</code> 组件，即 <code>import Pager from '@opentiny/vue-pager'</code> 或者 <code>{ Pager } from '@opentiny/vue'</code> 。</li><br>            <li>2、<code>Pager</code> 传入给 <code>data()</code> 函数存储起来以便模板中使用。</li><br>            <li>3、表格属性设置 <code>pager</code> 进行分页相关配置，通过 <code>pager</code> 的属性 <code>{component: Pager}</code> 注入分页组件。</li><br>            <li>4、配置 seq-serial 属性可以设置翻页后序号连续显示，默认是不连续显示的。</li><br>          </ul><br>        </div><br>       | grid/pager/inner-pager.vue |
| pager-show-save-msg | 提示保存数据 | <p>配置 <code>showSaveMsg</code> 属性，当检查到表格数据存在修改时，会提示用户进行保存。</p><br> | grid/pager/show-save-msg.vue |
| pager-in-grid | 自定义分页 | <p>表格内置分页组件需要和 <code>fetch-data</code> 属性配合使用，若使用 <code>data</code> 设置表格数据源，则需要使用自定义分页。</p><br> | grid/pager/pager-in-grid.vue |
