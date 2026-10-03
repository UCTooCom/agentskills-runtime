# 计划任务调度引擎（Crontab Scheduler）编码任务

> 基于 spec.md v1.0.0 需求规格 和 design.md v2.1.0 技术设计  
> 项目路径: `apps/agentskills-runtime`  
> 生成时间: 2026-05-18  
> 更新时间: 2026-05-18（日志基础设施复用 + 开发流程调整）

---

## 🔄 开发流程说明

本任务规划采用**里程碑式开发流程**，关键节点需要人工介入：

```
阶段1：项目依赖准备 + 数据库迁移脚本编写（自动化）
    ↓
里程碑1：数据库迁移脚本完成 ✅
    ↓
🛑 等待人工操作（3步）：
    ① 人工运行迁移脚本 scripts/migration/crontab_sched_v1.sql
    ② 人工运行 loadDbInfo 方法，刷新 db_info 表数据
    ③ 人工使用 crudgen 工具重新生成三表标准 CRUD 模块（crontab、crontab_log、crontab_task_registry）
    ↓
里程碑2：crudgen 重新生成完成 ✅
    ↓
阶段2：基于 crudgen 重新生成的代码进行增量迭代开发（自动化）
    ↓
阶段3：编译验证与集成测试（自动化）
```

**关键约定**：
- crudgen 重新生成后，`CrontabPO`/`CrontabDAO`/`CrontabService`/`CrontabController`/`CrontabRoute` 等文件将被覆盖为新版本
- 增量开发代码必须写在 `//#region AutoCreateCode` 之外的区域，避免被 crudgen 再次覆盖
- 新增文件（调度引擎核心、执行器等）不受 crudgen 影响

---

## 1. 项目依赖准备

- [ ] **1.1 声明 f_ticktock 依赖**  
  在 `cjpm.toml` 的 `[dependencies]` 中新增 `f_ticktock = {path = "libs/fountain/f_ticktock", version = "1.0.45"}`  
  验收：项目可正常 `cjpm build` 编译通过  
  涉及文件: `cjpm.toml`（修改）  
  预估复杂度: 低  

---

## 2. 数据库迁移脚本（里程碑1）

- [ ] **2.1 创建数据库迁移脚本**  
  编写 `scripts/migration/crontab_sched_v1.sql`，包含：  
  - Phase 1: ALTER TABLE crontab ADD COLUMN（11个新增字段：timeout, max_retries, retry_count, concurrentable, once, priority, parameters, misfire_threshold, last_executed_at, next_executed_at, exec_count）  
  - Phase 2: ALTER TABLE crontab_log ADD COLUMN（6个新增字段：start_time, end_time, trigger_type, retry_attempt, executor_type, result_summary）  
  - Phase 3: CREATE TABLE crontab_task_registry（含初始执行器数据 INSERT）  
  - Phase 4: CREATE INDEX（6个索引）  
  验收：迁移脚本SQL语法正确，包含完整注释  
  涉及文件: `scripts/migration/crontab_sched_v1.sql`（新增）  
  预估复杂度: 中  
  依赖: 无  

---

## 🛑 里程碑1：等待人工操作

> ⚠️ **以下操作必须由人工执行，自动化工具无法替代**

- [ ] **人工步骤1：运行数据库迁移脚本**  
  ```bash
  # 在目标数据库执行迁移脚本
  psql -h <host> -U <user> -d <database> -f scripts/migration/crontab_sched_v1.sql
  ```  
  验证：现有 crontab/crontab_log 数据不受影响，新增字段有合理默认值，crontab_task_registry 表创建成功且初始数据存在，所有索引创建成功  

- [ ] **人工步骤2：运行 loadDbInfo 刷新 db_info 表**  
  调用 `DbInfoService.loadDbInfo()` 方法，重新刷新 `db_info` 表数据，使 crudgen 工具能识别到新增的 crontab_task_registry 表以及 crontab/crontab_log 的新增字段  
  验证：db_info 表中包含 crontab_task_registry 表信息；crontab/crontab_log 表字段信息已更新  

- [ ] **人工步骤3：使用 crudgen 重新生成三个表的标准 CRUD 模块**  
  对以下三个表运行 crudgen 工具：  
  - `crontab` → 重新生成 CrontabPO/CrontabDAO/CrontabService/CrontabController/CrontabRoute  
  - `crontab_log` → 重新生成 CrontabLogPO/CrontabLogDAO/CrontabLogService/CrontabLogController/CrontabLogRoute  
  - `crontab_task_registry` → 新增生成 CrontabTaskRegistryPO/CrontabTaskRegistryDAO/CrontabTaskRegistryService/CrontabTaskRegistryController/CrontabTaskRegistryRoute  
  验证：三个表的 CRUD 模块可正常编译，所有新增字段已包含在 PO 的 `//#region AutoCreateCode` 区域内  

---

## 3. 基于 crudgen 重新生成代码的增量开发 — 数据模型层增强

> 📌 **本阶段开始，所有增量代码写在 `//#region AutoCreateCode` 之外的区域**

- [ ] **3.1 增强 CrontabPO 自定义方法**  
  在 `CrontabPO.cj` 的 `//#endregion AutoCreateCode` 之后追加：  
  - 自定义辅助方法：`getMisfirePolicy()` 将 tactics 映射为 MisfirePolicy 枚举  
  - `isSystemTask()` 判断 group==2  
  - `isOneShot()` 判断 once==true  
  - `isConcurrentAllowed()` 判断 concurrentable==true  
  验收：CrontabPO 自定义方法可正确调用  
  涉及文件: `src/app/models/uctoo/CrontabPO.cj`（修改，AutoCreateCode 之外）  
  预估复杂度: 低  
  依赖: 里程碑2  

- [ ] **3.2 增强 CrontabLogPO 自定义方法**  
  在 `CrontabLogPO.cj` 的 `//#endregion AutoCreateCode` 之后追加：  
  - `toSchedulerLog()` 转换为调度引擎日志格式  
  验收：CrontabLogPO 自定义方法可正确调用  
  涉及文件: `src/app/models/uctoo/CrontabLogPO.cj`（修改，AutoCreateCode 之外）  
  预估复杂度: 低  
  依赖: 里程碑2  

- [ ] **3.3 增强 CrontabTaskRegistryPO 自定义方法**  
  在 `CrontabTaskRegistryPO.cj` 的 `//#endregion AutoCreateCode` 之后追加：  
  - `isEnabled()` 判断 status==1  
  - `parseParametersTemplate()` 解析 parametersTemplate JSON  
  验收：CrontabTaskRegistryPO 自定义方法可正确调用  
  涉及文件: `src/app/models/uctoo/CrontabTaskRegistryPO.cj`（修改，AutoCreateCode 之外）  
  预估复杂度: 低  
  依赖: 里程碑2  

---

## 4. 基于 crudgen 重新生成代码的增量开发 — DAO 层增强

