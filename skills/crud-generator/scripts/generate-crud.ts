#!/usr/bin/env ts-node

import * as fs from 'fs';
import * as path from 'path';

interface GeneratorOptions {
  table: string;
  database: string;
  requireAuth: boolean;
  enableCache: boolean;
  output: string;
}

interface Field {
  name: string;
  type: string;
  isNullable: boolean;
  isPrimaryKey: boolean;
  defaultValue: string;
  dbType: string;
}

/**
 * Parse Prisma schema to extract table fields
 */
function parsePrismaSchema(schemaPath: string, tableName: string): Field[] {
  const schema = fs.readFileSync(schemaPath, 'utf-8');
  
  // Find the model definition
  const modelRegex = new RegExp(`model\\s+${tableName}\\s*\\{([^}]+)\\}`, 's');
  const match = schema.match(modelRegex);
  
  if (!match) {
    console.warn(`Model ${tableName} not found in schema, using default fields`);
    return getDefaultFields();
  }
  
  const fields: Field[] = [];
  const lines = match[1].split('\n');
  
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('//') || trimmed.startsWith('@@')) {
      continue;
    }
    
    // Parse field: name type [attributes]
    const fieldMatch = trimmed.match(/^(\w+)\s+(\w+)(\?)?(?:\s+(.*))?$/);
    if (fieldMatch) {
      const [, name, type, nullable, attrs] = fieldMatch;
      
      // Skip relation fields
      if (attrs && attrs.includes('@relation')) {
        continue;
      }
      
      fields.push({
        name,
        type,
        isNullable: !!nullable,
        isPrimaryKey: attrs?.includes('@id') || false,
        defaultValue: getDefaultValue(type, nullable),
        dbType: extractDbType(attrs || '')
      });
    }
  }
  
  return fields.length > 0 ? fields : getDefaultFields();
}

function extractDbType(attrs: string): string {
  const dbTypeMatch = attrs.match(/@db\.(\w+)/);
  return dbTypeMatch ? dbTypeMatch[1] : '';
}

function getDefaultValue(type: string, nullable: boolean): string {
  if (nullable) return `None<${mapPrismaToCangjie(type)}>`;
  
  switch (type) {
    case 'String': return '""';
    case 'Int': return '0';
    case 'Float': return '0.0';
    case 'Boolean': return 'false';
    case 'DateTime': return 'DateTime.now()';
    default: return '""';
  }
}

function getDefaultFields(): Field[] {
  return [
    { name: 'id', type: 'String', isNullable: false, isPrimaryKey: true, defaultValue: '""', dbType: 'Uuid' },
    { name: 'name', type: 'String', isNullable: false, isPrimaryKey: false, defaultValue: '""', dbType: 'VarChar' },
    { name: 'description', type: 'String', isNullable: true, isPrimaryKey: false, defaultValue: 'None<String>', dbType: 'VarChar' },
    { name: 'status', type: 'Int', isNullable: false, isPrimaryKey: false, defaultValue: '0', dbType: '' },
    { name: 'created_at', type: 'DateTime', isNullable: false, isPrimaryKey: false, defaultValue: 'DateTime.now()', dbType: 'Timestamptz' },
    { name: 'updated_at', type: 'DateTime', isNullable: false, isPrimaryKey: false, defaultValue: 'DateTime.now()', dbType: 'Timestamptz' },
    { name: 'deleted_at', type: 'DateTime', isNullable: true, isPrimaryKey: false, defaultValue: 'None<DateTime>', dbType: 'Timestamptz' },
    { name: 'creator', type: 'String', isNullable: true, isPrimaryKey: false, defaultValue: 'None<String>', dbType: 'Uuid' }
  ];
}

function mapPrismaToCangjie(prismaType: string): string {
  switch (prismaType) {
    case 'String': return 'String';
    case 'Int': return 'Int32';
    case 'Float': return 'Float64';
    case 'Boolean': return 'Bool';
    case 'DateTime': return 'DateTime';
    default: return 'String';
  }
}

function toPascalCase(str: string): string {
  return str
    .split('_')
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join('');
}

function toCamelCase(str: string): string {
  const pascal = toPascalCase(str);
  return pascal.charAt(0).toLowerCase() + pascal.slice(1);
}

