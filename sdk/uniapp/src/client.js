// AgentSkills Runtime UniApp Client
// 处理与 Runtime API 的 HTTP 通信

import { DEFAULT_BASE_URL, DEFAULT_TIMEOUT } from './constants.js';

/**
 * AgentSkills Runtime 客户端
 */
export default class SkillsClient {
  /**
   * 构造函数
   * @param {Object} config - 配置选项
   * @param {string} config.baseUrl - Runtime API 基础 URL
   * @param {string} config.authToken - 认证令牌
   * @param {number} config.timeout - 请求超时时间（毫秒）
   */
  constructor(config = {}) {
    this.baseUrl = config.baseUrl || DEFAULT_BASE_URL;
    this.authToken = config.authToken;
    this.timeout = config.timeout || DEFAULT_TIMEOUT;
  }

  /**
   * 发送 HTTP 请求
   * @param {string} url - 请求路径
   * @param {Object} options - 请求选项
   * @returns {Promise} 请求结果
   */
  async request(url, options = {}) {
    const headers = {
      'Content-Type': 'application/json',
      ...(this.authToken ? { 'Authorization': `Bearer ${this.authToken}` } : {}),
      ...options.headers
    };

    return new Promise((resolve, reject) => {
      uni.request({
        url: `${this.baseUrl}${url}`,
        method: options.method || 'GET',
        data: options.data,
        header: headers,
        timeout: this.timeout,
        success: (res) => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(res.data);
          } else {
            reject(new Error(`Request failed with status ${res.statusCode}: ${res.data?.errmsg || res.errMsg}`));
          }
        },
        fail: (err) => {
          reject(err);
        }
      });
    });
  }

  /**
   * 健康检查
   * @returns {Promise<Object>} 健康检查结果
   */
  async healthCheck() {
    try {
      const response = await this.request('/hello');
      return { status: 'ok', message: response };
    } catch (error) {
      return { status: 'error', message: 'Server not responding' };
    }
  }

  /**
   * 列出所有技能
   * @param {Object} options - 查询选项
   * @param {number} options.limit - 每页数量
   * @param {number} options.page - 页码
   * @param {number} options.skip - 跳过数量
   * @returns {Promise<Object>} 技能列表
   */
  async listSkills(options = {}) {
    const { limit = 10, page = 0, skip = 0 } = options;
    const params = new URLSearchParams();
    params.append('limit', String(limit));
    params.append('page', String(page));
    if (skip > 0) params.append('skip', String(skip));

    return await this.request(`/skills?${params.toString()}`);
  }

  /**
   * 获取技能详情
   * @param {string} skillId - 技能 ID
   * @returns {Promise<Object>} 技能详情
   */
  async getSkill(skillId) {
    return await this.request(`/skills/${skillId}`);
  }

  /**
   * 安装技能
   * @param {Object} options - 安装选项
   * @param {string} options.source - 技能来源
   * @param {boolean} options.validate - 是否验证
   * @param {string} options.creator - 创建者
   * @param {string} options.install_path - 安装路径
   * @param {string} options.branch - 分支
   * @param {string} options.tag - 标签
   * @param {string} options.commit - 提交
   * @returns {Promise<Object>} 安装结果
   */
  async installSkill(options) {
    return await this.request('/skills/add', {
      method: 'POST',
      data: options
    });
  }

  /**
   * 从多技能仓库安装技能
   * @param {string} source - 仓库来源
   * @param {string} skillPath - 技能路径
   * @param {Object} options - 其他选项
   * @returns {Promise<Object>} 安装结果
   */
  async installSkillFromMultiRepo(source, skillPath, options = {}) {
    return await this.request('/skills/add', {
      method: 'POST',
      data: {
        source,
        skill_subpath: skillPath,
        ...options
      }
    });
  }

  /**
   * 卸载技能
   * @param {string} skillId - 技能 ID
   * @returns {Promise<Object>} 卸载结果
   */
  async uninstallSkill(skillId) {
    return await this.request('/skills/del', {
      method: 'POST',
      data: { id: skillId }
    });
  }

  /**
   * 执行技能
   * @param {string} skillId - 技能 ID
   * @param {Object} params - 执行参数
   * @returns {Promise<Object>} 执行结果
   */
  async executeSkill(skillId, params = {}) {
    return await this.request('/skills/execute', {
      method: 'POST',
      data: {
        skill_id: skillId,
        params
      }
    });
  }

  /**
   * 执行技能工具
   * @param {string} skillId - 技能 ID
   * @param {string} toolName - 工具名称
   * @param {Object} args - 工具参数
   * @returns {Promise<Object>} 执行结果
   */
  async executeSkillTool(skillId, toolName, args = {}) {
    return await this.request(`/skills/${skillId}/tools/${toolName}/run`, {
      method: 'POST',
      data: { args }
    });
  }

  /**
   * 搜索技能
   * @param {string|Object} options - 搜索选项
   * @returns {Promise<Object>} 搜索结果
   */
  async searchSkills(options) {
    const searchOptions = typeof options === 'string' 
      ? { query: options, source: 'all', limit: 10 }
      : { query: options.query, source: options.source || 'all', limit: options.limit || 10 };

    return await this.request('/skills/search', {
      method: 'POST',
      data: searchOptions
    });
  }

  /**
   * 更新技能
   * @param {string} skillId - 技能 ID
   * @param {Object} updates - 更新内容
   * @returns {Promise<Object>} 更新结果
   */
  async updateSkill(skillId, updates) {
    return await this.request('/skills/edit', {
      method: 'POST',
      data: {
        id: skillId,
        ...updates
      }
    });
  }

  /**
   * 获取技能配置
   * @param {string} skillId - 技能 ID
   * @returns {Promise<Object>} 技能配置
   */
  async getSkillConfig(skillId) {
    return await this.request(`/skills/${skillId}/config`);
  }

  /**
   * 设置技能配置
   * @param {string} skillId - 技能 ID
   * @param {Object} config - 技能配置
   * @returns {Promise<Object>} 设置结果
   */
  async setSkillConfig(skillId, config) {
    return await this.request(`/skills/${skillId}/config`, {
      method: 'POST',
      data: config
    });
  }

  /**
   * 列出技能工具
   * @param {string} skillId - 技能 ID
   * @returns {Promise<Array>} 工具列表
   */
  async listSkillTools(skillId) {
    return await this.request(`/skills/${skillId}/tools`);
  }

  /**
   * 设置认证令牌
   * @param {string} token - 认证令牌
   */
  setAuthToken(token) {
    this.authToken = token;
  }

  /**
   * 获取基础 URL
   * @returns {string} 基础 URL
   */
  getBaseUrl() {
    return this.baseUrl;
  }
}
