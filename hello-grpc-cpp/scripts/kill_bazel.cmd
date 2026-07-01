@echo off
tasklist /FI "IMAGENAME eq bazel.exe"
echo ---
taskkill /F /IM bazel.exe
