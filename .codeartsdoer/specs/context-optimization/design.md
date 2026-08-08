# 上下文优化引擎 - 设计文档

## 架构概述

实现5层压缩管道和提示缓存机制，优化Agent上下文窗口利用率。

## 核心组件

### ContextCompressionPipeline
5层压缩管道：去重→摘要→抽象→提取→Token缩减

### PromptCache
LRU缓存 + Sacred保护机制，对话级缓存不被清除

## 关键文件
- `src/interaction/context_optimization.cj` — CompressionLayer/ContextCompressionPipeline/PromptCacheEntry/PromptCache