# Android模拟器键盘输入配置指南

## 📱 当前状态

✅ Flutter应用已成功在Android模拟器上运行
✅ Android键盘已配置为默认输入法

## ⌨️ 键盘配置说明

### 1. 基本配置（已完成）

- 默认输入法：Android键盘 (LatinIME)
- 虚拟键盘显示：即使有物理键盘也显示
- 文本功能：自动替换、自动大写、自动标点

### 2. 输入方法

#### 方法一：使用ADB命令输入

```bash
# 输入英文文本
adb -s emulator-5554 shell input text "Hello World"

# 输入中文需要先编码
adb -s emulator-5554 shell input text "你好世界"

# 输入特殊字符
adb -s emulator-5554 shell input text "test@email.com"
```

#### 方法二：PC键盘直接输入

1. 点击Flutter应用中的文本输入框
2. 直接在PC键盘上输入（如果模拟器支持）
3. 虚拟键盘会自动显示在屏幕底部

#### 方法三：虚拟键盘输入

1. 点击文本输入框
2. 在屏幕上的虚拟键盘上点击输入

### 3. 键盘快捷键

- `Ctrl+A`：全选
- `Ctrl+C`：复制
- `Ctrl+V`：粘贴
- `Ctrl+X`：剪切
- `Del`：删除
- `Backspace`：退格

### 4. 调试和测试命令

#### 检查当前输入法

```bash
adb -s emulator-5554 shell settings get secure default_input_method
```

#### 打开输入法设置

```bash
adb -s emulator-5554 shell am start -a android.settings.INPUT_METHOD_SETTINGS
```

#### 测试键盘输入

```bash
# 在Flutter应用的输入框中输入测试文本
adb -s emulator-5554 shell input text "Testing keyboard input"
```

### 5. 常见问题解决

#### 问题1：PC键盘无法输入

**解决方案：**

- 确保模拟器窗口有焦点
- 尝试点击输入框后再输入
- 使用ADB命令作为替代

#### 问题2：中文输入问题

**解决方案：**

- 安装中文输入法APK
- 或使用ADB命令输入中文

#### 问题3：虚拟键盘不显示

**解决方案：**

```bash
adb -s emulator-5554 shell settings put secure show_ime_with_hard_keyboard 1
```

### 6. Flutter应用测试

当前Flutter gRPC应用正在运行，您可以：

1. 点击应用中的文本输入框
2. 使用上述任一方法输入文本
3. 测试gRPC功能的输入参数

### 7. 模拟器重启后的设置保持

配置的设置在模拟器重启后会保持，但如果需要重新配置，可以运行：

```bash
./configure_android_keyboard.bat
```

## 🎯 下一步

- 可以开始测试Flutter应用的各种功能
- 输入不同的gRPC测试数据
- 体验应用的用户界面交互
