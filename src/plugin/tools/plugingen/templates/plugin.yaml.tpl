# 插件清单（design.md §2.5）——插件自描述，分发与 build-sync 同步用
# 与宿主加载清单 config/plugins.yaml 职责分离：本文件是插件静态元数据
name: {{name}}
version: 1.0.0
description: "{{tableName}} 表 CRUD 技能插件（plugingen 生成）"
entry: skill_{{name}}.{{className}}Plugin
dependencies: ""
enabled: true
# 需访问的表（tableWhitelist）：宿主按此做白名单校验，未列入的表 host.db 调用会被拒绝。
# 注意：这才是**功能字段**；下方 tables 仅为人工可读的元数据描述。
tableWhitelist:
{{tablesDecl}}
tables:
{{tablesDecl}}
skills:
  - SKILL.md
routes:
{{routesDecl}}
platform: all
