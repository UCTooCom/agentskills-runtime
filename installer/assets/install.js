// install.js - AgentSkills Runtime 安装配置脚本

// NestJS 后端服务器地址
const API_BASE_URL = 'http://localhost:3000';

/**
 * 服务检测器
 */
class ServiceDetector {
    constructor() {
        this.maxRetries = 30; // 最多尝试 30 次
        this.retryInterval = 2000; // 每次间隔 2 秒
    }

    /**
     * 检测服务是否就绪
     */
    async checkServiceReady() {
        try {
            const response = await fetch(`${API_BASE_URL}/healthCheck`, {
                method: 'GET',
                signal: AbortSignal.timeout(3000) // 3 秒超时
            });
            const text = await response.text();
            return text.trim() === 'success';
        } catch (error) {
            return false;
        }
    }

    /**
     * 等待服务就绪
     */
    async waitForService(onProgress) {
        for (let i = 0; i < this.maxRetries; i++) {
            const progress = ((i + 1) / this.maxRetries) * 100;
            onProgress(progress, i + 1, this.maxRetries);

            const isReady = await this.checkServiceReady();
            if (isReady) {
                return true;
            }

            // 等待一段时间后重试
            await new Promise(resolve => setTimeout(resolve, this.retryInterval));
        }

        return false;
    }
}

/**
 * 加载页面管理器
 */
class LoadingManager {
    constructor() {
        this.loadingScreen = document.getElementById('loading-screen');
        this.loadingMessage = document.getElementById('loading-message');
        this.progressBar = document.getElementById('loading-progress-bar');
    }

    /**
     * 更新加载消息
     */
    updateMessage(message) {
        if (this.loadingMessage) {
            this.loadingMessage.textContent = message;
        }
    }

    /**
     * 更新进度条
     */
    updateProgress(progress) {
        if (this.progressBar) {
            this.progressBar.style.width = `${progress}%`;
        }
    }

    /**
     * 显示错误
     */
    showError(title, message) {
        if (this.loadingScreen) {
            const errorDiv = document.createElement('div');
            errorDiv.className = 'loading-error';
            errorDiv.innerHTML = `
                <div class="loading-error-title">${title}</div>
                <div class="loading-error-message">${message}</div>
                <button class="loading-error-button" onclick="location.reload()">重新检测</button>
            `;
            this.loadingScreen.appendChild(errorDiv);
        }
    }

    /**
     * 隐藏加载页面
     */
    hide() {
        if (this.loadingScreen) {
            this.loadingScreen.classList.add('hidden');
        }
    }
}

/**
 * 环境检测类
 */
class EnvironmentChecker {
    constructor() {
        this.results = {};
    }

    /**
     * 检测 Node.js 版本
     */
    async checkNodeJS() {
        try {
            const response = await fetch(`${API_BASE_URL}/api/setup/check-environment`);
            const data = await response.json();
            const nodejs = data.data.find(item => item.name === 'nodejs');
            return {
                installed: nodejs.passed,
                version: nodejs.current,
                required: nodejs.required,
                passed: nodejs.passed
            };
        } catch (error) {
            return {
                installed: false,
                version: '未检测到',
                required: '>= 18.0.0',
                passed: false
            };
        }
    }

    /**
     * 检测 PostgreSQL 服务
     */
    async checkPostgreSQL() {
        try {
            const response = await fetch(`${API_BASE_URL}/api/setup/check-environment`);
            const data = await response.json();
            const postgresql = data.data.find(item => item.name === 'postgresql');
            return {
                installed: postgresql.passed,
                version: postgresql.current,
                required: postgresql.required,
                passed: postgresql.passed
            };
        } catch (error) {
            return {
                installed: false,
                version: '未检测到',
                required: '>= 14.0',
                passed: false
            };
        }
    }

    /**
     * 检测 Redis 服务
     */
    async checkRedis() {
        try {
            const response = await fetch(`${API_BASE_URL}/api/setup/check-environment`);
            const data = await response.json();
            const redis = data.data.find(item => item.name === 'redis');
            return {
                installed: redis.passed,
                version: redis.current,
                required: redis.required,
                passed: redis.passed,
                optional: true
            };
        } catch (error) {
            return {
                installed: false,
                version: '未检测到',
                required: '>= 6.0',
                passed: false,
                optional: true
            };
        }
    }

    /**
     * 检测端口占用
     */
    async checkPorts() {
        const ports = [443, 5432, 6379, 8080];
        const results = {};

        // 通过服务状态 API 获取端口信息
        try {
            const response = await fetch(`${API_BASE_URL}/api/setup/service-status`);
            const data = await response.json();

            // 从服务状态推断端口占用情况
            const services = data.data || [];
            const serviceMap = {};
            services.forEach(service => {
                if (service.name === 'PostgreSQL') {
                    serviceMap[5432] = service.status === 'running';
                } else if (service.name === 'Redis') {
                    serviceMap[6379] = service.status === 'running';
                } else if (service.name === 'agentskills-runtime') {
                    // agentskills-runtime 可能在多个端口运行，这里只检测 443 和 8080
                    if (service.status === 'running') {
                        serviceMap[443] = true;
                        serviceMap[8080] = true;
                    }
                }
            });

            // 对于未检测到的端口，尝试直接检测
            for (const port of ports) {
                if (serviceMap[port] !== undefined) {
                    results[port] = serviceMap[port];
                } else {
                    // 未检测到的端口，默认为可用
                    results[port] = true;
                }
            }
        } catch (error) {
            console.error('端口检测失败:', error);
            // 如果 API 调用失败，所有端口默认为可用
            for (const port of ports) {
                results[port] = true;
            }
        }

        return results;
    }

    /**
     * 执行所有检测
     */
    async runAllChecks() {
        this.results = {
            nodejs: await this.checkNodeJS(),
            postgresql: await this.checkPostgreSQL(),
            redis: await this.checkRedis(),
            ports: await this.checkPorts()
        };
        return this.results;
    }
}

/**
 * 配置管理类
 */
class ConfigManager {
    constructor() {
        this.config = {};
    }