- [ ] **4.1 增强 CrontabDAO 新增调度相关方法**  
  在 `CrontabDAO.cj` 的 `//#endregion AutoCreateCode` 之后追加：  
  - `findAllActiveCrontab()`: 查询所有 status=1 且未软删除的任务  
  - `updateExecutionMeta(id, lastExecutedAt, nextExecutedAt, execCount)`: 更新执行元数据  
  - `resetRetryCount(id)`: 重置重试计数  
  - `incrementRetryCount(id)`: 递增重试计数  
  - `batchUpdateNextExecutedAt(ids, nextTimes)`: 批量更新下次执行时间  
  验收：所有新增方法可正确执行SQL并返回预期结果  
  涉及文件: `src/app/dao/uctoo/CrontabDAO.cj`（修改，AutoCreateCode 之外）  
  预估复杂度: 高  
  依赖: 3.1  

- [ ] **4.2 增强 CrontabLogDAO 新增日志相关方法**  
  在 `CrontabLogDAO.cj` 的 `//#endregion AutoCreateCode` 之后追加：  
  - `batchInsert(logs)`: 批量插入日志（供异步写入器调用）  
  - `findRecentByCrontabId(crontabId, limit)`: 按任务ID查询最近日志  
  - `findRecentLogs(limit)`: 查询全局最近执行日志  
  - `getStatsByTimeRange(since)`: 按时间范围统计执行结果  
  - `findLogByCrontabIdPage(crontabId, page, size)`: 按任务ID分页查询日志  
  验收：所有新增方法可正确执行SQL并返回预期结果  
  涉及文件: `src/app/dao/uctoo/CrontabLogDAO.cj`（修改，AutoCreateCode 之外）  
  预估复杂度: 高  
  依赖: 3.2  

- [ ] **4.3 增强 CrontabTaskRegistryDAO 新增自定义方法**  
  在 `CrontabTaskRegistryDAO.cj` 的 `//#endregion AutoCreateCode` 之后追加：  
  - `findByPrefix(prefix)`: 按协议前缀查找  
  - `findAllEnabled()`: 查询所有启用的执行器（status=1）  
  验收：CrontabTaskRegistryDAO 自定义方法可正确执行SQL操作  
  涉及文件: `src/app/dao/uctoo/CrontabTaskRegistryDAO.cj`（修改，AutoCreateCode 之外）  
  预估复杂度: 中  
  依赖: 3.3  

---

## 5. 调度引擎核心模型定义（新增文件）

- [ ] **5.1 新增 TriggerType 枚举**  
  定义触发类型枚举：Cron, Manual, Misfire, Retry, SkippedConcurrent  
  每个枚举值对应 crontab_log.trigger_type 字符串值  
  验收：枚举值与数据库 trigger_type 字段值一一对应  
  涉及文件: `src/app/services/crontab/model/TriggerType.cj`（新增）  
  预估复杂度: 低  
  依赖: 无  

- [ ] **5.2 新增 MisfirePolicy 枚举**  
  定义错过执行策略枚举：FireNow(tactics=1), FireOnce(tactics=2), Ignore(tactics=3)  
  验收：枚举值与数据库 tactics 字段值一一对应  
  涉及文件: `src/app/services/crontab/model/MisfirePolicy.cj`（新增）  
  预估复杂度: 低  
  依赖: 无  

- [ ] **5.3 新增 RetryStrategy 枚举与扩展方法**  
  定义重试策略枚举：FixedDelay(base), ExponentialBackoff(base, multiplier)  
  实现 `calculateDelay(attempt)` 扩展方法，含最大延迟上限300秒截断  
  验收：FixedDelay(5000).calculateDelay(3) = 5000；ExponentialBackoff(2000, 2.0).calculateDelay(3) = 16000  
  涉及文件: `src/app/services/crontab/model/RetryStrategy.cj`（新增）  
  预估复杂度: 低  
  依赖: 无  

- [ ] **5.4 新增 ExecutionResult 数据类**  
  定义执行结果：success, exitCode, output, errorOutput, duration, resultSummary  
  验收：ExecutionResult 可正确构建和访问所有字段  
  涉及文件: `src/app/services/crontab/model/ExecutionResult.cj`（新增）  
  预估复杂度: 低  
  依赖: 无  

- [ ] **5.5 新增 CrontabExecutionContext 数据类**  
  定义执行上下文：crontabId, taskName, taskUri, parameters, timeout, triggerType, retryAttempt, maxRetries, startTime  
  验收：CrontabExecutionContext 可正确构建和访问所有字段  
  涉及文件: `src/app/services/crontab/model/CrontabExecutionContext.cj`（新增）  
  预估复杂度: 低  
  依赖: 5.1  

- [ ] **5.6 新增 SchedulerStatus 数据类**  
  定义调度器状态：isRunning, totalTasks, activeTasks, runningTasks, lastTickTime  
  验收：SchedulerStatus 可正确构建和访问所有字段  
  涉及文件: `src/app/services/crontab/model/SchedulerStatus.cj`（新增）  
  预估复杂度: 低  
  依赖: 无  

---

## 6. 执行器层实现（新增文件）

- [ ] **6.1 新增 CrontabExecutor 执行器接口**  
  定义执行器接口：prop scheme, func execute(context), func validate(taskUri)  
  验收：接口可被其他类正确实现  
  涉及文件: `src/app/services/crontab/executor/CrontabExecutor.cj`（新增）  
  预估复杂度: 低  
  依赖: 5.4, 5.5  

- [ ] **6.2 新增 BuiltinTaskHandler 内置任务处理器接口**  
  定义内置任务处理器接口：func handle(context): ExecutionResult  
  验收：接口可被具体处理器类正确实现  
  涉及文件: `src/app/services/crontab/executor/builtin/BuiltinTaskHandler.cj`（新增）  
  预估复杂度: 低  
  依赖: 5.4, 5.5  

- [ ] **6.3 新增 ScriptExecutor 脚本执行器**  
  实现 CrontabExecutor 接口：  
  - 解析 script:// URI 提取脚本路径和参数  
  - 安全检查：路径穿越检测（禁止`..`）、脚本目录白名单校验  
  - spawn 子进程执行脚本，设置环境变量 CRONTAB_ID/CRONTAB_NAME/CRONTAB_PARAMS  
  - 捕获 stdout/stderr，超时则 kill 子进程  
  - 输出截断至2000字符  
  - 日志输出使用 `magic.log.LogUtils`：`LogUtils.info("ScriptExecutor", "...")`  
  验收：给定合法脚本路径可正确执行并返回 ExecutionResult；路径穿越URI返回 validate=false  
  涉及文件: `src/app/services/crontab/executor/ScriptExecutor.cj`（新增）  
  预估复杂度: 高  
  依赖: 6.1  

- [ ] **6.4 新增 HttpExecutor HTTP回调执行器**  
  实现 CrontabExecutor 接口：  
  - 解析 http:// / https:// URL  
  - SSRF 防护：内网IP黑名单校验  
  - 构建 POST 请求，携带 X-Crontab-Id/Name/Trigger Header  
  - Body 为 parameters JSON，设置超时  
  - 2xx 视为成功，响应体截断存入 resultSummary  
  - 不自动跟随重定向  
  - 日志输出使用 `magic.log.LogUtils`：`LogUtils.info("HttpExecutor", "...")`  
  验收：给定合法URL可发送请求并返回 ExecutionResult；内网URL返回 validate=false  
  涉及文件: `src/app/services/crontab/executor/HttpExecutor.cj`（新增）  
  预估复杂度: 高  
  依赖: 6.1  

