# Hunter MVP Acceptance Checklist

日期：2026-05-30

## 验收结论

当前版本已经具备可运行的 macOS MVP 主链路：可打包启动、可配置监督规则、可创建时长任务，默认 LLM 使用 DeepSeek，本地 ASR 使用 SenseVoice，TTS 使用千问云 CosyVoice。已通过“中文语音 -> 40 分钟监督任务”烟测；DeepSeek LLM + 千问云 TTS 也已用真实本机密钥通过命令行端到端烟测。本机 Qwen TTS 模型、runtime、脚本和 TTS 缓存已清理。本机 GUI 基础验收、演示抓包、历史记录、麦克风权限、录制测试入口和 DMG 打包均通过。Option+Space 真人按住说话、真实浏览器黑名单命中、搜索增强真实 Key 和桌面抓包/对喷真实播报仍需要继续做桌面验收。

## Checklist

| 验收项 | 状态 | 证据 / 说明 |
| --- | --- | --- |
| 原生 macOS App 可构建 | Pass | `swift build` 通过 |
| 单元测试通过 | Pass | `swift test`，38 个测试覆盖时长解析、语音控制命令、时长任务控制、倒计时环进度、工作时段、黑名单匹配、本机 App 扫描、支持浏览器识别、Provider headers、默认 DeepSeek/本地 ASR/云端 TTS 配置、Search 默认配置、头像和快捷键配置兼容迁移、快捷键组合/单键/右 Option 展示、英文监督语言兜底、旧本地音色迁移、TTS 缓存、TTS 下载 URL HTTPS 升级、吐槽 URL/长 ID 清洗、短播报压缩、粗口 opt-in prompt、空文本兜底、禁用词过滤、可见标签双语、语音活动状态、时长任务 toast、事件去重和录音音量检测 |
| `.app` 可打包 | Pass | `./scripts/package_app.sh` 产出 `build/Hunter.app` |
| `.app` 签名校验 | Pass | `codesign --verify --deep --strict build/Hunter.app` 通过 |
| DMG 可分发包 | Pass | `./scripts/package_dmg.sh` 产出 `build/Hunter.dmg`，`hdiutil verify` 通过 |
| App 可启动并创建窗口 | Pass | `open build/Hunter.app` 后 Computer Use 可读取 `Hunter` 设置窗 |
| 设置窗口视觉完成度 | Pass | 本轮先补全 PRD 2A 页面结构契约，再生成 `docs/design-prototype/redesign-2026-05-30/` 高保真参考图；SwiftUI 设置窗口已按参考稿收敛为 196px sidebar、760px 内容宽度、低饱和蓝色选中态、实体白色 settings row；通用、黑名单、AI、声音、历史页用 Computer Use 逐页检查，布局无明显遮挡；AI Provider 表单使用上标签字段，API Key 已保存时显示 masked 状态；历史清除增加二次确认 |
| 权限引导 | Pass | 设置页展示麦克风、浏览器自动化、通知和辅助功能状态；权限区已简化为“状态标签 + 未允许时的操作按钮”，移除绿点/已允许/对勾重复表达；页面自动刷新权限，并提供“重新检查”按钮；麦克风可请求或打开系统设置，浏览器自动化优先检查当前浏览器，若设置窗口在前台则回退检查 Chrome，且只在用户点击授权时触发系统弹窗；通知和辅助功能改为可选增强，不再用“需要处理”误导用户；当前 ad-hoc 重新打包后麦克风可能被系统视为新 App 主体，需要重新允许 |
| 界面中英文切换 | Pass | 设置页、菜单栏、悬浮窗、Provider 表单、枚举标签和主要运行时状态已跟随语言切换 |
| 工作时段配置 | Pass | 设置页支持多个时段、工作日/周末开关，单测覆盖日间、跨午夜、多时段和周末排除 |
| 网站/App 黑名单配置 | Pass | 设置页支持新增、删除、启用/停用规则，并提供常见平台预设；新增本机 App 列表扫描入口，可搜索已安装 App 名称或 Bundle ID 并一键加入 App 黑名单；单测覆盖 `.app` Bundle 元数据读取 |
| 悬浮球/小组件 | Pass | 设置页可开启小组件；悬浮头像固定为圆形裁切，支持上传自定义头像并恢复默认；右下角状态点已移除，时长任务使用头像边缘倒计时环；空闲态悬浮窗为 72×72 透明面板，头像缩到 56×56 收在圆环内侧并内缩绘制圆环，避免方形半透明底板、头像超出圆环和边缘裁切；悬浮球可拖动到任意位置，点击可展开快捷控制菜单，展示倒计时并支持 15/25/40 分钟监督、暂停/恢复和取消；快捷菜单 6 秒无操作自动收起，手动收起时保持悬浮球 top-left 锚点不跳位；进度条用蓝色显示剩余时间；取消会立即结束当前时长任务并停止监督；按住语音键时头像外侧出现绿色呼吸圆环；用户拖动后的窗口位置会被保留，状态变化只调整尺寸不重置坐标；抓包卡片和时长任务 toast 不再展示内部模型/Provider/播放状态，并改为实体白色 popover 背景；音频合成完成后才弹出并同步播放；toast 自动消失，抓包卡片播报结束且用户无操作后自动收起 |
| 语音快速创建监督时长 | Pass | `--smoke-local-voice-focus`：`监督我接下来的四十分钟` WAV -> 本地 SenseVoice 文本 `监督我接下来的四十分钟` -> `focus_minutes=40`；手动语音命令 ASR 改为自动/中英混合，不再跟随 AI 监督语言；单测覆盖“帮我开始一个15分钟的监督任务”“三十五分钟”“半小时”“一个半小时” |
| 时长任务暂停/延长/结束 | Pass | 设置页和菜单栏提供暂停/恢复/延长/结束；GUI 验证 40 分钟任务会启用暂停、+10、结束按钮；单测覆盖 pause/resume/extend |
| 监督结束语音总结 | Pass | 时长任务自然结束会创建本轮完成事件，根据本轮抓包次数分为 0 次彩虹屁、1-3 次鼓励、4 次及以上吐槽；总结语音走当前云端 TTS Provider，不回退系统朗读；单测覆盖过期时长任务只统计 session 时间窗口内抓包次数 |
| ASR 默认链路 | Pass | 本地 SenseVoice Small INT8 安装和识别通过；5 次本地 ASR 耗时首轮约 1.05 秒、后续约 0.58-0.64 秒；云端 `paraformer-realtime-v2` 仍保留为 fallback |
| LLM 默认链路 | Pass | 默认配置和当前本机保存运行配置均为 DeepSeek `deepseek-v4-flash` / `https://api.deepseek.com`；`DEEPSEEK_API_KEY` 已写入本机 App Support `.env.local`，抓包和回击状态会显示实际 LLM `Provider / Model`；千问云/DashScope 仅用于当前 TTS Provider |
| TTS 默认链路 | Pass | 本地 TTS 已移除，抓包/对喷播报统一走云端 TTS Provider，默认 `cosyvoice-v3-flash + longanyang`；`DASHSCOPE_API_KEY` 已写入本机 App Support `.env.local`，千问云鉴权 HTTP 200，`--smoke-llm-tts` 返回 `tts_ok=true` |
| TTS 本地缓存 | Pass | 仅缓存云端 TTS 返回的音频，按 model、voice、language、text 隔离；本机旧 TTS 缓存目录已清理 |
| Provider 可配置 | Pass | 设置页中 ASR/LLM/TTS/Search 四类能力可独立配置；云端模式只填 Provider、Base URL、Model、API Key；仅 ASR 提供本地模型下载入口；本地 ASR adapter 已实测通过 |
| AI 监工角色 | Pass | 支持自律教练、办公室老板、冷面助理、脱口秀损友，prompt 已带 persona |
| 搜索增强吐槽 | Partial | 设置页新增 Brave Search / Tavily Search 配置与测试入口；抓包 prompt 会合并页面标题和可选搜索摘要；未填搜索 Key 时自动跳过增强，仍需真实 Search API Key 验收 |
| 吐槽边界配置 | Pass | 支持允许/禁止粗口和禁用词；prompt 已升级为“识别当前内容 -> 输出现场短句”，中文目标 12-26 字、英文目标 7-14 词；测试阶段若用户允许粗口，会明确要求模型自然使用普通脏话增强节目效果；禁用词同时进入 prompt，并对 LLM 输出做本地过滤 |
| 吐槽播报文本清洗 | Pass | LLM 输出进入 TTS 前会本地移除 URL、域名、长 ID 和符号串，并压缩过长中文吐槽；清洗后为空会回退为短提醒，避免把 B 站 BV 号、网页链接或 query 参数逐字念出来 |
| 语音对喷链路 | Partial | 代码已从单次回击升级为多轮同上下文对话：用户说完 -> Hunter 生成并播报 -> 播报结束后等待用户再次按住快捷键继续下一轮；不再后台自动开始下一轮录音，避免第二次手动按键和自动录音抢麦克风；抓包卡片按钮改为“按住 {当前快捷键} 对话”，默认 `Option + Space`；设置页快捷键改为单个录制框，点击后直接按新的组合键或单键即可保存，支持右侧 `Option` 这类 modifier-only 单键，并为 modifier-only 全局快捷键补充 `flagsChanged` 监听；按钮本身已改为按下录音、松开发送；手动回击补充按下/松开/麦克风授权状态/录音诊断和 9 秒安全兜底，已授权时跳过重复权限请求直接录音，未授权弹窗无响应时 2.5 秒后给出可见权限提示；ASR/LLM/TTS 子链路已测，仍需真人靠近麦克风复测按住说话 |
| 前台 App 检测 | Partial | 代码使用 `NSWorkspace.didActivateApplicationNotification` 事件驱动；真实黑名单命中需桌面交互验收 |
| Chrome/Safari/Brave/Edge/Arc URL 检测 | Partial | 仅浏览器前台时启动后台 AppleScript URL/标签标题 watcher；监控循环只做静默自动化权限检查，未授权时跳过读取不弹窗；需浏览器自动化授权后验收 |
| 今日历史统计与清理 | Pass | 历史页展示今日抓包、今日最多命中和清除日志；GUI 验证演示抓包从 10 增至 11，且同次 LLM 升级不重复插入 |
| 本地通知降级反馈 | Pass | 通知授权后，抓包/回击成功会发送无声本地通知 |
| 安全与隐私 | Pass | `.env.local` 被忽略，API Key 写入本机 Application Support `.env.local` 并缓存到内存，运行和保存都不访问 Keychain；搜索增强默认关闭，只发送页面标题/域名 query，仓库未发现明文 key |
| 音色克隆 | Deferred | MVP 已移除本地声音克隆入口；声音页已露出云端音色克隆区域，上传/录制样本禁用并标注为待接入；后续如接云端克隆/音色设计，只保存 Provider 返回的授权 voice id |
| 登录时启动 | Pass | 设置页开关接入 `SMAppService.mainApp.register/unregister` |

