/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.model.channel

import std.collection.ArrayList

/**
 * 通道变更事件（design.md §4）。
 * - code：发生变更的通道编码（"" 表示「影响默认通道/全局」的变更，如一键设默认）。
 * - revision：变更后的行级版本；监听方当前实现忽略该值，直接 refresh 全量重读，
 *   因为通道表很小（≤数十行），全量重建成本可忽略，且避免漏掉关联变更。
 */
public struct ChannelChanged {
    public let channelCode: String
    public let revision: Int64

    public init(channelCode: String, revision: Int64) {
        this.channelCode = channelCode
        this.revision = revision
    }
}

/**
 * 进程内轻量事件总线（T011）。
 *
 * 主路径：写操作（ChannelService.setDefault / 后续 add/edit/toggle 等）→
 *   publish(ChannelChanged) → 订阅者（ChannelRegistry）即时 refresh。
 * 满足 V1（切换 ≤5s 生效，实际即时）。
 * 备用路径：多实例 / 外部直接改库场景，由 main.cj 启动 2s 轮询 refresh 兜底。
 *
 * 说明：Phase 0 单写者（setDefault/管理 API），监听器在启动期注册一次，
 * publish 偶发；用普通 ArrayList 即可，无需额外锁。
 */
public class ChannelEventBus {
    private static let INSTANCE = ChannelEventBus()
    public static func shared(): ChannelEventBus {
        INSTANCE
    }

    private var listeners: ArrayList<(ChannelChanged) -> Unit> = ArrayList<(ChannelChanged) -> Unit>()

    public func subscribe(listener: (ChannelChanged) -> Unit): Unit {
        listeners.add(listener)
    }

    public func publish(event: ChannelChanged): Unit {
        for (l in listeners) {
            l(event)
        }
    }
}
