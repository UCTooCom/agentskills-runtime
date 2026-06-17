/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.tool

import std.collection.ArrayList

public interface PermissionProvider {
    func findRoleIdsByUserId(userId: String): ArrayList<String>

    func findPermissionNamesByRoleIds(roleIds: ArrayList<String>): ArrayList<String>
}