    /**
     * 保存配置
     */
    async saveConfig(config) {
        // 保存到 localStorage
        localStorage.setItem('install-config', JSON.stringify(config));

        // 保存到文件（通过 NestJS API）
        try {
            const response = await fetch(`${API_BASE_URL}/api/setup/save-config`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(config)
            });
            const result = await response.json();
            return result.code === 200;
        } catch (error) {
            console.error('保存配置失败:', error);
            return false;
        }
    }

    /**
     * 加载配置
     */
    async loadConfig() {
        // 从 localStorage 加载
        const localConfig = localStorage.getItem('install-config');
        if (localConfig) {
            this.config = JSON.parse(localConfig);
            return this.config;
        }

        // 从文件加载
        try {
            const response = await fetch(`${API_BASE_URL}/api/setup/load-config`);
            const data = await response.json();
            this.config = data.data || {};
            return this.config;
        } catch (error) {
            console.error('加载配置失败:', error);
            return {};
        }
    }

    /**
     * 生成 .env 文件内容
     */
    generateEnvFile(config) {
        const envLines = [];
        
        // 数据库配置
        if (config.dbHost && config.dbPort && config.dbName && config.dbUser && config.dbPassword) {
            envLines.push('# 数据库配置');
            envLines.push(`DATABASE_URL=postgresql://${config.dbUser}:${config.dbPassword}@${config.dbHost}:${config.dbPort}/${config.dbName}`);
            envLines.push('orm_drivers=opengauss');
            envLines.push('orm_defaultDriver=opengauss');
            envLines.push('');
        }
        
        // Redis 配置
        envLines.push('# Redis 配置');
        envLines.push(`REDIS_HOST=${config.redisHost || 'localhost'}`);
        envLines.push(`REDIS_PORT=${config.redisPort || 6379}`);
        envLines.push('');
        
        // SSL 配置
        envLines.push('# SSL 配置');
        envLines.push(`CERT_FILE_NAME=${config.certFile || 'ssl/server.crt'}`);
        envLines.push(`KEY_FILE_NAME=${config.keyFile || 'ssl/server.key'}`);
        envLines.push('');
        
        // API 密钥
        envLines.push('# API 密钥');
        if (config.stepfunApiKey) {
            envLines.push(`STEPFUN_API_KEY=${config.stepfunApiKey}`);
        }
        if (config.sophnetApiKey) {
            envLines.push(`SOPHNET_API_KEY=${config.sophnetApiKey}`);
        }
        if (config.otherApiKeys) {
            envLines.push(config.otherApiKeys);
        }
        envLines.push('');
        
        // 服务配置
        envLines.push('# 服务配置');
        envLines.push(`PORT=${config.port || 443}`);
        envLines.push(`LOG_LEVEL=${config.logLevel || 'info'}`);
        
        return envLines.join('\n');
    }

    /**
     * 测试配置
     */
    async testConfig(config) {
        try {
            const response = await fetch(`${API_BASE_URL}/api/setup/test-config`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(config)
            });
            const result = await response.json();
            return result.code === 200;
        } catch (error) {
            console.error('测试配置失败:', error);
            return false;
        }
    }
}

/**
 * 管理员账号管理类
 */
class AdminAccountManager {
    /**
     * 创建管理员账号
     */
    async createAdminAccount(account) {
        try {
            const response = await fetch(`${API_BASE_URL}/api/setup/create-admin`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(account)
            });
            const result = await response.json();
            return result;
        } catch (error) {
            console.error('创建管理员账号失败:', error);
            return { code: 500, message: '创建失败' };
        }
    }

    /**
     * 验证密码强度
     */
    validatePassword(password) {
        const rules = {
            minLength: password.length >= 8,
            hasUpper: /[A-Z]/.test(password),
            hasLower: /[a-z]/.test(password),
            hasNumber: /[0-9]/.test(password),
            hasSpecial: /[!@#$%^&*]/.test(password)
        };
        
        return {
            valid: Object.values(rules).every(rule => rule),
            rules
        };
    }

    /**
     * 计算密码强度等级
     */
    calculateStrength(rules) {
        const passedCount = Object.values(rules).filter(rule => rule).length;
        
        if (passedCount <= 2) {
            return 'weak';
        } else if (passedCount <= 4) {
            return 'medium';
        } else {
            return 'strong';
        }
    }

    /**
     * 验证邮箱格式
     */
    validateEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }
}

/**
 * Runtime 管理类
 */
class RuntimeManager {
    /**
     * 检查 Runtime 是否已安装
     */
    async checkRuntime() {
        try {
            const response = await fetch(`${API_BASE_URL}/api/setup/check-runtime`);
            const result = await response.json();
            return result;
        } catch (error) {
            console.error('检查 Runtime 失败:', error);
            return { installed: false, message: '检查失败' };
        }
    }

    /**
     * 安装 Runtime
     */
    async installRuntime(options = {}) {
        try {
            const response = await fetch(`${API_BASE_URL}/api/setup/install-runtime`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(options)
            });
            const result = await response.json();
            return result;
        } catch (error) {
            console.error('安装 Runtime 失败:', error);
            return { code: 500, message: '安装失败' };
        }
    }
}

/**
 * 安装向导类
 */
class InstallWizard {
    constructor() {
        this.currentStep = 1;
        this.totalSteps = 7;
        this.config = {};
        this.envChecker = new EnvironmentChecker();
        this.configManager = new ConfigManager();
        this.adminManager = new AdminAccountManager();
        this.runtimeManager = new RuntimeManager();
        this.serviceDetector = new ServiceDetector();
        this.loadingManager = new LoadingManager();

        this.init();
    }

    /**
     * 初始化
     */
    async init() {
        // 先检测服务是否就绪
        const serviceReady = await this.checkService();

        if (serviceReady) {
            // 服务就绪，隐藏加载页面，开始正常流程
            this.loadingManager.hide();
            this.bindEvents();
            await this.loadSavedConfig();
            this.runEnvironmentCheck();
        }
    }

    /**
     * 检测服务是否就绪
     */
    async checkService() {
        this.loadingManager.updateMessage('正在检测安装服务...');

        // 先尝试一次快速检测
        const quickCheck = await this.serviceDetector.checkServiceReady();
        if (quickCheck) {
            this.loadingManager.updateMessage('安装服务已就绪');
            this.loadingManager.updateProgress(100);
            await this.sleep(500); // 短暂延迟，让用户看到成功消息
            return true;
        }

        // 快速检测失败，开始等待
        this.loadingManager.updateMessage('正在等待安装服务启动...');

        const serviceReady = await this.serviceDetector.waitForService((progress, current, total) => {
            this.loadingManager.updateProgress(progress);
            this.loadingManager.updateMessage(`正在等待安装服务启动... (${current}/${total})`);
        });

        if (serviceReady) {
            this.loadingManager.updateMessage('安装服务已就绪');
            this.loadingManager.updateProgress(100);
            await this.sleep(500);
            return true;
        } else {
            this.loadingManager.showError(
                '安装服务未启动',
                '无法连接到安装服务。请确保已运行 start-installer.bat 启动安装服务，或手动启动 NestJS 服务器。'
            );
            return false;
        }
    }

