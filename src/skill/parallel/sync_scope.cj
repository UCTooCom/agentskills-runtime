/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

/**
 * 分发作用域（TG22/T087）。
 *
 * - `AgentOwned`：归属于某个 Agent 实例，随 Agent 生命周期；
 * - `UserOwned`：归属于用户，跨 Agent 共享；
 * - `NodeLocal`：仅本节点本地，不上云、不跨端漫游（MEMORY 类默认）。
 *
 * 仓颉 enum 不原生支持 `==`/`!=`，需显式重载（参照 load_policy.cj 范式）。
 */
public enum SyncScope {
    | AgentOwned
    | UserOwned
    | NodeLocal

    public operator func ==(other: SyncScope): Bool {
        match (this) {
            case AgentOwned => match (other) {
                case AgentOwned => true
                case _ => false
            }
            case UserOwned => match (other) {
                case UserOwned => true
                case _ => false
            }
            case NodeLocal => match (other) {
                case NodeLocal => true
                case _ => false
            }
        }
    }

    public operator func !=(other: SyncScope): Bool {
        !(this == other)
    }
}

extend SyncScope <: ToString {
    public func toString(): String {
        match (this) {
            case AgentOwned => "agent_owned"
            case UserOwned => "user_owned"
            case NodeLocal => "node_local"
        }
    }
}
