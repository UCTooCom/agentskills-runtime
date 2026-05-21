# 权限管理系统 - 编码任务清单

> 基于需求规格 spec.md 和实现方案 design.md 生成
> 后端：仓颉语言（使用 cangjie-coder 技能编写）| 前端：Vue3 + TinyVue + pinia-orm

---

## 1. 后端：新增获取所有权限节点接口

- [ ] 在 PermissionsRoute.cj 中注册新路由 `GET /api/v1/uctoo/permissions/all`
  - 文件：`apps/agentskills-runtime/src/app/routes/uctoo/permissions/PermissionsRoute.cj`
  - 在 `registerCustomRoutes()` 方法中添加路由，调用 `controller.getAllPermissions`
  - 依赖：无

- [ ] 在 PermissionsController.cj 中实现 `getAllPermissions` 方法
  - 文件：`apps/agentskills-runtime/src/app/controllers/uctoo/permissions/PermissionsController.cj`
  - JWT 认证校验
  - 校验当前用户是否持有 `"*"` 权限（超级管理员），无权限返回 403
  - 调用 service 查询 permissions 表所有记录（deleted_at 为空）
  - 返回 JSON 格式 `{ errno: "0", errmsg: "success", data: { permissions: [...] } }`
  - 使用 cangjie-coder 技能编写
  - 依赖：1.1

- [ ] 在 PermissionsService.cj 中实现全量查询方法
  - 文件：`apps/agentskills-runtime/src/app/services/uctoo/PermissionsService.cj`
  - 新增 `getAllPermissions()` 方法，查询 permissions 表中 deleted_at 为空的所有记录
  - 返回 `APIResult<ArrayList<PermissionsPO>>`
  - 使用 cangjie-coder 技能编写
  - 依赖：1.2

## 2. 后端：新增批量授权接口

- [ ] 在 PermissionsRoute.cj 中注册新路由 `POST /api/v1/uctoo/permissions/authorize`
  - 文件：`apps/agentskills-runtime/src/app/routes/uctoo/permissions/PermissionsRoute.cj`
  - 在 `registerCustomRoutes()` 方法中添加路由，调用 `controller.batchAuthorize`
  - 依赖：无

- [ ] 在 PermissionsController.cj 中实现 `batchAuthorize` 方法
  - 文件：`apps/agentskills-runtime/src/app/controllers/uctoo/permissions/PermissionsController.cj`
  - JWT 认证校验
  - 校验当前用户是否持有 `"*"` 权限，无权限返回 403
  - 解析请求体：`{ permission_names: string[], role_ids: string[], creator?: string }`
  - 调用 service 执行批量授权逻辑
  - 返回 `{ errno: "0", data: { authorized_count, skipped_count, message } }`
  - 使用 cangjie-coder 技能编写
  - 依赖：2.1

- [ ] 在 PermissionsService.cj 中实现批量授权业务逻辑
  - 文件：`apps/agentskills-runtime/src/app/services/uctoo/PermissionsService.cj`
  - 新增 `batchAuthorize(permissionNames: ArrayList<String>, roleIds: ArrayList<String>, creator: String)` 方法
  - 遍历 permission_names × role_ids，写入 role_has_permission 表
  - 利用 (role_id, permission_name) 联合主键保证幂等性（INSERT ON CONFLICT DO NOTHING）
  - 校验 permission_name 是否存在于 permissions 表，不存在则跳过并计入 skipped_count
  - 校验 role_id 是否存在于 uctoo_role 表，不存在则返回错误
  - 记录 creator 和 created_at
  - 事务一致性：全部成功或全部失败
  - 使用 cangjie-coder 技能编写
  - 依赖：2.2

## 3. 后端：增强权限分页查询支持 deleted_at 筛选

- [ ] 确认 PermissionsService.cj 的 getMany 方法已支持 filter 参数中 deleted_at 条件
  - 文件：`apps/agentskills-runtime/src/app/services/uctoo/PermissionsService.cj`
  - 验证 `filter: { deleted_at: null }` 筛选正常数据
  - 验证 `filter: { deleted_at: { not: null } }` 筛选回收站数据
  - 如不支持，在 RequestParserService 解析逻辑中补充对 deleted_not_null 操作符的处理
  - 使用 cangjie-coder 技能编写
  - 依赖：无

## 4. 后端：清空回收站时同步清理 role_has_permission 关联

