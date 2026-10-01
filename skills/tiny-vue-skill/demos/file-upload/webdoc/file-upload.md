# file-upload Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | 通过 <code>action</code> 设置上传的服务器地址， <code>data</code> 设置上传时附带的额外参数。 | file-upload/basic-usage.vue |
| disabled | 禁用 | 通过 <code>disabled</code> 设置禁用功能。 | file-upload/disabled.vue |
| multiple-file | 文件多选 | 通过 <code>multiple</code> 设置实现文件多选，默认单选。 | file-upload/multiple-file.vue |
| manual-upload | 手动上传 | 通过 <code>auto-upload</code> 取消自动上传，配合 <code>submit</code> 实例方法手动上传。 | file-upload/manual-upload.vue |
| accept-file-image | 限制文件类型 | 通过 <code>accept</code> 设置限制上传文件的格式只能为图片类型。 | file-upload/accept-file-image.vue |
| max-file-count | 最大上传数 | 通过 <code>limit</code> 设置限制上传文件的个数， <code>is-hidden</code> 设置达到最大上传数时是否隐藏上传按钮。 | file-upload/max-file-count.vue |
| custom-prefix | 文件选择前确认 | 通过 <code>before-add-file</code> 执行文件选择之前的钩子，若返回 <code>false</code> 或者返回 <code>Promise</code> 且被 <code>reject</code>，则停止添加文件。<br>          如果不用以上 2 种方式，也可以通过执行回调函数继续进行上传，参数为回调函数。 | file-upload/custom-prefix.vue |
| before-upload-limit | 自定义上传前限制 | 通过 <code>before-upload</code> 执行上传文件前的操作，对文件类型和大小做限制，返回 <code>false</code> 或 <code>reject</code> 则阻止上传。 | file-upload/before-upload-limit.vue |
| prevent-delete-file | 阻止删除文件 | 通过 <code>before-remove</code> 执行移除文件前的操作，返回 <code>false</code> 或 <code>reject</code> 则阻止删除。 | file-upload/prevent-delete-file.vue |
| upload-request | 定义请求头部 | 通过 <code>headers</code> 配置上传请求头部信息， <code>with-credentials</code> 设置允许发送 cookie 凭证信息。 | file-upload/upload-request.vue |
| http-request | 覆盖默认请求 | 通过 <code>http-request</code> 配置覆盖默认的上传行为，自定义上传的实现。 | file-upload/http-request.vue |
| drag-upload | 拖拽文件上传 | 通过 <code>drag</code> 设置能否拖拽文件上传，若配置了 <code>accept</code> 属性，则通过监听 <code>drop-error</code> 事件来操作不合规的拖拽文件信息。 | file-upload/drag-upload.vue |
| paste-upload | 粘贴上传 | 通过 <code>paste-upload</code> 设置能否粘贴文件上传， <code>max-name-length</code> 限制文件名显示的字符数。 | file-upload/paste-upload.vue |
| upload-file-list | 文件列表 | 通过 <code>file-list</code> 设置上传的文件列表，也可通过 <code>:show-file-list="false"</code> 关闭列表的显示； <code>open-download-file</code> 设置文件是否可下载。 | file-upload/upload-file-list.vue |
| file-size | 文件大小限制 | <p>通过 <code>file-size</code> 配置上传文件的大小。<p> | file-upload/file-size.vue |
| file-size-array | 文件大小范围 | <p>通过 <code>file-size</code> 配置为数组类型限制上传文件的大小范围。<p> | file-upload/file-size-array.vue |
| prompt-tip | tip 提示 | <p>通过 <code>promptTip</code> 为 `true` 设置提示为 tip 类型，悬浮图标时显示 tip 提示。<p> | file-upload/prompt-tip.vue |
| upload-file-list-slot | 定义文件列表 | 通过 <code>name</code> 设置上传的文件字段名， <code>file</code> 插槽自定义文件列表。 | file-upload/upload-file-list-slot.vue |
| upload-file-list-thumb | 列表弹窗显示 | 通过 <code>list-type="thumb"</code> 开启文件列表弹窗显示， <code>thumb-option</code> 设置弹窗相关数据。 | file-upload/upload-file-list-thumb.vue |
| upload-file-list-saas | SaaS 风格文件列表 | 通过 <code>list-type = saas</code> 切换 SaaS 风格文件列表。 | file-upload/upload-file-list-saas.vue |
| show-download-bar | 下载进度条 | 通过给 file 对象设置 <code>showDownloadBar=true</code> 可以显示下载进度条， <code>downloadPercentage</code> 属性传入下载进度， <code>downloadStatus</code> 设置下载状态。 | file-upload/show-download-bar.vue |
| picture-card | 照片墙 | 通过设置 <code>list-type="picture-card"</code> 开启照片墙模式， <code>preview</code> 监听此模式下的图片预览按钮的点击事件。 | file-upload/picture-card.vue |
| file-picture-card | 定义照片墙列表 | 通过 <code>downloadFile</code> 实例方法实现下载功能， <code>handleRemove</code> 实例方法实现删除功能。 | file-upload/file-picture-card.vue |
| picture-list | 图片列表缩略图 | 通过设置 <code>list-type="picture"</code> 实现图片列表缩略图显示。 | file-upload/picture-list.vue |
| clear-files | 手动清空列表 | 通过 <code>clearFiles</code> 实例方法实现清空已上传的文件列表（注意：该方法不支持在 <code>before-upload</code> 中调用）。 | file-upload/clear-files.vue |
| abort-quest | 手动取消上传请求 | 通过 <code>abort</code> 实例方法取消上传请求。 | file-upload/abort-quest.vue |
| form-validation | 表单校验 | 通过 <code>form</code> 表单结合，实现表单校验。 | file-upload/form-validation.vue |
| upload-user-head | 用户头像上传 | 通过 <code>URL.createobjectURL</code> 创建出文件的 URL 对象，用来展示头像。 | file-upload/upload-user-head.vue |
| image-size | 获取图片原始尺寸 | 通过 <code>FileReader.readAsDataURL()</code> 读取文件中的内容，获取图片的原始尺寸。 | file-upload/image-size.vue |
| custom-trigger | 触发源插槽 | 通过 <code>trigger</code> 插槽自定义文件选择触发源的内容，有触发文件选项框弹出的功能。 | file-upload/custom-trigger.vue |
| custom-upload-tip | 定义上传提示 | 通过 <code>tip</code> 插槽自定义上传提示， <code>re-uploadable</code> 启用重新上传功能， <code>re-upload-tip</code> 自定义重新上传提示的左侧文字。 | file-upload/custom-upload-tip.vue |
| encrypt-config | 水印和加密 | 通过 <code>encrypt-config</code> 开启水印和加密弹窗配置。 | file-upload/encrypt-config.vue |
| upload-events | 事件 | <div class="tip custom-block"><code>preview</code> 监听文件点击事件；<br/> <code>remove</code> 监听文件移除事件；<br/> <code>error</code> 监听文件上传失败事件；<br/><br>          <code>exceed</code> 监听文件超出个数限制事件；<br/> <code>progress</code> 监听文件上传过程事件；<br/> <code>change</code> 监听文件改变事件（文件改变涵盖文件添加、上传成功和上传失败）；<br/><br>          <code>success</code> 监听文件上传成功事件；<br/> <code>hash-progress</code> 监听文件上传生成 hash 值事件。</div> | file-upload/upload-events.vue |
