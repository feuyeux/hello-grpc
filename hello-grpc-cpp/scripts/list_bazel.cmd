@echo off
echo --- searching javaw / java / bazel ---
tasklist /FI "IMAGENAME eq java.exe"
echo ---bazel---
tasklist /FI "IMAGENAME eq bazel.exe"
echo ---javaw---
tasklist /FI "IMAGENAME eq javaw.exe"
echo ---javaW (64)---
tasklist /FI "IMAGENAME eq javaW.exe"
