DDL → sql/incremental/xxx.sql
  → loaddbinfo（刷新 db_info 表元数据）
  → crudgen（生成后端五层模块：PO/DAO/Service/Controller/Route）
  → crudweb（生成前端 store 模型 + views CRUD 页面）
  → 迭代定制（手写业务逻辑）