- [ ] **6.5 新增 BuiltinExecutor 内置执行器**  
  实现 CrontabExecutor 接口：  
  - 内置任务注册表 ConcurrentHashMap<String, BuiltinTaskHandler>  
  - registerBuiltinTask(name, handler) 注册方法  
  - execute(): 从注册表查找处理器并调用  
  - validate(): 校验内置任务名称仅允许 `[a-zA-Z0-9-]+`  
  - 异常隔离：捕获处理器异常不传播到调度引擎  
  - 日志输出使用 `magic.log.LogUtils`  
  验收：注册处理器后可正确执行；未注册的处理器返回 validate=false  
  涉及文件: `src/app/services/crontab/executor/BuiltinExecutor.cj`（新增）  
  预估复杂度: 中  
  依赖: 6.1, 6.2  

- [ ] **6.6 新增内置任务处理器实现**  
  实现以下5个内置任务处理器：  
  - DatabaseCleanupHandler: 清理过期数据（基于 CRONTAB_LOG_RETENTION_DAYS 配置，7天保护期）  
  - CacheRefreshHandler: 刷新缓存（调用现有 CacheManager）  
  - LogRotationHandler: 日志轮转（按日分批DELETE，每批1000条）  
  - HealthCheckHandler: 健康检查（检查DB连接和调度器状态）  
  - MetricsReportHandler: 指标上报（采集执行统计信息）  
  所有处理器使用 `magic.log.LogUtils` 输出日志  
  验收：每个处理器可独立执行并返回 ExecutionResult  
  涉及文件:  
  - `src/app/services/crontab/executor/builtin/DatabaseCleanupHandler.cj`（新增）  
  - `src/app/services/crontab/executor/builtin/CacheRefreshHandler.cj`（新增）  
  - `src/app/services/crontab/executor/builtin/LogRotationHandler.cj`（新增）  
  - `src/app/services/crontab/executor/builtin/HealthCheckHandler.cj`（新增）  
  - `src/app/services/crontab/executor/builtin/MetricsReportHandler.cj`（新增）  
  预估复杂度: 中  
  依赖: 6.2, 5.4, 5.5  

- [ ] **6.7 新增 ExecutorRegistry 执行器注册表**  
  管理三类执行器的注册与查找：  
  - register(scheme, executor): 注册执行器  
  - getExecutor(taskUri): 根据 URI 协议前缀查找执行器  
  - parseScheme(taskUri): 解析 URI 协议（script/http/https/builtin）  
  - parsePath(taskUri): 解析 URI 路径（去掉协议前缀）  
  - 日志输出使用 `magic.log.LogUtils`  
  验收：注册 script/http/builtin 三类执行器后，getExecutor 可按 URI 正确分发  
  涉及文件: `src/app/services/crontab/executor/ExecutorRegistry.cj`（新增）  
  预估复杂度: 中  
  依赖: 6.1, 6.3, 6.4, 6.5  

---

## 7. 调度策略管理器（新增文件）

- [ ] **7.1 新增 MisfireManager 错过执行管理器**  
  实现：  
  - checkAndHandle(crontab, now): 检测是否错过执行，根据 tactics 策略返回 MisfireAction  
  - countMissedExecutions(cron, from, to): 计算错过的执行次数  
  - misfire_threshold 阈值检测：超过阈值视为过期错过  
  - 日志输出使用 `magic.log.LogUtils`：`LogUtils.info("MisfireManager", "...")`  
  验收：tactics=1立即执行、tactics=2仅执行一次、tactics=3忽略；超过阈值不补充执行  
  涉及文件: `src/app/services/crontab/misfire/MisfireManager.cj`（新增）  
  预估复杂度: 高  
  依赖: 5.2, 3.1  

- [ ] **7.2 新增 RetryManager 重试管理器**  
  实现：  
  - executeWithRetry(crontab, executor, context): 包装任务执行加入重试逻辑  
  - calculateRetryDelay(attempt): 根据执行器类型选择重试策略（HTTP用指数退避，其他用固定间隔）  
  - 重试状态追踪：retry_count 递增/重置  
  - 重试耗尽处理：标记 `[RETRY_EXHAUSTED]`，下次CRON触发重置  
  - 日志输出使用 `magic.log.LogUtils`：`LogUtils.info("RetryManager", "...")`  
  验收：执行失败后自动重试；达到 max_retries 后停止重试；重试成功后 retry_count 重置为0  
  涉及文件: `src/app/services/crontab/retry/RetryManager.cj`（新增）  
  预估复杂度: 高  
  依赖: 5.3, 6.1, 4.1  

---

## 8. 异步日志写入器（新增文件）

- [ ] **8.1 新增 AsyncLogWriter 异步日志写入器**  
  实现生产者-消费者模式：  
  - Channel<CrontabLogPO> 有界队列（容量从 CRONTAB_LOG_QUEUE_SIZE 配置读取，默认1000）  
  - writeLog(log): 非阻塞入队，队列满时丢弃最早条目并记录告警  
  - consume(): 消费线程循环批量取出（最多100条/批或等待1秒），调用 CrontabLogDAO.batchInsert  
  - start(): 启动消费线程  
  - close(timeout): 优雅关闭，等待队列消费完或超时  
  - 批量写入失败时重试一次  
  - 日志输出使用 `magic.log.LogUtils`：`LogUtils.info("AsyncLogWriter", "...")`、`LogUtils.warn("AsyncLogWriter", "队列已满，丢弃最早日志")`  
  验收：日志写入不阻塞调度线程；批量写入可正确持久化到数据库  
  涉及文件: `src/app/services/crontab/log/AsyncLogWriter.cj`（新增）  
  预估复杂度: 高  
  依赖: 4.2, 3.2  

---

## 9. 调度引擎核心（SchedulerEngine，新增文件）

- [ ] **9.1 实现 SchedulerEngine 核心类**  
  实现调度引擎核心：  
  - 单例模式：`instance_` AtomicOptionReference + `initialize()` + `instance` prop  
  - 持有 Ticktock 引用、ExecutorRegistry、MisfireManager、RetryManager、AsyncLogWriter  
  - runningTasks ConcurrentHashMap 追踪运行中任务（并发控制和优雅关闭）  
  - shuttingDown AtomicBool 标记关闭状态  
  - 日志输出使用 `magic.log.LogUtils`：`LogUtils.info("SchedulerEngine", "初始化调度引擎...")`  
  验收：SchedulerEngine.initialize() 可创建单例并获取  
  涉及文件: `src/app/services/crontab/SchedulerEngine.cj`（新增）  
  预估复杂度: 高  
  依赖: 6.7, 7.1, 7.2, 8.1  