class CRUDGenerator {
  private options: GeneratorOptions;
  private fields: Field[];

  constructor(options: GeneratorOptions, fields: Field[]) {
    this.options = options;
    this.fields = fields;
  }

  async generate(): Promise<void> {
    console.log(`🚀 Generating CRUD module for ${this.options.table}...`);

    // 1. 生成Model
    await this.generateModel();

    // 2. 生成DAO (V4新增)
    await this.generateDAO();

    // 3. 生成Service
    await this.generateService();

    // 4. 生成Controller
    await this.generateController();

    // 5. 生成Route
    await this.generateRoute();

    console.log(`✅ CRUD module generated successfully!`);
    console.log(`   - Model: src/app/models/${this.options.database}/${this.toPascalCase(this.options.table)}PO.cj`);
    console.log(`   - DAO: src/app/dao/${this.options.database}/${this.toPascalCase(this.options.table)}DAO.cj`);
    console.log(`   - Service: src/app/services/${this.options.database}/${this.toPascalCase(this.options.table)}Service.cj`);
    console.log(`   - Controller: src/app/controllers/${this.options.database}/${this.options.table}/${this.toPascalCase(this.options.table)}Controller.cj`);
    console.log(`   - Route: src/app/routes/${this.options.database}/${this.options.table}/${this.toPascalCase(this.options.table)}Route.cj`);
  }

  private async generateModel(): Promise<void> {
    const className = this.toPascalCase(this.options.table);
    const fieldDeclarations = this.generateModelFields();
    const toJsonBody = this.generateToJsonBody();
    
    const content = `/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.models.${this.options.database}

import std.time.DateTime
import f_orm.macros.{QueryMappersGenerator, ORMField}
import f_orm.*

/**
 * ${className}PO - ${this.options.table}表数据模型
 */
@QueryMappersGenerator["${this.options.table}"]
public class ${className}PO {
${fieldDeclarations}
    
    public init() {}
    
    /**
     * 转换为JSON字符串
     */
    public func toJson(): String {
${toJsonBody}
    }
}
`;

    const modelDir = path.join(this.options.output, 'models', this.options.database);
    await fs.promises.mkdir(modelDir, { recursive: true });
    await fs.promises.writeFile(
      path.join(modelDir, `${className}PO.cj`),
      content
    );
  }

  private generateModelFields(): string {
    return this.fields.map(f => {
      const cangjieType = mapPrismaToCangjie(f.type);
      const fullType = f.isNullable ? `?${cangjieType}` : cangjieType;
      const defaultVal = f.isNullable ? `None<${cangjieType}>` : f.defaultValue;
      
      let annotation = '';
      if (f.isPrimaryKey) {
        annotation = `    @ORMField[true]\n`;
      } else if (f.name !== toCamelCase(f.name)) {
        annotation = `    @ORMField[false "${f.name}"]\n`;
      }
      
      return `${annotation}    public var ${toCamelCase(f.name)}: ${fullType} = ${defaultVal}`;
    }).join('\n');
  }

  private generateToJsonBody(): string {
    const lines: string[] = ['        let sb = StringBuilder()', '        sb.append("{")'];
    
    let first = true;
    for (const f of this.fields) {
      const fieldName = toCamelCase(f.name);
      const jsonKey = f.name;
      
      if (first) {
        if (f.isNullable) {
          lines.push(`        if (let Some(v) <- ${fieldName}) {`);
          lines.push(`            sb.append("\\"${jsonKey}\\":\\"" + v.toString() + "\\"")`);
          lines.push('        } else {');
          lines.push(`            sb.append("\\"${jsonKey}\\":\\"\\"")`);
          lines.push('        }');
        } else {
          lines.push(`        sb.append("\\"${jsonKey}\\":\\"" + ${fieldName}.toString() + "\\"")`);
        }
        first = false;
      } else {
        if (f.isNullable) {
          lines.push(`        if (let Some(v) <- ${fieldName}) {`);
          lines.push(`            sb.append(",\\"${jsonKey}\\":\\"" + v.toString() + "\\"")`);
          lines.push('        }');
        } else {
          lines.push(`        sb.append(",\\"${jsonKey}\\":\\"" + ${fieldName}.toString() + "\\"")`);
        }
      }
    }
    
    lines.push('        sb.append("}")');
    lines.push('        return sb.toString()');
    
    return lines.join('\n');
  }

