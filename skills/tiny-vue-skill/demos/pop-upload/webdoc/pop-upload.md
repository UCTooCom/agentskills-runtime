# pop-upload Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 通过 <code>action</code> 设置上传的服务接口， <code>upload-name</code> 设置上传的文件字段名，<code>data</code> 自定义上传时附带的额外参数。 | pop-upload/basic-usage.vue |
| custom-request-headers | 定义请求头部 | 通过 <code>with-credentials</code> 开启支持发送 cookie 凭证信息，<code>headers</code> 自定义上传请求头信息。 | pop-upload/custom-request-headers.vue |
| size | 尺寸和禁用 | 通过 <code>large</code>，<code>medium</code>，<code>small</code>，<code>mini</code> 设置组件尺寸，<code>disabled</code> 设置是否禁用，默认值为 false。 | pop-upload/size.vue |
| http-request | 自定义上传 | 通过 <code>http-request</code> 配置覆盖默认的上传行为，自定义上传的实现。 | pop-upload/http-request.vue |
| fill-button-text | 定义按钮和标题 | 通过 <code>dialog-title</code> 设置弹框的标题，<code>cancel-button-text</code> 设置取消按钮的文本，<br>          <code>submit-button-text</code> 设置提交按钮的文本， <code>upload-button-text</code> 设置上传按钮的文本。 | pop-upload/fill-button-text.vue |
| file-limit | 上传数限制 | 通过 <code>limit</code> 设置最大上传的文件数量，<code>multiple</code> 设置是否可同时选择多个文件。 | pop-upload/file-limit.vue |
| file-type | 限制文件类型和大小 | 通过 <code>max-upload-file-size</code> 设置上传文件的大小， <code>accept</code> 设置可上传的文件类型，还可通过 <code>upload-file-type</code> 指定在上传时进行校验的文件类型。 | pop-upload/file-type.vue |
| upload-tip | 自定义上传提示 | 通过 <code>uploadTip</code> 插槽自定义上传提示的内容块。 | pop-upload/upload-tip.vue |
| prevent-delete-file | 阻止删除 | 在 <code>before-remove</code> 处理移除文件前的逻辑，若返回 false 或者返回 Promise 且被 reject，则阻止删除。 | pop-upload/prevent-delete-file.vue |
| before-upload | 阻止上传 | 在 <code>before-upload</code> 回调中处理文件上传前的逻辑，若返回 false 或者返回 Promise 且被 reject，则阻止上传。 | pop-upload/before-upload.vue |
| upload-events | 事件 | <div class="tip custom-block"><code>remove</code> 监听文件移除事件；<br/> <code>error</code> 监听文件上传失败事件；<br/><br>          <code>exceed</code> 监听文件超出个数限制事件；<br/> <code>progress</code> 监听文件上传过程事件；<br/><br>          <code>success</code> 监听文件上传成功事件。</div> | pop-upload/upload-events.vue |
