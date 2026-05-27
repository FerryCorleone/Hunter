# Hunter MVP Acceptance Checklist

日期：2026-05-27

## 验收结论

当前版本已经具备可运行的 macOS MVP 主链路：可打包启动、可配置监督规则、可创建时长任务、默认阿里 `ASR -> LLM -> TTS` 链路已通过低成本云端烟测。已补本机 GUI 基础验收：设置窗启动、40 分钟时长任务、演示抓包、历史记录、麦克风权限、录制测试入口和 DMG 打包均通过。Option+Space 真实按住说话、真人麦克风输入和真实浏览器黑名单命中仍需要继续做最终权限/桌面验收。

## Checklist

| 验收项 | 状态 | 证据 / 说明 |
| --- | --- | --- |
| 原生 macOS App 可构建 | Pass | `swift build` 通过 |
| 单元测试通过 | Pass | `swift test`，17 个测试覆盖时长解析、语音控制命令、时长任务控制、工作时段、黑名单匹配、Provider headers、TTS 缓存、禁用词过滤、可见标签双语、事件去重和录音音量检测 |
| `.app` 可打包 | Pass | `./scripts/package_app.sh` 产出 `build/Hunter.app` |
| `.app` 签名校验 | Pass | `codesign --verify --deep --strict build/Hunter.app` 通过 |
| DMG 可分发包 | Pass | `./scripts/package_dmg.sh` 产出 `build/Hunter.dmg`，`hdiutil verify` 通过 |
| App 可启动并创建窗口 | Pass | `open build/Hunter.app` 后 Computer Use 可读取 `Hunter` 设置窗 |
| 权限引导 | Pass | 设置页展示辅助功能、麦克风、通知状态，并提供系统设置/通知请求入口；本机辅助功能和麦克风均已允许 |
| 界面中英文切换 | Pass | 设置页、菜单栏、悬浮窗、Provider 表单、枚举标签和主要运行时状态已跟随语言切换 |
| 工作时段配置 | Pass | 设置页支持多个时段、工作日/周末开关，单测覆盖日间、跨午夜、多时段和周末排除 |
| 网站/App 黑名单配置 | Pass | 设置页支持新增、删除、启用/停用规则，并提供常见平台预设 |
| 悬浮球/小组件 | Pass | 设置页可开启小组件，启动后保持监督入口；悬浮抓包卡片还需补单独截图验收 |
| 语音快速创建监督时长 | Pass | `--smoke-voice-focus`：`监督我接下来的四十分钟` WAV -> ASR 文本 `监督我接下来的40分钟。` -> `focus_minutes=40` |
| 时长任务暂停/延长/结束 | Pass | 设置页和菜单栏提供暂停/恢复/延长/结束；GUI 验证 40 分钟任务会启用暂停、+10、结束按钮；单测覆盖 pause/resume/extend |
| ASR 默认链路 | Pass | `paraformer-realtime-v2` 识别 `监督我接下来的40分钟。` |
| LLM 默认链路 | Pass | `qwen-turbo` 生成抓包吐槽 |
| TTS 默认链路 | Pass | `cosyvoice-v3-flash + longanyang` 返回 WAV 音频字节 |
| TTS 本地缓存 | Pass | 按 model、voice、language、text 缓存音频，单测覆盖命中和隔离 |
| Provider 可配置 | Partial | 设置页可编辑端点、鉴权 scheme、额外 headers、region 和 Keychain key，提供 LLM/TTS/ASR/端到端测试入口；完全异构供应商还需新增 adapter |
| AI 监工角色 | Pass | 支持自律教练、办公室老板、冷面助理、脱口秀损友，prompt 已带 persona |
| 吐槽边界配置 | Pass | 支持允许/禁止轻度粗口和禁用词；禁用词同时进入 prompt，并对 LLM 输出做本地过滤 |
| 语音对喷链路 | Partial | ASR/LLM/TTS 子链路已测，麦克风权限已允许，设置页录制测试入口可触发录音；本机正常音量 `say` 播报未被麦克风识别，需真人靠近麦克风复测 Option+Space |
| 前台 App 检测 | Partial | 代码使用 `NSWorkspace`；真实黑名单命中需桌面交互验收 |
| Chrome/Safari/Brave/Edge/Arc URL 检测 | Partial | 代码使用 AppleScript；需浏览器自动化授权后验收 |
| 今日历史统计与清理 | Pass | 历史页展示今日抓包、Top 对象，支持复制语录和清除日志；GUI 验证演示抓包从 10 增至 11，且同次 LLM 升级不重复插入 |
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
./scripts/package_dmg.sh
codesign --verify --deep --strict build/Hunter.app
hdiutil verify build/Hunter.dmg
open build/Hunter.app
```