  private async generateDAO(): Promise<void> {
    const className = this.toPascalCase(this.options.table);
    const insertFields = this.generateInsertFields();
    const updateFields = this.generateUpdateFields();
    
    const content = `/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.dao.${this.options.database}

import std.collection.*
import std.time.DateTime
import f_orm.*
import f_orm.macros.*
import f_orm.sql.{Pagination, SqlPartial}
import magic.app.models.${this.options.database}.${className}PO
import magic.log.LogUtils

/**
 * ${className}DAO - ${this.options.table}数据访问接口
 * 
 * 提供标准CRUD操作，遵循UCTOO V4 ORM规范
 * 
 * 设计原则：
 * 1. DAO层只负责数据访问，不包含业务逻辑
 * 2. 所有查询方法不过滤软删除数据，返回完整数据集
 * 3. 软删除数据的显示/过滤由Service层或API使用方根据业务需求决定
 * 4. 使用 setSql 方法构建查询，避免 FROM().WHERE().first() 的问题
 */
@DAO
public interface ${className}DAO {
    prop executor: SqlExecutor
    
    //#region AutoCreateCode
    
    // ==================== 插入操作 ====================
    
    /**
     * 插入记录（id由数据库自动生成UUID）
     * @param entity 实体对象
     * @return 插入成功返回生成的ID，失败返回空字符串
     */
    func insert${className}(entity: ${className}PO): String {
        executor.setSql('''
            insert into ${this.options.table}(
${insertFields}
            ) values(
                ${this.fields.filter(f => f.name !== 'id').map(f => `\${arg(entity.${toCamelCase(f.name)})}`).join(',\n                ')}
            )
            returning id
        ''').singleFirst<String>() ?? ""
    }
    
    // ==================== 单条查询 ====================
    
    /**
     * 根据ID查询（不过滤软删除）
     * @param id 记录ID
     * @return 实体对象（Option类型）
     */
    func findById(id: String): Option<${className}PO> {
        executor.setSql('''
            select * from ${this.options.table} where id = \${arg(id)}
        ''').first<${className}PO>()
    }
    
    // ==================== 列表查询 ====================
    
    /**
     * 分页查询所有记录
     * @param page 页码（从1开始）
     * @param size 每页大小
     * @return 分页结果
     */
    func findAllPage(page: Int64, size: Int64): Pagination<${className}PO> {
        executor.page<${className}PO>('''
            select * from ${this.options.table} order by created_at desc
        ''', size, page: page)
    }
    
    /**
     * 查询所有记录（不分页）
     * @return 实体列表
     */
    func listAll(): ArrayList<${className}PO> {
        executor.setSql('''
            select * from ${this.options.table} order by created_at desc
        ''').list<${className}PO>()
    }
    
    // ==================== 更新操作 ====================
    
    /**
     * 更新记录
     * @param entity 实体对象
     * @return 影响行数
     */
    func update${className}(entity: ${className}PO): Int64 {
        executor.setSql('''
            update ${this.options.table} set
${updateFields}
            where id = \${arg(entity.id)}
        ''').update
    }
    
    // ==================== 删除操作 ====================
    
    /**
     * 软删除
     * @param id 记录ID
     * @return 影响行数
     */
    func softDeleteById(id: String): Int64 {
        executor.setSql('''
            update ${this.options.table} set deleted_at = \${arg(DateTime.now())} where id = \${arg(id)}
        ''').update
    }
    
    /**
     * 恢复软删除的记录
     * @param id 记录ID
     * @return 影响行数
     */
    func restoreById(id: String): Int64 {
        executor.setSql('''
            update ${this.options.table} set deleted_at = null where id = \${arg(id)}
        ''').update
    }
    
    /**
     * 硬删除
     * @param id 记录ID
     * @return 影响行数
     */
    func deleteById(id: String): Int64 {
        executor.setSql('''
            delete from ${this.options.table} where id = \${arg(id)}
        ''').delete
    }
    
    // ==================== 统计操作 ====================
    
    /**
     * 统计总数
     * @return 数量
     */
    func countAll(): Int64 {
        executor.setSql('''
            select count(*) from ${this.options.table}
        ''').first<Int64>() ?? 0
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
`;

    const daoDir = path.join(this.options.output, 'dao', this.options.database);
    await fs.promises.mkdir(daoDir, { recursive: true });
    await fs.promises.writeFile(
      path.join(daoDir, `${className}DAO.cj`),
      content
    );
  }

