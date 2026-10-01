# carousel Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 通过<code>arrow</code>属性设置左右箭头切换效果，<code>loop</code>属性是否循环显示，<code>autoplay</code>属性自动切换。 | carousel/basic-usage.vue |
| indicator-trigger | 指示器和触发方式 | <p>通过配置 <code>indicator-position</code> 为<code>outside</code>后，走马灯指示器默认显示在幻灯片内容上，将显示在外部。<br>配置 <code>trigger</code> 为<code>click</code>，可以修改指示器触发方式为单击，默认鼠标悬停到指示器时，走马灯幻灯片就会对应切换。</p><br> | carousel/indicator-trigger.vue |
| manual-play | 手动轮播 | <p>通过调用 <code>setActiveItem()</code>、<code>next()</code>、<code>prev()</code> 方法可根据需要进行轮播。<code>initial-index</code> 属性可以指定初始激活的幻灯片索引。</p><br> | carousel/manual-play.vue |
| close-loop | 关闭循环轮播 | <p>通过配置 <code>loop</code> 属性为<code>true</code>，<code>disabled</code> 属性为<code>true</code>后，若走马灯幻灯片已切换到最后一项，则将不能再从第一项开始循环切换。即切换到最后一项时，右侧切换箭头不再显示，切换到第一项时，左侧切换箭头不再显示。</p><br> | carousel/close-loop.vue |
| autoplay | 自动切换 | <p>通过配置 <code>autoplay</code> 属性为<code>true</code>后，走马灯的幻灯片内容将自动轮播切换。</p><br> | carousel/autoplay.vue |
| play-interval | 轮播间隔时间 | <p>通过 <code>interval</code> 属性可以自定义，走马灯幻灯片轮播间隔时间默认为 3000 毫秒。</p><br> | carousel/play-interval.vue |
| up-down-carousel | 纵向轮播 | <p>通过配置 <code>type</code> 属性为<code>vertical</code>即可实现纵向轮播。</p><br> | carousel/up-down-carousel.vue |
| show-title | 显示标题 | <p>通过 <code>title</code> 配置显示标题，需要与 <code>show-title</code> 结合使用。</p><br> | carousel/show-title.vue |
| carousel-arrow-always | 总是显示切换箭头 | 通过<code>arrow</code>设置属性为<code>always</code>。 | carousel/carousel-arrow-always.vue |
| carousel-arrow-hover | hover 时显示切换箭头 | 通过<code>arrow</code>设置属性为<code>hover</code>。 | carousel/carousel-arrow-hover.vue |
| carousel-arrow-never | 隐藏切换箭头 | 通过<code>arrow</code>设置属性为<code>never</code>。 | carousel/carousel-arrow-never.vue |
| card-mode | 卡片模式 | <p>通过配置 <code>type</code> 属性为<code>card</code>后，走马灯将以卡片形式进行展示。</p><br> | carousel/card-mode.vue |
| carousel-events | 走马灯事件 | <p>主要包含<code>change</code>事件。</p><br><p>当幻灯片切换时会触发该事件，回调函数可接收两个参数：<code>当前幻灯片索引</code>和<code>上一张幻灯片索引</code>。</p><br> | carousel/carousel-events.vue |
| card-show | 轮播卡片 | <p>通过设置 <code>default</code> 插槽，自定义卡片轮播场景。</p> | carousel/card-show.vue |
| dialog-show | 弹窗展示 | <p>在弹窗中嵌入轮播场景。</p> | carousel/dialog-show.vue |
