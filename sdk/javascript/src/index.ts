import axios, { AxiosInstance, AxiosError } from 'axios';
import { spawn, ChildProcess, execSync } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';
import * as os from 'os';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
const packageJson = require('../package.json');

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const SDK_VERSION = packageJson.version;
const RUNTIME_VERSION = packageJson.runtime?.version || '0.0.2';

export interface EnvironmentConfig {
  [key: string]: string | undefined;
}

export interface SkillMetadata {
  name: string;
  version: string;
  description: string;
  author: string;
  license?: string;
  format?: string;
  created_at?: string;
  updated_at?: string;
}

export interface Skill extends SkillMetadata {
  id: string;
  source_path: string;
  metadata?: Record<string, unknown>;
  dependencies?: string[];
  tools?: ToolDefinition[];
}

export interface ToolParameter {
  name: string;
  paramType: 'string' | 'number' | 'boolean' | 'file' | 'array' | 'object';
  description: string;
  required: boolean;
  defaultValue?: string | number | boolean;
}

export interface ToolDefinition {
  name: string;
  description: string;
  parameters: ToolParameter[];
}

export interface SkillExecutionResult {
  success: boolean;
  output: string;
  errorMessage: string | null;
  data?: Record<string, unknown>;
}

export interface SkillListResponse {
  current_page: number;
  total_count: number;
  total_page: number;
  skills: Skill[];
}

export interface SkillInstallOptions {
  source: string;
  validate?: boolean;
  creator?: string;
  install_path?: string;
  branch?: string;
  tag?: string;
  commit?: string;
}

export interface SkillInstallResult {
  id: string;
  name: string;
  status: string;
  message: string;
  created_at: string;
}

export interface AvailableSkillInfo {
  name: string;
  description: string;
  relative_path: string;
  full_path: string;
  depth: number;
  parent_path: string;
}

export interface MultiSkillRepoResponse {
  status: 'multi_skill_repo';
  message: string;
  available_skills: AvailableSkillInfo[];
  total_count: number;
  source_url: string;
}

export interface SkillInstallResponse {
  id?: string;
  name?: string;
  status: string;
  message: string;
  created_at?: string;
  source_type?: string;
  source_url?: string;
  available_skills?: AvailableSkillInfo[];
  total_count?: number;
}

export interface SkillSearchResultItem {
  name: string;
  full_name: string;
  description: string;
  url?: string;
  html_url?: string;
  clone_url: string;
  source: string;
  stars?: number;
  forks?: number;
  stargazers_count?: number;
  forks_count?: number;
  updated_at: string;
  author?: string;
  owner?: {
    login: string;
    avatar_url: string;
  };
  topics?: string[];
  license?: string;
}

export interface SkillSearchResult {
  total_count: number;
  results: SkillSearchResultItem[];
}

export interface ApiError {
  errno: number;
  errmsg: string;
  details?: Record<string, unknown>;
}

export interface ClientConfig {
  baseUrl?: string;
  authToken?: string;
  timeout?: number;
}

export interface RuntimeStatus {
  running: boolean;
  version?: string;
  sdkVersion?: string;
  pid?: number;
  port?: number;
}

export interface RuntimeOptions {
  port?: number;
  host?: string;
  detached?: boolean;
  cwd?: string;
  env?: Record<string, string>;
  skillInstallPath?: string;
}

const DEFAULT_BASE_URL = 'http://127.0.0.1:8080';
const DEFAULT_TIMEOUT = 30000;
const GITHUB_REPO = 'UCTooCom/agentskills-runtime';
const ATOMGIT_REPO = 'uctoo/agentskills-runtime';

interface DownloadMirror {
  name: string;
  url: string;
  priority: number;
  region: string;
}

