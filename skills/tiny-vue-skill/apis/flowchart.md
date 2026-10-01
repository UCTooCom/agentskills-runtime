## flowchart

### Props

| 属性名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| config | IFlowchartConfig |  | 流程图的全局配置对象，通过 Flowchart.createConfig() 创建 |
| config.adjustPos | function | null | 节点位置微调钩子函数，参数为节点对象，返回调整后的 { x, y } 坐标 |
| config.align | String |  | 在卡片模式下，节点内部文字的对齐方式，包括居左 left、居中 center |
| config.anchor | 'center' \| 'left' | 'center' | 节点标签的对齐锚点，center 为居中，left 为左对齐 |
| config.background | string | '#fff' | 画布背景颜色 |
| config.checkItemStatus | function | null | 检查人员列表项状态的回调函数，用于自定义项的显示逻辑 |
| config.colors | Record<number, string> | { 1: '#1890ff', 2: '#096dd9', 3: '#d9d9d9', 4: '#f5222d' } | 节点状态码与颜色的映射对象，键为状态码，值为颜色字符串 |
| config.cols | number | 8 | 画布网格的列数，用于节点水平方向的网格定位 |
| config.condClass | string | '' | 多端 dot 点模式下，条件节点（cond 为 true 的连线）的默认 CSS 类名 |
| config.delay | number | 10 |  Canvas 绘制动画的延迟时间（毫秒） |
| config.drawLink | function | null | 自定义 Canvas 连线绘制函数，接收 Canvas 上下文和连线数据，用于高级定制连线特效 |
| config.extraWidth | Number |  | 在多端 dot 模式下，图形预留宽度，用于图形最小宽度计算，适当修改保证图形宽度不被过分挤压 |
| config.font | string | '12px "Microsoft YaHei"' |  Canvas 绘制文字的字体配置 |
| config.gap | Number |  | 图形节点在垂直方向上的最小间距 |
| config.headSize | number | 20 | 人员列表中头像的显示尺寸（像素） |
| config.headUrl | string | '' | 人员列表中默认头像的 URL 地址 |
| config.height | Number | 420 | 图形的高度。在多端 dot 模式下，如果高度小于图形计算高度，则使用图形计算高度 |
| config.hoverHit | number | 3 | 连线悬停检测的命中范围（像素），值越大悬停越容易触发 |
| config.iconSize | number | 20 | 节点图标的尺寸（像素） |
| config.iconSvgSize | number | 14 | 节点图标内部 SVG 的尺寸（像素） |
| config.iconWrapperSize | number | 24 | 节点图标外包裹层的尺寸（像素） |
| config.labelDateColor | string | '#999' | 节点标签中日期文字的颜色 |
| config.labelHeight | number | 60 | 节点标签区域的高度（像素） |
| config.labelSpacing | number | 8 | 节点图标与标签之间的间距（像素） |
| config.labelWidth | number | 80 | 节点标签区域的宽度（像素） |
| config.linkEndMinus | Number |  | 在 dot 点模式下，连线末端在连线方向上的偏移量，可以用来调整连线末端位置 |
| config.listBorderColor | string | '#d9d9d9' | 人员列表容器的边框颜色 |
| config.listIconColor | string | '#999' | 人员列表中状态图标的颜色 |
| config.listIconSize | number | 20 | 人员列表中状态图标的尺寸（像素） |
| config.listThreshold | number | 1 | 当存在createItem用于创建人员列表项，人员列表显示的阈值，当 items数组长度大于此值时显示列表，默认值1。所以当数组长度为1，默认不显示，应该设置成0，才能显示。 |
| config.listWidth | number | 62 | 人员列表容器的宽度（像素） |
| config.nodeLayout | String |  | 在 dot 点模式下，节点内部布局，Label在节点下部居中 up-down、在节点右侧 left-right |
| config.nodeSize | String |  | 在 dot 点模式下，节点图标尺寸，mini/small/medium |
| config.ongoingBackgroundColor | String |  | 在卡片模式下，状态为进行中的节点的背景色 |
| config.padding | Number |  | 图形的内边距。在 dot 模式自适应宽度时或者自定义布局时失效，只参与图形高度的计算 |
| config.popoverPlacement | String |  | 在卡片模式下，节点 tooltip 的位置 |
| config.prior | String |  | 在内置连线逻辑中使用，图形连线的优先方向，包括水平 horizontal、垂直 vertical |
| config.radius | number | 4 | 节点图标和连线的圆角半径（像素） |
| config.renderCond | function | null | 多端 dot 点模式下，条件节点（cond 为 true 的连线）的自定义渲染函数，参数为 (h, afterLink, config)，返回 VNode |
| config.rows | number | 8 | 画布网格的行数，用于节点垂直方向的网格定位 |
| config.showArrow | boolean |  | 在 dot 点模式下，全局设置连线是否显示箭头 |
| config.showOnly | String |  | 在 dot 点模式下，节点只显示图标、只显示标题，icon/title |
| config.status | Record<number, string> | { 1: 'complete', 2: 'ongoing', 3: 'pending', 4: 'fail' } | 节点状态码与状态名称的映射对象 |
| config.statusComplete | number | 1 | 表示已完成状态的状态码 |
| config.statusFail | number | 4 | 表示失败状态的状态码 |
| config.statusOngoing | number | 2 | 表示进行中状态的状态码 |
| config.styleHoverLink | function | null | 自定义悬停时连线样式的函数，接收连线数据，返回样式对象 |
| config.styleLink | function | null | 自定义连线样式的函数，接收连线数据，返回样式对象 |
| config.thin | boolean | true | 是否使用细线模式绘制连线；多端 dot 模式下也用于控制 Canvas 缩放比例 |
| config.type | String |  | 设置为 dot 开启点模式 |
| config.width | Number | 1024 | 图形的宽度。在多端 dot 模式下失效，因为宽度要自适应容器宽度 |
| data | IFlowchartData |  | 流程图的数据对象，包含节点和连线 |
| data.groups | Array |  | 多端 dot 模式下，流程图的分组列表 |
| data.groups[i].fillStyle | String |  | 分组的填充颜色 |
| data.groups[i].lineDash | Array |  | 分组的边框虚线样式 |
| data.groups[i].nodes | Array |  | 分组中的节点名称列表 |
| data.groups[i].padding | Array |  | 分组的上下、左右内边距 |
| data.groups[i].strokeStyle | String |  | 分组的边框颜色 |
| data.groups[i].title | String |  | 分组的名称 |
| data.groups[i].titleClass | String |  | 分组的名称样式 token |
| data.groups[i].titlePosition | String |  | 分组的名称位置，支持 top、top-left（顶部中间、顶部居左） |
| data.links | IFlowchartLink[] | [] | 流程图的连线数组，通过 Flowchart.createLink() 创建 |
| data.links[i].cond | boolean | false | 多端 dot 点模式下，标记该连线是否为条件连线。为 true 时会在连线上渲染条件节点，显示 info.other.title 文字 |
| data.links[i].from | String |  | 连线起始节点的名称 |
| data.links[i].fromJoint | String |  | 连线在起始节点的连接点。值可以为 bottom、top、left、right，表示从底部中间、顶部中间、左侧中间、右侧中间；值也可以为变体 bottom-1/2、bottom-2/2，表示从底部左半部分中间、底部右半部分中间；值也可以为变体 bottom-1/3、bottom-2/3、bottom-3/3 等 |
| data.links[i].info | Object |  | 连线的详细信息，包括连线的状态、样式等 |
| data.links[i].info.other | object |  | 多端 dot 点模式下，连线的扩展信息。cond 为 true 时，other.title 用于显示条件节点的文字内容 |
| data.links[i].info.status | number |  | 多端连线的状态码，对应 config.status 中的状态 |
| data.links[i].info.style | 'solid' \| 'dashed' \| 'dash' | 'solid' | 连线的样式，solid 为实线，dashed/dash 为虚线 |
| data.links[i].linkOffset | Number |  | 在 dot 点模式下，连线起点在连线方向的偏移量，可以用来调整连线起点位置 |
| data.links[i].p | string | '' | 连线路径的 DSL 字符串，控制连线的走向和拐点，如 "0 r0.5 t1 c r1.5" |
| data.links[i].showArrow | boolean |  | 在 dot 点模式下，单独设置连线是否显示箭头 |
| data.links[i].to | String |  | 连线结束节点的名称 |
| data.links[i].toJoint | String |  | 连线在结束节点的连接点。值可以为 bottom、top、left、right，表示从底部中间、顶部中间、左侧中间、右侧中间；值也可以为变体 bottom-1/2、bottom-2/2，表示从底部左半部分中间、底部右半部分中间；值也可以为变体 bottom-1/3、bottom-2/3、bottom-3/3 等 |
| data.nodes | IFlowchartNode[] | [] | 流程图的节点数组，通过 Flowchart.createNode() 创建 |
| data.nodes[i].hidden | boolean |  | 节点是否隐藏 |
| data.nodes[i].info | Object |  | 节点的详细信息，包括节点所在的行列、宽高、形状和其它信息 |
| data.nodes[i].info.col | number |  | 节点在网格中的列索引（从 0 开始） |
| data.nodes[i].info.date | string | '' | 节点对应的日期文本，显示在标签下方 |
| data.nodes[i].info.items | IFlowchartItem[] \| null | null | 节点的人员列表，通过 Flowchart.createItem() 创建，为 null 时不显示 |
| data.nodes[i].info.label | string | '' | 节点的标签文本；多端 dot 点模式下，当 nodeLayout 为 up-down 时显示为下部主标题 |
| data.nodes[i].info.other | object |  | 多端 dot 点模式下节点的扩展信息。包含 shape（形状 circle/rectangle）、main（主标题）、auxi（辅助标题）、error（错误提示）等字段 |
| data.nodes[i].info.other.auxi | string | '' | 多端 dot 点模式下，节点的辅助标题文本，显示在主标题下方或右侧（取决于 nodeLayout） |
| data.nodes[i].info.other.error | string | '' | 多端 dot 点模式下，节点状态为失败时显示的错误提示文本，通过 Popover 悬浮展示 |
| data.nodes[i].info.other.main | string | '' | 多端 dot 点模式下，节点的主标题文本，当 nodeLayout 为 left-right 时显示为右侧主标题 |
| data.nodes[i].info.other.shape | 'circle' \| 'rectangle' | 'circle' | 多端 dot 点模式下，节点的形状，circle 为圆形，rectangle 为圆角矩形 |
| data.nodes[i].info.row | number |  | 节点在网格中的行索引（从 0 开始） |
| data.nodes[i].info.status | number |  | 节点的状态码，对应 config.status 中的状态；多端 dot 模式下也用于控制节点边框颜色和背景色 |
| data.nodes[i].name | String |  | 节点的名称，用于保证节点的唯一性 |
| data.nodes[i].renderInner | function | null | 多端 dot 点模式下，单个节点的自定义内部渲染函数，优先级高于 config.renderInner。参数为 (h, rawNode)，返回 VNode |
| data.nodes[i].renderOuter | function | null | 多端 dot 点模式下，单个节点的自定义外部渲染函数，优先级高于 config.renderOuter。参数为 (h, rawNode)，返回 VNode |
| fetch | function |  | 多端 dot 异步流程图 AsyncFlowchart 数据和配置的加载方法。 |

