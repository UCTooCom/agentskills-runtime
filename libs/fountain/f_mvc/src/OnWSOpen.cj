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
package f_mvc

/**
 * 如果需要主动向客户端写应为被@OnWSOpen注解的函数声明WebSocket参数并设法保持此WebSocket实例。
 * WSMeta提供了几个静态写函数用于辅助向客户端写。
 */
@Annotation[target:[MemberFunction]]
public class  OnWSOpen {
    public const init(){}
}