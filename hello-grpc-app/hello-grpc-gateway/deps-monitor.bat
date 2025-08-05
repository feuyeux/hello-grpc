@echo off
REM Hello gRPC Gateway - Dependency Version Monitor (Windows)
REM This script checks for dependency updates and generates reports

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%"
set "REPORTS_DIR=%PROJECT_DIR%reports"

echo 🔍 Hello gRPC Gateway - Dependency Monitor
echo ==================================================

REM Create reports directory
if not exist "%REPORTS_DIR%" mkdir "%REPORTS_DIR%"

REM Check if we're in the right directory
if not exist "go.mod" (
    echo ❌ Error: go.mod not found. Please run this script from the hello-grpc-gateway directory.
    exit /b 1
)

REM Get current timestamp
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "YY=%dt:~2,2%" & set "YYYY=%dt:~0,4%" & set "MM=%dt:~4,2%" & set "DD=%dt:~6,2%"
set "HH=%dt:~8,2%" & set "Min=%dt:~10,2%" & set "Sec=%dt:~12,2%"
set "timestamp=%YYYY%%MM%%DD%_%HH%%Min%%Sec%"

goto :main

:check_go_dependencies
echo.
echo 📦 Checking Go dependencies...

REM Get Go version
for /f "tokens=3" %%i in ('go version') do set "GO_VERSION=%%i"
echo Go version: %GO_VERSION%

echo.
echo ⚠️ Checking for available updates...

REM Create temporary file for outdated deps
set "OUTDATED_FILE=%REPORTS_DIR%\outdated_deps.txt"
go list -u -m all > "%OUTDATED_FILE%"

REM Count outdated dependencies
findstr /R "\[.*\]" "%OUTDATED_FILE%" > nul
if !errorlevel! equ 0 (
    echo ⚠️ Found outdated dependencies
    
    REM Create detailed report
    set "REPORT_FILE=%REPORTS_DIR%\dependency_report_%timestamp%.md"
    
    (
        echo # Hello gRPC Gateway - Dependency Report
        echo.
        echo **Generated**: %date% %time%
        echo **Go Version**: %GO_VERSION%
        echo.
        echo ## Outdated Dependencies
        echo.
        echo ^| Module ^| Current Version ^| Available Version ^|
        echo ^|--------^|----------------^|-------------------^|
    ) > "!REPORT_FILE!"
    
    REM Process outdated dependencies
    for /f "tokens=*" %%i in ('findstr /R "\[.*\]" "%OUTDATED_FILE%"') do (
        set "line=%%i"
        for /f "tokens=1,2" %%a in ("!line!") do (
            set "module=%%a"
            set "current=%%b"
            REM Extract available version from brackets
            for /f "tokens=*" %%c in ('echo !line! ^| findstr /o "\[.*\]"') do (
                set "available=%%c"
                set "available=!available:[=!"
                set "available=!available:]=!"
            )
            echo ^| !module! ^| !current! ^| !available! ^| >> "!REPORT_FILE!"
            echo   !module!: !current! → !available!
        )
    )
    
    (
        echo.
        echo ## Direct Dependencies
        echo.
        echo ```
    ) >> "!REPORT_FILE!"
    
    go list -m all | findstr /v "hello-grpc/hello-grpc-gateway" >> "!REPORT_FILE!"
    
    (
        echo ```
        echo.
        echo ## Commands to Update
        echo.
        echo To update all dependencies:
        echo ```bash
        echo go get -u ./...
        echo go mod tidy
        echo ```
    ) >> "!REPORT_FILE!"
    
    echo.
    echo 📄 Detailed report saved to: !REPORT_FILE!
) else (
    echo ✅ All dependencies are up to date!
    
    REM Create up-to-date report
    set "REPORT_FILE=%REPORTS_DIR%\dependency_report_%timestamp%.md"
    (
        echo # Hello gRPC Gateway - Dependency Report
        echo.
        echo **Generated**: %date% %time%
        echo **Go Version**: %GO_VERSION%
        echo **Status**: ✅ All dependencies are up to date
        echo.
        echo ## Current Dependencies
        echo.
        echo ```
    ) > "!REPORT_FILE!"
    
    go list -m all | findstr /v "hello-grpc/hello-grpc-gateway" >> "!REPORT_FILE!"
    echo ``` >> "!REPORT_FILE!"
)

REM Cleanup
del "%OUTDATED_FILE%" >nul 2>&1
goto :eof

:check_vulnerabilities
echo.
echo 🔒 Checking for security vulnerabilities...

REM Check if govulncheck is installed
govulncheck --help >nul 2>&1
if !errorlevel! neq 0 (
    echo Installing govulncheck...
    go install golang.org/x/vuln/cmd/govulncheck@latest
)

REM Run vulnerability check
set "VULN_FILE=%REPORTS_DIR%\vulnerabilities_%timestamp%.txt"
govulncheck ./... > "%VULN_FILE%" 2>&1

if !errorlevel! equ 0 (
    echo ✅ No vulnerabilities found
) else (
    echo ⚠️ Vulnerabilities detected. Check: %VULN_FILE%
)
goto :eof

:generate_dependency_tree
echo.
echo 🌳 Generating dependency tree...

set "TREE_FILE=%REPORTS_DIR%\dependency_tree_%timestamp%.txt"

(
    echo # Hello gRPC Gateway - Dependency Tree
    echo Generated: %date% %time%
    echo.
    echo ## Module Graph
) > "%TREE_FILE%"

go mod graph >> "%TREE_FILE%"

echo 📄 Dependency tree saved to: %TREE_FILE%
goto :eof

:update_dependencies
echo.
echo 🔄 Updating dependencies...

REM Backup current go.mod and go.sum
copy go.mod "go.mod.backup.%timestamp%" >nul
if exist go.sum copy go.sum "go.sum.backup.%timestamp%" >nul

echo Backing up current go.mod...

REM Update dependencies
echo Updating all dependencies...
go get -u ./...
if !errorlevel! neq 0 (
    echo ❌ Failed to update dependencies
    exit /b 1
)

echo Running go mod tidy...
go mod tidy

echo Verifying build...
go build ./...
if !errorlevel! equ 0 (
    echo ✅ Dependencies updated successfully!
) else (
    echo ❌ Build failed after update. Restoring backup...
    copy "go.mod.backup.%timestamp%" go.mod >nul
    if exist "go.sum.backup.%timestamp%" copy "go.sum.backup.%timestamp%" go.sum >nul
    exit /b 1
)
goto :eof

:main
set "command=%~1"
if "%command%"=="" set "command=check"

if "%command%"=="check" (
    call :check_go_dependencies
    call :check_vulnerabilities
    call :generate_dependency_tree
) else if "%command%"=="update" (
    echo ⚠️ This will update all dependencies. Continue? (y/N^)
    set /p "response="
    if /i "!response!"=="y" (
        call :update_dependencies
        call :check_go_dependencies
    ) else (
        echo Update cancelled.
    )
) else if "%command%"=="report" (
    call :check_go_dependencies
    call :generate_dependency_tree
) else if "%command%"=="vuln" (
    call :check_vulnerabilities
) else (
    echo Usage: %0 [check^|update^|report^|vuln]
    echo.
    echo Commands:
    echo   check   - Check for outdated dependencies (default^)
    echo   update  - Update all dependencies
    echo   report  - Generate dependency reports
    echo   vuln    - Check for security vulnerabilities
    exit /b 1
)

endlocal