const DOWNLOAD_MIRRORS: DownloadMirror[] = [
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

function getPlatformInfo(): { platform: string; arch: string; suffix: string } {
  const platform = os.platform();
  const arch = os.arch();
  
  const platformMap: Record<string, string> = {
    'win32': 'win',
    'darwin': 'darwin',
    'linux': 'linux'
  };
  
  const archMap: Record<string, string> = {
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

function getRuntimeDir(): string {
  return path.join(__dirname, '..', 'runtime');
}

function getRuntimePath(): string {
  const { platform, arch, suffix } = getPlatformInfo();
  return path.join(getRuntimeDir(), `${platform}-${arch}`, 'release', 'bin', `agentskills-runtime${suffix}`);
}

function getReleaseDir(): string {
  const { platform, arch } = getPlatformInfo();
  return path.join(getRuntimeDir(), `${platform}-${arch}`, 'release');
}

function getVersionFilePath(): string {
  const { platform, arch } = getPlatformInfo();
  return path.join(getRuntimeDir(), `${platform}-${arch}`, 'release', 'VERSION');
}

function getInstalledVersion(): string | null {
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
  } catch {
    // Ignore errors
  }
  return null;
}

function isRuntimeInstalled(): boolean {
  return fs.existsSync(getRuntimePath());
}

export class RuntimeManager {
  private process: ChildProcess | null = null;
  private baseUrl: string;

  constructor(baseUrl: string = DEFAULT_BASE_URL) {
    this.baseUrl = baseUrl;
  }

  isInstalled(): boolean {
    return isRuntimeInstalled();
  }

  getRuntimePath(): string {
    return getRuntimePath();
  }

  async downloadRuntime(version: string = RUNTIME_VERSION): Promise<boolean> {
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
        
        await new Promise<void>((resolve, reject) => {
          const file = fs.createWriteStream(archivePath);
          
          const download = (url: string) => {
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
        
        const releaseDir = path.join(runtimeDir, 'release');
        const envFile = path.join(releaseDir, '.env');
        const envExampleFile = path.join(releaseDir, '.env.example');
        
        if (!fs.existsSync(envFile) && fs.existsSync(envExampleFile)) {
          fs.copyFileSync(envExampleFile, envFile);
          console.log('Created .env file from .env.example');
        } else if (!fs.existsSync(envFile)) {
          const defaultEnvContent = `# AgentSkills Runtime Configuration
# This file was auto-generated. Edit as needed.

# Skill Installation Path
SKILL_INSTALL_PATH=./skills
`;
          fs.writeFileSync(envFile, defaultEnvContent);
          console.log('Created default .env file');
        }
        
        console.log(`AgentSkills Runtime v${version} downloaded successfully from ${mirror.name}!`);
        return true;
      } catch (error) {
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

  start(options: RuntimeOptions = {}): ChildProcess | null {
    const runtimePath = getRuntimePath();
    
    if (!fs.existsSync(runtimePath)) {
      console.error('Runtime not found. Run "skills install-runtime" first.');
      return null;
    }
    
    const port = options.port || 8080;
    const host = options.host || '127.0.0.1';
    const cwd = options.cwd || getReleaseDir();
    
    const skillInstallPath = options.skillInstallPath || process.env.SKILL_INSTALL_PATH || path.join(process.cwd(), 'skills');
    
    const env = {
      ...process.env,
      SKILL_INSTALL_PATH: skillInstallPath,
      ...options.env
    };
    
    console.log(`[SDK DEBUG] cwd: ${cwd}`);
    console.log(`[SDK DEBUG] SKILL_INSTALL_PATH in env: ${env.SKILL_INSTALL_PATH}`);
    console.log(`[SDK DEBUG] runtimePath: ${runtimePath}`);
    
    // On Windows, use shell to properly handle path arguments
    // When using shell: true, we need to properly escape the command
    if (process.platform === 'win32') {
      // Use escaped quotes for Windows paths
      const escapedPath = skillInstallPath.replace(/"/g, '""');
      const command = `"${runtimePath}" ${port} --skill-path "${escapedPath}"`;
      console.log(`[SDK DEBUG] command: ${command}`);
      
      this.process = spawn(command, [], {
        stdio: options.detached ? 'ignore' : 'inherit',
        detached: options.detached || false,
        cwd: cwd,
        env: env,
        windowsHide: true,
        shell: true
      });
    } else {
      const args = [String(port), '--skill-path', skillInstallPath];
      console.log(`[SDK DEBUG] args: ${args.join(' ')}`);
      
      this.process = spawn(runtimePath, args, {
        stdio: options.detached ? 'ignore' : 'inherit',
        detached: options.detached || false,
        cwd: cwd,
        env: env,
        windowsHide: true
      });
    }
    
    if (options.detached && this.process.pid) {
      this.process.unref();
      const pidFile = path.join(getRuntimeDir(), 'runtime.pid');
      fs.writeFileSync(pidFile, String(this.process.pid));
    }
    
    return this.process;
  }

  stop(): boolean {
    const pidFile = path.join(getRuntimeDir(), 'runtime.pid');
    
    if (fs.existsSync(pidFile)) {
      const pid = parseInt(fs.readFileSync(pidFile, 'utf-8'), 10);
      try {
        if (process.platform === 'win32') {
          execSync(`taskkill /F /PID ${pid}`, { stdio: 'ignore' });
        } else {
          process.kill(pid, 'SIGTERM');
        }
        fs.unlinkSync(pidFile);
        return true;
      } catch {
        try {
          fs.unlinkSync(pidFile);
        } catch {}
        return false;
      }
    }
    
    if (this.process) {
      try {
        if (process.platform === 'win32') {
          execSync(`taskkill /F /PID ${this.process.pid}`, { stdio: 'ignore' });
        } else {
          this.process.kill('SIGTERM');
        }
      } catch {}
      this.process = null;
      return true;
    }
    
    return false;
  }

  async status(): Promise<RuntimeStatus> {
    try {
      const response = await axios.get(`${this.baseUrl}/hello`, { timeout: 2000 });
      const headerVersion = response.headers['x-runtime-version'];
      const installedVersion = getInstalledVersion();
      
      return {
        running: true,
        version: headerVersion || installedVersion || 'unknown',
        sdkVersion: SDK_VERSION
      };
    } catch {
      return { running: false, sdkVersion: SDK_VERSION };
    }
  }
}

export class SkillsClient {
  private client: AxiosInstance;
  private baseUrl: string;
  private runtimeManager: RuntimeManager;

  constructor(config: ClientConfig = {}) {
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

  get runtime(): RuntimeManager {
    return this.runtimeManager;
  }

  setAuthToken(token: string): void {
    this.client.defaults.headers.common['Authorization'] = `Bearer ${token}`;
  }

  getBaseUrl(): string {
    return this.baseUrl;
  }

  async healthCheck(): Promise<{ status: string; message: string }> {
    try {
      const response = await this.client.get('/hello');
      return { status: 'ok', message: response.data };
    } catch {
      return { status: 'error', message: 'Server not responding' };
    }
  }

  async listSkills(options: { limit?: number; page?: number; skip?: number } = {}): Promise<SkillListResponse> {
    const { limit = 10, page = 0, skip = 0 } = options;
    const params = new URLSearchParams();
    params.append('limit', String(limit));
    params.append('page', String(page));
    if (skip > 0) params.append('skip', String(skip));

    const response = await this.client.get(`/skills?${params.toString()}`);
    return response.data;
  }

  async getSkill(skillId: string): Promise<Skill> {
    const response = await this.client.get(`/skills/${skillId}`);
    return response.data;
  }

  async installSkill(options: SkillInstallOptions): Promise<SkillInstallResponse> {
    const response = await this.client.post('/skills/add', options);
    return response.data;
  }
  
  async installSkillFromMultiRepo(source: string, skillPath: string, options: Omit<SkillInstallOptions, 'source'> = {}): Promise<SkillInstallResponse> {
    const response = await this.client.post('/skills/add', {
      source,
      skill_subpath: skillPath,
      ...options
    });
    return response.data;
  }
  
  isMultiSkillRepoResponse(response: SkillInstallResponse): response is MultiSkillRepoResponse {
    return response.status === 'multi_skill_repo' && response.available_skills !== undefined;
  }

  async uninstallSkill(skillId: string): Promise<{ success: boolean; message: string }> {
    const response = await this.client.post('/skills/del', { id: skillId });
    return response.data;
  }

  async executeSkill(skillId: string, params: Record<string, unknown> = {}): Promise<SkillExecutionResult> {
    const response = await this.client.post('/skills/execute', {
      skill_id: skillId,
      params
    });
    return response.data;
  }

  async executeSkillTool(skillId: string, toolName: string, args: Record<string, unknown> = {}): Promise<SkillExecutionResult> {
    const response = await this.client.post(`/skills/${skillId}/tools/${toolName}/run`, { args });
    return response.data;
  }

  async searchSkills(options: { query: string; source?: string; limit?: number } | string): Promise<SkillSearchResult> {
    const searchOptions = typeof options === 'string' 
      ? { query: options, source: 'all', limit: 10 }
      : { query: options.query, source: options.source || 'all', limit: options.limit || 10 };
    
    const response = await this.client.post('/skills/search', searchOptions);
    return response.data;
  }

  async updateSkill(skillId: string, updates: Partial<Skill>): Promise<Skill> {
    const response = await this.client.post('/skills/edit', {
      id: skillId,
      ...updates
    });
    return response.data;
  }

  async getSkillConfig(skillId: string): Promise<Record<string, unknown>> {
    const response = await this.client.get(`/skills/${skillId}/config`);
    return response.data;
  }

  async setSkillConfig(skillId: string, config: Record<string, unknown>): Promise<{ success: boolean; message: string }> {
    const response = await this.client.post(`/skills/${skillId}/config`, config);
    return response.data;
  }

  async listSkillTools(skillId: string): Promise<ToolDefinition[]> {
    const response = await this.client.get(`/skills/${skillId}/tools`);
    return response.data;
  }
}

export function createClient(config: ClientConfig = {}): SkillsClient {
  return new SkillsClient(config);
}

export function handleApiError(error: unknown): ApiError {
  if (axios.isAxiosError(error)) {
    const axiosError = error as AxiosError<ApiError>;
    if (axiosError.response?.data) {
      const data = axiosError.response.data as ApiError;
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

export function defineSkill(config: {
  metadata: SkillMetadata;
  tools: ToolDefinition[];
  validateConfig?: (config: EnvironmentConfig) => { ok: null } | { err: string };
}): { metadata: SkillMetadata; tools: ToolDefinition[] } {
  return config;
}

export function getConfig<T extends EnvironmentConfig = EnvironmentConfig>(): T {
  const config: Record<string, string> = {};

  for (const [key, value] of Object.entries(process.env)) {
    if (key.startsWith('SKILL_') && value !== undefined) {
      const configKey = key.substring(6);
      config[configKey] = value;
    }
  }

  return config as T;
}

export function getSdkVersion(): string {
  return SDK_VERSION;
}

export function getRuntimeVersion(): string {
  return RUNTIME_VERSION;
}

export { SkillsClient as SkillRuntimeClient, RUNTIME_VERSION };