  private generateInsertFields(): string {
    const fields = this.fields.filter(f => f.name !== 'id');
    return fields.map(f => `                ${f.name}`).join(',\n');
  }

  private generateUpdateFields(): string {
    const fields = this.fields.filter(f => 
      f.name !== 'id' && 
      f.name !== 'created_at' && 
      f.name !== 'creator'
    );
    return fields.map(f => {
      const fieldName = toCamelCase(f.name);
      return `                ${f.name} = \${arg(entity.${fieldName})}`;
    }).join(',\n');
  }

  private generateMapToEntityBody(): string {
    const lines: string[] = [];
    
    for (const f of this.fields) {
      const fieldName = toCamelCase(f.name);
      const cangjieType = mapPrismaToCangjie(f.type);
      
      // Skip id field (usually auto-generated)
      if (f.name === 'id') {
        lines.push(`        if (let Some(${fieldName}) <- map.get("${fieldName}")) {`);
        lines.push(`            let ${fieldName}Str = ${fieldName} as String`);
        lines.push(`            if (let Some(s) <- ${fieldName}Str) { entity.${fieldName} = s }`);
        lines.push('        }');
        continue;
      }
      
      // Skip auto-managed fields
      if (f.name === 'created_at' || f.name === 'updated_at') {
        continue;
      }
      
      if (f.isNullable) {
        lines.push(`        if (let Some(${fieldName}) <- map.get("${fieldName}")) {`);
        if (f.name === 'deleted_at') {
          lines.push(`            let ${fieldName}Str = ${fieldName} as String`);
          lines.push(`            if (let Some(s) <- ${fieldName}Str) { entity.${fieldName} = Some<String>(s) }`);
        } else if (cangjieType === 'String') {
          lines.push(`            let ${fieldName}Str = ${fieldName} as String`);
          lines.push(`            if (let Some(s) <- ${fieldName}Str) { entity.${fieldName} = Some<String>(s) }`);
        } else if (cangjieType === 'Int32') {
          lines.push(`            let ${fieldName}Int = ${fieldName} as Int32`);
          lines.push(`            if (let Some(v) <- ${fieldName}Int) { entity.${fieldName} = Some<Int32>(v) }`);
        } else if (cangjieType === 'Float64') {
          lines.push(`            let ${fieldName}Float = ${fieldName} as Float64`);
          lines.push(`            if (let Some(v) <- ${fieldName}Float) { entity.${fieldName} = Some<Float64>(v) }`);
        }
        lines.push('        }');
      } else {
        lines.push(`        if (let Some(${fieldName}) <- map.get("${fieldName}")) {`);
        if (cangjieType === 'String') {
          lines.push(`            let ${fieldName}Str = ${fieldName} as String`);
          lines.push(`            if (let Some(s) <- ${fieldName}Str) { entity.${fieldName} = s }`);
        } else if (cangjieType === 'Int32') {
          lines.push(`            let ${fieldName}Int = ${fieldName} as Int32`);
          lines.push(`            if (let Some(v) <- ${fieldName}Int) { entity.${fieldName} = v }`);
        } else if (cangjieType === 'Float64') {
          lines.push(`            let ${fieldName}Float = ${fieldName} as Float64`);
          lines.push(`            if (let Some(v) <- ${fieldName}Float) { entity.${fieldName} = v }`);
        } else if (cangjieType === 'Bool') {
          lines.push(`            let ${fieldName}Bool = ${fieldName} as Bool`);
          lines.push(`            if (let Some(v) <- ${fieldName}Bool) { entity.${fieldName} = v }`);
        }
        lines.push('        }');
      }
    }
    
    return lines.join('\n');
  }

