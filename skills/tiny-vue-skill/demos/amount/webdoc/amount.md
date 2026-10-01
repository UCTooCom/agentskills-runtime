# amount Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 详细用法参考如下示例 | amount/basic-usage.vue |
| set-date | 设置日期 | <p>通过 <code>date</code> 属性设置日期后，将会在金额组件中显示日期框。值可设置为 string 或者 Date() 类型。<br>通过 <code>change</code> 获取改变后的值。</p><br> | amount/set-date.vue |
| size | 编辑框大小 | <p>可选择的类型：<code>medium</code>，<code>small</code>，<code>mini</code></p><br> | amount/size.vue |
| custom-currency | 指定币种 | <p>默认显示币种为 CNY，可通过 <code>currency</code> 指定需要的币种，若指定的币种在返回的服务数据中不存在，则币种下拉框将不显示该币种。</p><br> | amount/custom-currency.vue |
| digits-maxlen | 金额设置 | <p>设置 <code>digits</code> 属性可指定金额小数位数，默认为 2 位。设置 <code>max-len</code> 属性指定整数位最大可输入长度，默认为 15 位。</p><br> | amount/digits-maxlen.vue |
| custom-service | 自定义服务 | <p><code>fetchCurrency</code> 指定自定义服务，<code>fields</code> 可指定显示字段和值设置在服务数据中的字段映射。</p><br> | amount/custom-service.vue |
| amount-disable | 禁用 | <p>通过 <code>disabled</code> 配置 Amount 组件禁用。</p><br> | amount/amount-disable.vue |
