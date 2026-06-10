# Hunter

Mac 端 AI 摸鱼监工工具。用户设定工作时间和摸鱼黑名单后，Hunter 会检测当前前台 App 或浏览器 URL；一旦抓到摸鱼行为，就用 AI 语音当场吐槽，并允许用户语音反驳，形成“人类摸鱼 vs AI 监工”的整活互动。

## Current Stage

当前仓库已进入原生 macOS 可用版本打磨阶段，包含产品文档、HTML 审稿原型和可编译、可打包的 SwiftUI/AppKit 应用：

- [PRD](docs/PRD.md)
- [设计稿](docs/DESIGN.md)
- [模型/API 技术评估](docs/TECHNICAL_EVALUATION.md)
- [实现状态](docs/IMPLEMENTATION_STATUS.md)
- [MVP 验收清单](docs/ACCEPTANCE.md)
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
- 语音链路：`ASR -> LLM -> TTS`，ASR 支持本地模型或云端 API，TTS 统一走云端 Provider
- 默认测试模板：本地 SenseVoice ASR + DeepSeek `deepseek-v4-flash` + 阿里 CosyVoice `cosyvoice-v3.5-flash`
- 云端模板：阿里云百炼 `paraformer-realtime-v2 -> qwen-turbo -> cosyvoice-v3.5-flash`
- 本地存储：SQLite 或 SwiftData
- 密钥存储：macOS Keychain

## Local Build

```bash
swift build
swift test
./scripts/package_app.sh
./scripts/package_dmg.sh
open build/Hunter.app
```

本地开发密钥放在 `.env.local` 或 macOS Keychain，不要提交。

## Provider Smoke Tests

在已配置 `DEEPSEEK_API_KEY` 和云端 ASR Key 后，可以用命令行入口验证默认 LLM 和云端 ASR 链路：

```bash
./.build/debug/Hunter --smoke-llm
say -v Tingting -o /tmp/hunter-asr.aiff "监督我接下来的四十分钟"
afconvert -f WAVE -d LEI16@16000 -c 1 /tmp/hunter-asr.aiff /tmp/hunter-asr.wav
./.build/debug/Hunter --smoke-cloud-asr /tmp/hunter-asr.wav
./.build/debug/Hunter --smoke-cloud-voice-focus /tmp/hunter-asr.wav
```

如果用户切换到本地 ASR，可以再验证 SenseVoice 下载和本机识别：

```bash
./.build/debug/Hunter --install-local-asr
./.build/debug/Hunter --smoke-local-asr /tmp/hunter-asr.wav
./.build/debug/Hunter --smoke-local-voice-focus /tmp/hunter-asr.wav
```

如果用户选择云端 ASR/TTS，并配置了 `DASHSCOPE_API_KEY`，可以继续验证阿里链路：

```bash
./.build/debug/Hunter --smoke-llm-tts
./.build/debug/Hunter --smoke-cloud-asr /tmp/hunter-asr.wav
./.build/debug/Hunter --smoke-cloud-voice-focus /tmp/hunter-asr.wav
./.build/debug/Hunter --smoke-current-context
```

ASR / LLM / TTS 的 provider 名称、base URL、model 和 API Key 可以在设置页编辑，并提供 LLM/TTS/ASR/端到端测试入口。当前内置 adapter 覆盖云端阿里/OpenAI-compatible ASR、本地 SenseVoice ASR、DeepSeek/OpenAI-compatible LLM、云端 TTS；TTS 本地模型方案已移除，接入完全不同协议的供应商时，需要新增 adapter。

时长任务支持开始、暂停、恢复、延长 10 分钟和结束，也支持语音指令控制，例如“暂停监督”“恢复监督”“延长 10 分钟”“结束监督”。

吐槽语气支持学习监督、工作监督和自定义角色，强度支持温柔、鼓励、正经、凶狠、强制；禁用词会同时约束 LLM prompt，并在本地对输出做一次过滤后再播报。强制档只在用户主动开启监督后，对当前命中的浏览器标签页或前台 App 执行本地关闭/退出请求。

设置页的“录制测试”按钮可用于验证麦克风权限和语音指令识别；悬浮球/快捷键保留短录音体验，设置页测试入口使用更长录音窗口，方便验收“监督我接下来的 40 分钟”这类时长任务。
