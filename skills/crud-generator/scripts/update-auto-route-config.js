/**
 * AutoRouteConfig 更新器
 * 
 * 自动更新 AutoRouteConfig.cj 文件，添加新路由的注册配置
 */

import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

/**
 * 更新 AutoRouteConfig.cj 文件
 * 
 * @param {Object} config 配置对象
 * @param {string} config.tableName 表名
 * @param {string} config.tableNameCamel 驼峰表名
 * @param {string} config.tableNamePascal 帕斯卡表名
 * @param {string} config.dbName 数据库名
 * @param {string} config.outputDir 输出目录
 * @param {number} config.priority 优先级（可选，默认自动计算）
 * @param {boolean} config.isCompositeKey 是否复合主键（可选）
 */
export function updateAutoRouteConfig(config) {
    const { tableName, tableNameCamel, tableNamePascal, dbName, outputDir, priority, isCompositeKey = false } = config
    
    // 修正路径：outputDir 是相对于 scripts 目录的，需要找到实际的 AutoRouteConfig.cj
    // AutoRouteConfig.cj 位于 agentskills-runtime/src/app/registry/AutoRouteConfig.cj
    const configPath = path.resolve(
        __dirname,
        '../../../src/app/registry/AutoRouteConfig.cj'
    )
    
    // 检查文件是否存在
    if (!fs.existsSync(configPath)) {
        console.log('⚠️  AutoRouteConfig.cj 不存在，跳过自动更新')
        console.log(`   查找路径: ${configPath}`)
        console.log('   请确保已创建 AutoRouteConfig.cj 文件')
        return
    }
    
    let content = fs.readFileSync(configPath, 'utf-8')
    
    // 检查是否已存在该路由配置
    const routeCheckPattern = new RegExp(`"${tableName}",\\s*"/api/v1/${dbName}/${tableName}"`, 'g')
    if (routeCheckPattern.test(content)) {
        console.log(`⚠️  路由配置已存在: ${tableName}，跳过添加`)
        return
    }
    
    // 计算优先级（如果未指定）
    const routePriority = priority || calculatePriority(content)
    
    // 生成新的路由配置项
    const newRouteEntry = generateRouteEntry(tableName, tableNameCamel, tableNamePascal, routePriority, isCompositeKey)
    
    // 生成新的导入语句
    const newImports = generateImports(tableName, tableNameCamel, tableNamePascal, dbName)
    
    // 更新内容
    content = addImports(content, newImports)
    content = addRouteEntry(content, newRouteEntry, tableName)
    
    // 写入文件
    fs.writeFileSync(configPath, content)
    console.log(`✅ Updated AutoRouteConfig.cj: 添加 ${tableName} 路由配置`)
}

/**
 * 计算新路由的优先级
 */
function calculatePriority(content) {
    // 查找所有现有的 priority 值
    const priorityPattern = /priority:\s*(\d+)/g
    let maxPriority = 0
    let match
    
    while ((match = priorityPattern.exec(content)) !== null) {
        const p = parseInt(match[1])
        if (p > maxPriority) {
            maxPriority = p
        }
    }
    
    // 新路由优先级 = 最大优先级 + 10
    return maxPriority + 10
}

/**
 * 生成路由配置项
 */
function generateRouteEntry(tableName, tableNameCamel, tableNamePascal, priority, isCompositeKey) {
    const comment = isCompositeKey ? ' (复合主键)' : ''
    
    return `        // ${tableNamePascal} 路由${comment}
        registry.add(RouteEntry(
            "${tableName}",
            "/api/v1/uctoo/${tableName}",
            ${priority},
            true,
            { router: Router =>
                let service = ${tableNamePascal}Service()
                let controller = ${tableNamePascal}Controller(service)
                let route = ${tableNamePascal}Route(router, controller)
                route.register()
            }
        ))`
}

/**
 * 生成导入语句
 */
function generateImports(tableName, tableNameCamel, tableNamePascal, dbName) {
    return {
        route: `import magic.app.routes.uctoo.${tableName}.${tableNamePascal}Route`,
        controller: `import magic.app.controllers.uctoo.${tableName}.${tableNamePascal}Controller`,
        service: `    ${tableNamePascal}Service`
    }
}

/**
 * 添加导入语句
 */