- [ ] 确认 PermissionsController.cj 的 emptyRecycleBinPermissions 方法实现完整性
  - 文件：`apps/agentskills-runtime/src/app/controllers/uctoo/permissions/PermissionsController.cj`
  - 验证清空回收站时：物理删除前先查询将被删除的 permission_name 列表
  - 同步删除 role_has_permission 表中对应 permission_name 的关联记录
  - 如现有实现未包含此逻辑，补充完善
  - 使用 cangjie-coder 技能编写
  - 依赖：无

## 5. 前端 Store：新增 API 方法到 permissions Model

- [ ] 在 permissions.ts 中新增 `getAllPermissions` 方法
  - 文件：`apps/web-admin/web/src/store/models/uctoo/permissions.ts`
  - 在 `static config.axiosApi.actions` 中添加
  - `getAllPermissions()` → `GET /api/v1/uctoo/permissions/all`，dataKey: `'permissions'`
  - 包含 Authorization Bearer token 和 baseURL
  - 依赖：1.3（后端接口就绪）

- [ ] 在 permissions.ts 中新增 `batchAuthorize` 方法
  - 文件：`apps/web-admin/web/src/store/models/uctoo/permissions.ts`
  - `batchAuthorize(data: { permission_names: string[], role_ids: string[], creator?: string })`
  - → `POST /api/v1/uctoo/permissions/authorize`
  - 依赖：2.3（后端接口就绪）

- [ ] 在 permissions.ts 中新增 `batchRestorePermission` 方法
  - 文件：`apps/web-admin/web/src/store/models/uctoo/permissions.ts`
  - `batchRestorePermission(ids: string[])`
  - → `POST /api/v1/uctoo/permissions/edit`，body: `{ ids: JSON.stringify(ids), deleted_at: '0' }`
  - 依赖：无（复用已有 edit 接口）

- [ ] 在 permissions.ts 中新增 `emptyRecycleBinPermissions` 方法
  - 文件：`apps/web-admin/web/src/store/models/uctoo/permissions.ts`
  - `emptyRecycleBinPermissions()`
  - → `POST /api/v1/uctoo/permissions/empty-recycle-bin`
  - 依赖：无（复用已有路由）

- [ ] 在 permissions.ts 中新增 `batchDeletePermission` 方法
  - 文件：`apps/web-admin/web/src/store/models/uctoo/permissions.ts`
  - `batchDeletePermission(params: { ids: string, force?: number })`
  - → `POST /api/v1/uctoo/permissions/del`
  - 依赖：无（复用已有 del 接口）

## 6. 前端：重构 info-tab.vue 主组件架构

- [ ] 重构 info-tab.vue 顶部区域，新增权限类型筛选按钮组
  - 文件：`apps/web-admin/web/src/views/permission/info/components/info-tab.vue`
  - 使用 TinyButtonGroup 或 TinyButton 组件实现 4 个筛选按钮：菜单(type=1)、按钮(type=2)、路由(type=3)、工具(type=4)
  - 默认选中"菜单"
  - 切换类型时前端内存筛选，不发起服务端请求
  - 切换类型时分页重置到第 1 页
  - 依赖：无

- [ ] 重构 info-tab.vue 按钮栏区域，集成回收站开关和按钮状态切换
  - 文件：`apps/web-admin/web/src/views/permission/info/components/info-tab.vue`
  - 正常模式按钮：添加权限、刷新API、批量授权（仅超级管理员可见且选中数量>0时可用）
  - 回收站模式按钮：清空、批量恢复、批量彻底删除
  - 回收站开关使用 TinySwitch，位于按钮栏右侧
  - 使用 `v-if/v-else` 切换两套按钮
  - 参考 entity 模块的 add-entity.vue 按钮栏模式
  - 依赖：无

- [ ] 重构 info-tab.vue 数据初始化逻辑，加载权限全量数据和用户权限数据
  - 文件：`apps/web-admin/web/src/views/permission/info/components/info-tab.vue`
  - 页面 onMounted 时调用 `getUserAllPermissions()` 获取用户权限列表
  - 判断是否超级管理员（权限列表包含 `"*"`）
  - 超级管理员调用 `getAllPermissions()` 获取所有权限节点
  - 将全量数据保存到 pinia-orm 本地仓库，支持前端内存筛选
  - 计算圆形复选框状态（调用 computeCheckStates 函数）
  - 非超级管理员仅用用户权限数据渲染
  - 依赖：5.1

- [ ] 实现 computeCheckStates 圆形复选框状态计算函数
  - 文件：`apps/web-admin/web/src/views/permission/info/components/info-tab.vue`（或提取为 utils 函数）
  - 对比"所有权限节点"与"用户已有权限"两份数据
  - 叶子节点：用户已有权限中包含该节点的 permission_name → checked；否则 → unchecked
  - 父级节点：所有子节点均 checked → checked；均 unchecked → unchecked；部分 → indeterminate
  - 返回 `Record<string, 'checked' | 'unchecked' | 'indeterminate'>`
  - 依赖：6.3