### Events

| 事件名 | 回调参数 | 说明 |
|--------|----------|------|
| click-blank | (param: IFlowchartClickBlankEvent, e: MouseEvent) => void | 点击画布空白区域时触发 |
| click-group | (param: IFlowchartClickGroupEvent, e: MouseEvent) => void | 点击分组时触发 |
| click-link | (param: IFlowchartClickLinkEvent, e: MouseEvent) => void | 点击连线时触发 |
| click-node | (param: IFlowchartClickNodeEvent, e: MouseEvent) => void | 点击节点时触发 |

### Methods

| 方法名 | 返回值 | 说明 |
|--------|--------|------|
| createConfig | () => IFlowchartConfig | 流程图组件 Flowchart 的静态方法，用于创建包含默认值的图形基础配置对象 |
| createItem | (key: string, name: string, role: string, status: number, comment: string, date: string, other?: any) => IFlowchartItem | 流程图组件 Flowchart 的静态方法，用于创建人员列表项 |
| createLink | (from: string, to: string, p: string, status: number, style?: string, other?: any) => IFlowchartLink | 流程图组件 Flowchart 的静态方法，用于创建连线 |
| createNode | (name: string, status: number, label: string, date: string, items: IFlowchartItem[] \| null, row: number, col: number, other?: any) => IFlowchartNode | 流程图组件 Flowchart 的静态方法，用于创建节点 |
| layout | function | 多端 dot 点模式下用于处理图形的自定义布局，设置在全局配置上，参数为图形宽、高和节点列表，期望获取每个节点的位置 |
| linkPath | function | 多端 dot 点模式下用于处理图形连线的自定义布局，设置在全局配置上，参数为连线和节点列表，期望获取连线的路径、中点和渐变 |
| linkPath[i].method({ afterLink, afterNodes, from, to, api }) | function | afterLink当前连线，afterNodes节点列表，from起点矩形，to终点矩形，api处理矩形的方法集 |
| Node | Component | 多端 dot 点模式下内置的节点组件，可通过 Flowchart.Node 访问 |
| refresh | function | 在修改配置或数据之后，用于刷新多端异步流程图 AsyncFlowchart 实例的图形 |
| renderInner | function | 多端流卡片模式下节点的自定义渲染方法，渲染的内容为卡片内部内容，不包括卡片容器 |
| renderOuter | function | 多端卡片模式下节点的自定义渲染方法，渲染的内容包括卡片容器 |
| resizeMixin | object | 多端 dot 点模式下用于处理图形的水平自适应宽度，后续在点模式的异步流程图中被内置 |

