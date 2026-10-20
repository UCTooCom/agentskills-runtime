Microsoft Windows [版本 10.0.19045.6466]
(c) Microsoft Corporation。保留所有权利。

C:\Users\patrick>d:

D:\>cd D:\UCT\products\gitcode\opentiny\agent-skills

D:\UCT\products\gitcode\opentiny\agent-skills>git pull
Already up to date.

D:\UCT\products\gitcode\opentiny\agent-skills>cd D:\UCT\products\gitcode\opentiny\docs

D:\UCT\products\gitcode\opentiny\docs>git pull
Already up to date.

D:\UCT\products\gitcode\opentiny\docs>cd D:\UCT\products\gitcode\opentiny\genui-sdk

D:\UCT\products\gitcode\opentiny\genui-sdk>git pull
remote: Enumerating objects: 307, done.
remote: Counting objects: 100% (158/158), done.
remote: Compressing objects: 100% (8/8), done.
remote: Total 307 (delta 152), reused 150 (delta 150), pack-reused 149 (from 1)
Receiving objects: 100% (307/307), 141.99 KiB | 1.41 MiB/s, done.
Resolving deltas: 100% (184/184), completed with 79 local objects.
From https://atomgit.com/opentiny/genui-sdk
   1c6e368d..d1bae393  feat-angular-material -> origin/feat-angular-material
   dbb9dcf0..78de5385  feat/conversation-zip -> origin/feat/conversation-zip
   2e7d44c1..1e7a158e  feat/template-select-node-chat -> origin/feat/template-select-node-chat
 * [new branch]        hotfix-1.3.1          -> origin/hotfix-1.3.1
 * [new branch]        legacy-adapt-theme    -> origin/legacy-adapt-theme
   89befacd..7305c5a5  lhs/materials-i18n    -> origin/lhs/materials-i18n
   b71ab08f..e6b2addf  main                  -> origin/main
 * [new branch]        merge-hotflx-1.3.1    -> origin/merge-hotflx-1.3.1
 * [new branch]        render-slot-fix       -> origin/render-slot-fix
 * [new tag]           @opentiny/genui-sdk-angular@1.4.0-alpha.0 -> @opentiny/genui-sdk-angular@1.4.0-alpha.0
 * [new tag]           @opentiny/genui-sdk-core@1.4.0-alpha.1 -> @opentiny/genui-sdk-core@1.4.0-alpha.1
 * [new tag]           @opentiny/genui-sdk-materials-angular-opentiny-ng@1.4.0-alpha.1 -> @opentiny/genui-sdk-materials-angular-opentiny-ng@1.4.0-alpha.1
 * [new tag]           @opentiny/genui-sdk-materials-react-antd@1.4.0-alpha.1 -> @opentiny/genui-sdk-materials-react-antd@1.4.0-alpha.1
 * [new tag]           @opentiny/genui-sdk-react@1.4.0-alpha.1 -> @opentiny/genui-sdk-react@1.4.0-alpha.1
 * [new tag]           @opentiny/genui-sdk-vue@1.3.0-alpha.8 -> @opentiny/genui-sdk-vue@1.3.0-alpha.8
 * [new tag]           @opentiny/genui-sdk-vue@1.3.1 -> @opentiny/genui-sdk-vue@1.3.1
 * [new tag]           @opentiny/genui-sdk-vue@1.3.1-alpha.1 -> @opentiny/genui-sdk-vue@1.3.1-alpha.1
 * [new tag]           @opentiny/genui-sdk-vue@1.3.1-alpha.2 -> @opentiny/genui-sdk-vue@1.3.1-alpha.2
Already up to date.

D:\UCT\products\gitcode\opentiny\genui-sdk>cd D:\UCT\products\gitcode\opentiny\genui-sdk-demos

D:\UCT\products\gitcode\opentiny\genui-sdk-demos>git pull
Already up to date.

D:\UCT\products\gitcode\opentiny\genui-sdk-demos>cd D:\UCT\products\gitcode\opentiny\tiny-robot

D:\UCT\products\gitcode\opentiny\tiny-robot>git pull
remote: Enumerating objects: 1920, done.
remote: Counting objects: 100% (1920/1920), done.
remote: Compressing objects: 100% (1156/1156), done.
remote: Total 1775 (delta 755), reused 1524 (delta 610), pack-reused 0 (from 0)
Receiving objects: 100% (1775/1775), 25.33 MiB | 2.25 MiB/s, done.
Resolving deltas: 100% (755/755), completed with 102 local objects.
From https://gitcode.com/opentiny/tiny-robot
   1c28b533..0f75d2c9  develop    -> origin/develop
   fd71406e..02bfc3be  gh-pages   -> origin/gh-pages