- [ ] 实现前端内存筛选函数 filterByType
  - 文件：`apps/web-admin/web/src/views/permission/info/components/info-tab.vue`
  - 使用 `useRepo(permissions).all()` 获取本地仓库数据
  - 按 `type` 字段过滤，返回对应类型的权限列表
  - 菜单类型数据需构建树形结构（根据 parent_id 递归构建 children 数组）
  - 依赖：6.3

- [ ] 重构 info-tab.vue 分页查询逻辑，支持筛选条件和回收站过滤
  - 文件：`apps/web-admin/web/src/views/permission/info/components/info-tab.vue`
  - 正常视图：filter 包含 `deleted_at: null`
  - 回收站视图：filter 包含 `deleted_at: { not: null }`
  - 类型筛选条件作为隐含 AND 条件参与服务端过滤
  - 切换回收站时重新请求数据
  - 依赖：3.1

- [ ] 重构 info-tab.vue 操作列处理函数（查看/编辑/删除/恢复/彻底删除）
  - 文件：`apps/web-admin/web/src/views/permission/info/components/info-tab.vue`
  - onView：打开查看弹窗（readonly=true）
  - onEdit：打开编辑弹窗（readonly=false）
  - onDelete：调用 `deletePermission({ id })` 软删除
  - onRestore：调用 `editPermission({ deleted_at: '0', id })` 恢复
  - onHardDelete：调用 `deletePermission({ id, force: 1 })` 彻底删除
  - onEmptyRecycleBin：调用 `emptyRecycleBinPermissions()` 清空回收站（TinyModal.confirm 二次确认）
  - 操作后刷新表格数据
  - 依赖：5.4, 5.5

## 7. 前端：新增 permission-tree-table.vue 菜单权限树形表格组件

- [ ] 创建 permission-tree-table.vue 组件
  - 文件：`apps/web-admin/web/src/views/permission/info/components/permission-tree-table.vue`
  - 基于 TinyGrid + `tree-config="{ children: 'children' }"` 实现树形表格
  - 参考 menu 模块的树形展示模式
  - 接收 props：data（树形数据）、checkStates（圆形复选框状态）、isSuperAdmin、isRecycleBin
  - emit 事件：selection-change、view、edit、delete、restore、hard-delete
  - 依赖：6.5（树形数据构建）

- [ ] 实现圆形复选框渲染
  - 文件：`apps/web-admin/web/src/views/permission/info/components/permission-tree-table.vue`
  - 在名称列（title 列）左侧添加圆形复选框
  - 使用 CSS 自定义圆形样式（checked/unchecked/indeterminate 三种状态）
  - 圆形复选框只读：`pointer-events: none`
  - 通过 checkStates prop 获取每个节点的状态
  - 依赖：6.4, 7.1

- [ ] 实现方形复选框列（授权多选）
  - 文件：`apps/web-admin/web/src/views/permission/info/components/permission-tree-table.vue`
  - 在 id 列之前添加 TinyGridColumn type="selection"
  - 仅超级管理员可见：`v-if="isSuperAdmin"`
  - 选中变更时 emit `selection-change` 事件
  - 依赖：7.1

- [ ] 实现操作列
  - 文件：`apps/web-admin/web/src/views/permission/info/components/permission-tree-table.vue`
  - 操作列 `fixed="right"`，宽度 `14%`
  - 正常模式：查看、编辑、删除（Popconfirm 确认）
  - 回收站模式：恢复、彻底删除（Popconfirm 确认）
  - 所有按钮使用 `v-permission` 指令控制可见性
  - 依赖：7.1

## 8. 前端：新增 permission-table.vue 普通权限表格组件

- [ ] 创建 permission-table.vue 组件
  - 文件：`apps/web-admin/web/src/views/permission/info/components/permission-table.vue`
  - 基于 TinyGrid 实现普通表格（无 tree-config）
  - 接收 props：data、isSuperAdmin、isRecycleBin、fetchData、pagerConfig
  - emit 事件：selection-change、view、edit、delete、restore、hard-delete
  - 支持远程分页查询
  - 依赖：无

- [ ] 实现方形复选框列（授权多选）
  - 文件：`apps/web-admin/web/src/views/permission/info/components/permission-table.vue`
  - 在 id 列之前添加 TinyGridColumn type="selection"
  - 仅超级管理员可见：`v-if="isSuperAdmin"`
  - 选中变更时 emit `selection-change` 事件
  - 依赖：8.1