备注：当前本地包使用 ad-hoc 重新签名，每次重新打包后 macOS 可能把 `build/Hunter.app` 当成新的麦克风权限主体，需要再允许一次麦克风；正式分发应使用稳定 Developer ID 签名来避免频繁重授权。

## 本轮验证命令

```bash
swift build
swift test
./.build/debug/Hunter --smoke-llm
./.build/debug/Hunter --smoke-llm-tts
say -v Tingting -o /tmp/hunter-asr.aiff "监督我接下来的四十分钟"
afconvert -f WAVE -d LEI16@16000 -c 1 /tmp/hunter-asr.aiff /tmp/hunter-asr.wav
./.build/debug/Hunter --install-local-asr
./.build/debug/Hunter --smoke-local-asr /tmp/hunter-asr.wav
./.build/debug/Hunter --smoke-local-voice-focus /tmp/hunter-asr.wav
./.build/debug/Hunter --smoke-asr /tmp/hunter-asr.wav
./.build/debug/Hunter --smoke-voice-focus /tmp/hunter-asr.wav
./.build/debug/Hunter --smoke-current-context
./scripts/package_app.sh
./scripts/package_dmg.sh
codesign --verify --deep --strict build/Hunter.app
hdiutil verify build/Hunter.dmg
tail -n 40 "$HOME/Library/Application Support/Hunter/Logs/tts.log"
tail -n 40 "$HOME/Library/Application Support/Hunter/Logs/asr.log"
open build/Hunter.app
```
