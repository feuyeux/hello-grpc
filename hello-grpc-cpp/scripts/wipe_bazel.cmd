@echo off
echo --- killing bazel/java ---
taskkill /F /IM bazel.exe 2>nul
taskkill /F /IM java.exe 2>nul
taskkill /F /IM javaw.exe 2>nul
ping -n 2 127.0.0.1 >nul
echo --- check ---
tasklist /FI "IMAGENAME eq bazel.exe" 2>nul
tasklist /FI "IMAGENAME eq java.exe" 2>nul
