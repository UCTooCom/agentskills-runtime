// AgentSkills Runtime UniApp SDK Constants
// 常量定义

// 默认配置
export const DEFAULT_BASE_URL = 'http://127.0.0.1:8080';
export const DEFAULT_WS_URL = 'ws://127.0.0.1:8080/ws/chat';
export const DEFAULT_TIMEOUT = 30000; // 30秒

// WebSocket 消息类型
export const WS_MESSAGE_TYPES = {
  PING: 'ping',
  PONG: 'pong',
  MESSAGE: 'message',
  ERROR: 'error',
  SYSTEM: 'system',
  SKILL_EXECUTION: 'skill_execution',
  SKILL_RESULT: 'skill_result'
};

// API 路径
export const API_PATHS = {
  HEALTH: '/hello',
  SKILLS: '/skills',
  SKILLS_ADD: '/skills/add',
  SKILLS_DEL: '/skills/del',
  SKILLS_EXECUTE: '/skills/execute',
  SKILLS_SEARCH: '/skills/search',
  SKILLS_EDIT: '/skills/edit'
};

// 错误码
export const ERROR_CODES = {
  NETWORK_ERROR: 1001,
  TIMEOUT_ERROR: 1002,
  SERVER_ERROR: 1003,
  AUTH_ERROR: 1004,
  NOT_FOUND: 1005,
  BAD_REQUEST: 1006
};
