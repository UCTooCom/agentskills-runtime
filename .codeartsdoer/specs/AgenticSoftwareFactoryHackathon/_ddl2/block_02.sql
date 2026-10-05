### 2.1.3 关键组件设计

- **GitHub 协作平台 Service 层**：`src/app/services/github/` 下按模块组织，RepositoryService 负责仓库 CRUD + 可见性控制 + Fork，BranchService 负责分支管理 + 保护规则，CommitService 负责提交历史 + 差异，PullRequestService 负责 PR 生命周期 + 合并 + 评审。
- **电子表格工作台 Service 层**：`src/app/services/sheets/` 下，WorkbookService 负责工作簿 CRUD + CSV 导入导出，WorksheetService 负责工作表管理，CellService 负责单元格 CRUD + 批量操作，FormulaService 负责公式解析 + 计算 + 依赖重算，PivotTableService 负责透视表聚合。
- **前端公式引擎**：纯前端实现，复用 `xlsx@^0.18.0` 库的 CSV 解析能力 + 自定义公式计算器（支持 SUM/AVERAGE/COUNT/MAX/MIN/IF/STDEV/HYPERLINK/SIN/SUMIF/PMT 等函数 + 相对引用调整 + 依赖链重算 + 循环引用检测 + 错误标识 #DIV/0!/#REF!/#CIRC!）。

---

## 2.2 数据设计

### 2.2.1 GitHub 协作平台增量表设计

> 所有 DDL 放置于 `sql/incremental/hackathon_github_repository.sql` 和 `hackathon_github_issue_pr.sql`，遵循 uctoo-v4 数据库设计规范（UUID 主键、timestamptz、creator 行级权限、软删除）。

#### 2.2.1.1 repository（仓库）
