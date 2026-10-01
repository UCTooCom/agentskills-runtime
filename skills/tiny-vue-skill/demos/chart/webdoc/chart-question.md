# chart Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| question-base | 父元素的初始宽度未知 1 | <p>在一个初始宽度未知的容器内绘制图表时，因为无法获取宽度，所以图表会绘制失败，解决的办法是在容器宽度已知后，<br>调用 echarts 的 resize 方法。<br>通过 <code>cancel-resize-check</code> 是用于 resize 之前，检测组件元素是否存在，元素是否有宽高，没有则不 resize。</p><br> | chart/question/base.vue |
| question-demo5 | 父元素的初始宽度未知 2 | 当父元素改变时，图表需要执行 resize 方法同步图表的宽高。 | chart/question/demo5.vue |
| question-demo4 | 数据改变视图自动更新 | <p>图表是基于 Vue 开发的，同样支持 <code>双向数据绑定</code>，只要改变图表数据 <code>(示例中的 chartData.row)</code> 视图会自动更新。</p><br> | chart/question/demo4.vue |
| question-demo2 | 小数显示精度 1 | <p>处理数据类型时默认保留两位有效数字，但是当数字较小并设置为百分比类型时，这种方式会导致显示上的问题，例如：</p><br> | chart/question/demo2.vue |
| question-demo3 | 小数显示精度 2 | 每个图表内都有 digit 配置项，设置此属性，保证设置类型后，数值较小也能够正常显示，如下所示： | chart/question/demo3.vue |