function addImports(content, newImports) {
    // 添加 Route 导入
    const routeImportPattern = /import magic\.app\.routes\.uctoo\.[\w.]+Route/g
    const routeImports = content.match(routeImportPattern) || []
    
    if (!routeImports.includes(newImports.route)) {
        // 找到最后一个 Route 导入的位置
        const lastRouteImport = routeImports[routeImports.length - 1]
        if (lastRouteImport) {
            content = content.replace(
                lastRouteImport,
                `${lastRouteImport}\n${newImports.route}`
            )
        } else {
            // 如果没有找到 Route 导入，在文件开头添加
            const packageEnd = content.indexOf('\n\n')
            if (packageEnd > -1) {
                content = content.slice(0, packageEnd + 2) + 
                          newImports.route + '\n' + 
                          content.slice(packageEnd + 2)
            }
        }
    }
    
    // 添加 Controller 导入
    const controllerImportPattern = /import magic\.app\.controllers\.uctoo\.[\w.]+Controller/g
    const controllerImports = content.match(controllerImportPattern) || []
    
    if (!controllerImports.includes(newImports.controller)) {
        const lastControllerImport = controllerImports[controllerImports.length - 1]
        if (lastControllerImport) {
            content = content.replace(
                lastControllerImport,
                `${lastControllerImport}\n${newImports.controller}`
            )
        }
    }
    
    // 添加 Service 导入
    const serviceImportPattern = /import magic\.app\.services\.uctoo\.\{[\s\S]*?\}/
    const serviceMatch = content.match(serviceImportPattern)
    
    if (serviceMatch) {
        const serviceBlock = serviceMatch[0]
        // 检查是否已存在
        if (!serviceBlock.includes(newImports.service)) {
            // 提取现有的 Service 列表
            const servicesMatch = serviceBlock.match(/\{([\s\S]*?)\}/)
            if (servicesMatch) {
                const servicesContent = servicesMatch[1].trim()
                // 将新的 Service 添加到列表中，保持正确的格式
                const serviceList = servicesContent.split(',').map(s => s.trim()).filter(s => s)
                serviceList.push(newImports.service)
                
                // 重新格式化，每个Service占一行，保持4空格缩进
                const formattedServices = serviceList.map(s => `    ${s}`).join(',\n')
                const updatedServiceBlock = `import magic.app.services.uctoo.{\n${formattedServices}\n}`
                
                content = content.replace(serviceImportPattern, updatedServiceBlock)
            }
        }
    }
    
    return content
}

/**
 * 添加路由配置项
 */
function addRouteEntry(content, newRouteEntry, tableName) {
    // 找到 initRegistry 方法的结束位置
    // 查找最后一个 registry.add 调用
    const lastAddPattern = /registry\.add\(RouteEntry\([\s\S]*?\)\)\s*\)/g
    const adds = content.match(lastAddPattern)
    
    if (adds && adds.length > 0) {
        const lastAdd = adds[adds.length - 1]
        // 在最后一个 add 之后添加新的配置
        content = content.replace(
            lastAdd,
            `${lastAdd}\n        \n${newRouteEntry}`
        )
    } else {
        // 如果没有找到任何 add，在方法体开头添加
        const methodBodyPattern = /public static func initRegistry\(registry: RouteRegistry\): Unit \{/
        content = content.replace(
            methodBodyPattern,
            `public static func initRegistry(registry: RouteRegistry): Unit {\n        \n${newRouteEntry}`
        )
    }
    
    return content
}

/**
 * 从 AutoRouteConfig.cj 中移除路由配置
 * 
 * @param {string} tableName 表名
 * @param {string} outputDir 输出目录
 */
export function removeRouteFromConfig(tableName, outputDir) {
    const configPath = path.join(outputDir, 'registry', 'AutoRouteConfig.cj')
    
    if (!fs.existsSync(configPath)) {
        console.log('⚠️  AutoRouteConfig.cj 不存在')
        return
    }
    
    let content = fs.readFileSync(configPath, 'utf-8')
    
    // 移除路由配置项（包括注释）
    const routePattern = new RegExp(
        `\\s*// ${tableName} 路由[^\n]*\n\\s*registry\\.add\\(RouteEntry\\([\\s\\S]*?\\)\\)`,
        'g'
    )
    content = content.replace(routePattern, '')
    
    // 写入文件
    fs.writeFileSync(configPath, content)
    console.log(`✅ Removed ${tableName} route from AutoRouteConfig.cj`)
}