- [ ] 实现操作列
  - 文件：`apps/web-admin/web/src/views/permission/info/components/permission-table.vue`
  - 操作列 `fixed="right"`，宽度 `14%`
  - 正常模式：查看、编辑、删除（Popconfirm 确认）
  - 回收站模式：恢复、彻底删除（Popconfirm 确认）
  - 所有按钮使用 `v-permission` 指令控制可见性
  - 依赖：8.1

## 9. 前端：新增 edit-form.vue 查看/编辑表单组件

- [ ] 创建 edit-form.vue 组件
  - 文件：`apps/web-admin/web/src/views/permission/info/components/edit-form.vue`
  - 使用 TinyForm 实现，复用同一表单
  - props：`permissionData`（Partial\<permissions\>）、`readonly`（boolean）
  - 使用 `:display-only="readonly"` 控制只读/可编辑状态
  - 表单字段：permission_name、type、path、title、component、icon、method、parent_id、weight、menu_type、locale、hidden、keepalive
  - 参考 entity 模块的 edit-form.vue 模式
  - 依赖：无

- [ ] 实现编辑变更检测逻辑
  - 文件：`apps/web-admin/web/src/views/permission/info/components/edit-form.vue`
  - 保存原始数据 originalData
  - `getFormData()` 函数使用 `getChangedFields` 工具函数检测变更
  - 仅返回变更字段 + id，未修改返回 null
  - `defineExpose({ getFormData, valid })`
  - 依赖：9.1

- [ ] 在 info-tab.vue 中集成查看/编辑弹窗
  - 文件：`apps/web-admin/web/src/views/permission/info/components/info-tab.vue`
  - 使用 TinyModalComponent 弹窗
  - 根据操作类型设置 readonly 状态
  - 查看模式：标题"查看权限"，无确认按钮
  - 编辑模式：标题"编辑权限"，有确认按钮
  - 确认时调用 `getFormData()` 获取变更字段
  - 无变更时提示"没有修改任何字段"
  - 有变更时调用 `editPermission()` 提交更新
  - 依赖：9.2, 6.7

## 10. 前端：新增 authorize-dialog.vue 批量授权弹窗组件

- [ ] 创建 authorize-dialog.vue 组件
  - 文件：`apps/web-admin/web/src/views/permission/info/components/authorize-dialog.vue`
  - 使用 TinyModalComponent 弹窗
  - props：`visible`（boolean）、`selectedPermissions`（Permission[]）
  - 弹窗左侧显示已选权限列表（permission_name）
  - 弹窗右侧显示角色列表，使用 TinyCheckbox 多选
  - 未选择角色时确认按钮 disabled
  - 依赖：无

- [ ] 实现角色列表加载逻辑
  - 文件：`apps/web-admin/web/src/views/permission/info/components/authorize-dialog.vue`
  - 弹窗打开时调用 `useAxiosRepo(uctoo_role).api().getUctooRoleList(1, 100)` 获取角色列表
  - 渲染角色名称和描述
  - 依赖：10.1

- [ ] 实现批量授权提交逻辑
  - 文件：`apps/web-admin/web/src/views/permission/info/components/authorize-dialog.vue`
  - 确认时收集 `permission_names`（从 selectedPermissions 提取）和 `role_ids`（从选中角色提取）
  - 调用 `useAxiosRepo(permissions).api().batchAuthorize({ permission_names, role_ids })`
  - 成功后 emit `success` 事件，关闭弹窗，显示"授权成功"提示
  - 失败时保持弹窗打开，显示错误信息
  - 依赖：10.2, 5.2

- [ ] 在 info-tab.vue 中集成批量授权弹窗
  - 文件：`apps/web-admin/web/src/views/permission/info/components/info-tab.vue`
  - 点击"批量授权"按钮时打开 authorize-dialog
  - 传入 selectedPermissions（方形复选框选中的记录）
  - 监听 success 事件：重新加载权限数据，刷新圆形复选框状态，清空方形复选框选中
  - 依赖：10.3, 6.3

## 11. 前端：实现筛选搜索区域

- [ ] 在 info-tab.vue 中实现筛选搜索区域
  - 文件：`apps/web-admin/web/src/views/permission/info/components/info-tab.vue`
  - 参考 entity-table.vue 的筛选搜索实现模式
  - 筛选字段列表：permission_name、type、path、title、component、method、parent_id、weight、menu_type、locale、icon、hidden、keepalive
  - 操作符列表：等于、不等于、包含、开头是、结尾是、大于、小于
  - 支持动态添加/删除筛选条件行
  - "添加筛选条件"按钮 + "重置"按钮 + "搜索"按钮
  - 所有条件为 AND 关系
  - 依赖：无