### Slots

| 插槽名 | 说明 |
|--------|------|
| content | 节点内容插槽，用于自定义节点下方的人员列表或扩展内容，插槽内的样式根据用户实际情况调试。插槽参数: { afterNode, node, config, allItem, dropdowns, showPop } |
| icon | 节点图标插槽，用于自定义节点中心的图标。插槽参数: { afterNode, node, config, allItem, dropdowns, showPop } |
| label | 节点标签插槽，用于自定义节点下方的标签文本。插槽参数: { afterNode, node, config, allItem, dropdowns, showPop } |

## Types

### IFlowchartConfig

```typescript
interface IFlowchartConfig {
  width: number
  height: number
  rows: number
  cols: number
  status: Record<number, string>
  colors: Record<number, string>
  background: string
  statusComplete: number
  statusOngoing: number
  statusFail: number
  anchor: 'center' | 'left'
  iconWrapperSize: number
  iconSize: number
  iconSvgSize: number
  labelSpacing: number
  labelWidth: number
  labelHeight: number
  labelDateColor: string
  listWidth: number
  listThreshold: number
  listIconSize: number
  listBorderColor: string
  listIconColor: string
  headUrl: string
  headSize: number
  drawLink: ((ctx: CanvasRenderingContext2D, link: IFlowchartLink) => void) | null
  styleLink: ((link: IFlowchartLink) => object) | null
  styleHoverLink: ((link: IFlowchartLink) => object) | null
  hoverHit: number
  checkItemStatus: ((item: IFlowchartItem) => boolean) | null
  font: string
  delay: number
  adjustPos: ((node: IFlowchartNode) => { x: number; y: number }) | null
  radius: number
  thin: boolean
  type?: string
  nodeSize?: 'mini' | 'small' | 'medium'
  nodeLayout?: 'up-down' | 'left-right'
  align?: 'left' | 'center'
  popoverPlacement?: string
  ongoingBackgroundColor?: string
  showArrow?: boolean
  showOnly?: 'icon' | 'title'
  prior?: 'horizontal' | 'vertical'
  gap?: number
  padding?: number
  extraWidth?: number
  linkEndMinus?: number
  condClass?: string
  renderCond?: (h: any, afterLink: any, config: any) => any
  renderInner?: (h: any, rawNode: any) => any
  renderOuter?: (h: any, rawNode: any) => any
}
```