  private async generateService(): Promise<void> {
    const className = this.toPascalCase(this.options.table);
    
    const content = `/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.${this.options.database}

import std.collection.*
import std.time.DateTime
import f_orm.*
import magic.app.models.${this.options.database}.${className}PO
import magic.app.dao.${this.options.database}.${className}DAO
import magic.app.core.response.APIResult
import magic.log.LogUtils

/**
 * ${className}Service - ${this.options.table}服务类
 * 
 * 提供业务逻辑处理，使用DAO层进行数据访问
 */
public class ${className}Service {
    private var executor: ?SqlExecutor = None<SqlExecutor>
    
    private func getExecutor(): SqlExecutor {
        if (let Some(exe) <- executor) {
            return exe
        }
        let exe = ORM.executor()
        executor = Some<SqlExecutor>(exe)
        return exe
    }
    
    public init() {}
    
    //#region AutoCreateCode
    
    /**
     * 创建记录
     */
    public func create(entity: ${className}PO): APIResult<${className}PO> {
        try {
            entity.createdAt = DateTime.now()
            entity.updatedAt = DateTime.now()
            
            let id = getExecutor().insert${className}(entity)
            
            if (!id.isEmpty()) {
                entity.id = id
                return APIResult<${className}PO>(entity)
            } else {
                return APIResult<${className}PO>(false, "数据库操作失败")
            }
        } catch (e: Exception) {
            return APIResult<${className}PO>(false, e.message)
        }
    }
    
    /**
     * 更新记录
     */
    public func update(entityId: String, entity: ${className}PO): APIResult<${className}PO> {
        try {
            let existing = getExecutor().findById(entityId)
            
            if (existing.isNone()) {
                return APIResult<${className}PO>(false, "记录不存在")
            }
            
            entity.updatedAt = DateTime.now()
            entity.id = entityId
            
            let rows = getExecutor().update${className}(entity)
            
            if (rows > 0) {
                return APIResult<${className}PO>(entity)
            } else {
                return APIResult<${className}PO>(false, "更新失败")
            }
        } catch (e: Exception) {
            return APIResult<${className}PO>(false, e.message)
        }
    }
    
    /**
     * 删除记录
     * @param force true: 硬删除，false: 软删除
     */
    public func delete(entityId: String, force: Bool): APIResult<Bool> {
        try {
            let existing = getExecutor().findById(entityId)
            
            if (existing.isNone()) {
                return APIResult<Bool>(false, "记录不存在")
            }
            
            let rows: Int64
            if (force) {
                rows = getExecutor().deleteById(entityId)
            } else {
                rows = getExecutor().softDeleteById(entityId)
            }
            
            if (rows > 0) {
                return APIResult<Bool>(true)
            } else {
                return APIResult<Bool>(false, "删除失败")
            }
        } catch (e: Exception) {
            return APIResult<Bool>(false, e.message)
        }
    }
    
    /**
     * 恢复软删除的记录
     */
    public func restore(entityId: String): APIResult<${className}PO> {
        try {
            let rows = getExecutor().restoreById(entityId)
            
            if (rows > 0) {
                let result = getExecutor().findById(entityId)
                if (let Some(entity) <- result) {
                    return APIResult<${className}PO>(entity)
                } else {
                    return APIResult<${className}PO>(false, "恢复后查询失败")
                }
            } else {
                return APIResult<${className}PO>(false, "恢复失败")
            }
        } catch (e: Exception) {
            return APIResult<${className}PO>(false, e.message)
        }
    }
    
    /**
     * 根据ID获取记录
     */
    public func getById(entityId: String): APIResult<${className}PO> {
        try {
            let result = getExecutor().findById(entityId)
            
            if (let Some(entity) <- result) {
                return APIResult<${className}PO>(entity)
            } else {
                return APIResult<${className}PO>(false, "未找到该记录")
            }
        } catch (e: Exception) {
            return APIResult<${className}PO>(false, e.message)
        }
    }
    
    /**
     * 获取列表（分页）
     */
    public func getList(page: Int32, pageSize: Int32): (ArrayList<${className}PO>, Int64) {
        let pagination = getExecutor().findAllPage(
            Int64(page + 1),
            Int64(pageSize)
        )
        
        return (pagination.list, pagination.rows)
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
`;

    const serviceDir = path.join(this.options.output, 'services', this.options.database);
    await fs.promises.mkdir(serviceDir, { recursive: true });
    await fs.promises.writeFile(
      path.join(serviceDir, `${className}Service.cj`),
      content
    );
  }