- [ ] **9.2 实现任务加载与注册逻辑**  
  在 SchedulerEngine 中实现：  
  - loadAllActiveTasks(): 从DB加载所有 status=1 且未软删除的 crontab，注册到 Ticktock  
  - reloadTask(crontabId): 重新加载单个任务到调度器  
  - removeTask(crontabId): 从调度器移除任务  
  - 注册时使用 Ticktock.addOrReplaceTask() 快捷方法，任务名 "crontab:${id}"  
  - CRON 表达式校验：不合法则跳过注册并记录警告日志  
  - 执行器白名单加载：从 crontab_task_registry 加载注册信息  
  - 一次性任务识别：once=true 且已有成功执行记录则不注册  
  验收：数据库中 N 条启用的任务被正确注册到 Ticktock；非法CRON表达式被跳过  
  涉及文件: `src/app/services/crontab/SchedulerEngine.cj`（修改）  
  预估复杂度: 高  
  依赖: 9.1, 4.1, 4.3  

- [ ] **9.3 实现任务执行与调度回调**  
  在 SchedulerEngine 中实现：  
  - executeTask(crontabId): 由 Ticktock CRON 触发回调，执行完整调度流程  
  - triggerTask(crontabId, triggerType): 手动触发（API/CLI）  
  - 执行流程：优先级排序 → 并发控制（concurrentable检查）→ 执行器分发 → 错过执行检测 → 重试包装 → 异步日志写入 → 元数据更新  
  - 执行后更新 crontab 表：lastExecutedAt, execCount, nextExecutedAt  
  - 一次性任务成功后更新 status=3 并从调度器移除  
  - 参数脱敏：sanitizeParameters() 对 password/token/secret/key 脱敏  
  - 关闭期间拒绝新触发  
  验收：CRON触发后任务正确执行并写入日志；并发冲突跳过记录 skipped_concurrent 日志  
  涉及文件: `src/app/services/crontab/SchedulerEngine.cj`（修改）  
  预估复杂度: 高  
  依赖: 9.2, 6.7, 7.1, 7.2, 8.1  

- [ ] **9.4 实现优雅关闭逻辑**  
  在 SchedulerEngine 中实现：  
  - gracefulShutdown(timeout): 标记关闭中 → 停止Ticktock → 等待运行中任务完成 → 取消重试 → 关闭AsyncLogWriter → 更新nextExecutedAt → 释放资源  
  - 超时后强制终止未完成任务  
  - 注册 env.atExit 钩子  
  - 关闭期间：CRON触发跳过、API返回503、状态查询正常返回  
  验收：优雅关闭时运行中任务可等待完成；超时30秒后强制终止  
  涉及文件: `src/app/services/crontab/SchedulerEngine.cj`（修改）  
  预估复杂度: 高  
  依赖: 9.3  

- [ ] **9.5 实现状态查询方法**  
  在 SchedulerEngine 中实现：  
  - getRunningTasks(): 获取运行中任务快照  
  - getStatus(): 获取调度器运行状态（SchedulerStatus）  
  验收：getStatus() 返回正确的 totalTasks/activeTasks/runningTasks 计数  
  涉及文件: `src/app/services/crontab/SchedulerEngine.cj`（修改）  
  预估复杂度: 中  
  依赖: 9.4  

---

## 10. 调度服务层（SchedulerService，新增文件）

- [ ] **10.1 新增 SchedulerService**  
  调度服务层封装 SchedulerEngine 操作供 Controller 调用：  
  - triggerTask(crontabId): 手动触发  
  - pauseTask(crontabId): 暂停任务  
  - resumeTask(crontabId): 恢复任务  
  - reloadAllTasks(): 重新加载所有任务  
  - getSchedulerStatus(): 获取调度器状态  
  - getRunningTasks(): 获取运行中任务  
  - getTaskRuntimeStatus(crontabId): 获取单个任务运行时状态  
  - calculateNextExecution(crontabId): 计算下次执行时间  
  - 日志输出使用 `magic.log.LogUtils`  
  验收：所有方法正确委托 SchedulerEngine 执行并返回预期结果  
  涉及文件: `src/app/services/crontab/SchedulerService.cj`（新增）  
  预估复杂度: 中  
  依赖: 9.5  

---

## 11. 服务层增强（CrontabService/CrontabLogService 增量修改）

> 📌 **增量代码写在 `//#endregion AutoCreateCode` 之外的区域**

- [ ] **11.1 增强 CrontabService 调度联动方法**  
  在 `CrontabService.cj` 的 `//#endregion AutoCreateCode` 之后追加：  
  - triggerTask(crontabId, userId): 手动触发任务（含权限校验）  
  - pauseTask(crontabId, userId): 暂停任务（group=2禁止，更新status=2，调用SchedulerEngine.removeTask）  
  - resumeTask(crontabId, userId): 恢复任务（更新status=1，调用SchedulerEngine.reloadTask）  
  - reloadAllTasks(): 重新加载所有任务到调度器  
  - getSchedulerStatus(): 获取调度器状态  
  - getRunningTasks(): 获取运行中任务  
  - getTaskRuntimeStatus(crontabId): 获取单个任务运行时状态  
  - calculateNextExecution(crontabId): 计算下次执行时间  
  - 修改 create() 方法：创建 status=1 任务后自动注册到调度引擎  
  - 修改 update() 方法：编辑调度相关字段后自动更新调度引擎  
  - 修改 delete() 方法：删除后自动从调度引擎移除  
  - 日志输出使用 `magic.log.LogUtils`  
  验收：创建/编辑/删除任务后调度引擎同步更新；group=2任务禁止删除和禁用  
  涉及文件: `src/app/services/uctoo/CrontabService.cj`（修改，AutoCreateCode 之外）  
  预估复杂度: 高  
  依赖: 10.1, 4.1  

- [ ] **11.2 增强 CrontabLogService 统计查询方法**  
  在 `CrontabLogService.cj` 的 `//#endregion AutoCreateCode` 之后追加：  
  - findByCrontabId(crontabId, page, size): 按任务ID分页查询日志  
  - findRecentLogs(limit): 查询最近执行日志  
  - getExecutionStats(crontabId, since): 获取执行统计信息  
  验收：所有新增方法可正确查询并返回结果  
  涉及文件: `src/app/services/uctoo/CrontabLogService.cj`（修改，AutoCreateCode 之外）  
  预估复杂度: 中  
  依赖: 4.2  

---

## 12. 控制器与路由层（增量修改）

> 📌 **增量代码写在 `//#endregion AutoCreateCode` 之外的区域**

- [ ] **12.1 增强 CrontabController 新增调度控制Action**  
  在 `CrontabController.cj` 的 `//#endregion AutoCreateCode` 之后追加（构造函数增加 SchedulerService 参数）：  
  - trigger(req, res): POST /api/v1/uctoo/crontab/trigger/:id  
  - pause(req, res): POST /api/v1/uctoo/crontab/pause/:id（group=2禁止）  
  - resume(req, res): POST /api/v1/uctoo/crontab/resume/:id  
  - reload(req, res): POST /api/v1/uctoo/crontab/reload  
  - schedulerStatus(req, res): GET /api/v1/uctoo/crontab/scheduler/status  
  - running(req, res): GET /api/v1/uctoo/crontab/running  
  - runtime(req, res): GET /api/v1/uctoo/crontab/:id/runtime  
  - nextExec(req, res): GET /api/v1/uctoo/crontab/:id/next-exec  
  - executors(req, res): GET /api/v1/uctoo/crontab/executors  
  所有接口受 JWT 认证 + RBAC 权限保护，系统任务保护逻辑在Controller层拦截  
  日志输出使用 `magic.log.LogUtils`  
  验收：所有新增API可正确响应；未登录返回401；group=2任务暂停/删除返回错误  
  涉及文件: `src/app/controllers/uctoo/crontab/CrontabController.cj`（修改，AutoCreateCode 之外）  
  预估复杂度: 高  
  依赖: 11.1, 10.1  

