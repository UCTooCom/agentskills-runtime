# kaca_cookies

> **本项目 不依赖 stdx** — 所有依赖仅来自仓颉 `std` 标准库和 `kaca_*` 系列项目。

## 1. 本项目通过了哪些标准测试
- 标准：WPT Cookies 兼容测试子集
- 范围：Cookie 解析、属性处理、路径/域名匹配、前缀规则等
- 结果（通过数/总数）：24/24
- 统计日期：2026-04-26

## 2. 实现这些标准测试有什么好处
- 与浏览器 Cookie 行为对齐，减少语义偏差。
- 提升与 URL/HTTP 组件联动时的兼容性。
- 标准回归用例可持续约束行为不回退。

## 3. 本项目暴露哪些接口（含示例与说明）
- 接口：`CookieJar.setCookieString(...)`
- 参数：Cookie 文本、请求主机/路径、安全上下文等。
- 返回：`Bool`，表示是否接受该 Cookie。
- 失败行为：非法格式、前缀约束不满足、域名规则不满足时返回 `false`。

- 接口：`CookieJar.documentCookie(...)`
- 参数：请求主机、请求路径、安全上下文。
- 返回：`String`，可见 Cookie 串。
- 失败行为：无匹配 Cookie 时返回空字符串。

示例：
```cangjie
import kaca_cookies.*

main(): Int64 {
    let jar = CookieJar()
    _ = jar.setCookieString("a=1; Path=/")
    println(jar.documentCookie(requestHost: "www.example.test", requestPath: "/"))
    return 0
}
```

## 4. 通过标准测试引用了哪个项目的测试数据
- 来源项目：`web-platform-tests/wpt`
- 路径/类别：`cookies/**` 相关用例子集
- 用途：验证 Cookie 解析、存储和发送行为。

## 5. 如何引入本项目
```toml
[dependencies]
kaca_cookies = { git = "https://gitcode.com/cangjie_no_1/kaca_cookies.git", tag = "v0.8.0" }
```

```cangjie
import kaca_cookies.*
```

## 6. AI 开发声明
本项目使用 AI 辅助开发，覆盖测试迁移、行为对齐与代码整理。

## 7. 性能优先声明
本项目以性能优先作为目标，重点优化 Cookie 匹配与序列化路径。

## 8. 测试资产分离声明
本项目与测试代码、测试数据分离；测试代码统一在 `kaca_projects/tests/`，测试数据统一在 `kaca_projects/testdata/`。