  private async generateController(): Promise<void> {
    const className = this.toPascalCase(this.options.table);
    
    const content = `/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.controllers.${this.options.database}.${this.options.table}

import magic.app.core.http.{HttpRequest, HttpResponse}
import magic.app.core.response.{APIError, APIResult}
import magic.app.models.${this.options.database}.${className}PO
import magic.app.services.${this.options.database}.${className}Service
import magic.log.LogUtils
import std.collection.{HashMap, Map, ArrayList}
import stdx.encoding.json.{JsonValue, JsonObject, JsonString, JsonInt, JsonFloat, JsonBool, JsonArray}

public class ${className}Controller {
    private var service: ${className}Service
    
    public init(service: ${className}Service) {
        this.service = service
    }
    
    //#region AutoCreateCode
    
    public func add(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let entity = mapToEntity(b)
                let result = service.create(entity)
                if (result.success) {
                    if (let Some(data) <- result.data) {
                        res.status(200).json(data.toJson())
                    } else {
                        res.status(500).json("{\\"errno\\":\\"50001\\",\\"errmsg\\":\\"创建失败\\"}")
                    }
                } else {
                    let reason = result.reason ?? "创建失败"
                    res.status(500).json("{\\"errno\\":\\"50001\\",\\"errmsg\\":\\"\${reason}\\"}")
                }
            } else {
                res.status(400).json("{\\"errno\\":\\"40001\\",\\"errmsg\\":\\"提交数据格式错误\\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\\"errno\\":\\"50000\\",\\"errmsg\\":\\"\${e.message}\\"}")
        }
    }
    
    public func edit(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let id = b.get("id")
                
                // 检查是否是恢复软删除数据 (deleted_at === "0")
                let deletedAt = b.get("deleted_at")
                let isRestore = if (let Some(da) <- deletedAt) {
                    let daStr = da as String
                    if (let Some(s) <- daStr) {
                        s == "0"
                    } else {
                        false
                    }
                } else {
                    false
                }
                
                if (let Some(idVal) <- id) {
                    let idStrOpt = idVal as String
                    if (let Some(idStr) <- idStrOpt) {
                        if (isRestore) {
                            let result = service.restore(idStr)
                            if (result.success) {
                                if (let Some(data) <- result.data) {
                                    res.status(200).json(data.toJson())
                                } else {
                                    res.status(500).json("{\\"errno\\":\\"50001\\",\\"errmsg\\":\\"恢复失败\\"}")
                                }
                            } else {
                                let reason = result.reason ?? "恢复失败"
                                res.status(500).json("{\\"errno\\":\\"50001\\",\\"errmsg\\":\\"\${reason}\\"}")
                            }
                        } else {
                            let entity = mapToEntity(b)
                            let result = service.update(idStr, entity)
                            if (result.success) {
                                if (let Some(data) <- result.data) {
                                    res.status(200).json(data.toJson())
                                } else {
                                    res.status(500).json("{\\"errno\\":\\"50001\\",\\"errmsg\\":\\"更新失败\\"}")
                                }
                            } else {
                                let reason = result.reason ?? "更新失败"
                                res.status(500).json("{\\"errno\\":\\"50001\\",\\"errmsg\\":\\"\${reason}\\"}")
                            }
                        }
                    } else {
                        res.status(400).json("{\\"errno\\":\\"40002\\",\\"errmsg\\":\\"ID参数格式错误\\"}")
                    }
                } else {
                    res.status(400).json("{\\"errno\\":\\"40002\\",\\"errmsg\\":\\"缺少ID参数\\"}")
                }
            } else {
                res.status(400).json("{\\"errno\\":\\"40001\\",\\"errmsg\\":\\"提交数据格式错误\\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\\"errno\\":\\"50000\\",\\"errmsg\\":\\"\${e.message}\\"}")
        }
    }
    
    public func delete(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let body = parseBody(req)
            if (let Some(b) <- body) {
                let id = b.get("id")
                let forceOpt = b.get("force")
                let force = parseForce(forceOpt)
                
                if (let Some(idVal) <- id) {
                    let idStrOpt = idVal as String
                    if (let Some(idStr) <- idStrOpt) {
                        let result = service.delete(idStr, force)
                        if (result.success) {
                            res.status(200).json("{\\"desc\\":\\"删除成功\\"}")
                        } else {
                            let reason = result.reason ?? "删除失败"
                            res.status(500).json("{\\"errno\\":\\"50001\\",\\"errmsg\\":\\"\${reason}\\"}")
                        }
                    } else {
                        res.status(400).json("{\\"errno\\":\\"40002\\",\\"errmsg\\":\\"ID参数格式错误\\"}")
                    }
                } else {
                    res.status(400).json("{\\"errno\\":\\"40002\\",\\"errmsg\\":\\"缺少ID参数\\"}")
                }
            } else {
                res.status(400).json("{\\"errno\\":\\"40001\\",\\"errmsg\\":\\"提交数据格式错误\\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\\"errno\\":\\"50000\\",\\"errmsg\\":\\"\${e.message}\\"}")
        }
    }
    
    public func getSingle(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let id = req.pathParam("id")
            
            if (let Some(idVal) <- id) {
                let result = service.getById(idVal)
                
                if (result.success) {
                    if (let Some(data) <- result.data) {
                        res.status(200).json(data.toJson())
                    } else {
                        res.status(404).json("{\\"errno\\":\\"40401\\",\\"errmsg\\":\\"未找到该记录\\"}")
                    }
                } else {
                    res.status(404).json("{\\"errno\\":\\"40401\\",\\"errmsg\\":\\"未找到该记录\\"}")
                }
            } else {
                res.status(400).json("{\\"errno\\":\\"40002\\",\\"errmsg\\":\\"缺少ID参数\\"}")
            }
        } catch (e: Exception) {
            res.status(500).json("{\\"errno\\":\\"50000\\",\\"errmsg\\":\\"\${e.message}\\"}")
        }
    }
    
    public func getManyWithPathParams(req: HttpRequest, res: HttpResponse): Unit {
        try {
            let limitParam = req.pathParam("limit")
            let pageParam = req.pathParam("page")
            
            let limitNum = if (let Some(l) <- limitParam) {
                Int32.parse(l)
            } else {
                Int32(10)
            }
            
            let pageNum = if (let Some(p) <- pageParam) {
                Int32.parse(p)
            } else {
                Int32(1)
            }
            
            if (limitNum > 100) {
                res.status(400).json("{\\"errno\\":\\"40004\\",\\"errmsg\\":\\"请求数量不能超过100条\\"}")
                return
            }
            
            let (entities, total) = service.getList(pageNum - 1, limitNum)
            
            let totalPage = if (limitNum > 0) {
                Int32((total + Int64(limitNum) - 1) / Int64(limitNum))
            } else {
                Int32(0)
            }
            
            var entitiesJson = ""
            for (e in entities) {
                if (entitiesJson.isEmpty()) {
                    entitiesJson = e.toJson()
                } else {
                    entitiesJson = entitiesJson + "," + e.toJson()
                }
            }
            res.status(200).json("{\\"currentPage\\":\${pageNum},\\"totalCount\\":\${total},\\"totalPage\\":\${totalPage},\\"${this.options.table}s\\":[\${entitiesJson}]}")
        } catch (e: Exception) {
            res.status(500).json("{\\"errno\\":\\"50000\\",\\"errmsg\\":\\"\${e.message}\\"}")
        }
    }
    
    private func parseBody(req: HttpRequest): ?Map<String, Any> {
        try {
            let body = req.body

            if (body.isEmpty()) {
                return None<Map<String, Any>>
            }

            let jsonValue = JsonValue.fromStr(body)
            if (!(jsonValue is JsonObject)) {
                return None<Map<String, Any>>
            }

            let jsonObj = jsonValue.asObject()
            let map = HashMap<String, Any>()

            for ((key, value) in jsonObj.getFields()) {
                let anyValue = jsonValueToAny(value)
                map.add(key, anyValue)
            }

            return Some<Map<String, Any>>(map)
        } catch (e: Exception) {
            return None<Map<String, Any>>
        }
    }

    private func jsonValueToAny(value: JsonValue): Any {
        if (value is JsonString) {
            return value.asString().getValue()
        } else if (value is JsonInt) {
            return value.asInt().getValue()
        } else if (value is JsonFloat) {
            return value.asFloat().getValue()
        } else if (value is JsonBool) {
            return value.asBool().getValue()
        } else {
            return ""
        }
    }
    
    private func mapToEntity(map: Map<String, Any>): ${className}PO {
        let entity = ${className}PO()
${this.generateMapToEntityBody()}
        return entity
    }
    
    private func parseForce(forceOpt: ?Any): Bool {
        if (let Some(f) <- forceOpt) {
            let fInt64 = f as Int64
            if (let Some(v) <- fInt64) {
                v == 1
            } else {
                let fInt32 = f as Int32
                if (let Some(v) <- fInt32) {
                    v == 1
                } else {
                    let fStr = f as String
                    if (let Some(s) <- fStr) {
                        s == "true" || s == "1"
                    } else {
                        false
                    }
                }
            }
        } else {
            false
        }
    }
    
    //#endregion AutoCreateCode
    
    // ========== 定制开发方法（在此区域添加自定义方法）==========
}
`;

    const controllerDir = path.join(
      this.options.output,
      'controllers',
      this.options.database,
      this.options.table
    );
    await fs.promises.mkdir(controllerDir, { recursive: true });
    await fs.promises.writeFile(
      path.join(controllerDir, `${className}Controller.cj`),
      content
    );
  }

