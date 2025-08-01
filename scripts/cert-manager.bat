@echo off
setlocal

echo FastCopy Certificate Manager
echo ==========================
echo.

if "%1"=="" (
    echo Usage: %0 [action] [options]
    echo.
    echo Actions:
    echo   generate  - Generate new certificate
    echo   install   - Install certificate to trusted store
    echo   remove    - Remove certificate and files
    echo   list      - List existing certificates
    echo   sign      - Sign a file ^(requires -FilePath^)
    echo   verify    - Verify file signature ^(requires -FilePath^)
    echo.
    echo Examples:
    echo   %0 generate
    echo   %0 install
    echo   %0 sign "C:\path\to\your\file.exe"
    echo   %0 verify "C:\path\to\your\file.exe"
    echo.
    pause
    goto :eof
)

set action=%1
set filepath=%2

if "%action%"=="sign" (
    if "%filepath%"=="" (
        echo Error: Sign action requires a file path
        echo Usage: %0 sign "C:\path\to\file.exe"
        pause
        goto :eof
    )
    powershell -ExecutionPolicy Bypass -File "%~dp0Certificate-Manager.ps1" -Action Sign -FilePath "%filepath%"
) else if "%action%"=="verify" (
    if "%filepath%"=="" (
        echo Error: Verify action requires a file path
        echo Usage: %0 verify "C:\path\to\file.exe"
        pause
        goto :eof
    )
    powershell -ExecutionPolicy Bypass -File "%~dp0Certificate-Manager.ps1" -Action Verify -FilePath "%filepath%"
) else (
    powershell -ExecutionPolicy Bypass -File "%~dp0Certificate-Manager.ps1" -Action %action%
)

echo.
pause
