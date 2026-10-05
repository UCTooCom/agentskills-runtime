# github-password-settings.png — GitHub 密码和认证设置页

## 页面用途
GitHub 账户设置中的"密码和认证"页面，管理登录方式、密码设置及双因素认证（2FA）。

## 布局结构
经典左右侧边栏布局：左侧垂直导航菜单 + 右侧主内容区（上下两板块）。

## 主要UI元素
- **左侧导航**：Public profile、Account、Appearance、**Password and authentication**（当前选中，蓝色左边框高亮）、Sessions、SSH and GPG keys、Organizations、Repositories等
- **右侧上部"Sign in methods"**：
  - Email："1 verified email configured" + "Manage"按钮
  - Password："Not configured" + "Set password"按钮
  - Passkeys：说明文字 + "Add passkey"按钮
  - Google："1 account connected"
  - Apple："Sign in with your Apple account" + "Connect"按钮
- **右侧下部"Two-factor authentication"**：
  - "Two-factor authentication is not enabled yet."
  - "Enable two-factor authentication"绿色按钮
  - "Learn more"链接

## 颜色样式
- 背景：浅灰 #F6F8FA，白色内容卡片
- 选中项：蓝色左边框 #0969DA
- 绿色按钮：#2DA44E