Updating 1c28b533..0f75d2c9
Fast-forward
 .github/workflows/auto-publish.yml                 |   21 +-
 .github/workflows/dispatch-publish.yml             |    5 +
 docs/.vitepress/theme/style.css                    |    5 +
 docs/.vitepress/themeConfig.ts                     |    9 +
 docs/component-documentation-standard.md           | 1152 ++++++++++++++++++++
 docs/demos/bubble/list-auto-scroll.vue             |  119 +-
 docs/demos/chat/basic.vue                          |   39 +
 docs/demos/chat/business-right-aside.vue           |  140 +++
 docs/demos/chat/controlled-ui.vue                  |   52 +
 docs/demos/chat/data-driven-ui.vue                 |  214 ++++
 docs/demos/chat/floating-layout.vue                |  124 +++
 docs/demos/chat/layout-presets.vue                 |  140 +++
 docs/demos/chat/release-preview.html               |  156 +++
 docs/demos/chat/responsive-layout.vue              |  149 +++
 docs/demos/chat/right-aside-panel.vue              |  142 +++
 docs/demos/chat/runtime-adapter.vue                |  132 +++
 docs/demos/chat/runtime-error.vue                  |  119 ++
 docs/demos/chat/runtime-send.vue                   |  118 ++
 docs/demos/chat/shared/createChatRuntime.ts        |   60 +
 docs/demos/chat/shared/formatChatActionError.ts    |   55 +
 docs/demos/chat/shared/mockConversationStorage.ts  |   71 ++
 docs/demos/chat/shared/modelProviders.ts           |   51 +
 docs/env.d.ts                                      |   10 +
 docs/package.json                                  |    1 +
 docs/src/components/bubble.md                      |   67 +-
 docs/src/migration/bubble-migration.md             |    2 +-
 docs/src/suites/chat-runtime.md                    |  465 ++++++++
 docs/src/suites/chat.md                            |  572 ++++++++++
 package.json                                       |    2 +-
 packages/chat/src/Chat.vue                         |    3 -
 packages/chat/src/ChatUI.vue                       |   17 -
 packages/chat/src/composables/useChatDraft.ts      |   14 +-
 .../src/composables/useChatRuntimeAdapter.test.ts  |  162 +++
 .../chat/src/composables/useChatRuntimeAdapter.ts  |  179 ++-
 packages/chat/src/index.ts                         |   13 +
 packages/chat/src/runtime/defaults.ts              |    9 +
 .../src/runtime/mcp/createDefaultMcpAdapter.ts     |  292 +++++
 packages/chat/src/runtime/mcp/types.ts             |   13 +
 .../src/runtime/plugins/errorStatePlugin.test.ts   |  191 ++++
 .../chat/src/runtime/plugins/errorStatePlugin.ts   |   68 ++
 packages/chat/src/runtime/plugins/mcpToolPlugin.ts |  111 ++
 .../src/runtime/plugins/runConfigContextPlugin.ts  |   18 +
 packages/chat/src/runtime/provider/index.ts        |   12 +
 packages/chat/src/runtime/provider/modelRuntime.ts |  158 +++
 packages/chat/src/runtime/provider/presets.ts      |  106 ++
 .../chat/src/runtime/provider/requestPlugin.ts     |   63 ++
 .../chat/src/runtime/provider/responseProvider.ts  |   70 ++
 packages/chat/src/runtime/provider/types.ts        |   32 +
 packages/chat/src/runtime/runConfig.ts             |  178 +++
 packages/chat/src/runtime/useChatRuntime.test.ts   |   76 ++
 packages/chat/src/runtime/useChatRuntime.ts        |   92 ++
 .../src/runtime/useChatRuntimeFromConversation.ts  |  229 ++++
 packages/chat/src/types/base.ts                    |    2 +-
 packages/chat/src/types/runtime.ts                 |    2 +-
 packages/chat/src/types/ui/data.ts                 |    1 -
 packages/chat/src/types/ui/slots.ts                |    1 -
 packages/chat/src/ui/formatRequestError.ts         |   30 -
 packages/chat/src/ui/messages/ChatMessages.vue     |   16 +-
 packages/chat/src/ui/messages/ScrollToBottom.vue   |    2 +
 packages/components/src/bubble/Bubble.vue          |   10 +-
 packages/components/src/bubble/BubbleList.vue      |  105 +-
 packages/components/src/bubble/BubbleProvider.vue  |   11 +-
 .../components/src/bubble/composables/index.ts     |    1 +
 .../bubble/composables/useBubbleContentRenderer.ts |    3 +-
 .../bubble/composables/useBubbleErrorRenderer.ts   |   14 +
 .../src/bubble/composables/useMessageContent.ts    |    4 +-
 packages/components/src/bubble/constants.ts        |    4 +
 packages/components/src/bubble/index.ts            |    1 +
 packages/components/src/bubble/index.type.ts       |   18 +-
 packages/components/src/bubble/renderers/Error.vue |   37 +
 .../src/bubble/renderers/allRenderers.ts           |    2 +
 .../components/ExtensionCardActions.vue            |   78 +-
 packages/components/src/index.ts                   |   14 +
 .../components/src/mcp-extension-detail/index.ts   |   14 +
 .../src/mcp-extension-detail/index.type.ts         |   24 +
 .../components/src/mcp-extension-detail/index.vue  |  109 ++
 .../mcp-extension-form/components/CodeEditor.vue   |  116 ++
 .../mcp-extension-form/components/FormEditor.vue   |  438 ++++++++
 .../src/mcp-extension-form/components/index.ts     |    2 +
 .../src/mcp-extension-form/default-thumbnail.svg   |   14 +
 .../components/src/mcp-extension-form/index.ts     |   14 +
 .../src/mcp-extension-form/index.type.test.ts      |   43 +
 .../src/mcp-extension-form/index.type.ts           |   27 +
 .../components/src/mcp-extension-form/index.vue    |  447 ++++++++
 .../src/mcp-extension-form/internal.type.ts        |   10 +
 .../src/mcp-extension-form/validation.ts           |  157 +++
 .../components/src/mcp-extension-storage/config.ts |   59 +
 .../src/mcp-extension-storage/document.ts          |  187 ++++
 .../components/src/mcp-extension-storage/index.ts  |   14 +
 .../src/mcp-extension-storage/index.type.test.ts   |   29 +
 .../src/mcp-extension-storage/index.type.ts        |   82 ++
 .../components/src/mcp-extension-storage/memory.ts |   29 +
 .../src/mcp-extension-storage/normalize.ts         |   69 ++
 .../src/mcp-extension-storage/storage.ts           |  202 ++++
 packages/components/src/model-selector/index.vue   |    5 +-
 .../shared/components/ExtensionDetailSummary.vue   |   72 ++
 .../components/src/shared/components/Switch.vue    |  112 ++
 .../src/shared/composables/useAutoScroll.ts        |  176 ++-
 packages/kit/src/message/core/engine.ts            |   15 +-
 packages/kit/src/message/types.ts                  |    7 +-
 packages/kit/src/vue/message/types.ts              |    7 +-
 .../src/vue/message/useMessage.lifecycle.test.ts   |  110 +-
 packages/kit/src/vue/message/useMessage.ts         |    1 +
 .../test/component/bubble/AutoScroll.fixture.vue   |   85 ++
 packages/test/component/bubble/AutoScroll.spec.ts  |  110 ++
 packages/test/component/bubble/Bubble.fixture.vue  |   95 +-
 packages/test/component/bubble/Bubble.spec.ts      |   63 ++
 .../test/component/bubble/BubbleList.fixture.vue   |   38 +-
 packages/test/component/bubble/BubbleList.spec.ts  |  104 +-
 .../bubble/BubbleListAutoScrollDemo.spec.ts        |  121 ++
 .../component/bubble/BubbleProvider.fixture.vue    |   25 +
 .../test/component/bubble/BubbleProvider.spec.ts   |   27 +
 .../test/component/bubble/TestErrorRenderer.vue    |   22 +
 .../ExtensionCardActionEvent.spec.ts               |    6 +-
 .../extension-manager/ExtensionManager.spec.ts     |   12 +-
 .../McpExtensionDetail.fixture.vue                 |   31 +
 .../McpExtensionDetail.spec.ts                     |   55 +
 .../McpExtensionForm.fixture.vue                   |   62 ++
 .../mcp-extension-form/McpExtensionForm.spec.ts    |  350 ++++++
 .../McpExtensionStorage.spec.ts                    |  163 +++
 .../McpExtensionStorageDataOptions.spec.ts         |  238 ++++
 scripts/verify-publish-versions.js                 |   93 ++
 scripts/verify-publish-versions.test.js            |  142 +++
 123 files changed, 10742 insertions(+), 345 deletions(-)
 create mode 100644 docs/component-documentation-standard.md
 create mode 100644 docs/demos/chat/basic.vue
 create mode 100644 docs/demos/chat/business-right-aside.vue
 create mode 100644 docs/demos/chat/controlled-ui.vue
 create mode 100644 docs/demos/chat/data-driven-ui.vue
 create mode 100644 docs/demos/chat/floating-layout.vue
 create mode 100644 docs/demos/chat/layout-presets.vue
 create mode 100644 docs/demos/chat/release-preview.html
 create mode 100644 docs/demos/chat/responsive-layout.vue
 create mode 100644 docs/demos/chat/right-aside-panel.vue
 create mode 100644 docs/demos/chat/runtime-adapter.vue
 create mode 100644 docs/demos/chat/runtime-error.vue
 create mode 100644 docs/demos/chat/runtime-send.vue
 create mode 100644 docs/demos/chat/shared/createChatRuntime.ts
 create mode 100644 docs/demos/chat/shared/formatChatActionError.ts
 create mode 100644 docs/demos/chat/shared/mockConversationStorage.ts
 create mode 100644 docs/demos/chat/shared/modelProviders.ts
 create mode 100644 docs/src/suites/chat-runtime.md
 create mode 100644 docs/src/suites/chat.md
 create mode 100644 packages/chat/src/composables/useChatRuntimeAdapter.test.ts
 create mode 100644 packages/chat/src/runtime/defaults.ts
 create mode 100644 packages/chat/src/runtime/mcp/createDefaultMcpAdapter.ts
 create mode 100644 packages/chat/src/runtime/mcp/types.ts
 create mode 100644 packages/chat/src/runtime/plugins/errorStatePlugin.test.ts
 create mode 100644 packages/chat/src/runtime/plugins/errorStatePlugin.ts
 create mode 100644 packages/chat/src/runtime/plugins/mcpToolPlugin.ts
 create mode 100644 packages/chat/src/runtime/plugins/runConfigContextPlugin.ts
 create mode 100644 packages/chat/src/runtime/provider/index.ts
 create mode 100644 packages/chat/src/runtime/provider/modelRuntime.ts
 create mode 100644 packages/chat/src/runtime/provider/presets.ts
 create mode 100644 packages/chat/src/runtime/provider/requestPlugin.ts
 create mode 100644 packages/chat/src/runtime/provider/responseProvider.ts
 create mode 100644 packages/chat/src/runtime/provider/types.ts
 create mode 100644 packages/chat/src/runtime/runConfig.ts
 create mode 100644 packages/chat/src/runtime/useChatRuntime.test.ts
 create mode 100644 packages/chat/src/runtime/useChatRuntime.ts
 create mode 100644 packages/chat/src/runtime/useChatRuntimeFromConversation.ts
 delete mode 100644 packages/chat/src/ui/formatRequestError.ts
 create mode 100644 packages/components/src/bubble/composables/useBubbleErrorRenderer.ts
 create mode 100644 packages/components/src/bubble/renderers/Error.vue
 create mode 100644 packages/components/src/mcp-extension-detail/index.ts
 create mode 100644 packages/components/src/mcp-extension-detail/index.type.ts
 create mode 100644 packages/components/src/mcp-extension-detail/index.vue
 create mode 100644 packages/components/src/mcp-extension-form/components/CodeEditor.vue
 create mode 100644 packages/components/src/mcp-extension-form/components/FormEditor.vue
 create mode 100644 packages/components/src/mcp-extension-form/components/index.ts
 create mode 100644 packages/components/src/mcp-extension-form/default-thumbnail.svg
 create mode 100644 packages/components/src/mcp-extension-form/index.ts
 create mode 100644 packages/components/src/mcp-extension-form/index.type.test.ts
 create mode 100644 packages/components/src/mcp-extension-form/index.type.ts
 create mode 100644 packages/components/src/mcp-extension-form/index.vue
 create mode 100644 packages/components/src/mcp-extension-form/internal.type.ts
 create mode 100644 packages/components/src/mcp-extension-form/validation.ts
 create mode 100644 packages/components/src/mcp-extension-storage/config.ts
 create mode 100644 packages/components/src/mcp-extension-storage/document.ts
 create mode 100644 packages/components/src/mcp-extension-storage/index.ts
 create mode 100644 packages/components/src/mcp-extension-storage/index.type.test.ts
 create mode 100644 packages/components/src/mcp-extension-storage/index.type.ts
 create mode 100644 packages/components/src/mcp-extension-storage/memory.ts
 create mode 100644 packages/components/src/mcp-extension-storage/normalize.ts
 create mode 100644 packages/components/src/mcp-extension-storage/storage.ts
 create mode 100644 packages/components/src/shared/components/ExtensionDetailSummary.vue
 create mode 100644 packages/components/src/shared/components/Switch.vue
 create mode 100644 packages/test/component/bubble/AutoScroll.fixture.vue
 create mode 100644 packages/test/component/bubble/AutoScroll.spec.ts
 create mode 100644 packages/test/component/bubble/BubbleListAutoScrollDemo.spec.ts
 create mode 100644 packages/test/component/bubble/TestErrorRenderer.vue
 create mode 100644 packages/test/component/mcp-extension-detail/McpExtensionDetail.fixture.vue
 create mode 100644 packages/test/component/mcp-extension-detail/McpExtensionDetail.spec.ts
 create mode 100644 packages/test/component/mcp-extension-form/McpExtensionForm.fixture.vue
 create mode 100644 packages/test/component/mcp-extension-form/McpExtensionForm.spec.ts
 create mode 100644 packages/test/component/mcp-extension-storage/McpExtensionStorage.spec.ts
 create mode 100644 packages/test/component/mcp-extension-storage/McpExtensionStorageDataOptions.spec.ts
 create mode 100644 scripts/verify-publish-versions.js
 create mode 100644 scripts/verify-publish-versions.test.js

