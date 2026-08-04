@echo off
chcp 65001 >nul
title Phone Album Backup Tool v1.2
color 0B
echo ===========================================
echo    Phone Album Auto Backup Tool v1.2
echo ===========================================
echo.
echo  Features:
echo   - Auto download photos and videos from phone FTP
echo   - Organize by year-month (2024mm, 2025mm, 2026mm)
echo   - Skip existing files (no duplicate downloads)
echo   - Adaptive slowdown if connection unstable
echo   - Auto-retry failed files on next run
echo.
echo  Starting PowerShell backup script...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0backup_phone_album.ps1"

if %errorlevel% neq 0 (
    echo.
    echo [Error] Script execution failed, code: %errorlevel%
    echo.
    echo Please try right-clicking this file and select "Run as administrator".
    echo.
    pause
)
