// AgentSkills Runtime WebSocket Manager
// 处理与 Runtime 的实时 WebSocket 通信

import { DEFAULT_WS_URL } from './constants.js';

/**
 * WebSocket 管理器
 */
export default class WebSocketManager {
  /**
   * 构造函数
   * @param {Object} config - 配置选项
   * @param {string} config.wsUrl - WebSocket 连接 URL
   * @param {Function} config.onMessage - 消息接收回调
   * @param {Function} config.onError - 错误回调
   * @param {Function} config.onClose - 连接关闭回调
   * @param {Function} config.onOpen - 连接打开回调
   * @param {number} config.reconnectInterval - 重连间隔（毫秒）
   * @param {number} config.maxReconnectAttempts - 最大重连次数
   */
  constructor(config = {}) {
    this.wsUrl = config.wsUrl || DEFAULT_WS_URL;
    this.onMessage = config.onMessage || (() => {});
    this.onError = config.onError || (() => {});
    this.onClose = config.onClose || (() => {});
    this.onOpen = config.onOpen || (() => {});
    this.reconnectInterval = config.reconnectInterval || 3000;
    this.maxReconnectAttempts = config.maxReconnectAttempts || 5;
    this.reconnectAttempts = 0;
    this.ws = null;
    this.isConnecting = false;
    this.heartbeatInterval = null;
    this.heartbeatTimeout = null;
  }

  /**
   * 连接 WebSocket
   */
  connect() {
    if (this.ws && (this.ws.readyState === WebSocket.OPEN || this.ws.readyState === WebSocket.CONNECTING)) {
      return;
    }

    if (this.isConnecting) {
      return;
    }

    this.isConnecting = true;

    try {
      this.ws = uni.connectSocket({
        url: this.wsUrl,
        success: () => {
          console.log('WebSocket connection initiated');
        },
        fail: (err) => {
          console.error('WebSocket connection failed:', err);
          this.isConnecting = false;
          this.handleReconnect();
        }
      });

      this.ws.onOpen(() => {
        console.log('WebSocket connected');
        this.isConnecting = false;
        this.reconnectAttempts = 0;
        this.onOpen();
        this.startHeartbeat();
      });

      this.ws.onMessage((res) => {
        const message = JSON.parse(res.data);
        this.onMessage(message);
        this.resetHeartbeat();
      });

      this.ws.onError((err) => {
        console.error('WebSocket error:', err);
        this.onError(err);
      });

      this.ws.onClose((res) => {
        console.log('WebSocket closed:', res);
        this.isConnecting = false;
        this.stopHeartbeat();
        this.onClose(res);
        this.handleReconnect();
      });
    } catch (error) {
      console.error('WebSocket connection error:', error);
      this.isConnecting = false;
      this.handleReconnect();
    }
  }

  /**
   * 断开 WebSocket 连接
   */
  disconnect() {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
    this.stopHeartbeat();
    this.reconnectAttempts = 0;
  }

  /**
   * 发送消息
   * @param {Object} message - 消息对象
   * @returns {boolean} 是否发送成功
   */
  send(message) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      try {
        this.ws.send(JSON.stringify(message));
        return true;
      } catch (error) {
        console.error('Error sending message:', error);
        return false;
      }
    } else {
      console.error('WebSocket not connected');
      return false;
    }
  }

  /**
   * 处理重连
   */
  handleReconnect() {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++;
      console.log(`Attempting to reconnect... (${this.reconnectAttempts}/${this.maxReconnectAttempts})`);
      setTimeout(() => {
        this.connect();
      }, this.reconnectInterval);
    } else {
      console.error('Max reconnect attempts reached');
    }
  }

  /**
   * 开始心跳
   */
  startHeartbeat() {
    this.heartbeatInterval = setInterval(() => {
      this.send({ type: 'ping' });
    }, 15000); // 每15秒发送一次心跳

    this.heartbeatTimeout = setInterval(() => {
      console.warn('WebSocket heartbeat timeout, reconnecting...');
      this.disconnect();
      this.connect();
    }, 30000); // 30秒没有收到消息则重连
  }

  /**
   * 停止心跳
   */
  stopHeartbeat() {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }
    if (this.heartbeatTimeout) {
      clearInterval(this.heartbeatTimeout);
      this.heartbeatTimeout = null;
    }
  }

  /**
   * 重置心跳
   */
  resetHeartbeat() {
    if (this.heartbeatTimeout) {
      clearInterval(this.heartbeatTimeout);
      this.heartbeatTimeout = setInterval(() => {
        console.warn('WebSocket heartbeat timeout, reconnecting...');
        this.disconnect();
        this.connect();
      }, 30000);
    }
  }

  /**
   * 获取连接状态
   * @returns {number} 连接状态
   */
  getReadyState() {
    if (!this.ws) {
      return WebSocket.CLOSED;
    }
    return this.ws.readyState;
  }

  /**
   * 检查是否已连接
   * @returns {boolean} 是否已连接
   */
  isConnected() {
    return this.ws && this.ws.readyState === WebSocket.OPEN;
  }
}
