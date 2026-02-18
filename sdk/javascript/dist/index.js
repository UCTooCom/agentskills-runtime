import axios from 'axios';
import { spawn } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';
import * as os from 'os';
import { fileURLToPath } from 'url';
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const SDK_VERSION = '0.0.11';
const DEFAULT_BASE_URL = 'http://127.0.0.1:8080';
const DEFAULT_TIMEOUT = 30000;
const RUNTIME_VERSION = '0.0.1';
const GITHUB_REPO = 'UCTooCom/agentskills-runtime';
const ATOMGIT_REPO = 'uctoo/agentskills-runtime';
const DOWNLOAD_MIRRORS = [
    {
        name: 'atomgit',
        url: `https://atomgit.com/${ATOMGIT_REPO}/releases/download`,
        priority: 1,
        region: 'china'
    },
    {
        name: 'github',
        url: `https://github.com/${GITHUB_REPO}/releases/download`,
        priority: 2,
        region: 'global'
    }
];
function getPlatformInfo() {
    const platform = os.platform();
    const arch = os.arch();
    const platformMap = {
        'win32': 'win',
        'darwin': 'darwin',
        'linux': 'linux'
    };
    const archMap = {
        'x64': 'x64',
        'arm64': 'arm64',
        'x86': 'x86'
    };
    return {
        platform: platformMap[platform] || platform,
        arch: archMap[arch] || arch,
        suffix: platform === 'win32' ? '.exe' : ''
    };
}
function getRuntimeDir() {
    return path.join(__dirname, '..', 'runtime');
}
function getRuntimePath() {
    const { platform, arch, suffix } = getPlatformInfo();
    return path.join(getRuntimeDir(), `${platform}-${arch}`, 'release', 'bin', `agentskills-runtime${suffix}`);
}
function getVersionFilePath() {
    const { platform, arch } = getPlatformInfo();
    return path.join(getRuntimeDir(), `${platform}-${arch}`, 'release', 'VERSION');
}
function getInstalledVersion() {
    try {
        const versionFile = getVersionFilePath();
        if (fs.existsSync(versionFile)) {
            const content = fs.readFileSync(versionFile, 'utf-8');
            const lines = content.split('\n');
            for (const line of lines) {
                if (line.startsWith('AGENTSKILLS_RUNTIME_VERSION=')) {
                    return line.split('=')[1]?.trim() || null;
                }
            }
            const firstLine = lines[0]?.trim();
            if (firstLine && !firstLine.includes('=')) {
                return firstLine;
            }
        }
    }
    catch {
        // Ignore errors
    }
    return null;
}
function isRuntimeInstalled() {
    return fs.existsSync(getRuntimePath());
}
export class RuntimeManager {
    process = null;
    baseUrl;
    constructor(baseUrl = DEFAULT_BASE_URL) {
        this.baseUrl = baseUrl;
    }
    isInstalled() {
        return isRuntimeInstalled();
    }
    getRuntimePath() {
        return getRuntimePath();
    }
    async downloadRuntime(version = RUNTIME_VERSION) {
        const { platform, arch, suffix } = getPlatformInfo();
        const runtimeDir = path.join(getRuntimeDir(), `${platform}-${arch}`);
        if (!fs.existsSync(runtimeDir)) {
            fs.mkdirSync(runtimeDir, { recursive: true });
        }
        const fileName = `agentskills-runtime-${platform}-${arch}.tar.gz`;
        for (const mirror of DOWNLOAD_MIRRORS) {
            const downloadUrl = `${mirror.url}/v${version}/${fileName}`;
            console.log(`Trying mirror: ${mirror.name} (${mirror.region})`);
            console.log(`URL: ${downloadUrl}`);
            try {
                const https = await import('https');
                const archivePath = path.join(runtimeDir, 'runtime.tar.gz');
                await new Promise((resolve, reject) => {
                    const file = fs.createWriteStream(archivePath);
                    const download = (url) => {
                        https.get(url, (response) => {
                            if (response.statusCode === 302 || response.statusCode === 301) {
                                download(response.headers.location || '');
                                return;
                            }
                            if (response.statusCode !== 200) {
                                reject(new Error(`Download failed with status ${response.statusCode}`));
                                return;
                            }
                            response.pipe(file);
                            file.on('finish', () => {
                                file.close();
                                resolve();
                            });
                        }).on('error', reject);
                    };
                    download(downloadUrl);
                });
                const tar = await import('tar');
                await tar.x({
                    file: archivePath,
                    cwd: runtimeDir
                });
                fs.unlinkSync(archivePath);
                const runtimePath = getRuntimePath();
                if (fs.existsSync(runtimePath) && os.platform() !== 'win32') {
                    fs.chmodSync(runtimePath, '755');
                }
                console.log(`AgentSkills Runtime v${version} downloaded successfully from ${mirror.name}!`);
                return true;
            }
            catch (error) {
                console.log(`Mirror ${mirror.name} failed, trying next...`);
                console.error('Error:', error);
                continue;
            }
        }
        console.error('All mirrors failed to download runtime.');
        console.log('\nPlease download manually from one of these mirrors:');
        for (const mirror of DOWNLOAD_MIRRORS) {
            console.log(`  - ${mirror.url}/v${version}/${fileName}`);
        }
        return false;
    }
    start(options = {}) {
        const runtimePath = getRuntimePath();
        if (!fs.existsSync(runtimePath)) {
            console.error('Runtime not found. Run "skills install-runtime" first.');
            return null;
        }
        const port = options.port || 8080;
        const host = options.host || '127.0.0.1';
        const cwd = options.cwd || path.dirname(runtimePath);
        const args = [String(port)];
        const env = {
            ...process.env,
            ...options.env
        };
        this.process = spawn(runtimePath, args, {
            stdio: options.detached ? 'ignore' : 'inherit',
            detached: options.detached || false,
            cwd: cwd,
            env: env
        });
        if (options.detached && this.process.pid) {
            this.process.unref();
            const pidFile = path.join(getRuntimeDir(), 'runtime.pid');
            fs.writeFileSync(pidFile, String(this.process.pid));
        }
        return this.process;
    }
    stop() {
        const pidFile = path.join(getRuntimeDir(), 'runtime.pid');
        if (fs.existsSync(pidFile)) {
            const pid = parseInt(fs.readFileSync(pidFile, 'utf-8'), 10);
            try {
                process.kill(pid, 'SIGTERM');
                fs.unlinkSync(pidFile);
                return true;
            }
            catch {
                return false;
            }
        }
        if (this.process) {
            this.process.kill('SIGTERM');
            this.process = null;
            return true;
        }
        return false;
    }
    async status() {
        try {
            const response = await axios.get(`${this.baseUrl}/hello`, { timeout: 2000 });
            const headerVersion = response.headers['x-runtime-version'];
            const installedVersion = getInstalledVersion();
            return {
                running: true,
                version: headerVersion || installedVersion || 'unknown',
                sdkVersion: SDK_VERSION
            };
        }
        catch {
            return { running: false, sdkVersion: SDK_VERSION };
        }
    }
}
export class SkillsClient {
    client;
    baseUrl;
    runtimeManager;
    constructor(config = {}) {
        this.baseUrl = config.baseUrl || process.env.SKILL_RUNTIME_API_URL || DEFAULT_BASE_URL;
        this.client = axios.create({
            baseURL: this.baseUrl,
            timeout: config.timeout || DEFAULT_TIMEOUT,
            headers: {
                'Content-Type': 'application/json',
                ...(config.authToken ? { 'Authorization': `Bearer ${config.authToken}` } : {})
            }
        });
        this.runtimeManager = new RuntimeManager(this.baseUrl);
    }
    get runtime() {
        return this.runtimeManager;
    }
    setAuthToken(token) {
        this.client.defaults.headers.common['Authorization'] = `Bearer ${token}`;
    }
    getBaseUrl() {
        return this.baseUrl;
    }
    async healthCheck() {
        try {
            const response = await this.client.get('/hello');
            return { status: 'ok', message: response.data };
        }
        catch {
            return { status: 'error', message: 'Server not responding' };
        }
    }
    async listSkills(options = {}) {
        const { limit = 10, page = 0, skip = 0 } = options;
        const params = new URLSearchParams();
        params.append('limit', String(limit));
        params.append('page', String(page));
        if (skip > 0)
            params.append('skip', String(skip));
        const response = await this.client.get(`/skills?${params.toString()}`);
        return response.data;
    }
    async getSkill(skillId) {
        const response = await this.client.get(`/skills/${skillId}`);
        return response.data;
    }
    async installSkill(options) {
        const response = await this.client.post('/skills/add', options);
        return response.data;
    }
    async uninstallSkill(skillId) {
        const response = await this.client.post('/skills/del', { id: skillId });
        return response.data;
    }
    async executeSkill(skillId, params = {}) {
        const response = await this.client.post('/skills/execute', {
            skill_id: skillId,
            params
        });
        return response.data;
    }
    async executeSkillTool(skillId, toolName, args = {}) {
        const response = await this.client.post(`/skills/${skillId}/tools/${toolName}/run`, { args });
        return response.data;
    }
    async searchSkills(options) {
        const searchOptions = typeof options === 'string'
            ? { query: options, source: 'all', limit: 10 }
            : { query: options.query, source: options.source || 'all', limit: options.limit || 10 };
        const response = await this.client.post('/skills/search', searchOptions);
        return response.data;
    }
    async updateSkill(skillId, updates) {
        const response = await this.client.post('/skills/edit', {
            id: skillId,
            ...updates
        });
        return response.data;
    }
    async getSkillConfig(skillId) {
        const response = await this.client.get(`/skills/${skillId}/config`);
        return response.data;
    }
    async setSkillConfig(skillId, config) {
        const response = await this.client.post(`/skills/${skillId}/config`, config);
        return response.data;
    }
    async listSkillTools(skillId) {
        const response = await this.client.get(`/skills/${skillId}/tools`);
        return response.data;
    }
}
export function createClient(config = {}) {
    return new SkillsClient(config);
}
export function handleApiError(error) {
    if (axios.isAxiosError(error)) {
        const axiosError = error;
        if (axiosError.response?.data) {
            const data = axiosError.response.data;
            return {
                errno: data.errno || axiosError.response?.status || 500,
                errmsg: data.errmsg || axiosError.message || 'Unknown error'
            };
        }
        if (axiosError.response) {
            return {
                errno: axiosError.response.status,
                errmsg: axiosError.response.statusText || axiosError.message || 'Request failed'
            };
        }
        if (axiosError.request) {
            return {
                errno: 503,
                errmsg: 'Runtime server is not responding. Make sure the runtime is running.'
            };
        }
        return {
            errno: 500,
            errmsg: axiosError.message || 'Unknown error'
        };
    }
    if (error instanceof Error) {
        return { errno: 500, errmsg: error.message };
    }
    if (typeof error === 'string') {
        return { errno: 500, errmsg: error };
    }
    return { errno: 500, errmsg: 'Unknown error' };
}
export function defineSkill(config) {
    return config;
}
export function getConfig() {
    const config = {};
    for (const [key, value] of Object.entries(process.env)) {
        if (key.startsWith('SKILL_') && value !== undefined) {
            const configKey = key.substring(6);
            config[configKey] = value;
        }
    }
    return config;
}
export function getSdkVersion() {
    return SDK_VERSION;
}
export { SkillsClient as SkillRuntimeClient };
//# sourceMappingURL=index.js.map