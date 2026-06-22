/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.webmcp

import std.collection.{ArrayList, HashMap}
import magic.app.services.uctoo.PermissionsService
import magic.app.models.uctoo.PermissionsPO
import magic.log.LogUtils

/**
 * 菜单项
 *
 * 表示菜单树中的一个节点，由 PermissionsPO 转换而来。
 */
public class MenuItem {
    /// 页面路由路径
    public let path: String

    /// 页面标题
    public let title: String

    /// 图标
    public let icon: String

    /// 父菜单 ID
    public let parentId: ?String

    /// 子菜单
    public var children: ArrayList<MenuItem>

    public init(path: String, title: String, icon: String, parentId: ?String) {
        this.path = path
        this.title = title
        this.icon = icon
        this.parentId = parentId
        this.children = ArrayList<MenuItem>()
    }
}

/**
 * 菜单数据提供者
 *
 * 复用已有的 PermissionsService.getUserMenuTree(userId) 方法查询菜单数据
 * （该方法已实现完整的"用户角色 → 权限名称 → 菜单权限"查询链路，含菜单通配符 menu:* 处理，
 * 返回扁平的 ArrayList<PermissionsPO>）。
 *
 * MenuDataProvider 将 PermissionsPO 转换为 MenuItem 并根据 parentId 构建树形结构，
 * 供 system prompt 注入和 web_navigate 工具描述使用。
 *
 * 包路径：magic.app.services.webmcp（服务层，可 import magic.app.services.uctoo）
 */
public class MenuDataProvider {
    /// 复用 PermissionsService 查询菜单数据
    private let _permissionsService = PermissionsService()

    public init() {}

    /**
     * 查询指定用户有权限访问的菜单列表（树形结构）
     *
     * 复用 _permissionsService.getUserMenuTree(userId) 获取 ArrayList<PermissionsPO>，
     * 将 PermissionsPO 转换为 MenuItem（path 来自 PermissionsPO.path，title 来自 PermissionsPO.title，
     * icon 来自 PermissionsPO.icon，parentId 来自 PermissionsPO.parentId），
     * 根据 parentId 构建树形结构返回。
     *
     * @param userId 用户 ID
     * @return 菜单树（顶层节点列表）
     */
    public func getUserMenuTree(userId: String): ArrayList<MenuItem> {
        if (userId.isEmpty()) {
            LogUtils.warn("[MenuDataProvider] userId is empty, returning empty menu tree")
            return ArrayList<MenuItem>()
        }

        // 复用 PermissionsService.getUserMenuTree 查询（返回扁平的 ArrayList<PermissionsPO>）
        let permissions = _permissionsService.getUserMenuTree(userId)
        LogUtils.info("[MenuDataProvider] Got ${permissions.size.toString()} permissions for userId=${userId}")

        if (permissions.size == 0) {
            return ArrayList<MenuItem>()
        }

        // 1. 将 PermissionsPO 转换为 MenuItem，建立 id → MenuItem 映射
        let idToItem = HashMap<String, MenuItem>()
        let allItems = ArrayList<MenuItem>()
        for (perm in permissions) {
            let path = _optionToString(perm.path)
            let title = _optionToString(perm.title)
            let icon = _optionToString(perm.icon)
            let menuItem = MenuItem(path, title, icon, perm.parentId)
            idToItem.add(perm.id, menuItem)
            allItems.add(menuItem)
        }

        // 2. 根据 parentId 构建树形结构
        let rootItems = ArrayList<MenuItem>()
        for (item in allItems) {
            if (item.parentId.isSome()) {
                let parentId = item.parentId.getOrThrow()
                if (idToItem.contains(parentId)) {
                    // 有父节点，添加到父节点的 children
                    let parent = idToItem.get(parentId).getOrThrow()
                    parent.children.add(item)
                } else {
                    // 父节点不在当前列表中，作为顶层节点
                    rootItems.add(item)
                }
            } else {
                // 无父节点，作为顶层节点
                rootItems.add(item)
            }
        }

        LogUtils.info("[MenuDataProvider] Built menu tree with ${rootItems.size.toString()} root items for userId=${userId}")
        return rootItems
    }

    /**
     * 将菜单树扁平化为路由路径列表
     *
     * 递归遍历菜单树，只包含 path 非空的项。
     *
     * @param menuTree 菜单树
     * @return 扁平化的菜单项列表（只包含 path 非空的项）
     */
    public func flattenMenuPaths(menuTree: ArrayList<MenuItem>): ArrayList<MenuItem> {
        let result = ArrayList<MenuItem>()
        _flattenRecursive(menuTree, result)
        return result
    }

    /// 递归扁平化辅助方法
    private func _flattenRecursive(items: ArrayList<MenuItem>, result: ArrayList<MenuItem>): Unit {
        for (item in items) {
            if (!item.path.isEmpty()) {
                result.add(item)
            }
            if (item.children.size > 0) {
                _flattenRecursive(item.children, result)
            }
        }
    }

    /// 将 Option<String> 转换为 String（None 返回空字符串）
    private func _optionToString(opt: ?String): String {
        if (opt.isSome()) {
            return opt.getOrThrow()
        } else {
            return ""
        }
    }
}
