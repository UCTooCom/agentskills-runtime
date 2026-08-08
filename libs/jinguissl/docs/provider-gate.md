# 提供商门禁（Provider Gate）API 参考

## 类型

- `ContractProviderCapabilityRecord`：提供商能力记录
- `ContractProviderAttachContractInfo`：附加合约信息
- `ContractProviderErrorDescriptor`：错误描述器
- `ContractProviderFallbackDecision`：降级决策
- `ContractProviderSmokeProfile`：冒烟测试档案
- `ContractProviderConsumptionGateReport`：消费入口报告

## 提供商元数据

### contractProviderCapabilityRecord(): ContractProviderCapabilityRecord
当前提供商的能力记录。

### contractProviderAttachContractInfo(): ContractProviderAttachContractInfo
提供商附加合约信息。

### contractProviderServerAttachBoundary(): ContractProviderServerAttachBoundary
服务端附加边界描述。

## 错误映射

### contractMapToIgniteCryptoErrorCode(code: ContractErrorCode): ContractIgniteCryptoErrorCode
将 `ContractErrorCode` 映射为 Ignite 风格的错误码。

### contractMapExceptionToIgniteCryptoErrorCode(exception: ContractException): ContractIgniteCryptoErrorCode
从异常获取 Ignite 错误码。

### contractDescribeProviderErrorCode(code, phase?, detail?): ContractProviderErrorDescriptor
构造提供商错误描述。

### contractRecommendProviderFallback(error): ContractProviderFallbackDecision
推荐降级策略。

## 冒烟测试

### contractProviderSmokeFixtureCatalog(): Array<ContractProviderSmokeFixtureInfo>
获取冒烟测试夹具目录。

### contractProviderSmokeSuiteBaselineCatalog(): Array<ContractProviderSmokeBaselineReport>
获取基准报告目录。

### contractTryRequireProviderSmokeProfile(profile): ContractProviderSmokeSelfCheckOutcome
按 profile 检查提供商冒烟状态。

## 消费入口

### contractDescribeProviderConsumptionGate(path): ContractProviderConsumptionGateReport
描述指定消费路径的入口状态。

### contractListProviderConsumptionGates(): Array<ContractProviderConsumptionGateReport>
列出所有消费路径的入口状态。