### IFlowchartData

```typescript
interface IFlowchartData {
  nodes: IFlowchartNode[]
  links: IFlowchartLink[]
  groups?: IFlowchartGroup[]
}
```

### IFlowchartNode

```typescript
interface IFlowchartNode {
  name: string
  info: {
    status: number
    label: string
    date: string
    items: IFlowchartItem[] | null
    row: number
    col: number
    other?: {
      shape?: 'circle' | 'rectangle'
      main?: string
      auxi?: string
      error?: string
      [key: string]: any
    }
  }
  hidden?: boolean
  renderInner?: (h: any, rawNode: any) => any
  renderOuter?: (h: any, rawNode: any) => any
}
```

### IFlowchartLink

```typescript
interface IFlowchartLink {
  from: string
  to: string
  p: string
  cond?: boolean
  fromJoint?: string
  toJoint?: string
  linkOffset?: number
  showArrow?: boolean
  info: {
    status: number
    style: 'solid' | 'dashed' | 'dash'
    other?: {
      title?: string
      [key: string]: any
    }
  }
}
```

### IFlowchartItem

```typescript
interface IFlowchartItem {
  key: string
  name: string
  role: string
  status: number
  comment: string
  date: string
  other?: any
}
```

### IFlowchartGroup

```typescript
interface IFlowchartGroup {
  title: string
  nodes: string[]
  fillStyle?: string
  strokeStyle?: string
  lineDash?: number[]
  padding?: [number, number]
  titleClass?: string
  titlePosition?: 'top' | 'top-left'
}
```

### IFlowchartClickNodeEvent

```typescript
interface IFlowchartClickNodeEvent {
  afterNode: {
    x: number
    y: number
    raw: IFlowchartNode
  }
  node: IFlowchartNode
  config: IFlowchartConfig
  allItem: IFlowchartItem[]
  dropdowns: Record<string, boolean>
  showPop: boolean
}
```

### IFlowchartClickLinkEvent

```typescript
interface IFlowchartClickLinkEvent {
  afterLink: {
    raw: IFlowchartLink
  }
  link: IFlowchartLink
  config: IFlowchartConfig
}
```

### IFlowchartClickBlankEvent

```typescript
interface IFlowchartClickBlankEvent {
  x: number
  y: number
  config: IFlowchartConfig
}
```

### IFlowchartClickGroupEvent

```typescript
interface IFlowchartClickGroupEvent {
    group: {
      title: string
      nodes: string[]
    }
    config: IFlowchartConfig
  }
```
