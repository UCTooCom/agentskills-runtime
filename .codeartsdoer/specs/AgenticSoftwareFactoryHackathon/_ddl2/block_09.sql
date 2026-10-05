---

## 2.3 API 设计

### 2.3.1 API 规范约定

遵循 `docs/uctoo-v4/uctoo-v4-api-specification.md` 规范：

| 约定 | 规则 |
|------|------|
| 基础路径 | `/api/v1/uctoo/{table_name}` |
| 列表键名 | 表名 + `s`（如 `repositories` / `branches` / `workbooks`） |
| 响应格式 | `{ "data": {}, "currentPage": 1, "totalCount": 100, "totalPage": 10 }` |
| 错误响应 | `{ "errno": "40001", "errmsg": "参数错误" }` |
| HTTP 方法 | GET（查询）/ POST（创建）/ PUT（更新）/ DELETE（删除） |
| 资源路径 | `/api/v1/uctoo/{table}/{id}` |
| 操作路径 | `/api/v1/uctoo/{table}/{action}` |

### 2.3.2 GitHub 协作平台 API 列表

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/api/v1/uctoo/repositories` | 仓库列表（支持搜索/筛选/排序） |
| POST | `/api/v1/uctoo/repositories` | 创建仓库 |
| GET | `/api/v1/uctoo/repositories/:id` | 仓库详情 |
| PUT | `/api/v1/uctoo/repositories/:id` | 更新仓库（含可见性变更） |
| POST | `/api/v1/uctoo/repositories/:id/fork` | Fork 仓库 |
| GET | `/api/v1/uctoo/repositories/:id/branches` | 分支列表 |
| POST | `/api/v1/uctoo/repositories/:id/branches` | 创建分支 |
| GET | `/api/v1/uctoo/repositories/:id/commits` | 提交历史 |
| GET | `/api/v1/uctoo/repositories/:id/files` | 文件树（按分支） |
| PUT | `/api/v1/uctoo/repositories/:id/files/:file_id` | 在线编辑文件 |
| GET | `/api/v1/uctoo/repositories/:id/issues` | Issue 列表（复用 tasks 表） |
| POST | `/api/v1/uctoo/repositories/:id/issues` | 创建 Issue |
| GET | `/api/v1/uctoo/repositories/:id/pull-requests` | PR 列表 |
| POST | `/api/v1/uctoo/repositories/:id/pull-requests` | 创建 PR |
| POST | `/api/v1/uctoo/pull-requests/:id/reviews` | 提交 PR 评审 |
| POST | `/api/v1/uctoo/pull-requests/:id/merge` | 合并 PR |
| GET | `/api/v1/uctoo/repositories/:id/milestones` | 里程碑列表 |
| GET | `/api/v1/uctoo/repositories/:id/labels` | 标签列表 |
| POST | `/api/v1/uctoo/repositories/:id/branch-protections` | 设置分支保护 |

### 2.3.3 电子表格工作台 API 列表

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | `/api/v1/uctoo/workbooks` | 工作簿列表（含 Last updated） |
| POST | `/api/v1/uctoo/workbooks` | 创建空白工作簿 |
| GET | `/api/v1/uctoo/workbooks/:id` | 打开工作簿（含工作表/单元格完整状态） |
| PUT | `/api/v1/uctoo/workbooks/:id` | 重命名工作簿 |
| POST | `/api/v1/uctoo/workbooks/import-csv` | CSV 导入（上传文件 → 解析 → 创建工作簿） |
| GET | `/api/v1/uctoo/workbooks/:id/export-csv` | CSV 导出当前活动工作表 |
| POST | `/api/v1/uctoo/workbooks/:id/worksheets` | 添加工作表 |
| PUT | `/api/v1/uctoo/worksheets/:id` | 重命名/删除工作表 |
| GET | `/api/v1/uctoo/worksheets/:id/cells` | 获取工作表所有单元格 |
| PUT | `/api/v1/uctoo/worksheets/:id/cells` | 批量更新单元格（含公式） |
| POST | `/api/v1/uctoo/worksheets/:id/cells/batch` | 批量操作（插入/删除行列/粘贴） |
| POST | `/api/v1/uctoo/worksheets/:id/validation-rules` | 设置数据验证规则 |
| POST | `/api/v1/uctoo/worksheets/:id/pivot-tables` | 创建透视表 |
| POST | `/api/v1/uctoo/worksheets/:id/pivot-tables/:pt_id/refresh` | 刷新透视表 |

---

## 2.4 前端设计

### 2.4.1 GitHub 协作平台前端
