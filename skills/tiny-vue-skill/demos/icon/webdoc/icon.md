# icon Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <br>          从 <code>@opentiny/vue-icon</code> 图标库中引入图标函数，图标函数执行后生成一个有效的 <code> Vue </code> 图标组件，可以在模板中使用。在组件内应该保存图标组件的变量用于绑定，要避免在模板上直接绑定图标函数的执行。<br><br>          通过修改图标的 <code>font-size</code> 的样式，指定图标的大小，通过修改<code>fill</code> 的样式指定图标的颜色。<br>          <div class="tip custom-block"><br>            <p class="custom block title"> 常见的图标使用方式 </p><br>            以 <code>Shared</code>图标组件为例：<br><br>            1、在模板中通过标签式引入。比如 <code> &lt;tiny-shared /&gt; </code> <br><br>            2、在模板中通过<code> &lt;component&gt; </code> 组件引入。比如 <code> &lt;component :is="tinyShared" /&gt; </code> <br><br>            3、在组件属性中传入。比如 <code> &lt;tiny-button :icon="tinyShared" &gt; </code> <br><br>            4、避免模板绑定图标函数的执行。不建议 <code> &lt;component :is="IconShared()" /&gt; </code> <br>          </div><br>         | icon/basic-usage.vue |
| show-title | 显示 Title | 图标组件自身上指定 <code>title</code> 属性无效，需要通过其父元素的 <code>title</code> 属性实现提示功能。 | icon/show-title.vue |
| advance-icons | 标准图标合集 | Saas业务梳理 600 多个标准图标，Saas业务的应用必须使用标准图标。它新增了三大功能：支持线性、面性图标切换，支持双色切换和托底效果。<br><br>                  通过<code>shape</code> 属性，设置图标的线性或面性图标，它支持<code>'line' \| 'filled' </code>, 默认为线性图标 。<br><br><br>                  通过<code>firstColor, secondColor</code>属性，设置图标的主色和副色。<br><br><br>                  通过<code>underlay</code>属性，设置图标的托底效果。默认样式： { background:'#eef3fe', borderRadius:'4px',scale:0.8 } <br><br>                   | icon/advance-usage.vue |
| list | 图标集合 | 输入图标名称进行搜索，点击图标即可快速复制名称。 | icon/list.vue |
