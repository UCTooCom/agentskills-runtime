import { ChildProcess } from 'child_process';
declare const RUNTIME_VERSION: any;
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
export declare class RuntimeManager {
    private process;
    private baseUrl;
    constructor(baseUrl?: string);
    isInstalled(): boolean;
    getRuntimePath(): string;
    downloadRuntime(version?: string): Promise<boolean>;
    start(options?: RuntimeOptions): ChildProcess | null;
    stop(): boolean;
    status(): Promise<RuntimeStatus>;
}
export declare class SkillsClient {
    private client;
    private baseUrl;
    private runtimeManager;
    constructor(config?: ClientConfig);
    get runtime(): RuntimeManager;
    setAuthToken(token: string): void;
    getBaseUrl(): string;
    healthCheck(): Promise<{
        status: string;
        message: string;
    }>;
    listSkills(options?: {
        limit?: number;
        page?: number;
        skip?: number;
    }): Promise<SkillListResponse>;
    getSkill(skillId: string): Promise<Skill>;
    installSkill(options: SkillInstallOptions): Promise<SkillInstallResponse>;
    installSkillFromMultiRepo(source: string, skillPath: string, options?: Omit<SkillInstallOptions, 'source'>): Promise<SkillInstallResponse>;
    isMultiSkillRepoResponse(response: SkillInstallResponse): response is MultiSkillRepoResponse;
    uninstallSkill(skillId: string): Promise<{
        success: boolean;
        message: string;
    }>;
    executeSkill(skillId: string, params?: Record<string, unknown>): Promise<SkillExecutionResult>;
    executeSkillTool(skillId: string, toolName: string, args?: Record<string, unknown>): Promise<SkillExecutionResult>;
    searchSkills(options: {
        query: string;
        source?: string;
        limit?: number;
    } | string): Promise<SkillSearchResult>;
    updateSkill(skillId: string, updates: Partial<Skill>): Promise<Skill>;
    getSkillConfig(skillId: string): Promise<Record<string, unknown>>;
    setSkillConfig(skillId: string, config: Record<string, unknown>): Promise<{
        success: boolean;
        message: string;
    }>;
    listSkillTools(skillId: string): Promise<ToolDefinition[]>;
}
export declare function createClient(config?: ClientConfig): SkillsClient;
export declare function handleApiError(error: unknown): ApiError;
export declare function defineSkill(config: {
    metadata: SkillMetadata;
    tools: ToolDefinition[];
    validateConfig?: (config: EnvironmentConfig) => {
        ok: null;
    } | {
        err: string;
    };
}): {
    metadata: SkillMetadata;
    tools: ToolDefinition[];
};
export declare function getConfig<T extends EnvironmentConfig = EnvironmentConfig>(): T;
export declare function getSdkVersion(): string;
export declare function getRuntimeVersion(): string;
export { SkillsClient as SkillRuntimeClient, RUNTIME_VERSION };
//# sourceMappingURL=index.d.ts.map