- [ ] **12.2 增强 CrontabRoute 注册调度控制路由**  
  在 `CrontabRoute.cj` 的 `registerCustomRoutes()` 中注册新增路由：  
  - trigger, pause, resume, reload, schedulerStatus, running, runtime, nextExec, executors  
  注意：自定义路由需在动态路由 :id 之前注册，避免被错误匹配  
  CrontabRoute 构造函数增加 SchedulerService 参数传递  
  验收：所有新增路由可通过HTTP请求正确访问  
  涉及文件: `src/app/routes/uctoo/crontab/CrontabRoute.cj`（修改，AutoCreateCode 之外）  
  预估复杂度: 中  
  依赖: 12.1  

- [ ] **12.3 增强 CrontabLogRoute 注册扩展路由**  
  在 `CrontabLogRoute.cj` 的 `registerCustomRoutes()` 中注册：  
  - by-crontab: GET /api/v1/uctoo/crontab_log/by-crontab/:id  
  - recent: GET /api/v1/uctoo/crontab_log/recent  
  - stats: GET /api/v1/uctoo/crontab_log/stats  
  验收：扩展路由可通过HTTP请求正确访问  
  涉及文件: `src/app/routes/uctoo/crontab_log/CrontabLogRoute.cj`（修改，AutoCreateCode 之外）  
  预估复杂度: 中  
  依赖: 11.2  

- [ ] **12.4 修改 AutoRouteConfig 注入 SchedulerService**  
  在 AutoRouteConfig.initRegistry() 中 Crontab 路由部分：  
  - 新增 SchedulerService 实例创建  
  - 修改 CrontabController 构造：传入 CrontabService + SchedulerService  
  - 修改 CrontabRoute 构造：传入 controller（含 SchedulerService）  
  验收：应用启动后 Crontab 路由可正确处理调度控制请求  
  涉及文件: `src/app/registry/AutoRouteConfig.cj`（修改）  
  预估复杂度: 中  
  依赖: 12.2  

---

## 13. Application 启动集成

- [ ] **13.1 修改 Application 类集成调度引擎**  
  在 `src/app/main.cj` 的 Application 类中：  
  - 新增成员变量 `private var schedulerEngine: ?SchedulerEngine = None`  
  - init() 末尾新增 SchedulerEngine.initialize()（在 setupRoutes 之后）  
  - 初始化失败时使用 `LogUtils.error("Application", "调度引擎初始化失败: ${e.message}")` 记录错误但不阻塞 HTTP 服务启动  
  - 检查 CRONTAB_SCHEDULER_ENABLED 配置，false 则跳过初始化  
  - stop() 中新增优雅关闭：在 server.stop() 之前调用 engine.gracefulShutdown(30s)  
  验收：应用启动后 SchedulerEngine 单例可获取；启动失败不影响HTTP服务；关闭时等待运行任务完成  
  涉及文件: `src/app/main.cj`（修改）  
  预估复杂度: 中  
  依赖: 9.5, 12.4  

---

## 14. CLI 命令实现

- [ ] **14.1 新增 CrontabCLI 命令处理器**  
  实现 `CrontabCLI` 类：  
  - execute(args): 命令分发到子命令  
  - listCommand: 列出所有计划任务（格式化表格输出，支持 --format json）  
  - showCommand: 显示任务详情  
  - addCommand: 创建任务（解析 --name/--cron/--task/--group/--tactics 等选项）  
  - editCommand: 编辑任务  
  - deleteCommand: 删除任务  
  - triggerCommand: 手动触发  
  - pauseCommand: 暂停任务  
  - resumeCommand: 恢复任务  
  - reloadCommand: 重新加载  
  - statusCommand: 调度器状态  
  - logsCommand: 查看执行日志（支持 --limit/--page/--format）  
  - executorsCommand: 列出注册执行器  
  - printUsage: 使用说明  
  CLI 命令复用 Service 层方法，不直接操作 DAO  
  日志输出使用 `magic.log.LogUtils`  
  验收：所有CLI子命令可正确执行并输出格式化结果  
  涉及文件: `src/cli/crontab_cli.cj`（新增）  
  预估复杂度: 高  
  依赖: 11.1, 11.2, 10.1  

- [ ] **14.2 修改 SkillCLI 集成 crontab 子命令**  
  在 SkillCLI.executeCommand() 的 match 中新增：  
  - `case "crontab" => executeCrontabCommand(subArgs)`  
  - 新增 executeCrontabCommand() 方法，委托 CrontabCLI.execute()  
  - 更新 printUsage() 输出 crontab 命令说明  
  验收：`skill crontab list` 命令可正确输出任务列表  
  涉及文件: `src/cli/skill_cli.cj`（修改）  
  预估复杂度: 低  
  依赖: 14.1  

---

## 15. 安全增强

- [ ] **15.1 实现 CRON 表达式注入防护**  
  在 SchedulerEngine 或 CrontabService 中实现：  
  - validateCronExpression(cron): 长度检查（最大100字符）+ CronCompiler.compile() 编译验证  
  - 创建/编辑任务时自动校验 CRON 表达式合法性  
  验收：非法CRON表达式被拒绝；合法表达式可通过  
  涉及文件: `src/app/services/crontab/SchedulerEngine.cj`（修改）  
  预估复杂度: 低  
  依赖: 9.3  

- [ ] **15.2 实现日志安全脱敏**  
  在 SchedulerEngine 中实现：  
  - sanitizeParameters(params): 对 password/token/secret/key 字段值替换为 `***`  
  - truncateOutput(output, maxLength=2000): 截断输出防止日志膨胀攻击  
  - 错误信息中不暴露服务器内部路径和凭证信息  
  验收：敏感参数被脱敏；超长输出被截断；错误信息不含内部路径  
  涉及文件: `src/app/services/crontab/SchedulerEngine.cj`（修改）  
  预估复杂度: 中  
  依赖: 9.3  

---

## 16. 健康检查扩展

- [ ] **16.1 扩展健康检查端点**  
  在现有 `/api/v1/health` 端点响应中扩展调度器状态：  
  - 调度引擎未初始化: `{"scheduler": {"running": false}}`  
  - 调度引擎关闭中: `{"scheduler": {"running": false, "state": "shutting_down"}}`  
  - 正常运行: `{"scheduler": {"running": true, "totalTasks": N, "activeTasks": M, "runningTasks": K, "uptime": "..."}}`  
  验收：健康检查端点返回包含调度器状态的完整信息  
  涉及文件: 健康检查相关 Controller/Route（修改）  
  预估复杂度: 低  
  依赖: 9.5  

