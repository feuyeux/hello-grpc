@echo off
rmdir /q /s .idea   2>nul
rmdir /q /s android  2>nul 
rmdir /q /s build   2>nul
rmdir /q /s ios   2>nul
rmdir /q /s linux   2>nul
rmdir /q /s macos   2>nul
rmdir /q /s web   2>nul
rmdir /q /s windows  2>nul 
rmdir /q /s test   2>nul
del /q .metadata  2>nul