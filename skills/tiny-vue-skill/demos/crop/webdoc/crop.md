# crop Demos

| demoId | 名称 | 描述 | 代码文件 |
|--------|------|------|----------|
| basic-usage | 基本用法 | <p>通过 <code>src</code> 属性设置默认裁剪的图片源路径，并通过 <code>cropvisible</code> 属性来控制裁剪弹框是否可见。</p><br> | crop/basic-usage.vue |
| aspect-ratio | 裁剪框宽高比 | <p>通过 <code>aspect-ratio</code> 属性可以设置裁剪框的宽高比例，默认为 <code>16 / 9</code> 。还可以通过调用 <code>setAspectRatio</code> 方法来设置裁切框的宽高比。<br>通过 <code>center</code> 属性可以设置裁剪框是否在图片正中心。</p><br> | crop/aspect-ratio.vue |
| min-crop-box-width-height | 裁剪框最小宽高 | <p>通过属性 <code>min-crop-box-width</code> 、<code>min-crop-box-height</code> 设置裁剪框最小宽高。设置后，调整裁剪框宽高时，调整到最小值后将不能再调整。<br>通过属性 <code>min-container-width</code> 、<code>min-container-height</code> 设置容器的最小宽度，最小高度。</p><br> | crop/min-crop-box-width-height.vue |
| no-background | 不显示网格背景 | <p>通过设置 <code>background</code> 属性为 <code>false</code> 后，将不显示容器的网格背景。</p><br> | crop/no-background.vue |
| no-guides | 不显示虚线 | <p>通过设置 <code>guides</code> 属性为 <code>false</code> 将取消裁剪框上方的虚线显示。</p><br> | crop/no-guides.vue |
| no-modal | 不显示模态 | <p>通过设置 <code>modal</code> 属性为 <code>false</code> 将取消裁剪框下方图片上方的模态层显示。</p><br> | crop/no-modal.vue |
| view-mode | 视图模式 | <p>通过 <code>view-mode</code> 属性可以设置裁剪框的视图模式，有 <code>0</code>、<code>1</code>、<code>2</code>、<code>3</code> 四种选项，默认为 <code>0</code> 。</p><br><div class="tip custom-block"><p class="custom-block-title">view-mode 选项说明</p><br><p><code>0</code>：裁剪框可以移动到图片外面。<br><code>1</code>：裁剪框只能在图片内移动。<br><code>2</code>：图片不全部铺满容器，缩小时可以有一边出现空隙。<br><code>3</code>：图片填充整个容器。</p><br></div><br> | crop/view-mode.vue |
| drag-mode | 拖拽模式 | <br>          通过 <code>drag-mode</code> 属性可以设置裁剪框的拖拽模式，有 <code>crop</code>、<code>move</code>、<code>none</code> 三种选项，默认为 <code>crop</code> 。<br>          <div class="tip custom-block"><br>            <p class="custom-block-title">drag-mode 选项说明</p><br>            <code>crop</code>：当裁剪框取消后，按住鼠标左键在图片区域拖拽，将产生一个新的裁剪框。<br><br>            <code>move</code>：当裁剪框取消后，按住鼠标左键将移动图片。<br><br>            <code>none</code>：当裁剪框取消后，不能裁剪、也不能移动图片。<br><br>          </div><br>          通过 <code>movable</code> 控制图片是否可以移动，默认为 true。</p><br> | crop/drag-mode.vue |
| auto-crop-area | 自动裁剪面积 | <p>初始化时，通过属性 <code>auto-crop-area</code> 可以设置裁剪框自动裁剪的面积，默认为 <code>0.8</code>，在 <code>auto-crop</code> 属性为 <code>true</code> 时生效。</p><br> | crop/auto-crop-area.vue |
| get-container-data | 获取容器数据 | <p>通过调用 <code>getContainerData</code> 方法可以获取容器的大小数据。</p><br> | crop/get-container-data.vue |
| get-crop-box-data | 获取剪切框数据 | <p>通过调用 <code>getCropBoxData</code> 方法可以获取剪切框的位置和大小数据。</p><br> | crop/get-crop-box-data.vue |
| get-cropped-canvas | 获取裁剪后的图片数据 | <p>通过调用 <code>getCroppedCanvas</code> 方法可以获取裁剪后的图片数据，搭配 <code>toDataURL</code> 方法将转成 base64 图片数据，搭配 <code>toBlob</code> 方法将生成 Blob 图片数据。</p><br> | crop/get-cropped-canvas.vue |
| get-data | 获取裁剪区域数据 | <p>通过调用 <code>getData</code> 方法可以获取裁剪区域的位置以及大小。</p><br> | crop/get-data.vue |
| get-image-data | 获取图像数据 | <p>通过调用 <code>getImageData</code> 方法可以获取图像位置、大小和其他相关数据，若想获取画布位置和大小数据可以调用 <code>getCanvasData</code> 方法。</p><br> | crop/get-image-data.vue |
| replace-image | 替换图片 | <p>通过调用 <code>replace</code> 方法可以替换图像的 src 并重新构建 cropper。通过 <code>rotatable</code> 属性控制图片旋转，默认为 true。</p><br> | crop/replace-image.vue |
| replace-image1 | 放大图片 | 通过<code>zoomable</code>可放大图片。 | crop/replace-image.vue |
| wheel-zoom-ratio | 鼠标滚轮缩放图像时比例 | <p>通过<code>zoom-on-wheel</code> 属性为 <code>true</code> 情况下，通过 <code>wheel-zoom-ratio</code> 属性可以设置缩放比例，默认为 <code>0.1</code> 。</p><br> | crop/wheel-zoom-ratio.vue |
| zoom-on-wheel | 禁用鼠标滚轮缩放图像 | <p>通过设置 <code>zoom-on-wheel</code> 属性为 <code>false</code> 后，将不允许通过滚动鼠标滚轮来缩放图像。</p><br> | crop/zoom-on-wheel.vue |
| event-ready | ready 事件 | <p>当一个 cropper 实例完全构建时，通过触发 <code>ready</code> 事件。</p><br> | crop/event-ready.vue |
| crop-meth | 裁剪框的禁用/启用 | <p>当一个 cropper 实例完全构建时，通过触发 <code>disable</code> 方法禁用裁剪框，触发 <code>enable</code> 方法启用裁剪框。</p><br> | crop/crop-meth.vue |
| event-about-crop | 裁剪相关事件 | <div class="tip custom-block"><p class="custom-block-title">TIP</p><br><p>说明当画布或剪切框开始发生变化时触发 <code>cropstart</code> 事件，当画布或剪切框正在发生变化时触发 <code>cropmove</code> 事件，当画布或剪切框发生变化结束时触发 <code>cropend</code> 事件，当画布或裁剪框发生改变时触发 <code>crop</code> 事件，通过触发 <code>getCanvasData</code> 获取画布 Canvas（图像包装器）位置和大小数据。</p><br></div><br> | crop/event-about-crop.vue |