---

## 17. 编译验证与集成测试

- [ ] **17.1 编译验证**  
  执行 `cjpm build` 确保所有新增和修改文件编译通过，无编译错误  
  验收：`cjpm build` 成功，无错误输出  
  涉及文件: 全部新增和修改文件  
  预估复杂度: 中  
  依赖: 1~16 所有任务  

- [ ] **17.2 调度引擎启动验证**  
  启动应用，验证：  
  - SchedulerEngine 初始化成功，`LogUtils.info("SchedulerEngine", "初始化调度引擎成功")` 日志输出  
  - 从数据库加载任务并注册到 Ticktock  
  - 手动触发任务执行并写入 crontab_log  
  - 暂停/恢复/重新加载操作正常  
  验收：调度引擎可正常初始化和运行；API/CLI操作可正确执行  
  涉及文件: 全部  
  预估复杂度: 中  
  依赖: 17.1  

- [ ] **17.3 端到端功能验证**  
  验证完整功能闭环：  
  - 创建新任务 → 自动注册到调度器 → CRON触发执行 → 日志写入 → 元数据更新  
  - 暂停任务 → 从调度器移除 → 不再触发  
  - 恢复任务 → 重新注册 → 正常触发  
  - 删除任务 → 从调度器移除  
  - 一次性任务执行成功 → status=3 → 不再触发  
  - 重试机制：失败后自动重试 → 达到上限后标记耗尽  
  - 错过执行策略：tactics=1/2/3 各策略正确处理  
  - 优雅关闭：等待运行中任务完成  
  - CLI命令完整可用  
  验收：所有核心能力场景验证通过  
  涉及文件: 全部  
  预估复杂度: 高  
  依赖: 17.2  

---

## 任务依赖关系图

```
阶段1（自动化）：
  1.1 → 2.1

🛑 里程碑1：等待人工操作（运行迁移脚本 → loadDbInfo → crudgen重新生成）

阶段2（基于crudgen重新生成代码的增量开发）：
  3.1 → 4.1 → 9.2
  3.2 → 4.2 → 8.1 → 9.1 → 9.2 → 9.3 → 9.4 → 9.5
  3.3 → 4.3 → 9.2
  5.x (模型定义) → 6.x (执行器) → 6.7 → 9.1
  6.7 → 9.1
  7.1 → 9.1   7.2 → 9.1
  9.5 → 10.1 → 11.1 → 12.1 → 12.2 → 12.4 → 13.1
  9.5 → 10.1 → 14.1 → 14.2
  11.2 → 12.3
  9.3 → 15.1, 15.2
  9.5 → 16.1

阶段3（验证）：
  全部 → 17.1 → 17.2 → 17.3

阶段4（补充任务）：
  18.1 → 18.4
  18.1, 18.2, 18.3, 18.4, 18.5 → 18.6
  19.1 → 19.2 → 19.3 → 19.4 → 19.5
  19.2 → 19.6, 19.7
  19.1 → 19.8
  19.2, 19.3, 19.4, 19.5, 19.6, 19.7, 19.8 → 19.9 → 19.10
  17.3 → 18.6  （编译验证通过后再修复打包脚本）
  17.3 → 19.9  （功能验证通过后再执行测试脚本）
```

---

## 需求覆盖追踪

| spec.md 核心能力 | 对应任务 | 覆盖状态 |
|------------------|----------|----------|
| 5.1 调度引擎集成与初始化 | 1.1, 9.1, 9.2, 13.1 | ✅ |
| 5.2 任务注册与动态管理 | 9.2, 11.1, 12.1 | ✅ |
| 5.3 任务执行与执行器 | 6.3, 6.4, 6.5, 9.3 | ✅ |
| 5.4 失败重试机制 | 5.3, 7.2, 9.3 | ✅ |
| 5.5 一次性任务管理 | 9.3 (status=3逻辑) | ✅ |
| 5.6 执行日志记录 | 3.2, 4.2, 8.1, 9.3 | ✅ |
| 5.7 错过执行策略处理 | 5.2, 7.1, 9.3 | ✅ |
| 5.8 任务执行器注册与管理 | 3.3, 4.3, 6.7, 6.6 | ✅ |
| 5.9 系统任务保护 | 11.1, 12.1 (group=2保护) | ✅ |
| 5.10 优雅关闭 | 9.4, 13.1 | ✅ |
| 5.11 运行状态监控 | 9.5, 10.1, 12.1, 16.1 | ✅ |
| 5.12 CLI命令行管理 | 14.1, 14.2 | ✅ |
| DFX 4.1 性能 | 8.1 (异步日志), 9.3 (并发控制) | ✅ |
| DFX 4.2 可靠性 | 7.2 (重试), 9.4 (优雅关闭), 8.1 (异步日志) | ✅ |
| DFX 4.3 安全性 | 15.1, 15.2, 6.3 (路径穿越), 6.4 (SSRF) | ✅ |
| DFX 4.4 可维护性 | 9.5 (状态监控), 11.2 (统计), 16.1 (健康检查) | ✅ |
| DFX 4.5 兼容性 | 2.1 (增量迁移), 3.1/3.2 (默认值), 12.2 (现有路由不变) | ✅ |
| 7.1 打包发布程序DLL依赖修复 | 18.1, 18.2, 18.3, 18.4, 18.5, 18.6 | ✅ |
| 7.2 计划任务模块测试脚本 | 19.1~19.10 | ✅ |

---

## 日志基础设施约定

本项目中所有日志输出统一使用 `magic.log.LogUtils`，与项目现有代码保持一致：

```cangjie
import magic.log.LogUtils

// 使用方式（第一个参数为标签，通常为类名）
LogUtils.info("SchedulerEngine", "初始化调度引擎...")
LogUtils.info("ScriptExecutor", "执行脚本: path=${path}, id=${id}")
LogUtils.error("HttpExecutor", "HTTP请求失败: url=${url}, error=${e.message}")
LogUtils.warn("AsyncLogWriter", "队列已满，丢弃最早日志")
LogUtils.debug("ExecutorRegistry", "查找执行器: scheme=${scheme}")
```

**禁止使用** `f_log` 或其他日志框架，统一使用 `magic.log.LogUtils`。

---

## 18. 打包发布程序DLL依赖修复

- [ ] **18.1 fountainModules 数组增加 f_ticktock**  
  在 `apps/agentskills-runtime/src/scripts/package_release/main.cj` 行516-521的 fountainModules 数组中，在 "f_regex" 和 "f_time" 之间插入 `"f_ticktock"`  
  修改前：`"f_random", "f_regex", "f_time", "f_util", "f_version"`  
  修改后：`"f_random", "f_regex", "f_ticktock", "f_time", "f_util", "f_version"`  
  验收：fountainModules 数组包含 "f_ticktock"，脚本执行时遍历 target/release/f_ticktock/ 目录并复制 DLL  
  涉及文件: `apps/agentskills-runtime/src/scripts/package_release/main.cj`（行516-521）  
  预估复杂度: 低  
  依赖: 无

