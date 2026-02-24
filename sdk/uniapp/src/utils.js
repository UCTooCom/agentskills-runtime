// AgentSkills Runtime UniApp SDK Utils
// 通用工具函数

import { DEFAULT_BASE_URL, DEFAULT_WS_URL, DEFAULT_TIMEOUT } from './constants.js';

/**
 * 创建客户端配置
 * @param {Object} config - 原始配置
 * @returns {Object} 标准化的配置
 */
export function createClientConfig(config = {}) {
  return {
    baseUrl: config.baseUrl || process.env.SKILL_RUNTIME_API_URL || DEFAULT_BASE_URL,
    wsUrl: config.wsUrl || process.env.SKILL_RUNTIME_WS_URL || DEFAULT_WS_URL,
    authToken: config.authToken || process.env.SKILL_RUNTIME_AUTH_TOKEN,
    timeout: config.timeout || DEFAULT_TIMEOUT
  };
}

/**
 * 处理 API 错误
 * @param {Error|Object|string} error - 错误对象
 * @returns {Object} 标准化的错误对象
 */
export function handleApiError(error) {
  if (error instanceof Error) {
    return {
      errno: 500,
      errmsg: error.message
    };
  }
  
  if (typeof error === 'object') {
    if (error.errMsg) {
      return {
        errno: 500,
        errmsg: error.errMsg
      };
    }
    if (error.message) {
      return {
        errno: 500,
        errmsg: error.message
      };
    }
    return {
      errno: 500,
      errmsg: JSON.stringify(error)
    };
  }
  
  if (typeof error === 'string') {
    return {
      errno: 500,
      errmsg: error
    };
  }
  
  return {
    errno: 500,
    errmsg: 'Unknown error'
  };
}

/**
 * 格式化消息
 * @param {Object} message - 消息对象
 * @returns {Object} 格式化后的消息
 */
export function formatMessage(message) {
  return {
    id: message.id || Date.now().toString(),
    type: message.type || 'message',
    content: message.content || '',
    sender: message.sender || 'user',
    timestamp: message.timestamp || Date.now(),
    ...message
  };
}

/**
 * 延迟函数
 * @param {number} ms - 延迟时间（毫秒）
 * @returns {Promise} Promise 对象
 */
export function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