    /**
     * 辅助方法：sleep
     */
    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    /**
     * 绑定事件
     */
    bindEvents() {
        // 上一步/下一步按钮
        document.getElementById('prev-btn').addEventListener('click', () => this.prevStep());
        document.getElementById('next-btn').addEventListener('click', () => this.nextStep());

        // 重新检测按钮
        document.getElementById('recheck-btn').addEventListener('click', () => this.runEnvironmentCheck());

        // 测试数据库连接按钮
        document.getElementById('test-db-btn').addEventListener('click', () => this.testDatabaseConnection());

        // 保存数据库配置按钮
        const saveDbBtn = document.getElementById('save-db-btn');
        if (saveDbBtn) {
            saveDbBtn.addEventListener('click', () => this.saveDatabaseConfig());
        }

        // 重新检测 PostgreSQL 按钮
        const recheckPostgresqlBtn = document.getElementById('recheck-postgresql-btn');
        if (recheckPostgresqlBtn) {
            recheckPostgresqlBtn.addEventListener('click', () => this.checkPostgreSQLStatus());
        }

        // SSL 选项切换
        document.querySelectorAll('input[name="sslType"]').forEach(radio => {
            radio.addEventListener('change', (e) => this.handleSSLTypeChange(e));
        });

        // 保存 SSL 配置按钮
        const saveSslBtn = document.getElementById('save-ssl-btn');
        if (saveSslBtn) {
            saveSslBtn.addEventListener('click', () => this.saveSSLConfig());
        }

        // 保存 API 密钥按钮
        const saveApiKeysBtn = document.getElementById('save-api-keys-btn');
        if (saveApiKeysBtn) {
            saveApiKeysBtn.addEventListener('click', () => this.saveApiKeys());
        }

        // 保存管理员账号按钮
        const saveAdminBtn = document.getElementById('save-admin-btn');
        if (saveAdminBtn) {
            saveAdminBtn.addEventListener('click', () => this.saveAdminAccount());
        }

        // 密码强度检测
        document.getElementById('admin-password').addEventListener('input', (e) => this.handlePasswordInput(e));

        // 启动服务按钮
        document.getElementById('start-runtime-btn').addEventListener('click', () => this.startRuntime());

        // Runtime 安装按钮
        const installRuntimeBtn = document.getElementById('install-runtime-btn');
        if (installRuntimeBtn) {
            installRuntimeBtn.addEventListener('click', () => this.handleInstallRuntime());
        }

        // 跳过 Runtime 安装按钮
        const skipRuntimeBtn = document.getElementById('skip-runtime-btn');
        if (skipRuntimeBtn) {
            skipRuntimeBtn.addEventListener('click', () => this.handleSkipRuntime());
        }
    }

    /**
     * 加载已保存的配置
     */
    async loadSavedConfig() {
        this.config = await this.configManager.loadConfig();
        this.fillFormWithConfig();
    }

    /**
     * 使用配置填充表单
     */
    fillFormWithConfig() {
        if (this.config.dbHost) {
            document.getElementById('db-host').value = this.config.dbHost;
        }
        if (this.config.dbPort) {
            document.getElementById('db-port').value = this.config.dbPort;
        }
        if (this.config.dbName) {
            document.getElementById('db-name').value = this.config.dbName;
        }
        if (this.config.dbUser) {
            document.getElementById('db-user').value = this.config.dbUser;
        }
        if (this.config.stepfunApiKey) {
            document.getElementById('stepfun-api-key').value = this.config.stepfunApiKey;
        }
        if (this.config.sophnetApiKey) {
            document.getElementById('sophnet-api-key').value = this.config.sophnetApiKey;
        }
    }

    /**
     * 运行环境检测
     */
    async runEnvironmentCheck() {
        // 显示检测中的状态
        const recheckBtn = document.getElementById('recheck-btn');
        const originalText = recheckBtn.textContent;
        recheckBtn.textContent = '检测中...';
        recheckBtn.disabled = true;

        // 重置所有检测项为"检测中"状态
        this.resetCheckItems();

        try {
            const results = await this.envChecker.runAllChecks();
            this.updateEnvironmentUI(results);
        } catch (error) {
            console.error('环境检测失败:', error);
            alert('环境检测失败，请检查后端服务是否正常运行');
        } finally {
            // 恢复按钮状态
            recheckBtn.textContent = originalText;
            recheckBtn.disabled = false;
        }
    }

    /**
     * 重置所有检测项为"检测中"状态
     */
    resetCheckItems() {
        const checkItems = ['check-nodejs', 'check-postgresql', 'check-redis', 'check-ports'];
        checkItems.forEach(id => {
            const element = document.getElementById(id);
            if (element) {
                const statusElement = element.querySelector('.status');
                if (statusElement) {
                    statusElement.className = 'status pending';
                    statusElement.textContent = '检测中...';
                }
            }
        });
    }

    /**
     * 更新环境检测 UI
     */
    updateEnvironmentUI(results) {
        // Node.js
        this.updateCheckItem('check-nodejs', results.nodejs);
        
        // PostgreSQL
        this.updateCheckItem('check-postgresql', results.postgresql);
        
        // Redis
        this.updateCheckItem('check-redis', results.redis, true);
        
        // 端口
        this.updatePortCheck(results.ports);
    }

    /**
     * 更新检测项 UI
     */
    updateCheckItem(elementId, result, isOptional = false) {
        const element = document.getElementById(elementId);
        const statusElement = element.querySelector('.status');
        const detailElement = element.querySelector('.check-detail');
        
        statusElement.className = `status ${result.passed ? 'passed' : 'failed'}`;
        statusElement.textContent = result.passed ? '通过' : (isOptional ? '未安装' : '未通过');
        
        detailElement.style.display = 'block';
        detailElement.querySelector('.current-version').textContent = `当前版本: ${result.version}`;
        detailElement.querySelector('.required-version').textContent = `要求版本: ${result.required}`;
    }