D:\UCT\products\gitcode\opentiny\tiny-robot>cd  D:\UCT\products\gitcode\opentiny\webmcp-sdk

D:\UCT\products\gitcode\opentiny\webmcp-sdk>git pull
Already up to date.

D:\UCT\products\gitcode\opentiny\webmcp-sdk>cd ..

D:\UCT\products\gitcode\opentiny>git clone https://github.com/opentiny/tiny-pro.git
Cloning into 'tiny-pro'...
remote: Enumerating objects: 6458, done.
remote: Counting objects: 100% (1668/1668), done.
remote: Compressing objects: 100% (633/633), done.
error: RPC failed; curl 92 HTTP/2 stream 5 was not closed cleanly: CANCEL (err 8)
error: 12436 bytes of body are still expected
fetch-pack: unexpected disconnect while reading sideband packet
fatal: early EOF
fatal: fetch-pack: invalid index-pack output

D:\UCT\products\gitcode\opentiny>git clone https://github.com/opentiny/tiny-pro.git
Cloning into 'tiny-pro'...
remote: Enumerating objects: 6458, done.
remote: Counting objects: 100% (1668/1668), done.
remote: Compressing objects: 100% (633/633), done.
Receiving objects: 100% (6458/6458), 16.89 MiB | 49.00 KiB/s, done.
remote: Total 6458 (delta 1294), reused 1065 (delta 1035), pack-reused 4790 (from 1)
Resolving deltas: 100% (3383/3383), done.
Updating files: 100% (743/743), done.

D:\UCT\products\gitcode\opentiny>git clone https://github.com/opentiny/tiny-vue.git
Cloning into 'tiny-vue'...
remote: Enumerating objects: 133959, done.
remote: Counting objects: 100% (527/527), done.
remote: Compressing objects: 100% (102/102), done.
error: RPC failed; curl 56 Recv failure: Connection was reset/s
error: 6212 bytes of body are still expected
fetch-pack: unexpected disconnect while reading sideband packet
fatal: early EOF
fatal: fetch-pack: invalid index-pack output

D:\UCT\products\gitcode\opentiny>git clone https://github.com/opentiny/tiny-vue.git
Cloning into 'tiny-vue'...
fatal: unable to access 'https://github.com/opentiny/tiny-vue.git/': Recv failure: Connection was reset

D:\UCT\products\gitcode\opentiny>git clone https://github.com/opentiny/tiny-vue.git
Cloning into 'tiny-vue'...
remote: Enumerating objects: 133959, done.
remote: Counting objects: 100% (527/527), done.
remote: Compressing objects: 100% (102/102), done.
Receiving objects:  12% (16423/133959), 13.26 MiB | 35.00 KiB/s