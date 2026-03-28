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
package f_bean

/**
 * bean元数据
 */
@Annotation[target: [MemberFunction, Type]]
public class BeanMeta <: Comparable<BeanMeta> {
    public const BeanMeta(
        public let name!: String = '',
        public let lazy!: Bool = true,
        public let scope!: BeanScope = BeanScope.singleton,
        public let order!: Int64 = 0,
        public let primary!: Bool = false,
        public let condition!: BeanCondition = NoneBeanCondition.instance
    ) {}
    /**
     * BeanFactory.getList<T>()按照这个顺序返回
     */
    public func compare(meta: BeanMeta): Ordering {
        if (this.primary && !meta.primary) {
            LT
        } else if (!this.primary && meta.primary) {
            GT
        } else {
            match (this.order.compare(meta.order)) {
                case EQ where !(this.name.isEmpty() || meta.name.isEmpty()) => this.name.compare(meta.name)
                case x => x
            }
        }
    }
}
