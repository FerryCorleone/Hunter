# Hunter

Mac 端 AI 摸鱼监工工具。用户设定工作时间和摸鱼黑名单后，Hunter 会检测当前前台 App 或浏览器 URL；一旦抓到摸鱼行为，就用 AI 语音当场吐槽，并允许用户语音反驳，形成“人类摸鱼 vs AI 监工”的整活互动。

## Current Stage

当前仓库处于产品定义阶段，已产出第一版：

- [PRD](docs/PRD.md)
- [设计稿](docs/DESIGN.md)
- [模型/API 技术评估](docs/TECHNICAL_EVALUATION.md)
- [HTML 设计稿](docs/design-prototype/index.html)
- [设计稿预览图](docs/design-prototype/hunter-preview.png)

## MVP Target

第一版目标是跑通节目效果闭环：

1. 工作时间配置
2. App 与网站黑名单
3. 前台 App/浏览器 URL 检测
4. 黑名单命中后的 AI 吐槽生成
5. 云端 TTS 语音播报
6. 用户按键语音反驳，走 `ASR -> LLM -> TTS`
7. 本地抓包日志
8. 用户可配置 ASR/LLM/TTS Provider
9. 中英文界面与中英文监督语言

## Preferred Tech Direction

- macOS 原生菜单栏应用：SwiftUI + AppKit
- 前台 App 检测：`NSWorkspace`
- Chrome/Safari URL 检测：AppleScript/ScriptingBridge 起步
- 语音链路：用户可配置 ASR 云端 API -> LLM 云端 API -> TTS 云端 API
- 默认测试模板：阿里云百炼 `paraformer-realtime-v2 -> qwen-turbo -> cosyvoice-v3.5-flash`
- 本地存储：SQLite 或 SwiftData
- 密钥存储：macOS Keychain
