D:\UCT\projects\miniapp\qintong\Delivery\uctoo-admin\apps\web-admin\web>npm start

> tiny-pro-vue@1.0.0 start
> vite --config ./config/vite.config.dev.ts --port 3031

🔨 检测到本地依赖需要重新构建...
⚠️ 跳过构建本地依赖 (webmcp-sdk 使用 pnpm catalog 管理依赖)
✅ 本地依赖构建已跳过!
12:09:46 [vite] (client) Re-optimizing dependencies because lockfile has changed

  VITE v6.4.3  ready in 33902 ms

  ➜  Local:   http://localhost:3031/
  ➜  Network: http://172.29.32.1:3031/
  ➜  Network: http://172.16.9.57:3031/
  ➜  UnoCSS Inspector: http:/localhost:3031/__unocss/
  ➜  press h + enter to show help
Error: The following dependencies are imported but could not be resolved:

  @wxt-dev/storage (imported by D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/web-admin/web/src/lib/webmcp-sdk/packages/next-wxt/entrypoints/options/utils/skills-storage.ts)
  jszip (imported by D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/web-admin/web/src/lib/webmcp-sdk/packages/next-wxt/entrypoints/options/SkillsTab.vue?id=0)
  puppeteer-core/lib/esm/puppeteer/puppeteer-core-browser.js (imported by D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/web-admin/web/src/lib/webmcp-sdk/packages/next-wxt/entrypoints/sidepanel/utils/snapshotManager.ts)
  @opentiny/tiny-schema-renderer (imported by D:/UCT/products/gitcode/opentiny/genui-sdk/packages/frameworks/vue/src/config-provider/ConfigProvider.vue?id=0)
  prettier/standalone (imported by D:/UCT/products/gitcode/opentiny/genui-sdk/packages/frameworks/vue/src/code-generator/vue-code-generator.ts)
  @opentiny/genui-sdk-materials-vue-opentiny-vue/materials (imported by D:/UCT/products/gitcode/opentiny/genui-sdk/packages/frameworks/vue/src/legacy-chat/GenuiChatWithMaterials.vue?id=0)
  prettier/plugins/html (imported by D:/UCT/products/gitcode/opentiny/genui-sdk/packages/frameworks/vue/src/code-generator/vue-code-generator.ts)
  @opentiny/genui-sdk-core (imported by D:/UCT/products/gitcode/opentiny/genui-sdk/packages/frameworks/vue/src/config-provider/ConfigProvider.vue?id=0)
  prettier/plugins/babel (imported by D:/UCT/products/gitcode/opentiny/genui-sdk/packages/frameworks/vue/src/code-generator/vue-code-generator.ts)
  prettier/plugins/estree (imported by D:/UCT/products/gitcode/opentiny/genui-sdk/packages/frameworks/vue/src/code-generator/vue-code-generator.ts)
  prettier/plugins/postcss (imported by D:/UCT/products/gitcode/opentiny/genui-sdk/packages/frameworks/vue/src/code-generator/vue-code-generator.ts)
  @opentiny/tiny-robot (imported by D:/UCT/products/gitcode/opentiny/genui-sdk/packages/frameworks/vue/src/chat/renderer/ReasoningRenderer.vue?id=0)
  prettier/plugins/typescript (imported by D:/UCT/products/gitcode/opentiny/genui-sdk/packages/frameworks/vue/src/code-generator/vue-code-generator.ts)
  @opentiny/tiny-robot/dist/style.css (imported by D:/UCT/products/gitcode/opentiny/genui-sdk/packages/frameworks/vue/src/chat/GenuiChat.vue?id=0)
  uuid (imported by D:/UCT/products/gitcode/opentiny/genui-sdk/packages/frameworks/vue/src/chat/response-handler.ts)
  @opentiny/tiny-robot-svgs (imported by D:/UCT/products/gitcode/opentiny/genui-sdk/packages/frameworks/vue/src/chat/renderer/ReasoningRenderer.vue?id=0)
  @vue/compiler-sfc (imported by D:/UCT/products/gitcode/opentiny/genui-sdk/packages/frameworks/vue/src/code-generator/vue-sfc-validator.ts)
  @vue/shared (imported by D:/UCT/products/gitcode/opentiny/genui-sdk/packages/frameworks/vue/src/code-generator/vue-sfc-validator.ts)

Are they installed?
    at file:///D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/web-admin/web/node_modules/vite/dist/node/chunks/dep-Dm0c1Wj2.js:14849:15
    at process.processTicksAndRejections (node:internal/process/task_queues:105:5)
    at async file:///D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/web-admin/web/node_modules/vite/dist/node/chunks/dep-Dm0c1Wj2.js:47144:28
12:11:38 [vite] (client) ✨ new dependencies optimized: mitt, ajv, zod, @opentiny/next, @modelcontextprotocol/sdk/server/mcp.js, @modelcontextprotocol/sdk/shared/uriTemplate.js, @modelcontextprotocol/sdk/server/completable.js, @modelcontextprotocol/sdk/shared/metadataUtils.js, @modelcontextprotocol/sdk/inMemory.js, @mcp-b/webmcp-polyfill, @opentiny/vue-icon, @vueuse/core, @modelcontextprotocol/sdk/types.js, @modelcontextprotocol/sdk/client/index.js, @modelcontextprotocol/sdk/client/sse.js, @modelcontextprotocol/sdk/client/streamableHttp.js, @modelcontextprotocol/sdk/client/websocket.js, ai, zod-to-json-schema, @page-agent/page-controller, qrcode, @ai-sdk/mcp, @ai-sdk/openai, @ai-sdk/deepseek, dom-accessibility-api, tabbable, diff, ai-motion, @opentiny/tiny-robot, @opentiny/tiny-robot-svgs, html5-qrcode, vant, @opentiny/vue-tooltip
12:11:38 [vite] (client) ✨ optimized dependencies changed. reloading
The file does not exist at "D:/UCT/projects/miniapp/qintong/Delivery/uctoo-admin/apps/web-admin/web/node_modules/.vite/deps/chunk-DZ5VRGCL.js?v=92e397a1" which is in the optimize deps directory. The dependency might be incompatible with the dep optimizer. Try adding it to `optimizeDeps.exclude`.