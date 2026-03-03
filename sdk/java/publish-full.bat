@echo off
REM 一键发布脚本 for agentskills-runtime Java SDK
REM 前提：已生成并上传 GPG 密钥

setlocal enabledelayedexpansion

echo ==========================================
echo 准备发布 agentskills-runtime Java SDK
 echo ==========================================

echo 1. 复制 settings.xml 到 Maven 配置目录...

REM 创建 .m2 目录（如果不存在）
if not exist "%USERPROFILE%\.m2" (
    mkdir "%USERPROFILE%\.m2"
    echo 已创建 %USERPROFILE%\.m2 目录
)

REM 复制 settings.xml
copy "settings.xml" "%USERPROFILE%\.m2\settings.xml"
if %errorlevel% equ 0 (
    echo 已复制 settings.xml 到 %USERPROFILE%\.m2\settings.xml
) else (
    echo 复制 settings.xml 失败，请手动复制
    goto :error
)

echo.
echo 2. 检查 GPG 配置...

REM 检查 GPG 是否安装
where gpg >nul 2>nul
if %errorlevel% neq 0 (
    echo 错误：GPG 未安装
    echo 请从 https://www.gnupg.org/download/ 下载并安装 GPG
    goto :error
) else (
    echo GPG 已安装
)

echo.
echo 3. 开始发布...
echo 注意：请确保已在 settings.xml 中配置 GPG 密码

echo 运行 mvn clean deploy -P release...
call mvn clean deploy -P release

if %errorlevel% equ 0 (
    echo.
    echo ==========================================
    echo ✓ 发布成功！
    echo ==========================================
    echo 请登录 https://s01.oss.sonatype.org/ 查看 Staging 仓库
    echo 验证后点击 "Close" 和 "Release"
) else (
    echo.
    echo ==========================================
    echo ✗ 发布失败
    echo ==========================================
    echo 请检查错误信息并解决问题
    goto :error
)

:success
echo.
echo 发布完成！
echo 构件将在 10-30 分钟后同步到 Maven Central

goto :end

:error
echo 发布过程中出现错误

:end
pause
