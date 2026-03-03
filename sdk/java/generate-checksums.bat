@echo off
cd "%~dp0target\com\opencangjie\agentskills-runtime\0.0.1"

REM 为 JAR 文件生成校验和
for /f "tokens=2 delims= " %%a in ('certutil -hashfile agentskills-runtime-0.0.1.jar MD5 ^| findstr /v "MD5" ^| findstr /v "CertUtil"') do (echo %%a > agentskills-runtime-0.0.1.jar.md5)
for /f "tokens=2 delims= " %%a in ('certutil -hashfile agentskills-runtime-0.0.1.jar SHA1 ^| findstr /v "SHA1" ^| findstr /v "CertUtil"') do (echo %%a > agentskills-runtime-0.0.1.jar.sha1)

REM 为源码 JAR 生成校验和
for /f "tokens=2 delims= " %%a in ('certutil -hashfile agentskills-runtime-0.0.1-sources.jar MD5 ^| findstr /v "MD5" ^| findstr /v "CertUtil"') do (echo %%a > agentskills-runtime-0.0.1-sources.jar.md5)
for /f "tokens=2 delims= " %%a in ('certutil -hashfile agentskills-runtime-0.0.1-sources.jar SHA1 ^| findstr /v "SHA1" ^| findstr /v "CertUtil"') do (echo %%a > agentskills-runtime-0.0.1-sources.jar.sha1)

REM 为 Javadoc JAR 生成校验和
for /f "tokens=2 delims= " %%a in ('certutil -hashfile agentskills-runtime-0.0.1-javadoc.jar MD5 ^| findstr /v "MD5" ^| findstr /v "CertUtil"') do (echo %%a > agentskills-runtime-0.0.1-javadoc.jar.md5)
for /f "tokens=2 delims= " %%a in ('certutil -hashfile agentskills-runtime-0.0.1-javadoc.jar SHA1 ^| findstr /v "SHA1" ^| findstr /v "CertUtil"') do (echo %%a > agentskills-runtime-0.0.1-javadoc.jar.sha1)

REM 为 POM 文件生成校验和
for /f "tokens=2 delims= " %%a in ('certutil -hashfile agentskills-runtime-0.0.1.pom MD5 ^| findstr /v "MD5" ^| findstr /v "CertUtil"') do (echo %%a > agentskills-runtime-0.0.1.pom.md5)
for /f "tokens=2 delims= " %%a in ('certutil -hashfile agentskills-runtime-0.0.1.pom SHA1 ^| findstr /v "SHA1" ^| findstr /v "CertUtil"') do (echo %%a > agentskills-runtime-0.0.1.pom.sha1)

REM 列出所有文件
dir

echo 校验和文件生成完成！
pause