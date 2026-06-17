/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.app.services.uctoo

import magic.tool.PermissionProvider
import std.collection.ArrayList

public class UctooPermissionProvider <: PermissionProvider {
    private let userHasRolesService: UserHasRolesService
    private let roleHasPermissionService: RoleHasPermissionService

    public init(
        userHasRolesService: UserHasRolesService,
        roleHasPermissionService: RoleHasPermissionService
    ) {
        this.userHasRolesService = userHasRolesService
        this.roleHasPermissionService = roleHasPermissionService
    }

    public func findRoleIdsByUserId(userId: String): ArrayList<String> {
        let userRoles = userHasRolesService.findByUserId(userId)
        let roleIds = ArrayList<String>()
        for (ur in userRoles) {
            roleIds.add(ur.roleId)
        }
        roleIds
    }

    public func findPermissionNamesByRoleIds(roleIds: ArrayList<String>): ArrayList<String> {
        let permissions = roleHasPermissionService.findByRoleIds(roleIds)
        let names = ArrayList<String>()
        for (p in permissions) {
            names.add(p.permissionName)
        }
        names
    }
}