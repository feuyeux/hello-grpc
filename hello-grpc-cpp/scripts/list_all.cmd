@echo off
echo --- All relevant processes ---
tasklist | findstr /I "bazel java javaw"
