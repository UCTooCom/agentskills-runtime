# yuanbao-policy — L3 进程隔离轨插件（检索内核·编译态）

`skills/yuanbao-search` 的**编译态孪生兄弟**：同一套检索内核、同一套可信度四因子规则、
同一套「敢说不知道」门禁，差别只在于**载体**——本插件是独立可执行文件，
**删掉 `src/` 照样加载运行**，这是脚本型技能做不到的。

- 协议：MIT
- 运行形态：`mode: process`，JSON-RPC over stdio（stdout 是协议通道，诊断走 stderr）
- 能力契约：见 [`SKILL.md`](./SKILL.md)
- 完整规格：`.codeartsdoer/specs/1024/`（spec / design / research / tasks）

---

## 一、为什么要有这一轨

脚本型技能（JS / Python）必须以**明文源码**分发。当能力本身是有价的检索内核时，
「能交付但不泄露源码」就成了刚需。L3 进程隔离轨把内核编译成 exe：

| | 脚本轨 `yuanbao-search` | 插件轨 `yuanbao-policy` |
|---|---|---|
| 载体 | TypeScript / Python 明文 | `skill_yuanbao_policy.exe` |
| 分发 | 源码必须可见 | **删掉 `src/` 照样跑** |
| 时效判定 | 精确到日 | 按发布年份近似 |
| 参数 | 全参数 | 子集：`query` / `industry` / `cnt` / `freshness` |
| 出网 | `http_client.ts` 子进程 → 内置 fetch | 内置 `curl` 子进程 |
| 定位 | 主力 | 闭源分发载体 / 同规则降级通道 |

两轨共用同一套判定规则（design §2.5.5），可互为降级：插件不可用时宿主回退脚本轨。

## 二、构建

```bash
cd skills/yuanbao-policy
cjpm build
# 产物：target/release/bin/skill_yuanbao_policy.exe
```

要求 cjc 1.1.3 + `libs/cangjie-stdx-windows-x64-1.1.3.1`。
依赖：`ystyle::cordis_plugin`、`jsonvalue`、`jsonrpc`。

## 三、闭源分发（本插件的独有能力）

分发目录只需三样东西，**不需要 `src/`**：

```
yuanbao-policy/
├── plugin.yaml                                   # mode: process / enabled: true / order: 20
├── SKILL.md                                      # 模型行为契约
└── target/release/bin/skill_yuanbao_policy.exe   # 编译产物 + 同目录 DLL
```

> ⚠️ exe 依赖的 DLL 必须一并分发（SDK std / libs stdx / 依赖包 `*.dll` / OpenSSL 四路），
> 缺一路是加载期 `0xC0000135` 秒退、**一行日志都没有**。Windows 只搜 exe 同目录。

验证方法：复制分发目录 → 删除 `src/` → 宿主加载 → 执行一次检索 → 截图目录树（无 `src/`）+ 成功输出。

## 四、调用形态

handler key 为 `yuanbao-policy`，`args[0]` 是单个对象，用 `action` 分派：

```jsonc
// action = "search"
{ "action": "search", "query": "专精特新 中小企业 申报 条件",
  "industry": "gov", "cnt": 50, "freshness": "1y" }

// action = "selftest"
{ "action": "selftest" }
```

返回（成功）：`ok` / `requestId` / `version` / `elapsedMs` / `degraded` / `query` /
`track:"l3-process"` / `kb` / `kbCount` / `returned` / `credible` / `excludedCount` /
`items[]` / `excluded[]`。

返回（失败，不抛异常）：`{ ok:false, degraded:true, error:"…", items:[], excluded:[] }`。

`excluded[]` 是「敢说不知道」的对外可见证据——过不了门禁的条目不会被丢弃，
而是明确列出并说明原因。

## 五、构建过程实录（AI 驱动开发的真实一面）

本工程由 AI 按规格生成仓颉代码、用户在本机编译回传日志、AI 分析修复，**四轮闭环**后 0 errors：

| 轮次 | 报错 | 根因 |
|---|---|---|
| 1 | 16 errors（打印 8 条） | `init` 是关键字，`PolicyKb.init(...)` 非法 7 处（编译器「用反引号转义」的建议是错的） |
| 2 | 2 errors | `match` 是关键字，不可作函数名/成员名 → 改名 `matchPolicy`（反引号建议同样错误） |
| 3 | 31 errors（打印 8 条） | `HashMap[key]` 返回 `V`（键缺失抛 `NoneValueException`），而 `JsonValue[key]` 返回 `?JsonValue` —— 混用后报 `undeclared identifier 'Some'` 10 处 |
| 4 | 1 error | `Array<Rune>(n, { i => ... })` 的初始化 lambda 也是闭包，**不能捕获 `var`**（`transport.cj:78`） |

教训已固化进 `cangjie-coder` 技能的易错速查表，供后续生成复用。
这类「编译通过 ≠ 能用」的闭环正是本项目主张的 AI-Driven Development 工作流。

## 六、已知差异（插件轨 vs 脚本轨）

| 项 | 插件轨行为 |
|---|---|
| 时效判定 | 从 `date` 取年份，`nowYear - year > days/365 + 1` 判过期（精度到年） |
| 参数子集 | 不支持 `site` / `exclude` / `deeplinks`，需限定域名时走脚本轨 |
| 出网 | 写临时请求文件后 `curl --data-binary @file`，依赖系统 `curl.exe` |
| 原文库定位 | 依次尝试 5 个相对路径（进程工作目录由宿主决定），全失败则 `kb=false` |

## 七、合规

- 仅做客观政策的检索与条件比对，不做政策解读或倾向性评价。
- 凭据只从 `.env` 读取（`QCLOUD_COS_SECRET_ID` / `QCLOUD_COS_SECRET_KEY`），
  不进产物、日志、异常堆栈与进程参数。
- 政策原文库为北京地区 74 条政策，报告必须明示适用范围。
- 内容禁区：不涉时政评论与特定个人。

## 八、License

MIT。分发时无需附带 `src/`，但须保留本文件与 `SKILL.md` 中的来源声明。
