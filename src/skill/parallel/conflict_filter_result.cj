/*
 * Copyright (c) UCToo Co., Ltd. 2026. All rights reserved.
 */
package magic.skill.parallel

import std.collection.ArrayList

/**
 * 互斥过滤结果：
 * - survived：存活技能名（通过优先级/加载顺序裁决后保留）
 * - evicted：被淘汰技能名
 * - conflictPairs：检测到的互斥对（用于决策日志与调试）
 */
public class ConflictFilterResult {
    public var survived: ArrayList<String> = ArrayList<String>()
    public var evicted: ArrayList<String> = ArrayList<String>()
    public var conflictPairs: ArrayList<(String, String)> = ArrayList<(String, String)>()
}
