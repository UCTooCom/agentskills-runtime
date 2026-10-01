# sticky Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>将需要粘性布局的标签或者组件放入 <code>sticky</code> 组件的默认插槽中，则组件滚出屏幕范围时，始终会固定在屏幕顶部。</p> | sticky/basic-usage.vue |
| offset | 偏移距离 | <p>通过设置 <code>offset</code> 属性来改变吸顶或吸底距离，默认值为 0。</p> | sticky/offset.vue |
| position | 固定位置 | 通过设置 <code>position</code> 属性来改变固定位置，可选值有 <code>top</code> 和 <code>bottom</code>，默认值为 <code>top</code> 。 | sticky/position.vue |
| target | 目标容器 | 通过 <code>target</code> 属性可以指定组件的容器，页面滚动时，组件会始终保持在容器范围内，当组件即将超出容器底部时，会固定在容器的底部。 | sticky/target.vue |
| events | 事件 | 通过配置 <code>change</code> 事件监听吸顶或吸底状态改变时触发的事件，<code>scroll</code> 事件监听滚动事件。 | sticky/events.vue |
