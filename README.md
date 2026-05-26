# Hunter

Mac 端 AI 摸鱼监工工具。用户设定工作时间和摸鱼黑名单后，Hunter 会检测当前前台 App 或浏览器 URL；一旦抓到摸鱼行为，就用 AI 语音当场吐槽，并允许用户语音反驳，形成“人类摸鱼 vs AI 监工”的整活互动。

## Current Stage

当前仓库已进入原生 macOS MVP 开发阶段，包含产品文档、HTML 审稿原型和可编译、可打包的 SwiftUI/AppKit 应用：

- [PRD](docs/PRD.md)
- [设计稿](docs/DESIGN.md)
- [模型/API 技术评估](docs/TECHNICAL_EVALUATION.md)
- [实现状态](docs/IMPLEMENTATION_STATUS.md)
- [HTML 设计稿](docs/design-prototype/index.html)
- [设计稿预览图](docs/design-prototype/hunter-preview.png)
- [图像生成参考稿](docs/design-prototype/generated-ui-reference.png)

说明：HTML 设计稿里的 macOS 壁纸、Dock、系统菜单栏只作为审稿展示背景，不属于 Hunter 要开发的产品 UI。开发范围是悬浮球、小组件、时长任务 toast、设置窗口和菜单栏状态入口。

## MVP Target

第一版目标是跑通节目效果闭环：

1. 工作时间配置
2. App 与网站黑名单
3. 桌面悬浮球/小组件监督
4. 语音快速创建时长监督任务，例如“监督我接下来的 40 分钟”
5. 前台 App/浏览器 URL 检测
6. 黑名单命中后的 AI 吐槽生成
7. 云端 TTS 语音播报
8. 用户按键语音反驳，走 `ASR -> LLM -> TTS`
9. 本地抓包日志
10. 用户可配置 ASR/LLM/TTS Provider
11. 中英文界面与中英文监督语言

## Preferred Tech Direction

- macOS 原生菜单栏应用：SwiftUI + AppKit
- 前台 App 检测：`NSWorkspace`
- Chrome/Safari URL 检测：AppleScript/ScriptingBridge 起步
- 语音链路：用户可配置 ASR 云端 API -> LLM 云端 API -> TTS 云端 API
- 默认测试模板：阿里云百炼 `paraformer-realtime-v2 -> qwen-turbo -> cosyvoice-v3-flash`
- 本地存储：SQLite 或 SwiftData
- 密钥存储：macOS Keychain

## Local Build

```bash
swift build
swift test
./scripts/package_app.sh
open build/Hunter.app
```

本地开发密钥放在 `.env.local` 或 macOS Keychain，不要提交。

## Provider Smoke Tests

在已配置 `DASHSCOPE_API_KEY` 后，可以用命令行入口低成本验证默认阿里链路：

```bash
./.build/debug/Hunter --smoke-llm-tts
say -v Tingting -o /tmp/hunter-asr.aiff "监督我接下来的四十分钟"
afconvert -f WAVE -d LEI16@16000 -c 1 /tmp/hunter-asr.aiff /tmp/hunter-asr.wav
./.build/debug/Hunter --smoke-asr /tmp/hunter-asr.wav
./.build/debug/Hunter --smoke-voice-focus /tmp/hunter-asr.wav
```

ASR / LLM / TTS 的 provider 名称、base URL、model、API key 环境变量名和 TTS 音色 ID 都可以在设置页编辑。当前内置 adapter 覆盖阿里默认链路和 OpenAI-compatible LLM；接入完全不同协议的供应商时，需要新增 adapter。
