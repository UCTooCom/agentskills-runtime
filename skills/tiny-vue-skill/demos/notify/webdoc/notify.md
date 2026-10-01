# notify Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <br>          通过<code>Notify</code>函数，在页面上弹出通知框组件。<br><br>          通过 <code>title</code>  属性设置通知框标题。<br><br>          通过 <code>message</code>  属性设置通知框的内容。<br><br>          <div class="tip custom-block"><br>            <p class="custom-block-title"> 小技巧 </p><br>             标题和内容不仅支持字符串传入，还支持<code> jsx </code> 和 <code>h</code> 函数的写法。<br>          </div><br>         | notify/basic-usage.vue |
| type | 消息类型 | <p>可通过 <code>type</code> 设置不同的类型。可选值：success、warning、info、error，默认值：info。</p><br> | notify/type.vue |
| duration | 自动关闭延时 | 通过 <code>duration</code>  属性设置自动关闭的延迟时间，默认情况， <code>success  info </code> 延时 5 秒 <code> warning  error </code> 延时 10 秒自动关闭。 | notify/duration.vue |
| position | 显示位置 | <p>可通过 <code>position</code>  属性设置通知框显示位置，默认值：bottom-right。</p><br> | notify/position.vue |
| showClose | 不显示关闭按钮 | <p> <code>showClose</code> 属性设置通知框是否显示关闭按钮，默认值：<code>true</code> 。</p><br> | notify/showClose.vue |
| showIcon | 不显示类型图标 | <p>可通过 <code>showIcon</code>  属性设置通知框是否显示类型图标，默认值：true。</p><br> | notify/showIcon.vue |
| closeIcon | 自定义关闭图标 | <p>可通过 <code>closeIcon</code>  属性设置通知框关闭图标，默认值：IconClose。</p><br> | notify/closeIcon.vue |
| statusIcon | 自定义类型图标 | <p>可通过 <code>statusIcon</code>  属性设置通知框类型图标，默认值：IconInfoSolid。</p><br> | notify/statusIcon.vue |
| debounceDelay | 防抖 | <p>可通过 <code>debounceDelay</code> 设置防抖时间。 | notify/debounceDelay.vue |
| verticalOffset | 垂直偏移量 | <p>可通过 <code>verticalOffset</code> 设置垂直方向偏离距离。 | notify/verticalOffset.vue |
| manual-close | 手动关闭通知 | <br>          通过<code>Notify</code>函数弹出通知后，会返回一个对应的<code>instance</code>对象，并保存在组件库的内部闭包变量中。<br><br>          需要手动关闭通知时，可以调用 <code>instance.close()</code> 方法关闭该通知。<br><br>          在<code>Notify</code>函数中，还存在 2 个静态方法去关闭通知。<br><br>          1、<code>Notify.close :(id, beforeClose)=>void </code>, 关闭指定的通知。其中<code>id</code>可通过<code>instance</code>对象获取。 <br><br>          2、<code>Notify.closeAll :()=>void </code>, 关闭所有通知。<br><br>         | notify/manual-close.vue |
| notify-events | 事件 | <p><br>          <div>可通过 <code>beforeClose</code>  属性设置通知框关闭前的事件。</div><br>          <div>可通过 <code>onClose</code> 属性设置通知点击关闭按钮时触发事件。</div><br>        </p> | notify/notify-events.vue |
