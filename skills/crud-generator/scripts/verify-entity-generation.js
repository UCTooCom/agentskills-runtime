/**
 * 测试脚本：验证crud-generator生成的entity模块与原entity模块完全一致
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Entity表的字段定义（从Prisma schema提取）
const entityFields = [
  { name: 'id', dbName: 'id', camelName: 'id', type: 'String', isPrimaryKey: true, isOptional: false },
  { name: 'link', dbName: 'link', camelName: 'link', type: 'String', isPrimaryKey: false, isOptional: false },
  { name: 'privacy_level', dbName: 'privacy_level', camelName: 'privacyLevel', type: 'Int', isPrimaryKey: false, isOptional: false },
  { name: 'stars', dbName: 'stars', camelName: 'stars', type: 'Float', isPrimaryKey: false, isOptional: false },
  { name: 'description', dbName: 'description', camelName: 'description', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'group_id', dbName: 'group_id', camelName: 'groupId', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'picture', dbName: 'picture', camelName: 'picture', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'images', dbName: 'images', camelName: 'images', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'content', dbName: 'content', camelName: 'content', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'json', dbName: 'json', camelName: 'json', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'city', dbName: 'city', camelName: 'city', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'price', dbName: 'price', camelName: 'price', type: 'Float', isPrimaryKey: false, isOptional: true },
  { name: 'birthday', dbName: 'birthday', camelName: 'birthday', type: 'DateTime', isPrimaryKey: false, isOptional: true },
  { name: 'owner', dbName: 'owner', camelName: 'owner', type: 'String', isPrimaryKey: false, isOptional: true },
  { name: 'creator', dbName: 'creator', camelName: 'creator', type: 'String', isPrimaryKey: false, isOptional: false },
  { name: 'created_at', dbName: 'created_at', camelName: 'createdAt', type: 'DateTime', isPrimaryKey: false, isOptional: false },
  { name: 'updated_at', dbName: 'updated_at', camelName: 'updatedAt', type: 'DateTime', isPrimaryKey: false, isOptional: false },
  { name: 'deleted_at', dbName: 'deleted_at', camelName: 'deletedAt', type: 'DateTime', isPrimaryKey: false, isOptional: true },
  { name: 'end_time', dbName: 'end_time', camelName: 'endTime', type: 'DateTime', isPrimaryKey: false, isOptional: true },
  { name: 'start_time', dbName: 'start_time', camelName: 'startTime', type: 'DateTime', isPrimaryKey: false, isOptional: true },
  { name: 'status', dbName: 'status', camelName: 'status', type: 'String', isPrimaryKey: false, isOptional: true }
];

// 原entity模块路径
const originalPath = 'D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime-backup\\src\\app';

// 生成的entity模块路径
const generatedPath = 'D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\src\\app';

console.log('='.repeat(80));
console.log('验证crud-generator生成的entity模块与原entity模块的一致性');
console.log('='.repeat(80));
console.log();

// 验证文件列表
const filesToVerify = [
  { name: 'Model', path: 'models\\uctoo\\EntityPO.cj' },
  { name: 'DAO', path: 'dao\\uctoo\\EntityDAO.cj' },
  { name: 'Service', path: 'services\\uctoo\\EntityService.cj' },
  { name: 'Controller', path: 'controllers\\uctoo\\entity\\EntityController.cj' },
  { name: 'Route', path: 'routes\\uctoo\\entity\\EntityRoute.cj' }
];

let allMatch = true;

filesToVerify.forEach(file => {
  const originalFile = path.join(originalPath, file.path);
  const generatedFile = path.join(generatedPath, file.path);
  
  console.log(`验证 ${file.name}: ${file.path}`);
  
  if (!fs.existsSync(originalFile)) {
    console.log(`  ❌ 原文件不存在: ${originalFile}`);
    allMatch = false;
    return;
  }
  
  if (!fs.existsSync(generatedFile)) {
    console.log(`  ❌ 生成文件不存在: ${generatedFile}`);
    allMatch = false;
    return;
  }
  
  const originalContent = fs.readFileSync(originalFile, 'utf-8');
  const generatedContent = fs.readFileSync(generatedFile, 'utf-8');
  
  // 规范化内容（移除空行差异）
  const normalizedOriginal = originalContent.replace(/\r\n/g, '\n').trim();
  const normalizedGenerated = generatedContent.replace(/\r\n/g, '\n').trim();
  
  if (normalizedOriginal === normalizedGenerated) {
    console.log(`  ✅ 完全一致`);
  } else {
    console.log(`  ❌ 存在差异`);
    
    // 显示差异统计
    const originalLines = normalizedOriginal.split('\n');
    const generatedLines = normalizedGenerated.split('\n');
    
    console.log(`     原文件行数: ${originalLines.length}`);
    console.log(`     生成文件行数: ${generatedLines.length}`);
    
    // 找出第一个差异
    for (let i = 0; i < Math.max(originalLines.length, generatedLines.length); i++) {
      if (originalLines[i] !== generatedLines[i]) {
        console.log(`     第 ${i + 1} 行开始差异:`);
        console.log(`     原文件: ${originalLines[i] || '(无)'}`);
        console.log(`     生成文件: ${generatedLines[i] || '(无)'}`);
        break;
      }
    }
    
    allMatch = false;
  }
  
  console.log();
});

console.log('='.repeat(80));
if (allMatch) {
  console.log('✅ 验证通过：所有文件完全一致！');
  console.log('crud-generator生成的代码与原entity模块完全一致，满足确定性代码生成要求。');
} else {
  console.log('❌ 验证失败：存在差异！');
  console.log('需要进一步调整模板或生成逻辑，确保生成的代码与原entity模块完全一致。');
}
console.log('='.repeat(80));
