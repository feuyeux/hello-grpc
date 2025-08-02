@echo off
echo 配置Android模拟器键盘设置...

REM 设置默认输入法
adb -s emulator-5554 shell settings put secure default_input_method com.android.inputmethod.latin/.LatinIME

REM 启用输入法
adb -s emulator-5554 shell settings put secure enabled_input_methods com.android.inputmethod.latin/.LatinIME

REM 显示虚拟键盘（即使有硬件键盘）
adb -s emulator-5554 shell settings put secure show_ime_with_hard_keyboard 1

REM 启用文本功能
adb -s emulator-5554 shell settings put system text_auto_replace 1
adb -s emulator-5554 shell settings put system text_auto_caps 1
adb -s emulator-5554 shell settings put system text_auto_punctuate 1

REM 启用键盘声音和震动
adb -s emulator-5554 shell settings put system sound_effects_enabled 1
adb -s emulator-5554 shell settings put system haptic_feedback_enabled 1

REM 设置键盘布局为QWERTY
adb -s emulator-5554 shell settings put secure default_input_method_subtype -1

echo 键盘配置完成！
echo.
echo 当前输入法设置:
adb -s emulator-5554 shell settings get secure default_input_method
echo.
echo 要测试输入，请在应用中点击文本输入框，然后使用以下命令:
echo adb -s emulator-5554 shell input text "你的文本"
echo.
echo 或者直接在PC键盘上输入（如果支持）
pause
