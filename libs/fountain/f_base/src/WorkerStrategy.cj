/*
Copyright (c) 2025 WuJingrun（吴京润）

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
 */
package f_base

/**
 * 工作队列满的策略
 */
public enum WorkerStrategy {
    /**
     * 抛出JobQueueFullException
     */
    | Abort
    /**
     * 丢弃当前任务
     */
    | DiscardCurrent
    /**
     * 丢弃队头的的任务
     */
    | DiscardOldest
    /**
     * 一直阻塞
     */
    | Block
    /**
     * 等待Duration，然后抛出JobQueueFullException
     */
    | AbortAfter(Duration)
    /**
     * 等待Duration，然后抛出JobQueueFullException
     */
    | DiscardCurrentAfter(Duration)
    /**
     * 等待Duration，然后抛出JobQueueFullException
     */
    | DiscardOldestDuring(Duration)
    /**
     * 当前线程执行
     */
    | CurrentThread
    /**
     * 创建新实例，如果是任务队列就创建新线程，如果是ByteBuffer就创建新的ByteBuffer
     * 创建的新实例不受原工作线程或ByteBuffer池管理，用完即弃。
     */
    | New
}
