# 更新记录

## v1.1.0 - Mac + Windows 桌面版

发布日期：2026-06-30

这是监管者的跨平台桌面更新。Mac 版继续提供 Universal DMG，Windows 版新增 x64 自包含 zip 安装包。

### 下载

- Mac：`Hunter.dmg`，支持 macOS 14 Sonoma 及以上，支持 Apple Silicon 和 Intel 芯片 Mac。
- Windows：`Hunter-Windows-win-x64.zip`，支持 Windows 10 / 11 x64。
- 暂不支持 iOS、Android 或浏览器插件。

### Windows 版新增

- 使用 WPF 实现原生桌面悬浮球、抓包小组件、设置窗口和托盘入口。
- 使用 Win32 API 检测当前前台 App。
- 使用 Windows UI Automation 尝试读取 Chrome、Edge、Brave、Firefox 当前地址栏。
- 支持网站黑名单、App 黑名单、监督开关、时长监督、抓包历史和本地设置。
- 支持 OpenAI-compatible ASR / LLM / TTS、MiMo TTS 以及本地 `.env.local` / 环境变量 API Key。
- 提供 `windows/build-windows.ps1`，可在 Windows 上恢复、构建、测试、发布并生成 zip。

### 验证

- Mac 包：使用本机 `swift test`、Universal DMG 打包、`lipo`、`codesign` 和 `hdiutil verify` 验证。
- Windows 包：使用 GitHub Actions `windows-latest` 验证构建、核心测试、打包、前台窗口 smoke、UI 渲染 smoke，并上传 Windows zip 和 UI 截图 artifact。
- 本次 Windows CI 验证 run：`28452630413`。
- 发布包 SHA-256：
  - `Hunter.dmg`：`d241c6d0a4d7a4049b17edd20910ea39e0688137e29aaed6c40ec62e8b58e567`
  - `Hunter-Windows-win-x64.zip`：`39570b96f6e010e86e1fa653aba32e4308b59617398c07124ab380d91b2a67cb`

## v1.0.1 - Universal Mac 版

发布日期：2026-06-30

这是监管者的 Mac 兼容性更新。`Hunter.dmg` 现在打包为 Universal 应用，同时包含 `arm64` 和 `x86_64` 两种架构。

### 下载

- 支持 macOS 14 Sonoma 及以上。
- 支持 Apple Silicon 和 Intel 芯片 Mac。
- 仍然只提供 Mac 版 DMG 安装包：`Hunter.dmg`。
- 暂不支持 Windows、iOS、Android 或浏览器插件。

### 本版整理

- 打包脚本默认构建 Universal binary。
- App 版本号更新为 `1.0.1`，build 号更新为 `2`。
- 使用 `lipo` 验证发布包内主程序同时包含 `arm64` 和 `x86_64`。
- 使用 Rosetta 在 Apple Silicon 机器上执行 `x86_64` slice 的命令行烟测。
- 通过 `swift test`、签名验证和 DMG 校验。

## v1.0.0 - 第一版

发布日期：2026-06-16

这是监管者的第一个正式公开版本。从这一版开始记录 release，旧的开发过程记录和中间测试报告不再作为公开更新记录保留。

### 下载

- 仅支持 macOS 14 Sonoma 及以上。
- 仅提供 DMG 安装包：`Hunter.dmg`。
- 暂不支持 Windows、iOS、Android 或浏览器插件。

### 主要功能

- 桌面悬浮球和抓包小组件。
- 网站黑名单和本机 App 黑名单。
- 开启监督后检测当前前台 App / 浏览器标签页。
- 命中黑名单后生成 AI 吐槽并用 TTS 播报。
- 支持按住快捷键语音反驳，走 ASR -> LLM -> TTS 链路。
- 支持语音创建时长监督任务，例如“监督我接下来的 40 分钟”。
- 支持中文/英文界面和监督语言。
- 支持配置 ASR、LLM、TTS 三类模型服务。
- 支持本地历史记录。

### 本版整理

- App 内显示名称统一为“监管者”。
- 清理 AI 设置页里对普通用户没有意义的自动配置说明。
- 移除每个模型卡片里的额外“更新配置”按钮，保留 API Key 输入框后的保存/更新交互。
- 本机 App 搜索结果现在会展示已添加 App，并把按钮置为“已添加”。
- 开启监督时会重新检查当前前台上下文，避免用户先打开黑名单网站或 App 再开始监督时漏抓。

### 使用提醒

- 需要用户自己提供模型服务 API Key。
- 浏览器抓包需要允许 macOS 自动化权限。
- 云端 ASR / LLM / TTS 调用按用户选择的厂商规则计费。
