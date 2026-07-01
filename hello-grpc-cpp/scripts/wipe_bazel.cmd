@echo off
echo --- step 1: kill all bazel ---
taskkill /F /IM bazel.exe 2>nul
taskkill /F /IM java.exe 2>nul
taskkill /F /IM javaw.exe 2>nul
timeout /t 2 /nobreak >nul
echo --- step 2: confirm ---
tasklist | findstr /I "bazel.exe java.exe javaw.exe" || echo (no procs)
