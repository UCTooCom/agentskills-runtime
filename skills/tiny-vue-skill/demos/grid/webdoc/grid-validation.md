# grid Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| validation-editing-validation | 编辑时校验 | <p><code>grid</code> 标签配置 <code>edit-config</code> 对象，并配置 <code>edit-rules</code> 对象来设置校验对象和校验规则。</p><br> | grid/validation/editing-validation.vue |
| validation-editing-isvalidalways-validation | 常显编辑器校验 | <p><code>grid</code> 标签配置 <code>edit-config</code> 对象且列配置 <code>type：visible</code> 且配置 <code>isValidAlways</code> 属性时，即列总是显示可编辑状态时，支持编辑时校验，并配置 <code>edit-rules</code> 对象来设置校验对象和校验规则。</p><br> | grid/validation/editing-isvalidalways-validation.vue |
| validation-row-data-valid | 数据关联校验 | <p>在自定义校验时，<code>validator</code>方法<code>rule</code>参数中可获取到当前行与列的信息。可以按业务的需求实现数据关联的校验逻辑。</p><br> | grid/validation/row-data-valid.vue |
| validation-custcomp | 自定义组件校验 | <p>在使用自定义组件时，组件需要实现<code>v-model</code>的功能。在使用插槽时想要实时校验需要手动触发组件的校验方法。</p><br> | grid/validation/custcomp.vue |
| validation-select-validation | 选中时校验 | <p><code>grid</code> 标签配置 <code>edit-config</code> 对象，并配置 <code>edit-rules</code> 对象来设置校验对象和校验规则，通过按钮点击事件调用 <code>this.$refs.basicGrid.validate()</code> 方法来触发表格校验，具体参考下面示例。</p><br> | grid/validation/select-validation.vue |
| validation-before-submit-validation | 提交前校验 | <p><code>grid</code> 标签配置 <code>edit-config</code> 对象，并配置 <code>edit-rules</code> 对象来设置校验对象和校验规则，通过按钮点击事件调用 <code>this.$refs.basicGrid.validate()</code> 方法来触发表格校验，具体参考下面示例。注意：如果传递了 callback 回调就不能正常 catch 到 validate 捕获到的错误。</p><br> | grid/validation/before-submit-validation.vue |
| validation-bubbling | 校验提示跟随单元格移动 | <p>通过配置 <code>tooltipConfig.popperOptions.bubbling</code> 为 <code>true</code> ，可实现表格的校验提示跟随其外部的滚动条滚动。</p><br> | grid/validation/bubbling.vue |
| validation-validation-scroll-to-col | 触发校验时自动定位到当前校验的单元格 | <p><code>grid</code> 编辑器引入 <code>TinyVue</code> 组件，标签配置 <code>edit-config</code> 对象，并配置 <code>edit-rules</code> 对象来设置校验对象和校验规则，通过按钮点击事件调用 <code>this.$refs.basicGrid.validate()</code> 方法来触发表格校验，具体参考下面示例。</p><br> | grid/validation/validation-scroll-to-col.vue |
| validation-tipconfig | 错误提示配置项 | <p>表格默认错误提示挂载在 <code>body</code> 上，可以通过设置 <code>tooltip-config</code> 的 <code>appendTobody</code> 设置为 <code>false</code> 来解决页面滚动时 tip 位置错误的问题。设置 <code>placement</code> 属性调整默认显示方向。<code>tooltip-config</code> 的配置可参考 tooltip 组件。</p><br> | grid/validation/tipconfig.vue |
| validation-asterisk-method | 隐藏必填星号 | <p>通过表格属性 <code>editRules</code> 可以配置表格的编辑规则，如果指定某一字段的 <code>required</code> 为 <code>true</code>，就会在表头显示必填星号。如果想要隐藏掉必填星号，可以通过表格属性 <code>validConfig</code> 配置一个方法 <code>asteriskMethod</code> 来控制，返回 <code>false</code> 则隐藏。参考示例：</p><br> | grid/validation/asterisk-method.vue |
| valid-config | 行内校验 | <p>配置 <code>validConfig.message</code> 为 <code>'inline'</code> 开启行内校验。</p><br> | grid/validation/valid-config.vue |
| highlight-error | 高亮所有检验错误 | <p> （该特性在试验阶段） 配置 <code>validConfig.highlightError</code> 为 <code>true</code> 高亮所有检验错误。</p><br> | grid/validation/highlight-error.vue |
