# 插件清单（design.md §2.5）——插件自描述，分发与 build-sync 同步用
# 与宿主加载清单 config/plugins.yaml 职责分离：本文件是插件静态元数据
name: {{name}}
version: 1.0.0
description: "{{tableName}} 表 CRUD 技能插件（plugingen 生成）"
entry: skill_{{name}}.{{className}}Plugin
dependencies: ""
tables:
{{tablesDecl}}
skills:
  - SKILL.md
routes:
{{routesDecl}}
platform: all