- [ ] 实现筛选条件与服务端查询的对接
  - 文件：`apps/web-admin/web/src/views/permission/info/components/info-tab.vue`
  - 点击"搜索"时将筛选条件转换为 filter 参数对象
  - 类型筛选作为隐含 AND 条件
  - 回收站状态作为隐含 AND 条件
  - 调用 `getPermissionsList(page, pageSize, { filter })` 发起服务端查询
  - 点击"重置"时清空所有条件，恢复默认数据
  - 依赖：11.1, 6.6

## 12. 前端：集成权限表格组件到 info-tab.vue

- [ ] 在 info-tab.vue 中根据类型切换渲染不同表格组件
  - 文件：`apps/web-admin/web/src/views/permission/info/components/info-tab.vue`
  - `currentType === 1` 时渲染 `permission-tree-table`
  - `currentType !== 1` 时渲染 `permission-table`
  - 传递统一 props：data、isSuperAdmin、isRecycleBin、checkStates（仅树形表格）
  - 监听统一事件：selection-change、view、edit、delete、restore、hard-delete
  - 依赖：7.4, 8.3

## 13. 前端：超级管理员权限判断与 UI 联动

- [ ] 实现 isSuperAdmin 计算属性和 UI 联动
  - 文件：`apps/web-admin/web/src/views/permission/info/components/info-tab.vue`
  - `isSuperAdmin = computed(() => userPermissionNames.includes('*'))`
  - 超级管理员：显示方形复选框列、批量授权按钮
  - 普通用户：隐藏方形复选框列、批量授权按钮
  - 所有授权相关按钮使用 `v-permission="'*'"` 指令
  - 权限数据获取失败时默认按普通用户处理
  - 依赖：6.3

## 14. 集成测试与验证

- [ ] 验证后端新增接口功能
  - 验证 `GET /api/v1/uctoo/permissions/all`：超级管理员返回全量数据，普通用户返回 403
  - 验证 `POST /api/v1/uctoo/permissions/authorize`：批量授权成功、幂等性、权限校验
  - 验证分页查询 filter 参数中 deleted_at 条件生效
  - 验证清空回收站时 role_has_permission 关联同步清理
  - 依赖：1~4

- [ ] 验证前端权限类型筛选功能
  - 页面打开默认显示菜单类型
  - 切换类型按钮前端内存筛选，无额外网络请求
  - 切换类型分页重置到第 1 页
  - 筛选按钮组仅有 4 个按钮，无"全部"
  - 依赖：6.1, 12.1

- [ ] 验证圆形复选框状态
  - 用户持有权限的节点显示选中状态
  - 未持有权限的节点显示未选中状态
  - 部分子权限选中的父节点显示半选中状态
  - 圆形复选框只读，不可交互
  - 依赖：6.4, 7.2

- [ ] 验证方形复选框和批量授权功能
  - 仅超级管理员可见方形复选框列
  - 选中记录后显示"已选 N 项"和"批量授权"按钮
  - 授权弹窗正确显示已选权限和角色列表
  - 授权成功后刷新圆形复选框状态
  - 非超级管理员无方形复选框和授权按钮
  - 依赖：7.3, 8.2, 10.4, 13.1

- [ ] 验证回收站功能
  - 回收站开关切换视图
  - 正常视图仅显示 deleted_at 为空的记录
  - 回收站视图仅显示 deleted_at 不为空的记录
  - 恢复操作将 deleted_at 清空
  - 彻底删除操作物理删除记录
  - 清空回收站操作彻底删除所有回收站记录
  - 按钮栏在正常/回收站模式间切换
  - 依赖：6.2, 6.6, 6.7

- [ ] 验证操作列功能
  - 正常模式：查看（只读）、编辑（可修改，变更检测）、删除（软删除，Popconfirm 确认）
  - 回收站模式：恢复、彻底删除（Popconfirm 确认）
  - 操作列 fixed="right" 固定右侧
  - 所有按钮 v-permission 控制可见性
  - 依赖：7.4, 8.3, 9.3

- [ ] 验证筛选搜索功能
  - 添加/删除筛选条件行
  - 筛选条件与服务端查询对接
  - 类型筛选作为隐含条件
  - 回收站状态作为隐含条件
  - 重置清空所有条件
  - 依赖：11.2

- [ ] 验证授权后刷新逻辑
  - 批量授权成功后重新获取用户权限数据
  - 重新计算圆形复选框状态
  - 清空方形复选框选中
  - 表格数据刷新
  - 依赖：10.4
