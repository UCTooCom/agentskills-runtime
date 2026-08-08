# AES 后端探测 API 参考

## 枚举

- `ContractAesEngineKind`: `Auto`, `Software`, `Hardware`
- `ContractAesBackendReadiness`: `AcceleratedReady`, `BridgeReady`, `SoftwareOnly`, `Unavailable`

## 硬件探测

### contractAesListHardwareMountPoints(): Array<ContractAesHardwareMountPointInfo>
列出所有 AES 硬件挂载点（aesni, armv8-ce, shim, loongarch64 等）。

### contractAesDefaultHardwareBackendHint(): String
当前平台的默认硬件后端提示。

### contractAesProbeHardware(backendHint?: String): ContractAesHardwareProbeInfo
探测指定后端的可用性。

### contractAesHardwareRoadmap(): Array<ContractAesHardwareRoadmapEntry>
获取 AES 硬件路线图。

## 引擎解析

### contractResolveAesEngine(requestedEngine?, backendHint?): ContractAesEngineInfo
解析 AES 引擎。`requestedEngine` 默认为 `Auto`。

### contractTryResolveAesEngine(...): ContractAesEngineResolveOutcome
安全的引擎解析版本。

### contractRequireAesAcceleratedBackend(backendHint?): ContractAesHardwareProbeInfo
要求加速后端可用，否则抛出 `UNSUPPORTED`。

## 启动自检

### contractRecommendAesBackend(): ContractAesBackendRecommendation
推荐最佳可用后端。

### contractAesStartupSelfCheck(requestedEngine?, backendHint?): ContractAesStartupSelfCheckReport
全面的 AES 启动自检。

### contractAesCurrentReleasePlan(requestedEngine?, backendHint?): ContractAesCurrentReleasePlanReport
当前 release plan 与后端状态报告。

### contractRequireAesCurrentReleasePrimaryBackend(backendHint?)
要求使用当前 release 的首选后端，否则抛出 `UNSUPPORTED`。