- [ ] **18.2 DLL 复制 overwrite: false → true（magic 目录）**  
  修改 `apps/agentskills-runtime/src/scripts/package_release/main.cj` 行186的 magic 目录 DLL 复制语句，将 `overwrite: false` 改为 `overwrite: true`  
  验收：重新编译后新版 libmagic.app.dao.uctoo.dll（含 CrontabDAO.ti）可覆盖 bin/ 目录旧版  
  涉及文件: `apps/agentskills-runtime/src/scripts/package_release/main.cj`（行186）  
  预估复杂度: 低  
  依赖: 无

- [ ] **18.3 DLL 复制 overwrite: false → true（第三方库目录）**  
  修改 `apps/agentskills-runtime/src/scripts/package_release/main.cj` 中以下行号的 DLL 复制 overwrite 参数，统一改为 `overwrite: true`：  
  - 行217: commonmark4cj 目录  
  - 行249: json4cj 目录  
  - 行277: yaml4cj 目录  
  - 行305: f_orm 目录  
  - 行333: charset4cj 目录  
  - 行361: jwt4cj 目录  
  - 行389: logcj 目录  
  - 行417: f_data 目录  
  - 行445: f_config 目录  
  - 行473: opengauss 目录  
  - 行501: blowfish 目录  
  验收：所有第三方库 DLL 复制均使用 overwrite: true，重复执行 package_release 不会跳过已存在的 DLL  
  涉及文件: `apps/agentskills-runtime/src/scripts/package_release/main.cj`（行217/249/277/305/333/361/389/417/445/473/501）  
  预估复杂度: 低  
  依赖: 无

- [ ] **18.4 DLL 复制 overwrite: false → true（fountainModules/stdlib/stdx 目录）**  
  修改 `apps/agentskills-runtime/src/scripts/package_release/main.cj` 中以下行号的 DLL 复制 overwrite 参数，统一改为 `overwrite: true`：  
  - 行538: fountainModules 循环中的 DLL 复制  
  - 行567: stdx 目录 DLL 复制  
  - 行598: cangjie runtime 目录 DLL 复制  
  验收：f_ticktock 及其他 Fountain 模块 DLL、stdx DLL、runtime DLL 均使用 overwrite: true  
  涉及文件: `apps/agentskills-runtime/src/scripts/package_release/main.cj`（行538/567/598）  
  预估复杂度: 低  
  依赖: 18.1

- [ ] **18.5 CJO 复制 overwrite: false → true**  
  修改 `apps/agentskills-runtime/src/scripts/package_release/main.cj` 行718的 CJO 复制语句，将 `overwrite: false` 改为 `overwrite: true`；同时移除行716的 `if (!exists(destPath))` 检查（overwrite: true 下该检查冗余），确保新版 CJO 文件含新增类型反射信息能同步更新到 bin/ 目录  
  验收：重复执行 package_release 后 bin/ 目录中 CJO 文件为最新编译版本  
  涉及文件: `apps/agentskills-runtime/src/scripts/package_release/main.cj`（行716-721）  
  预估复杂度: 低  
  依赖: 无

- [ ] **18.6 修复后编译与打包验证**  
  执行以下验证步骤：  
  1. `cjpm build` 重新编译，确保 target/release/ 下生成最新 DLL  
  2. 删除 target/release/bin/ 目录  
  3. 执行 package_release 脚本，确认日志输出包含 f_ticktock DLL 复制信息  
  4. 检查 bin/ 目录包含 libf_ticktock.dll、libf_ticktock.exception.dll  
  5. 检查 libmagic.app.dao.uctoo.dll 文件时间戳与编译时间一致（非旧版）  
  6. 启动 agentskills-runtime.exe，确认无"无法定位程序输入点"错误  
  7. 检查 bin/ 目录包含所有 crontab 相关模块 DLL（见 design.md 17.1.1 清单）  
  验收：发布包可正常启动，无 DLL 依赖缺失错误  
  涉及文件: `apps/agentskills-runtime/src/scripts/package_release/main.cj`  
  预估复杂度: 中  
  依赖: 18.1, 18.2, 18.3, 18.4, 18.5

---

## 19. Python 测试脚本创建

- [ ] **19.1 创建测试脚本文件与基础结构**  
  创建 `apps/agentskills-runtime/tests/test_crontab_scheduler.py`，实现以下基础类和入口：  
  - `TestConfig`：测试配置（BASE_URL、TIMEOUT、AUTH_USERNAME/密码、API前缀常量）  
  - `TestResult`：单个测试结果记录（name、status、duration_ms、error_message、timestamp）  
  - `TestReporter`：测试报告生成器（results 列表、add_result、generate_json_report、generate_markdown_report）  
  - `main()`：命令行参数解析（--base-url、--timeout），测试执行入口框架  
  - 脚本首行 shebang 和编码声明，导入 requests、json、datetime、argparse 等标准库  
  验收：`python test_crontab_scheduler.py --help` 可正常执行并显示参数说明  
  涉及文件: `apps/agentskills-runtime/tests/test_crontab_scheduler.py`（新建）  
  预估复杂度: 中  
  依赖: 无

- [ ] **19.2 实现 AuthHelper 认证辅助类**  
  在测试脚本中实现 `AuthHelper` 类：  
  - `login(base_url, username, password) -> bool`：调用 POST /api/v1/uctoo/uctoo_user/signin，请求体 {"username": "admin", "password": "123456"}，成功提取 response.data.access_token  
  - `get_headers() -> dict`：返回 {"Authorization": "Bearer <token>"}  
  - `get_session() -> requests.Session`：返回已设置 Authorization header 的 session  
  - 登录失败时输出错误信息，所有需认证测试标记为 SKIP  
  验收：使用 admin/123456 调用登录 API 成功获取 access_token  
  涉及文件: `apps/agentskills-runtime/tests/test_crontab_scheduler.py`  
  预估复杂度: 低  
  依赖: 19.1

- [ ] **19.3 实现 TestCrontabCRUD 测试类（5个用例）**  
  在测试脚本中实现 `TestCrontabCRUD` 类，包含以下测试方法：  
  - `test_create_task()`：POST /api/v1/uctoo/crontab/add，传入测试任务数据（name=test_scheduler_task, cron_expression=*/5 * * * *, task_uri=echo hello, status=1, group=1），返回200且包含任务ID，保存ID供后续测试  
  - `test_query_task()`：GET /api/v1/uctoo/crontab/:id，验证返回200且字段 name/cron_expression 与创建时一致  
  - `test_query_task_list()`：GET /api/v1/uctoo/crontab/10/1，验证返回200且 data 为列表包含分页信息  
  - `test_edit_task()`：POST /api/v1/uctoo/crontab/edit，修改 cron_expression 为 "*/10 * * * *"，返回200，查询验证已更新  
  - `test_delete_task()`：POST /api/v1/uctoo/crontab/del，传入非系统任务ID，返回200，查询验证不再存在  
  创建失败时，依赖该任务的后续测试标记为 SKIP  
  验收：5个 CRUD 测试用例全部 PASS  
  涉及文件: `apps/agentskills-runtime/tests/test_crontab_scheduler.py`  
  预估复杂度: 中  
  依赖: 19.2

