@echo off
rem Double-click launcher: runs beta2forever.ps1 without changing the system's script policy.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0beta2forever.ps1" %*
pause
