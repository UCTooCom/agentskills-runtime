@echo off
REM Publish script for agentskills-runtime Java SDK to Maven Central
REM
REM Usage:
REM   publish.bat [--skip-tests]
REM
REM Prerequisites:
REM   1. GPG key installed and configured
REM   2. Maven settings.xml configured with Sonatype credentials
REM   3. Maven installed

setlocal enabledelayedexpansion

echo ==========================================
echo Publishing agentskills-runtime Java SDK
echo ==========================================

REM Parse arguments
set SKIP_TESTS=false
for %%a in (%*) do (
    if "%%a"=="--skip-tests" set SKIP_TESTS=true
)

REM Get version from pom.xml
for /f "tokens=2 delims=<>" %%a in ('findstr /r "<version>" pom.xml ^| findstr /v "jackson\|spring\|okhttp\|slf4j\|junit\|mockito" ^| findstr /n "." ^| findstr "^1:"') do (
    set VERSION=%%a
)

set GROUP_ID=com.opencangjie
set ARTIFACT_ID=agentskills-runtime

echo Version: %VERSION%
echo Group ID: %GROUP_ID%
echo Artifact ID: %ARTIFACT_ID%
echo.

REM Check prerequisites
echo Checking prerequisites...

REM Check if GPG is installed
where gpg >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: GPG is not installed. Please install GPG first.
    echo   - Windows: Download from https://www.gnupg.org/download/
    exit /b 1
)

REM Check if Maven is installed
where mvn >nul 2>nul
if %errorlevel% neq 0 (
    echo Error: Maven is not installed. Please install Maven first.
    echo   - Windows: Download from https://maven.apache.org/download.cgi
    exit /b 1
)

echo [OK] GPG installed
echo [OK] Maven installed
echo.

REM Clean previous builds
echo Cleaning previous builds...
call mvn clean

REM Run tests
if "%SKIP_TESTS%"=="false" (
    echo Running tests...
    call mvn test
    if %errorlevel% neq 0 (
        echo Error: Tests failed
        exit /b 1
    )
    echo [OK] Tests passed
) else (
    echo Skipping tests (--skip-tests flag)
)
echo.

REM Build and deploy
echo Building and deploying to Maven Central...
call mvn deploy -P release

if %errorlevel% neq 0 (
    echo Error: Deployment failed
    exit /b 1
)

echo.
echo ==========================================
echo [OK] Deployment completed successfully!
echo ==========================================
echo.
echo The artifact has been deployed to the staging repository.
echo Please check the staging repository at:
echo   https://s01.oss.sonatype.org/
echo.
echo After verifying the staging repository, close and release it manually
echo or wait for automatic release (if autoReleaseAfterClose is enabled).
echo.
echo Once released, the artifact will be available at:
echo   https://repo1.maven.org/maven2/com/opencangjie/agentskills-runtime/
echo.
echo Maven dependency:
echo   ^<dependency^>
echo     ^<groupId^>%GROUP_ID%^</groupId^>
echo     ^<artifactId^>%ARTIFACT_ID%^</artifactId^>
echo     ^<version^>%VERSION%^</version^>
echo   ^</dependency^>
echo.
echo Gradle dependency:
echo   implementation '%GROUP_ID%:%ARTIFACT_ID%:%VERSION%'
echo.

endlocal