    /**
     * 更新端口检测 UI
     */
    updatePortCheck(ports) {
        const element = document.getElementById('check-ports');
        const statusElement = element.querySelector('.status');
        const detailElement = element.querySelector('.check-detail');
        
        const allAvailable = Object.values(ports).every(available => available);
        statusElement.className = `status ${allAvailable ? 'passed' : 'failed'}`;
        statusElement.textContent = allAvailable ? '通过' : '部分端口被占用';
        
        detailElement.style.display = 'block';
        const portStatusText = Object.entries(ports)
            .map(([port, available]) => `端口 ${port}: ${available ? '可用' : '被占用'}`)
            .join(', ');
        detailElement.querySelector('.port-status').textContent = portStatusText;
    }

    /**
     * 测试数据库连接
     */
    async testDatabaseConnection() {
        const config = {
            dbHost: document.getElementById('db-host').value,
            dbPort: document.getElementById('db-port').value,
            dbName: document.getElementById('db-name').value,
            dbUser: document.getElementById('db-user').value,
            dbPassword: document.getElementById('db-password').value
        };
        
        const success = await this.configManager.testConfig(config);
        alert(success ? '数据库连接成功！' : '数据库连接失败，请检查配置。');
    }

    /**
     * 处理 SSL 类型切换
     */
    handleSSLTypeChange(event) {
        const uploadSection = document.getElementById('ssl-upload-section');
        uploadSection.style.display = event.target.value === 'production' ? 'block' : 'none';
    }

    /**
     * 保存 SSL 配置
     */
    async saveSSLConfig() {
        const saveBtn = document.getElementById('save-ssl-btn');
        const originalText = saveBtn.textContent;

        try {
            saveBtn.disabled = true;
            saveBtn.textContent = '保存中...';

            // 获取域名配置
            const backendUrl = document.getElementById('backend-url').value.trim();
            
            if (!backendUrl) {
                alert('请输入后端 API 地址');
                return;
            }

            // 验证 URL 格式
            if (!backendUrl.startsWith('http://') && !backendUrl.startsWith('https://')) {
                alert('后端 API 地址必须以 http:// 或 https:// 开头');
                return;
            }

            // 从 URL 中提取域名
            let certDomain;
            try {
                const urlObj = new URL(backendUrl);
                certDomain = urlObj.hostname; // 提取主机名（不包含端口）
            } catch (error) {
                alert('无效的 URL 格式');
                return;
            }

            // 获取 SSL 类型
            const sslType = document.querySelector('input[name="sslType"]:checked').value;

            // 准备配置数据
            const configData = {
                BACKEND_URL: backendUrl
            };

            if (sslType === 'development') {
                // 自签名证书 - 使用 API 地址的域名
                // 调用后端生成自签名证书
                const response = await fetch(`${API_BASE_URL}/api/setup/generate-ssl`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        type: 'self-signed',
                        domain: certDomain // 使用从 URL 提取的域名
                    })
                });

                const result = await response.json();

                if (result.code !== 200) {
                    alert(`生成自签名证书失败: ${result.message}`);
                    return;
                }

