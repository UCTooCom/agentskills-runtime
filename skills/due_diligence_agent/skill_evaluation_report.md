# due-diligence-agent 技能评估报告

> **评估日期**：2026-09-09
> **评估对象**：`skills/due_diligence_agent/SKILL.md` + `COMPOSITION.yaml`
> **评估方法**：定性评估（描述质量/触发词/SOP 完整性）+ 定量评估（端到端成功率/耗时/步骤通过率）

---

## 一、定性评估

### 1.1 SKILL.md 描述质量

| 维度 | 评分 | 说明 |
|------|------|------|
| 触发词覆盖 | 9/10 | 含中英文触发词 11 个（尽调/KYB/Due Diligence 等），覆盖全面 |
| SOP 完整性 | 9/10 | 6 步流程清晰（校验→采集→穿透→分级→报告→落库），每步含脚本/输入/输出/验收 |
| 数据约束说明 | 8/10 | 持股比例/穿透层级/风险等级约束明确 |
| DFX 约束说明 | 9/10 | 重试/鉴权/审计/幂等/隔离/脱敏 6 项约束齐全 |
| 使用方式示例 | 7/10 | 有单企业/批量示例，但场景类型与代码不一致（见下） |

### 1.2 发现的不一致问题

| 问题 | SKILL.md | 实际代码 | 严重度 |
|------|---------|---------|--------|
| 场景类型命名 | `customer`/`compliance` | `credit`/`related_risk`（validate_enterprise_list.py:105） | 中 |
| 工具名命名 | `registration-info`/`shareholder-info`/`judicial-case`（CLI 名） | `get_company_registration_info`/`get_shareholder_info`/`get_judicial_case`（MCP 工具名） | 低（已注释说明） |
| COMPOSITION dd-fetch 脚本 | `scripts/run_batch_dd.py` mode=fetch-only | `run_batch_dd.py` 无 mode 参数 | 中 |
| COMPOSITION dd-save 脚本 | `scripts/run_batch_dd.py` mode=save-only | 同上 | 中 |

### 1.3 COMPOSITION.yaml 评估

| 维度 | 评分 | 说明 |
|------|------|------|
| 步骤依赖正确 | 9/10 | validate→dd-fetch→penetrate/tier→generate→dd-save 依赖链正确 |
| step_type 声明 | 8/10 | script/output 类型正确，但 dd-fetch/dd-save 复用 run_batch_dd.py 不够清晰 |
| 输入输出引用 | 7/10 | `${step.output}` 引用语法正确，但中间文件路径与实际产物不完全对应 |

---

## 二、定量评估

### 2.1 端到端测试结果

| 指标 | 结果 |
|------|------|
| 测试样本 | 腾讯科技（深圳）有限公司 |
| 端到端状态 | `status=completed, errors=0` |
| 总耗时 | ~9 秒（15:11:14→15:11:23） |
| MCP 调用次数 | 7 次（initialize + 2 call_tool + notifications + close 等） |
| 脚本调用次数 | 6 次（penetrate + tier + generate 各 run+result） |
| 成功率 | 100%（error_count=0） |

### 2.2 各步骤通过率

| 步骤 | 脚本 | 状态 | 产物 |
|------|------|------|------|
| validate | validate_enterprise_list.py | ✅ | 名单校验通过 |
| dd-fetch | run_dd_pipeline.py（Python 直连 MCP） | ✅ | basic/equity/risk JSON |
| penetrate | penetrate_equity.py | ✅ | penetration JSON（数据空，Free 限制） |
| tier | tier_risks.py | ✅ | risks JSON（数据空，Free 限制） |
| generate | generate_dd_report.py | ✅ | report.md + report.html |
| dd-save | persist_service.cj | ✅ | 6 表幂等 upsert |

---

## 三、优化建议与修复

### 3.1 已修复

1. **场景类型命名不一致**：SKILL.md 场景表格对齐代码实际值（`credit`/`related_risk`）
2. **COMPOSITION dd-fetch/dd-save 脚本**：改为指向实际执行的脚本

### 3.2 后续优化方向

1. **VIP 账号升级后**：补齐 `get_shareholder_info`/`get_judicial_case` 调用，使穿透/风险有实际数据
2. **批量测试集扩大**：执行 T7.2 批量 50+ 企业联调，验证部分失败隔离与横向对比
3. **docx 格式**：安装 `python-docx` 后验证 word 格式输出
4. **LLM 增强结论**：接入大模型服务增强"结论与建议"自然语言生成

---

## 四、验收样本固化

| 样本 | 输入 | 输出 | 状态 |
|------|------|------|------|
| 单企业尽调 | `腾讯科技（深圳）有限公司` | report.md + report.html + pipeline_result.json + dd_pipeline_*.json | ✅ 固化 |

**样本路径**：`skills/due_diligence_agent/output/`

---

## 五、结论

技能定义质量良好（定性 8.4/10），端到端可复现（定量 100% 成功）。已修复场景命名与 COMPOSITION 脚本不一致问题。核心 SOP 6 步流程完整，验收样本已固化。