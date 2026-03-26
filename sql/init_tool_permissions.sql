-- ============================================================
-- 工具权限初始化脚本
-- ============================================================
-- 版本: v2.0
-- 日期: 2026-03-25
-- 说明: 将所有内置工具作为权限节点插入permissions表
-- 超管账号ID: 505cf909-5e0e-4dde-b215-74274d2cc548 (admin@uctoo.com)
-- ============================================================

-- 清理现有的工具权限（type=4）
DELETE FROM role_has_permission WHERE permission_id IN (
    SELECT id FROM permissions WHERE type = 4
);
DELETE FROM group_has_permission WHERE permission_id IN (
    SELECT id FROM permissions WHERE type = 4
);
DELETE FROM permissions WHERE type = 4;

-- ============================================================
-- 第一步：插入工具权限组根节点（不指定ID，让数据库自动生成UUID）
-- ============================================================

-- 文件系统工具组根节点
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/fs', 4, '/api/v1/tools/fs', '文件系统工具', 'tools', NULL, 100, 0, 1, '{"group": "fs", "description": "文件系统操作工具，包括文件读写、编辑、删除等操作"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- 网络工具组根节点
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/web', 4, '/api/v1/tools/web', '网络工具', 'tools', NULL, 200, 0, 1, '{"group": "web", "description": "网络请求和爬虫工具"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- 技能工具组根节点
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/skill', 4, '/api/v1/tools/skill', '技能工具', 'tools', NULL, 300, 0, 1, '{"group": "skill", "description": "技能生命周期管理工具"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- 代码生成工具组根节点
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/code', 4, '/api/v1/tools/code', '代码生成工具', 'tools', NULL, 400, 0, 1, '{"group": "code", "description": "代码生成和模板引擎工具"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- CLI工具组根节点
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/cli', 4, '/api/v1/tools/cli', 'CLI工具', 'tools', NULL, 500, 0, 1, '{"group": "cli", "description": "命令行执行工具"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

INSERT INTO "public"."permissions" ("id", "permission_name", "level", "icon", "module", "component", "redirect", "type", "hidden", "weight", "creator", "created_at", "updated_at", "deleted_at", "keepalive", "path", "title", "parent_id", "meta", "method") VALUES ('564dceb7-0f7e-464b-a84f-be81620d56dd', '/api/v1/tools/fs', NULL, NULL, 'tools', NULL, NULL, 4, 0, 100, '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-03-25 14:30:58.571033+08', '2026-03-25 14:30:58.571033+08', NULL, 1, '/api/v1/tools/fs', '文件系统工具', NULL, '{"group": "fs", "description": "文件系统操作工具，包括文件读写、编辑、删除等操作"}', NULL);
INSERT INTO "public"."permissions" ("id", "permission_name", "level", "icon", "module", "component", "redirect", "type", "hidden", "weight", "creator", "created_at", "updated_at", "deleted_at", "keepalive", "path", "title", "parent_id", "meta", "method") VALUES ('c2057e58-4a95-4069-8d32-99b736f47f88', '/api/v1/tools/web', NULL, NULL, 'tools', NULL, NULL, 4, 0, 200, '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-03-25 14:30:58.616153+08', '2026-03-25 14:30:58.616153+08', NULL, 1, '/api/v1/tools/web', '网络工具', NULL, '{"group": "web", "description": "网络请求和爬虫工具"}', NULL);
INSERT INTO "public"."permissions" ("id", "permission_name", "level", "icon", "module", "component", "redirect", "type", "hidden", "weight", "creator", "created_at", "updated_at", "deleted_at", "keepalive", "path", "title", "parent_id", "meta", "method") VALUES ('8d9c3eb8-107b-4ad2-8b9f-3400bcd28679', '/api/v1/tools/skill', NULL, NULL, 'tools', NULL, NULL, 4, 0, 300, '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-03-25 14:30:58.617626+08', '2026-03-25 14:30:58.617626+08', NULL, 1, '/api/v1/tools/skill', '技能工具', NULL, '{"group": "skill", "description": "技能生命周期管理工具"}', NULL);
INSERT INTO "public"."permissions" ("id", "permission_name", "level", "icon", "module", "component", "redirect", "type", "hidden", "weight", "creator", "created_at", "updated_at", "deleted_at", "keepalive", "path", "title", "parent_id", "meta", "method") VALUES ('3f056c44-1646-4c15-aaaf-5661aaa8244d', '/api/v1/tools/code', NULL, NULL, 'tools', NULL, NULL, 4, 0, 400, '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-03-25 14:30:58.619169+08', '2026-03-25 14:30:58.619169+08', NULL, 1, '/api/v1/tools/code', '代码生成工具', NULL, '{"group": "code", "description": "代码生成和模板引擎工具"}', NULL);
INSERT INTO "public"."permissions" ("id", "permission_name", "level", "icon", "module", "component", "redirect", "type", "hidden", "weight", "creator", "created_at", "updated_at", "deleted_at", "keepalive", "path", "title", "parent_id", "meta", "method") VALUES ('5fd4b124-8168-4516-b560-47969d098ccc', '/api/v1/tools/cli', NULL, NULL, 'tools', NULL, NULL, 4, 0, 500, '505cf909-5e0e-4dde-b215-74274d2cc548', '2026-03-25 14:30:58.620228+08', '2026-03-25 14:30:58.620228+08', NULL, 1, '/api/v1/tools/cli', 'CLI工具', NULL, '{"group": "cli", "description": "命令行执行工具"}', NULL);

-- ============================================================
-- 查询并显示生成的组节点ID（用于后续插入子节点）
-- ============================================================
SELECT 
    id,
    permission_name,
    title,
    weight
FROM permissions
WHERE type = 4 AND parent_id IS NULL
ORDER BY weight;

-- ============================================================
-- 说明：执行上述SQL后，请记录下各组的ID，然后使用下面的模板插入子节点
-- 将 <GROUP_ID> 替换为实际的组节点ID
-- ============================================================

-- ==================== 文件系统工具子节点 ====================
-- 文件读取工具（将 <FS_GROUP_ID> 替换为文件系统工具组的实际ID）
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/fs/read', 4, '/api/v1/tools/fs/read', '读取文件', 'tools', '564dceb7-0f7e-464b-a84f-be81620d56dd', 101, 0, 1, '{"tool": "file_read", "sensitiveLevel": 1, "requiresConfirmation": false, "auditEnabled": true, "description": "读取文件内容"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- 文件写入工具
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/fs/write', 4, '/api/v1/tools/fs/write', '写入文件', 'tools', '564dceb7-0f7e-464b-a84f-be81620d56dd', 102, 0, 1, '{"tool": "file_write", "sensitiveLevel": 2, "requiresConfirmation": false, "auditEnabled": true, "description": "写入文件内容"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- 文件编辑工具
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/fs/edit', 4, '/api/v1/tools/fs/edit', '编辑文件', 'tools', '564dceb7-0f7e-464b-a84f-be81620d56dd', 103, 0, 1, '{"tool": "file_edit", "sensitiveLevel": 2, "requiresConfirmation": false, "auditEnabled": true, "description": "编辑文件内容（文本替换）"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- 文件删除工具（高敏感）
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/fs/delete', 4, '/api/v1/tools/fs/delete', '删除文件', 'tools', '564dceb7-0f7e-464b-a84f-be81620d56dd', 104, 0, 1, '{"tool": "file_delete", "sensitiveLevel": 3, "requiresConfirmation": true, "auditEnabled": true, "description": "删除文件（需要二次确认）"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- 文件复制工具
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/fs/copy', 4, '/api/v1/tools/fs/copy', '复制文件', 'tools', '564dceb7-0f7e-464b-a84f-be81620d56dd', 105, 0, 1, '{"tool": "file_copy", "sensitiveLevel": 1, "requiresConfirmation": false, "auditEnabled": true, "description": "复制文件"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- 文件移动工具
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/fs/move', 4, '/api/v1/tools/fs/move', '移动文件', 'tools', '564dceb7-0f7e-464b-a84f-be81620d56dd', 106, 0, 1, '{"tool": "file_move", "sensitiveLevel": 2, "requiresConfirmation": false, "auditEnabled": true, "description": "移动或重命名文件"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- 文件搜索工具
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/fs/search', 4, '/api/v1/tools/fs/search', '搜索文件', 'tools', '564dceb7-0f7e-464b-a84f-be81620d56dd', 107, 0, 1, '{"tool": "file_search", "sensitiveLevel": 1, "requiresConfirmation": false, "auditEnabled": true, "description": "在文件中搜索内容"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- 目录列表工具
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/fs/list', 4, '/api/v1/tools/fs/list', '列出目录', 'tools', '564dceb7-0f7e-464b-a84f-be81620d56dd', 108, 0, 1, '{"tool": "directory_list", "sensitiveLevel": 1, "requiresConfirmation": false, "auditEnabled": true, "description": "列出目录内容"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- 创建目录工具
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/fs/create', 4, '/api/v1/tools/fs/create', '创建目录', 'tools', '564dceb7-0f7e-464b-a84f-be81620d56dd', 109, 0, 1, '{"tool": "directory_create", "sensitiveLevel": 2, "requiresConfirmation": false, "auditEnabled": true, "description": "创建目录"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- ==================== 网络工具子节点 ====================
-- HTTP请求工具（将 <WEB_GROUP_ID> 替换为网络工具组的实际ID）
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/web/http', 4, '/api/v1/tools/web/http', 'HTTP请求', 'tools', 'c2057e58-4a95-4069-8d32-99b736f47f88', 201, 0, 1, '{"tool": "http_request", "sensitiveLevel": 2, "requiresConfirmation": false, "auditEnabled": true, "description": "发送HTTP请求"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- 网页抓取工具
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/web/fetch', 4, '/api/v1/tools/web/fetch', '网页抓取', 'tools', 'c2057e58-4a95-4069-8d32-99b736f47f88', 202, 0, 1, '{"tool": "web_fetch", "sensitiveLevel": 1, "requiresConfirmation": false, "auditEnabled": true, "description": "抓取网页内容并转换为Markdown"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- Firecrawl爬虫工具
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/web/firecrawl', 4, '/api/v1/tools/web/firecrawl', 'Firecrawl爬虫', 'tools', 'c2057e58-4a95-4069-8d32-99b736f47f88', 203, 0, 1, '{"tool": "firecrawl", "sensitiveLevel": 2, "requiresConfirmation": false, "auditEnabled": true, "description": "使用Firecrawl进行网络搜索和爬取"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- ==================== 技能工具子节点 ====================
-- 技能搜索工具（将 <SKILL_GROUP_ID> 替换为技能工具组的实际ID）
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/skill/search', 4, '/api/v1/tools/skill/search', '搜索技能', 'tools', '8d9c3eb8-107b-4ad2-8b9f-3400bcd28679', 301, 0, 1, '{"tool": "skill_search", "sensitiveLevel": 1, "requiresConfirmation": false, "auditEnabled": true, "description": "搜索技能"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- 技能安装工具（高敏感）
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/skill/install', 4, '/api/v1/tools/skill/install', '安装技能', 'tools', '8d9c3eb8-107b-4ad2-8b9f-3400bcd28679', 302, 0, 1, '{"tool": "skill_install", "sensitiveLevel": 3, "requiresConfirmation": true, "auditEnabled": true, "description": "安装技能（需要二次确认）"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- 技能验证工具
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/skill/validate', 4, '/api/v1/tools/skill/validate', '验证技能', 'tools', '8d9c3eb8-107b-4ad2-8b9f-3400bcd28679', 303, 0, 1, '{"tool": "skill_validate", "sensitiveLevel": 1, "requiresConfirmation": false, "auditEnabled": true, "description": "验证技能结构"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- 技能初始化工具
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/skill/init', 4, '/api/v1/tools/skill/init', '初始化技能', 'tools', '8d9c3eb8-107b-4ad2-8b9f-3400bcd28679', 304, 0, 1, '{"tool": "skill_initializer", "sensitiveLevel": 2, "requiresConfirmation": false, "auditEnabled": true, "description": "初始化技能目录结构"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- 技能打包工具
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/skill/package', 4, '/api/v1/tools/skill/package', '打包技能', 'tools', '8d9c3eb8-107b-4ad2-8b9f-3400bcd28679', 305, 0, 1, '{"tool": "skill_packager", "sensitiveLevel": 2, "requiresConfirmation": false, "auditEnabled": true, "description": "打包技能为.skill文件"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- ==================== 代码生成工具子节点 ====================
-- 模板引擎工具（将 <CODE_GROUP_ID> 替换为代码生成工具组的实际ID）
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/code/template', 4, '/api/v1/tools/code/template', '模板引擎', 'tools', '3f056c44-1646-4c15-aaaf-5661aaa8244d', 401, 0, 1, '{"tool": "template_engine", "sensitiveLevel": 1, "requiresConfirmation": false, "auditEnabled": true, "description": "模板引擎，支持变量替换"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- 代码片段生成器工具
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/code/generate', 4, '/api/v1/tools/code/generate', '代码片段生成器', 'tools', '3f056c44-1646-4c15-aaaf-5661aaa8244d', 402, 0, 1, '{"tool": "code_snippet_generator", "sensitiveLevel": 1, "requiresConfirmation": false, "auditEnabled": true, "description": "生成代码片段（多语言支持）"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- ==================== CLI工具子节点 ====================
-- CLI执行工具（高敏感）（将 <CLI_GROUP_ID> 替换为CLI工具组的实际ID）
INSERT INTO permissions (permission_name, type, path, title, module, parent_id, weight, hidden, keepalive, meta, creator, created_at, updated_at) VALUES
('/api/v1/tools/cli/execute', 4, '/api/v1/tools/cli/execute', '执行CLI命令', 'tools', '5fd4b124-8168-4516-b560-47969d098ccc', 501, 0, 1, '{"tool": "cli_execute", "sensitiveLevel": 3, "requiresConfirmation": true, "auditEnabled": true, "description": "执行CLI命令（需要二次确认）"}', '505cf909-5e0e-4dde-b215-74274d2cc548', NOW(), NOW());

-- ============================================================
-- 统计信息
-- ============================================================
SELECT 
    '工具权限总数' as description,
    COUNT(*) as count
FROM permissions
WHERE type = 4;

SELECT 
    '文件系统工具组' as group_name,
    COUNT(*) as count
FROM permissions
WHERE type = 4 AND path LIKE '/api/v1/tools/fs%'
UNION ALL
SELECT 
    '网络工具组' as group_name,
    COUNT(*) as count
FROM permissions
WHERE type = 4 AND path LIKE '/api/v1/tools/web%'
UNION ALL
SELECT 
    '技能工具组' as group_name,
    COUNT(*) as count
FROM permissions
WHERE type = 4 AND path LIKE '/api/v1/tools/skill%'
UNION ALL
SELECT 
    '代码生成工具组' as group_name,
    COUNT(*) as count
FROM permissions
WHERE type = 4 AND path LIKE '/api/v1/tools/code%'
UNION ALL
SELECT 
    'CLI工具组' as group_name,
    COUNT(*) as count
FROM permissions
WHERE type = 4 AND path LIKE '/api/v1/tools/cli%';