                alert(`自签名证书已生成并保存到 SSL 目录\nAPI 地址: ${backendUrl}\n证书域名: ${certDomain}`);

            } else if (sslType === 'production') {
                // 自定义证书
                const certFile = document.getElementById('cert-file').files[0];
                const keyFile = document.getElementById('key-file').files[0];

                if (!certFile || !keyFile) {
                    alert('请上传证书文件和私钥文件');
                    return;
                }

                // 读取文件内容
                const certContent = await this.readFileAsText(certFile);
                const keyContent = await this.readFileAsText(keyFile);

                // 调用后端保存自定义证书
                const response = await fetch(`${API_BASE_URL}/api/setup/save-ssl`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        type: 'custom',
                        cert: certContent,
                        key: keyContent
                    })
                });

                const result = await response.json();

                if (result.code !== 200) {
                    alert(`保存自定义证书失败: ${result.message}`);
                    return;
                }

                alert(`自定义证书已保存到 SSL 目录\nAPI 地址: ${backendUrl}\n请确保证书域名与 API 地址域名一致: ${certDomain}`);
            }

            // 保存域名配置到 .env 文件
            const envResponse = await fetch(`${API_BASE_URL}/api/setup/save-runtime-env`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(configData)
            });

            const envResult = await envResponse.json();

            if (envResult.code === 200) {
                alert('域名及 SSL 配置保存成功！');
            } else {
                alert(`保存域名配置失败: ${envResult.message}`);
            }

        } catch (error) {
            console.error('保存 SSL 配置失败:', error);
            alert(`保存失败: ${error.message}`);
        } finally {
            saveBtn.disabled = false;
            saveBtn.textContent = originalText;
        }
    }

    /**
     * 读取文件为文本
     */
    readFileAsText(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = (e) => resolve(e.target.result);
            reader.onerror = (e) => reject(e);
            reader.readAsText(file);
        });
    }

    /**
     * 保存 API 密钥配置
     */
    async saveApiKeys() {
        const saveBtn = document.getElementById('save-api-keys-btn');
        const originalText = saveBtn.textContent;

        try {
            saveBtn.disabled = true;
            saveBtn.textContent = '保存中...';

            // 收集所有 API 密钥
            const configData = {};

            // OpenAI
            const openaiKey = document.getElementById('openai-api-key').value.trim();
            if (openaiKey) {
                configData.OPENAI_API_KEY = openaiKey;
            }

            // StepFun
            const stepfunKey = document.getElementById('stepfun-api-key').value.trim();
            if (stepfunKey) {
                configData.STEPFUN_API_KEY = stepfunKey;
            }

            // DeepSeek
            const deepseekKey = document.getElementById('deepseek-api-key').value.trim();
            if (deepseekKey) {
                configData.DEEPSEEK_API_KEY = deepseekKey;
            }

            // Sophnet
            const sophnetKey = document.getElementById('sophnet-api-key').value.trim();
            if (sophnetKey) {
                configData.SOPHNET_API_KEY = sophnetKey;
            }

            // 华为云 MaaS
            const maasKey = document.getElementById('maas-api-key').value.trim();
            if (maasKey) {
                configData.MAAS_API_KEY = maasKey;
            }

            // 智谱 AI
            const zhipuKey = document.getElementById('zhipu-api-key').value.trim();
            if (zhipuKey) {
                configData.ZHIPU_API_KEY = zhipuKey;
            }

            // 阿里云 DashScope
            const dashscopeKey = document.getElementById('dashscope-api-key').value.trim();
            if (dashscopeKey) {
                configData.DASHSCOPE_API_KEY = dashscopeKey;
            }

            // SiliconFlow
            const siliconflowKey = document.getElementById('siliconflow-api-key').value.trim();
            if (siliconflowKey) {
                configData.SILICONFLOW_API_KEY = siliconflowKey;
            }

            // Google Gemini
            const googleKey = document.getElementById('google-api-key').value.trim();
            if (googleKey) {
                configData.GOOGLE_API_KEY = googleKey;
            }

            // Moonshot
            const moonshotKey = document.getElementById('moonshot-api-key').value.trim();
            if (moonshotKey) {
                configData.MOONSHOT_API_KEY = moonshotKey;
            }

            // 火山引擎 ARK
            const arkKey = document.getElementById('ark-api-key').value.trim();
            if (arkKey) {
                configData.ARK_API_KEY = arkKey;
            }

            // OpenRouter
            const openrouterKey = document.getElementById('openrouter-api-key').value.trim();
            if (openrouterKey) {
                configData.OPENROUTER_API_KEY = openrouterKey;
            }

            // 检查是否至少配置了一个密钥
            if (Object.keys(configData).length === 0) {
                alert('请至少配置一个大模型 API 密钥');
                return;
            }

            // 保存到 Runtime .env 文件
            const response = await fetch(`${API_BASE_URL}/api/setup/save-runtime-env`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(configData)
            });

            const result = await response.json();

            if (result.code === 200) {
                const keyCount = Object.keys(configData).length;
                alert(`API 密钥配置保存成功！\n已保存 ${keyCount} 个 API 密钥`);
            } else {
                alert(`保存失败: ${result.message}`);
            }

        } catch (error) {
            console.error('保存 API 密钥失败:', error);
            alert(`保存失败: ${error.message}`);
        } finally {
            saveBtn.disabled = false;
            saveBtn.textContent = originalText;
        }
    }

    /**
     * 保存管理员账号
     */
    async saveAdminAccount() {
        const saveBtn = document.getElementById('save-admin-btn');
        const originalText = saveBtn.textContent;

        try {
            saveBtn.disabled = true;
            saveBtn.textContent = '保存中...';

            // 获取表单数据
            const email = document.getElementById('admin-email').value.trim();
            const username = document.getElementById('admin-username').value.trim();
            const password = document.getElementById('admin-password').value;
            const passwordConfirm = document.getElementById('admin-password-confirm').value;

            // 调试信息
            console.log('表单数据:', { email, username, password: password ? '***' : 'empty', passwordConfirm: passwordConfirm ? '***' : 'empty' });

            // 验证必填字段
            if (!email || !username || !password || !passwordConfirm) {
                const missing = [];
                if (!email) missing.push('邮箱');
                if (!username) missing.push('账号');
                if (!password) missing.push('密码');
                if (!passwordConfirm) missing.push('确认密码');
                alert(`请填写以下必填项：${missing.join('、')}`);
                return;
            }

            // 验证邮箱格式
            const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            if (!emailRegex.test(email)) {
                alert('请输入有效的邮箱地址！');
                return;
            }

            // 验证密码强度
            const validation = this.adminManager.validatePassword(password);
            if (!validation.valid) {
                alert('密码强度不足！请确保密码至少 8 位，包含大小写字母、数字和特殊字符。');
                return;
            }

            // 验证密码一致性
            if (password !== passwordConfirm) {
                alert('两次输入的密码不一致！');
                return;
            }

            // 调用后端创建管理员账号
            const response = await fetch(`${API_BASE_URL}/api/setup/create-admin`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    email,
                    username,
                    password,
                    name: username // name 字段使用 username 的值
                })
            });

            const result = await response.json();

            if (result.code === 200) {
                alert(`管理员账号创建成功！\n邮箱: ${email}\n账号: ${username}`);
            } else {
                alert(`创建失败: ${result.message}`);
            }

        } catch (error) {
            console.error('保存管理员账号失败:', error);
            alert(`保存失败: ${error.message}`);
        } finally {
            saveBtn.disabled = false;
            saveBtn.textContent = originalText;
        }
    }

    /**
     * 处理密码输入
     */
    handlePasswordInput(event) {
        const password = event.target.value;
        const validation = this.adminManager.validatePassword(password);
        const strength = this.adminManager.calculateStrength(validation.rules);
        
        const strengthFill = document.getElementById('strength-fill');
        const strengthText = document.getElementById('strength-text');
        
        strengthFill.className = `strength-fill ${strength}`;
        
        const strengthLabels = {
            weak: '弱',
            medium: '中',
            strong: '强'
        };
        strengthText.textContent = `密码强度：${strengthLabels[strength]}`;
    }

    /**
     * 上一步
     */
    prevStep() {
        if (this.currentStep > 1) {
            this.currentStep--;
            this.updateStepUI();
        }
    }

    /**
     * 下一步
     */
    async nextStep() {
        // 验证当前步骤
        const valid = await this.validateCurrentStep();
        if (!valid) {
            return;
        }
        
        // 保存当前步骤的配置
        this.saveCurrentStepConfig();
        
        if (this.currentStep < this.totalSteps) {
            this.currentStep++;
            this.updateStepUI();
            
            // 如果是最后一步，生成配置预览
            if (this.currentStep === this.totalSteps) {
                this.generateConfigPreview();
            }
        } else {
            // 完成安装
            this.completeInstall();
        }
    }

    /**
     * 验证当前步骤
     */
    async validateCurrentStep() {
        switch (this.currentStep) {
            case 1: // 环境检测
                const results = this.envChecker.results;
                if (!results.nodejs?.passed || !results.postgresql?.passed) {
                    alert('请确保 Node.js 和 PostgreSQL 已正确安装！');
                    return false;
                }
                return true;

            case 2: // Runtime 安装
                // Runtime 是可选的，直接通过
                return true;

            case 3: // 数据库配置
                const dbHost = document.getElementById('db-host').value;
                const dbPort = document.getElementById('db-port').value;
                const dbName = document.getElementById('db-name').value;
                const dbUser = document.getElementById('db-user').value;
                const dbPassword = document.getElementById('db-password').value;

                if (!dbHost || !dbPort || !dbName || !dbUser || !dbPassword) {
                    alert('请填写完整的数据库配置信息！');
                    return false;
                }
                return true;

            case 4: // SSL 配置
                return true;

            case 5: // API 密钥
                return true;

            case 6: // 管理员账号
                // 管理员账号创建是可选的，可以跳过
                const email = document.getElementById('admin-email').value.trim();
                const username = document.getElementById('admin-username').value.trim();
                const password = document.getElementById('admin-password').value;
                const passwordConfirm = document.getElementById('admin-password-confirm').value;

                // 如果所有字段都为空，允许跳过此步骤
                if (!email && !username && !password && !passwordConfirm) {
                    return true;
                }

                // 如果填写了部分字段，则需要验证所有必填字段
                if (!email || !username || !password || !passwordConfirm) {
                    const missing = [];
                    if (!email) missing.push('邮箱');
                    if (!username) missing.push('账号');
                    if (!password) missing.push('密码');
                    if (!passwordConfirm) missing.push('确认密码');
                    alert(`请填写以下必填项：${missing.join('、')}\n或者清空所有字段以跳过此步骤`);
                    return false;
                }

                // 验证邮箱格式
                if (!this.adminManager.validateEmail(email)) {
                    alert('请输入有效的邮箱地址！');
                    return false;
                }

                // 验证密码强度
                const validation = this.adminManager.validatePassword(password);
                if (!validation.valid) {
                    alert('密码强度不足！请确保密码至少 8 位，包含大小写字母、数字和特殊字符。');
                    return false;
                }

                // 验证密码一致性
                if (password !== passwordConfirm) {
                    alert('两次输入的密码不一致！');
                    return false;
                }
                return true;

            default:
                return true;
        }
    }

    /**
     * 保存当前步骤的配置
     */
    saveCurrentStepConfig() {
        switch (this.currentStep) {
            case 3: // 数据库配置
                this.config.dbHost = document.getElementById('db-host').value;
                this.config.dbPort = document.getElementById('db-port').value;
                this.config.dbName = document.getElementById('db-name').value;
                this.config.dbUser = document.getElementById('db-user').value;
                this.config.dbPassword = document.getElementById('db-password').value;
                break;

            case 4: // SSL 配置
                this.config.sslType = document.querySelector('input[name="sslType"]:checked').value;
                break;

            case 5: // API 密钥
                // API 密钥通过 saveApiKeys() 方法单独保存
                // 这里不需要额外处理
                break;

            case 6: // 管理员账号
                // 管理员账号通过 saveAdminAccount() 方法单独保存
                // 这里不需要额外处理
                break;
        }

        // 保存到 localStorage
        this.configManager.saveConfig(this.config);
    }

    /**
     * 更新步骤 UI
     */
    updateStepUI() {
        // 更新步骤导航
        document.querySelectorAll('.step').forEach((step, index) => {
            const stepNum = index + 1;
            step.classList.remove('active', 'completed');
            
            if (stepNum === this.currentStep) {
                step.classList.add('active');
            } else if (stepNum < this.currentStep) {
                step.classList.add('completed');
            }
        });
        
        // 更新内容区域
        document.querySelectorAll('.step-content').forEach((content, index) => {
            content.classList.remove('active');
            if (index + 1 === this.currentStep) {
                content.classList.add('active');
            }
        });
        
        // 更新按钮状态
        document.getElementById('prev-btn').disabled = this.currentStep === 1;
        document.getElementById('next-btn').textContent =
            this.currentStep === this.totalSteps ? '完成安装' : '下一步';

        // 如果进入 Runtime 安装步骤，自动检测
        if (this.currentStep === 2) {
            this.checkRuntimeStatus();
        }

        // 如果进入数据库配置步骤，自动检测 PostgreSQL 并加载配置
        if (this.currentStep === 3) {
            this.checkPostgreSQLStatus();
            this.loadDatabaseConfig();
        }

        // 如果进入 SSL 配置步骤，加载域名配置
        if (this.currentStep === 4) {
            this.loadSSLConfig();
        }

        // 如果进入 API 密钥配置步骤，加载已保存的密钥
        if (this.currentStep === 5) {
            this.loadApiKeysConfig();
        }
    }

    /**
     * 检查 Runtime 状态
     */
    async checkRuntimeStatus() {
        const statusIcon = document.querySelector('#runtime-status .status-icon');
        const statusText = document.querySelector('#runtime-status .status-text');
        const statusDetails = document.getElementById('runtime-details');
        const runtimeActions = document.getElementById('runtime-actions');
        const installBtn = document.getElementById('install-runtime-btn');
        const skipBtn = document.getElementById('skip-runtime-btn');

        // 显示检测中状态
        statusIcon.textContent = '⏳';
        statusText.textContent = '检测中...';
        statusDetails.innerHTML = '<p>正在检测 Runtime 安装状态...</p>';

        try {
            const result = await this.runtimeManager.checkRuntime();

            if (result.installed) {
                // Runtime 已安装
                statusIcon.textContent = '✅';
                statusText.textContent = '已安装';
                statusDetails.innerHTML = `
                    <p><strong>安装路径:</strong> ${result.path}</p>
                    <p><strong>版本:</strong> ${result.version || '未知'}</p>
                    <p><strong>配置文件:</strong> ${result.hasEnv ? '已配置' : '未配置'}</p>
                `;

                // 显示跳过按钮
                runtimeActions.style.display = 'block';
                installBtn.style.display = 'none';
                skipBtn.style.display = 'inline-block';
                skipBtn.textContent = '下一步';
            } else {
                // Runtime 未安装
                statusIcon.textContent = '❌';
                statusText.textContent = '未安装';
                statusDetails.innerHTML = `
                    <p>AgentSkills Runtime 未安装</p>
                    <p style="color: #666; font-size: 12px;">点击"安装 Runtime"按钮开始安装，或点击"下一步"跳过</p>
                `;

                // 显示安装和跳过按钮
                runtimeActions.style.display = 'block';
                installBtn.style.display = 'inline-block';
                skipBtn.style.display = 'inline-block';
                skipBtn.textContent = '跳过安装';
            }
        } catch (error) {
            statusIcon.textContent = '⚠️';
            statusText.textContent = '检测失败';
            statusDetails.innerHTML = `<p style="color: #f5222d;">检测失败: ${error.message}</p>`;

            runtimeActions.style.display = 'block';
            installBtn.style.display = 'inline-block';
            skipBtn.style.display = 'inline-block';
        }
    }

    /**
     * 处理安装 Runtime
     */
    async handleInstallRuntime() {
        const installBtn = document.getElementById('install-runtime-btn');
        const progressDiv = document.getElementById('runtime-progress');
        const progressFill = document.getElementById('runtime-progress-fill');
        const progressText = document.getElementById('runtime-progress-text');
        const statusDetails = document.getElementById('runtime-details');

        // 禁用按钮，显示进度
        installBtn.disabled = true;
        installBtn.textContent = '安装中...';
        progressDiv.style.display = 'block';

        try {
            // 模拟进度更新
            let progress = 0;
            const progressInterval = setInterval(() => {
                progress += 5;
                if (progress <= 90) {
                    progressFill.style.width = `${progress}%`;
                }
            }, 500);

            // 调用安装 API
            const result = await this.runtimeManager.installRuntime();

            clearInterval(progressInterval);

            if (result.code === 200) {
                // 安装成功
                progressFill.style.width = '100%';
                progressText.textContent = '安装成功！';

                statusDetails.innerHTML = `
                    <p style="color: #52c41a;"><strong>✓ ${result.message}</strong></p>
                    <p><strong>安装路径:</strong> ${result.path}</p>
                    <p><strong>版本:</strong> ${result.version || '未知'}</p>
                `;

                // 更新按钮
                installBtn.style.display = 'none';
                document.getElementById('skip-runtime-btn').textContent = '下一步';

                // 2秒后自动进入下一步
                setTimeout(() => {
                    this.nextStep();
                }, 2000);
            } else {
                // 安装失败
                progressFill.style.width = '100%';
                progressFill.style.backgroundColor = '#f5222d';
                progressText.textContent = '安装失败';

                statusDetails.innerHTML = `
                    <p style="color: #f5222d;"><strong>✗ ${result.message}</strong></p>
                    ${result.error ? `<p style="color: #666; font-size: 12px;">${result.error}</p>` : ''}
                `;

                installBtn.disabled = false;
                installBtn.textContent = '重新安装';
            }
        } catch (error) {
            progressFill.style.width = '100%';
            progressFill.style.backgroundColor = '#f5222d';
            progressText.textContent = '安装失败';

            statusDetails.innerHTML = `<p style="color: #f5222d;">安装失败: ${error.message}</p>`;

            installBtn.disabled = false;
            installBtn.textContent = '重新安装';
        }
    }

    /**
     * 处理跳过 Runtime 安装
     */
    handleSkipRuntime() {
        this.nextStep();
    }

    /**
     * 检查 PostgreSQL 状态
     */
    async checkPostgreSQLStatus() {
        const statusIcon = document.querySelector('#db-check-status .status-icon');
        const statusText = document.querySelector('#db-check-status .status-text');
        const statusDetails = document.getElementById('db-check-details');
        const installGuide = document.getElementById('db-install-guide');
        const configForm = document.getElementById('db-config-form');

        // 显示检测中状态
        statusIcon.textContent = '⏳';
        statusText.textContent = '检测中...';
        statusDetails.innerHTML = '<p>正在检测 PostgreSQL 安装状态...</p>';

        try {
            // 调用环境检测 API
            const response = await fetch(`${API_BASE_URL}/api/setup/check-environment`);
            const result = await response.json();

            console.log('环境检测结果:', result);

            // 查找 PostgreSQL 检测结果（后端返回的数据在 result.data 中）
            const checks = result.data || result.checks || [];
            const postgresqlCheck = checks.find(c => c.name === 'postgresql');

            console.log('PostgreSQL 检测结果:', postgresqlCheck);

            if (postgresqlCheck && postgresqlCheck.passed) {
                // PostgreSQL 已安装
                statusIcon.textContent = '✅';
                statusText.textContent = '已安装';
                statusDetails.innerHTML = `
                    <p><strong>版本:</strong> ${postgresqlCheck.current || '未知'}</p>
                    <p style="color: #52c41a;">PostgreSQL 已正确安装并可用</p>
                `;

                // 显示配置表单
                installGuide.style.display = 'none';
                configForm.style.display = 'block';
            } else {
                // PostgreSQL 未安装
                statusIcon.textContent = '❌';
                statusText.textContent = '未安装';
                statusDetails.innerHTML = `
                    <p style="color: #f5222d;">PostgreSQL 未安装或不可用</p>
                    <p style="color: #666; font-size: 12px;">请按照下方的安装指引进行安装</p>
                `;

                // 显示安装指引
                installGuide.style.display = 'block';
                configForm.style.display = 'none';
            }
        } catch (error) {
            console.error('检测 PostgreSQL 失败:', error);
            statusIcon.textContent = '⚠️';
            statusText.textContent = '检测失败';
            statusDetails.innerHTML = `<p style="color: #f5222d;">检测失败: ${error.message}</p>`;

            // 显示配置表单（让用户可以手动配置）
            installGuide.style.display = 'none';
            configForm.style.display = 'block';
        }
    }

    /**
     * 加载数据库配置
     */
    async loadDatabaseConfig() {
        try {
            // 从 Runtime .env 文件读取配置
            const response = await fetch(`${API_BASE_URL}/api/setup/read-runtime-env`);
            const result = await response.json();

            if (result.code === 200 && result.dbConfig) {
                // 填充表单
                document.getElementById('db-host').value = result.dbConfig.host || 'localhost';
                document.getElementById('db-port').value = result.dbConfig.port || '5432';
                document.getElementById('db-name').value = result.dbConfig.database || 'uctoo';
                document.getElementById('db-user').value = result.dbConfig.user || 'postgres';
                document.getElementById('db-password').value = result.dbConfig.password || '';
            }
        } catch (error) {
            console.error('加载数据库配置失败:', error);
        }
    }

    /**
     * 加载 SSL 配置
     */
    async loadSSLConfig() {
        try {
            // 从 Runtime .env 文件读取配置
            const response = await fetch(`${API_BASE_URL}/api/setup/read-runtime-env`);
            const result = await response.json();

            if (result.code === 200 && result.config) {
                // 填充域名配置
                const backendUrl = result.config.BACKEND_URL || result.config.backend_url;
                if (backendUrl) {
                    document.getElementById('backend-url').value = backendUrl;
                }
            }
        } catch (error) {
            console.error('加载 SSL 配置失败:', error);
        }
    }

    /**
     * 加载 API 密钥配置
     */
    async loadApiKeysConfig() {
        try {
            // 从 Runtime .env 文件读取配置
            const response = await fetch(`${API_BASE_URL}/api/setup/read-runtime-env`);
            const result = await response.json();

            if (result.code === 200 && result.config) {
                // 填充各个 API 密钥
                if (result.config.OPENAI_API_KEY) {
                    document.getElementById('openai-api-key').value = result.config.OPENAI_API_KEY;
                }
                if (result.config.STEPFUN_API_KEY) {
                    document.getElementById('stepfun-api-key').value = result.config.STEPFUN_API_KEY;
                }
                if (result.config.DEEPSEEK_API_KEY) {
                    document.getElementById('deepseek-api-key').value = result.config.DEEPSEEK_API_KEY;
                }
                if (result.config.SOPHNET_API_KEY) {
                    document.getElementById('sophnet-api-key').value = result.config.SOPHNET_API_KEY;
                }
                if (result.config.MAAS_API_KEY) {
                    document.getElementById('maas-api-key').value = result.config.MAAS_API_KEY;
                }
                if (result.config.ZHIPU_API_KEY) {
                    document.getElementById('zhipu-api-key').value = result.config.ZHIPU_API_KEY;
                }
                if (result.config.DASHSCOPE_API_KEY) {
                    document.getElementById('dashscope-api-key').value = result.config.DASHSCOPE_API_KEY;
                }
                if (result.config.SILICONFLOW_API_KEY) {
                    document.getElementById('siliconflow-api-key').value = result.config.SILICONFLOW_API_KEY;
                }
                if (result.config.GOOGLE_API_KEY) {
                    document.getElementById('google-api-key').value = result.config.GOOGLE_API_KEY;
                }
                if (result.config.MOONSHOT_API_KEY) {
                    document.getElementById('moonshot-api-key').value = result.config.MOONSHOT_API_KEY;
                }
                if (result.config.ARK_API_KEY) {
                    document.getElementById('ark-api-key').value = result.config.ARK_API_KEY;
                }
                if (result.config.OPENROUTER_API_KEY) {
                    document.getElementById('openrouter-api-key').value = result.config.OPENROUTER_API_KEY;
                }
            }
        } catch (error) {
            console.error('加载 API 密钥配置失败:', error);
        }
    }

    /**
     * 保存数据库配置
     */
    async saveDatabaseConfig() {
        const saveBtn = document.getElementById('save-db-btn');
        const originalText = saveBtn.textContent;

        try {
            saveBtn.disabled = true;
            saveBtn.textContent = '保存中...';

            // 获取表单数据
            const host = document.getElementById('db-host').value;
            const port = document.getElementById('db-port').value;
            const database = document.getElementById('db-name').value;
            const user = document.getElementById('db-user').value;
            const password = document.getElementById('db-password').value;

            // 构建数据库连接 URL
            const databaseUrl = `postgresql://${user}:${password}@${host}:${port}/${database}`;

            // 保存到 Runtime .env 文件
            const response = await fetch(`${API_BASE_URL}/api/setup/save-runtime-env`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    DATABASE_URL: databaseUrl,
                    orm_connectionUrl: databaseUrl,
                    opengauss_orm_connectionUrl: databaseUrl
                })
            });

            const result = await response.json();

            if (result.code === 200) {
                alert('数据库配置保存成功！');
            } else {
                alert(`保存失败: ${result.message}`);
            }
        } catch (error) {
            console.error('保存数据库配置失败:', error);
            alert(`保存失败: ${error.message}`);
        } finally {
            saveBtn.disabled = false;
            saveBtn.textContent = originalText;
        }
    }

    /**
     * 生成配置预览
     */
    generateConfigPreview() {
        const envContent = this.configManager.generateEnvFile(this.config);
        document.getElementById('config-preview-content').textContent = envContent;
    }

    /**
     * 启动 Runtime
     */
    async startRuntime() {
        const statusElement = document.getElementById('runtime-status');
        const logElement = document.getElementById('startup-log');
        const startupStatus = document.getElementById('startup-status');

        startupStatus.style.display = 'block';
        statusElement.textContent = '正在启动...';
        logElement.innerHTML = '<p>正在启动 agentskills-runtime...</p>';

        try {
            // 调用后端启动 API
            const response = await fetch(`${API_BASE_URL}/api/setup/start-runtime`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                }
            });
            const result = await response.json();

            if (result.code === 200) {
                logElement.innerHTML += `<p>[SUCCESS] ${result.message}</p>`;
                
                if (result.pid) {
                    logElement.innerHTML += `<p>[INFO] 进程 PID: ${result.pid}</p>`;
                }
                
                if (result.path) {
                    logElement.innerHTML += `<p>[INFO] Runtime 路径: ${result.path}</p>`;
                }

                // 等待一段时间，让服务启动
                await this.sleep(2000);

                statusElement.textContent = '运行中';
                statusElement.style.color = '#52c41a';

                // 更新按钮
                document.getElementById('start-runtime-btn').textContent = '服务已启动';
                document.getElementById('start-runtime-btn').disabled = true;
            } else {
                logElement.innerHTML += `<p>[ERROR] ${result.message}</p>`;
                statusElement.textContent = '启动失败';
                statusElement.style.color = '#ff4d4f';
            }
        } catch (error) {
            console.error('启动服务失败:', error);
            logElement.innerHTML += `<p>[ERROR] 启动失败: ${error.message}</p>`;
            statusElement.textContent = '启动失败';
            statusElement.style.color = '#ff4d4f';
        }
    }

    /**
     * 完成安装
     */
    completeInstall() {
        alert('安装配置完成！即将跳转到管理后台...');
        // 跳转到主应用
        window.location.href = '/';
    }

    /**
     * 辅助方法：sleep
     */
    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
}

// 初始化安装向导
document.addEventListener('DOMContentLoaded', () => {
    new InstallWizard();
});
