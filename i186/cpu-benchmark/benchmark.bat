@echo off
cd /d "%~dp0"

echo ==========================
echo       LANGUAGE RACE
echo ==========================

powershell -NoProfile -ExecutionPolicy Bypass -File benchmark.ps1

pause
