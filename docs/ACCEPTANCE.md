# Hunter MVP Acceptance Checklist

日期：2026-05-27

## 验收结论

当前版本已经具备可运行的 macOS MVP 主链路：可打包启动、可配置监督规则、可创建时长任务、默认阿里 `ASR -> LLM -> TTS` 链路已通过低成本云端烟测。GUI 截图、快捷键授权、麦克风录音和真实浏览器黑名单命中仍需要在已解锁并授权的桌面环境中做最终人工验收。

## Checklist

| 验收项 | 状态 | 证据 / 说明 |
| --- | --- | --- |
| 原生 macOS App 可构建 | Pass | `swift build` 通过 |
| 单元测试通过 | Pass | `swift test`，10 个测试覆盖时长解析、工作时段、黑名单匹配和 Provider headers |
| `.app` 可打包 | Pass | `./scripts/package_app.sh` 产出 `build/Hunter.app` |
| App 可启动并创建窗口 | Pass | `open build/Hunter.app` 后 CoreGraphics 可见 `Hunter` 设置窗和悬浮窗 |
| 权限引导 | Pass | 设置页展示辅助功能、麦克风、通知状态，并提供系统设置/通知请求入口 |
| 界面中英文切换 | Partial | 设置页、菜单栏、悬浮窗和主要运行时状态已跟随语言切换，后续可升级为正式 strings 资源 |
| 工作时段配置 | Pass | 设置页支持多个时段、工作日/周末开关，单测覆盖日间、跨午夜、多时段和周末排除 |
| 网站/App 黑名单配置 | Pass | 设置页支持新增、删除、启用/停用规则，并提供常见平台预设 |
| 悬浮球/小组件 | Pass | App 启动时创建悬浮窗；截图受当前环境屏幕录制权限限制 |
| 语音快速创建监督时长 | Pass | `--smoke-voice-focus`：WAV -> ASR -> `focus_minutes=40` |
| ASR 默认链路 | Pass | `paraformer-realtime-v2` 识别 `监督我接下来的40分钟。` |
| LLM 默认链路 | Pass | `qwen-turbo` 生成抓包吐槽 |
| TTS 默认链路 | Pass | `cosyvoice-v3-flash + longanyang` 返回 WAV 音频字节 |
| Provider 可配置 | Partial | 设置页可编辑端点、鉴权 scheme、额外 headers、region 和 Keychain key；完全异构供应商还需新增 adapter |
| 语音对喷链路 | Partial | ASR/LLM/TTS 子链路已测，真实麦克风权限和快捷键需桌面授权后验收 |
| 前台 App 检测 | Partial | 代码使用 `NSWorkspace`；真实黑名单命中需桌面交互验收 |
| Chrome/Safari/Brave/Edge/Arc URL 检测 | Partial | 代码使用 AppleScript；需浏览器自动化授权后验收 |
| 今日历史统计与清理 | Pass | 历史页展示今日抓包、Top 对象，支持复制语录和清除日志 |
| 本地通知降级反馈 | Pass | 通知授权后，抓包/回击成功会发送无声本地通知 |
| 安全与隐私 | Pass | `.env.local` 被忽略，API Key 可写 Keychain，仓库未发现明文 key |
| 音色克隆 | Not in MVP | 需要用户授权样本或选择声音设计方案 |
| 登录时启动 | Pass | 设置页开关接入 `SMAppService.mainApp.register/unregister` |

## 本轮验证命令

```bash
swift build
swift test
./.build/debug/Hunter --smoke-llm-tts
say -v Tingting -o /tmp/hunter-asr.aiff "监督我接下来的四十分钟"
afconvert -f WAVE -d LEI16@16000 -c 1 /tmp/hunter-asr.aiff /tmp/hunter-asr.wav
./.build/debug/Hunter --smoke-asr /tmp/hunter-asr.wav
./.build/debug/Hunter --smoke-voice-focus /tmp/hunter-asr.wav
./.build/debug/Hunter --smoke-current-context
./scripts/package_app.sh
open build/Hunter.app
```
