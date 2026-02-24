// AgentSkills Runtime UniApp SDK
// 轻量级 SDK，用于在 UniApp 应用中与 AgentSkills Runtime 通信

import SkillsClient from './client.js';
import WebSocketManager from './websocket.js';
import { handleApiError, createClientConfig } from './utils.js';

// 默认配置
const DEFAULT_BASE_URL = 'http://127.0.0.1:8080';
const DEFAULT_WS_URL = 'ws://127.0.0.1:8080/ws/chat';

/**
 * 创建 AgentSkills Runtime 客户端
 * @param {Object} config - 配置选项
 * @param {string} config.baseUrl - Runtime API 基础 URL
 * @param {string} config.wsUrl - WebSocket 连接 URL
 * @param {string} config.authToken - 认证令牌
 * @param {number} config.timeout - 请求超时时间（毫秒）
 * @returns {SkillsClient} SkillsClient 实例
 */
export function createClient(config = {}) {
  const clientConfig = createClientConfig(config);
  return new SkillsClient(clientConfig);
}

/**
 * 创建 WebSocket 管理器
 * @param {Object} config - 配置选项
 * @param {string} config.wsUrl - WebSocket 连接 URL
 * @param {Function} config.onMessage - 消息接收回调
 * @param {Function} config.onError - 错误回调
 * @param {Function} config.onClose - 连接关闭回调
 * @param {Function} config.onOpen - 连接打开回调
 * @returns {WebSocketManager} WebSocketManager 实例
 */
export function createWebSocketManager(config = {}) {
  return new WebSocketManager(config);
}

/**
 * 处理 API 错误
 * @param {Error|Object|string} error - 错误对象
 * @returns {Object} 标准化的错误对象
 */
export { handleApiError };

/**
 * AgentSkills Runtime UniApp SDK
 */
export default {
  createClient,
  createWebSocketManager,
  handleApiError,
  DEFAULT_BASE_URL,
  DEFAULT_WS_URL
};