  private async generateRoute(): Promise<void> {
    const className = this.toPascalCase(this.options.table);
    
    const content = `/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.routes.${this.options.database}.${this.options.table}

import magic.app.core.router.Router
import magic.app.controllers.${this.options.database}.${this.options.table}.${className}Controller
import magic.app.services.${this.options.database}.${className}Service

public class ${className}Route {
    public static func register(router: Router): Unit {
        let service = ${className}Service()
        let controller = ${className}Controller(service)
        
        //#region AutoCreateCode
        
        // POST /api/v1/${this.options.database}/${this.options.table}/add - 新增
        router.post("/api/v1/${this.options.database}/${this.options.table}/add", controller.add)
        
        // POST /api/v1/${this.options.database}/${this.options.table}/edit - 编辑
        router.post("/api/v1/${this.options.database}/${this.options.table}/edit", controller.edit)
        
        // POST /api/v1/${this.options.database}/${this.options.table}/del - 删除
        router.post("/api/v1/${this.options.database}/${this.options.table}/del", controller.delete)
        
        // GET /api/v1/${this.options.database}/${this.options.table}/:id - 查询单条
        router.get("/api/v1/${this.options.database}/${this.options.table}/:id", controller.getSingle)
        
        // GET /api/v1/${this.options.database}/${this.options.table}/:limit/:page - 分页查询
        router.get("/api/v1/${this.options.database}/${this.options.table}/:limit/:page", controller.getManyWithPathParams)
        
        //#endregion AutoCreateCode
        
        // ========== 定制开发方法（在此区域添加自定义路由）==========
    }
}
`;

    const routeDir = path.join(
      this.options.output,
      'routes',
      this.options.database,
      this.options.table
    );
    await fs.promises.mkdir(routeDir, { recursive: true });
    await fs.promises.writeFile(
      path.join(routeDir, `${className}Route.cj`),
      content
    );
  }

  private toPascalCase(str: string): string {
    return toPascalCase(str);
  }
}

// CLI入口
const args = process.argv.slice(2);

// 尝试解析Prisma schema
const schemaPath = path.join(process.cwd(), 'apps', 'backend', 'prisma', 'uctoo', 'schema.prisma');
let fields: Field[] = [];

try {
  fields = parsePrismaSchema(schemaPath, args[0] || 'entity');
  console.log(`📋 Parsed ${fields.length} fields from Prisma schema`);
} catch (e) {
  console.log(`📋 Using default fields (schema not found)`);
  fields = getDefaultFields();
}

const options: GeneratorOptions = {
  table: args[0] || 'entity',
  database: args[1] || 'uctoo',
  requireAuth: args[2] !== 'false',
  enableCache: args[3] === 'true',
  output: args[4] || './src/app',
};

const generator = new CRUDGenerator(options, fields);
generator.generate().catch(console.error);