- [ ] **19.4 实现 TestCrontabScheduler 测试类（8个用例）**  
  在测试脚本中实现 `TestCrontabScheduler` 类，包含以下测试方法：  
  - `test_trigger_task()`：POST /api/v1/uctoo/crontab/trigger/:id，返回200，查询日志验证 trigger_type="manual"  
  - `test_pause_task()`：POST /api/v1/uctoo/crontab/pause/:id，返回200，查询任务验证 status=2  
  - `test_resume_task()`：POST /api/v1/uctoo/crontab/resume/:id，返回200，查询任务验证 status=1  
  - `test_reload_tasks()`：POST /api/v1/uctoo/crontab/reload，返回200，验证调度器状态正常  
  - `test_scheduler_status()`：GET /api/v1/uctoo/crontab/scheduler/status，返回200，包含 scheduler_state、registered_task_count 字段  
  - `test_running_tasks()`：GET /api/v1/uctoo/crontab/running，返回200，data 为列表  
  - `test_task_runtime_status()`：GET /api/v1/uctoo/crontab/:id/runtime，返回200，包含任务运行时信息  
  - `test_next_execution()`：GET /api/v1/uctoo/crontab/:id/next-exec，返回200，包含下次执行时间  
  执行顺序：trigger 须在 create 之后、pause 须在 trigger 之后、resume 须在 pause 之后  
  验收：8个调度控制测试用例全部 PASS  
  涉及文件: `apps/agentskills-runtime/tests/test_crontab_scheduler.py`  
  预估复杂度: 中  
  依赖: 19.3

- [ ] **19.5 实现 TestCrontabLog 测试类（3个用例）**  
  在测试脚本中实现 `TestCrontabLog` 类，包含以下测试方法：  
  - `test_query_log_by_crontab()`：GET /api/v1/uctoo/crontab_log/by-crontab/:id，返回200，验证日志字段完整性（crontab_id、start_time、end_time、used_time、trigger_type、status）  
  - `test_recent_logs()`：GET /api/v1/uctoo/crontab_log/recent，返回200，data 为列表按时间倒序  
  - `test_log_stats()`：GET /api/v1/uctoo/crontab_log/stats，返回200，包含统计汇总信息  
  验收：3个日志查询测试用例全部 PASS  
  涉及文件: `apps/agentskills-runtime/tests/test_crontab_scheduler.py`  
  预估复杂度: 低  
  依赖: 19.4

- [ ] **19.6 实现 TestCrontabExecutor 测试类（2个用例）**  
  在测试脚本中实现 `TestCrontabExecutor` 类，包含以下测试方法：  
  - `test_executors()`：GET /api/v1/uctoo/crontab/executors，返回200，data 包含执行器类型列表（script/http/builtin）  
  - `test_builtin_tasks()`：GET /api/v1/uctoo/crontab/builtin-tasks，返回200，data 包含内置任务信息  
  验收：2个执行器/内置任务测试用例全部 PASS  
  涉及文件: `apps/agentskills-runtime/tests/test_crontab_scheduler.py`  
  预估复杂度: 低  
  依赖: 19.2

- [ ] **19.7 实现 TestSystemTaskProtection 测试类（2个用例）**  
  在测试脚本中实现 `TestSystemTaskProtection` 类，包含以下测试方法：  
  - `test_delete_system_task_forbidden()`：先查询任务列表找到 group=2 的系统任务，调用 POST /api/v1/uctoo/crontab/del 尝试删除，验证返回 403 或错误信息，任务未被删除  
  - `test_pause_system_task_forbidden()`：查找 group=2 的系统任务，调用 POST /api/v1/uctoo/crontab/pause/:id 尝试暂停，验证返回 403 或错误信息，任务未被暂停  
  前置条件：数据库中存在 group=2 的系统任务，若无则标记 SKIP  
  验收：2个系统任务保护测试用例 PASS 或合理 SKIP  
  涉及文件: `apps/agentskills-runtime/tests/test_crontab_scheduler.py`  
  预估复杂度: 低  
  依赖: 19.2

- [ ] **19.8 实现 TestReporter 双格式报告生成**  
  在测试脚本中完善 `TestReporter` 类的报告生成功能：  
  - `generate_json_report()`：生成 `test_crontab_scheduler_result.json`，结构包含 summary（total/passed/failed/skipped/error/duration_ms/start_time/end_time）和 results 数组（每个用例的 name/status/duration_ms/error_message/timestamp）  
  - `generate_markdown_report()`：生成 `test_crontab_scheduler_report.md`，包含汇总统计表和各用例结果明细表（序号/名称/状态/耗时/错误）  
  - 报告文件输出到 `apps/agentskills-runtime/tests/` 目录  
  验收：测试执行后生成 JSON 和 Markdown 两种格式报告文件，报告内容包含21个测试用例的完整结果和汇总统计  
  涉及文件: `apps/agentskills-runtime/tests/test_crontab_scheduler.py`  
  预估复杂度: 中  
  依赖: 19.1

- [ ] **19.9 集成 main() 测试执行流程与数据清理**  
  在 `main()` 中实现完整测试执行流程：  
  1. 解析命令行参数（--base-url、--timeout）  
  2. AuthHelper.login() 获取 access_token，失败则所有测试标记 SKIP 并退出  
  3. 按顺序执行 21 个测试用例（CRUD创建→查询→列表→编辑→调度控制→日志→执行器→系统保护→CRUD删除清理）  
  4. 测试数据清理：test_delete_task 删除测试创建的非系统任务  
  5. TestReporter.generate_json_report() 和 generate_markdown_report() 生成报告  
  确保系统任务（group=2）不被修改或删除；测试自包含创建和清理数据  
  验收：`python test_crontab_scheduler.py --base-url http://localhost:8080` 执行完毕后，测试数据已清理，系统任务未变更，tests 目录下生成两个报告文件  
  涉及文件: `apps/agentskills-runtime/tests/test_crontab_scheduler.py`  
  预估复杂度: 中  
  依赖: 19.2, 19.3, 19.4, 19.5, 19.6, 19.7, 19.8

- [ ] **19.10 异常场景处理与 SKIP 逻辑**  
  在测试脚本中实现以下异常场景处理：  
  - API 服务未启动：所有测试标记 FAIL，错误信息为 "Connection refused"  
  - 登录认证失败：所有需认证测试标记 SKIP，记录 "登录认证失败: <status_code> <reason>"  
  - 创建任务失败：标记 FAIL，依赖该任务的后续测试（查询/编辑/暂停/恢复/触发）标记 SKIP  
  - 无系统任务（group=2）：系统任务保护测试标记 SKIP，备注 "无系统任务可测试"  
  - 清理失败：记录 WARN 日志，不影响测试报告通过/失败统计  
  验收：各种异常场景下测试脚本不崩溃，报告正确反映 SKIP/FAIL 状态  
  涉及文件: `apps/agentskills-runtime/tests/test_crontab_scheduler.py`  
  预估复杂度: 低  
  依赖: 19.9
