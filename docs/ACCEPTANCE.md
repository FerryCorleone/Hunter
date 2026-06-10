# Hunter MVP Acceptance Checklist

日期：2026-06-01

## 验收结论

当前版本已经具备可运行的 macOS MVP 主链路：可打包启动、可配置监督规则、可创建时长任务，默认 LLM 使用 DeepSeek，默认 ASR 使用云端 API，TTS 使用 Xiaomi MiMo 云端 API；用户可主动切换到本地 SenseVoice 并在客户端内下载模型。已通过“中文语音 -> 40 分钟监督任务”烟测；DeepSeek LLM + 云端 TTS 也已用真实本机密钥通过命令行端到端烟测。早前 Qwen TTS 和本轮 CosyVoice3 本地 TTS 模型、runtime、helper 与旧 TTS 缓存已清理。本机 GUI 基础验收、演示抓包、历史记录、麦克风权限、录制测试入口和 DMG 打包均通过。Option+Space 真人按住说话、真实浏览器黑名单命中、本地 ASR 首次下载和桌面抓包/对喷真实播报仍需要继续做桌面验收。

## Checklist

| 验收项 | 状态 | 证据 / 说明 |
| --- | --- | --- |
| 原生 macOS App 可构建 | Pass | `swift build` 通过 |
| 单元测试通过 | Pass | `swift test`，71 个测试覆盖时长解析、语音控制命令、时长任务控制、倒计时环进度、工作时段、黑名单匹配、本机 App 扫描、支持浏览器识别、Provider headers、OpenAI/MiMo 鉴权、默认 DeepSeek/云端 ASR/云端 TTS 配置、ASR 模式顺序、ASR/LLM/TTS 厂商预设、头像和快捷键配置兼容迁移、快捷键组合/单键/右 Option 展示、英文监督语言兜底、旧本地音色迁移、TTS 缓存、TTS 下载 URL HTTPS 升级、吐槽 URL/长 ID 清洗、短播报压缩、全局短重复抓包冷却、粗口 opt-in prompt、空文本兜底、禁用词过滤、可见标签双语、语音活动状态、时长任务 toast、事件去重和录音音量检测 |
| `.app` 可打包 | Pass | `./scripts/package_app.sh` 产出 `build/Hunter.app` |
| `.app` 签名校验 | Pass | `codesign --verify --deep --strict build/Hunter.app` 通过 |
| DMG 可分发包 | Pass | `./scripts/package_dmg.sh` 产出 `build/Hunter.dmg`，`hdiutil verify` 通过 |
| App 可启动并创建窗口 | Pass | `open build/Hunter.app` 后 Computer Use 可读取 `Hunter` 设置窗 |
| 设置窗口视觉完成度 | Pass | 本轮先补全 PRD 2A 页面结构契约，再生成 `docs/design-prototype/redesign-2026-05-30/` 高保真参考图；SwiftUI 设置窗口已按参考稿收敛为 196px sidebar、760px 内容宽度、低饱和蓝色选中态、实体白色 settings row；通用、黑名单、AI、声音、历史页用 Computer Use 逐页检查，布局无明显遮挡；AI Provider 表单使用上标签字段，API Key 已保存时显示 masked 状态；历史清除增加二次确认 |
| Dock 与设置窗口入口 | Pass | 打包 App 不再使用 `LSUIElement` 菜单栏代理模式，Dock 中显示 Hunter 图标；状态栏菜单仍保留；点击 Dock 图标或状态栏“设置”都会打开同一个设置窗口，设置窗口不随失焦隐藏 |
| 权限引导 | Pass | 设置页展示麦克风、浏览器自动化和通知状态；权限区已简化为“状态标签 + 未允许时的操作按钮”，移除绿点/已允许/对勾重复表达；页面自动刷新权限；麦克风可请求或打开系统设置，浏览器自动化优先检查当前浏览器，若设置窗口在前台则回退检查 Chrome，且只在用户点击授权时触发系统弹窗；通知是可选增强，不再用“需要处理”误导用户；辅助功能不是当前 MVP 主链路权限，不再展示；当前 ad-hoc 或变更签名后 macOS 可能把本地 App 视为新权限主体，需要重新允许 |
| 界面中英文切换 | Pass | 设置页、菜单栏、悬浮窗、Provider 表单、枚举标签和主要运行时状态已跟随语言切换 |
| 工作时段配置 | Pass | 设置页支持多个时段、工作日/周末开关，单测覆盖日间、跨午夜、多时段和周末排除 |
| 网站/App 黑名单配置 | Pass | 设置页支持新增、删除、启用/停用规则，并提供常见平台预设；新增本机 App 列表扫描入口，可搜索已安装 App 名称或 Bundle ID 并一键加入 App 黑名单；单测覆盖 `.app` Bundle 元数据读取 |
| 悬浮球/小组件 | Pass | 设置页可开启小组件；悬浮头像固定为圆形裁切，支持上传自定义头像并恢复默认；右下角状态点已移除，时长任务使用头像边缘倒计时环；空闲态悬浮窗为 72×72 透明面板，头像缩到 56×56 收在圆环内侧并内缩绘制圆环，避免方形半透明底板、头像超出圆环和边缘裁切；悬浮球可拖动到任意位置，点击可展开快捷控制菜单，展示倒计时并支持 15/25/40 分钟监督、暂停/恢复和取消；拖动使用鼠标绝对位置和初始点击偏移，拖动期间冻结自动布局刷新，避免组件突然偏移或闪跳；快捷菜单 6 秒无操作自动收起，手动收起时保持悬浮球 top-left 锚点不跳位；进度条用蓝色显示剩余时间；取消会立即结束当前时长任务并停止监督；按住语音键时头像外侧出现绿色呼吸圆环；用户拖动后的窗口位置会被保留，状态变化只调整尺寸不重置坐标；抓包卡片和时长任务 toast 不再展示内部模型/Provider/播放状态，并改为实体白色 popover 背景；音频合成完成后才弹出并同步播放；toast 自动消失，抓包卡片播报结束且用户无操作后自动收起 |
| 语音快速创建监督时长 | Pass | `--smoke-local-voice-focus`：`监督我接下来的四十分钟` WAV -> 本地 SenseVoice 文本 `监督我接下来的四十分钟` -> `focus_minutes=40`；手动语音命令 ASR 改为自动/中英混合，不再跟随 AI 监督语言；单测覆盖“帮我开始一个15分钟的监督任务”“三十五分钟”“半小时”“一个半小时” |
| 时长任务暂停/延长/结束 | Pass | 设置页和菜单栏提供暂停/恢复/延长/结束；GUI 验证 40 分钟任务会启用暂停、+10、结束按钮；单测覆盖 pause/resume/extend |
| 监督结束语音总结 | Pass | 时长任务自然结束会创建本轮完成事件，根据本轮抓包次数分为 0 次彩虹屁、1-3 次鼓励、4 次及以上吐槽；总结语音走当前云端 TTS Provider，不回退系统朗读；单测覆盖过期时长任务只统计 session 时间窗口内抓包次数 |
| ASR 默认链路 | Partial | 默认 ASR 改为云端 API，设置页分段顺序为“云端 API / 本地模型”，并新增 `--smoke-cloud-asr` / `--smoke-cloud-voice-focus` 强制云端验收入口；本地 SenseVoice Small INT8 仍作为用户主动切换后的下载选项。本机已按本轮要求删除 LocalModels/asr，首次下载和下载后识别等待真机复验 |
| LLM 默认链路 | Pass | 默认 LLM 模板仍保留 DeepSeek `deepseek-v4-flash`；当前本机保存运行配置已切到 Xiaomi MiMo `mimo-v2.5` / `https://api.xiaomimimo.com/v1`，复用 App Support `.env.local` 里的 `MIMO_API_KEY`，抓包和回击状态会显示实际 LLM `Provider / Model` |
| Provider 预设 | Pass | 普通设置下拉已扩展为可运行模板：ASR 包含阿里 Paraformer、OpenAI Transcriptions 和 Xiaomi MiMo `mimo-v2.5-asr`；LLM 包含 DeepSeek、Xiaomi MiMo、OpenAI、阿里百炼、Moonshot Kimi、智谱 GLM、火山方舟、腾讯混元；TTS 包含 Xiaomi MiMo、OpenAI 和阿里 CosyVoice。MiniMax、百度千帆、腾讯/火山语音等需专用 adapter 的服务暂不放入普通下拉 |
| TTS 默认链路 | Pass | TTS 回滚为云端 API only，默认 Provider 已切到 Xiaomi MiMo `mimo-v2.5-tts + 白桦`；`MIMO_API_KEY` 已写入本机 App Support `.env.local`，MiMo 鉴权和 `--smoke-llm-tts` 返回 `tts_ok=true`；OpenAI `gpt-4o-mini-tts + coral` 和阿里 `cosyvoice-v3.5-flash` 保留为可选模板 |
| TTS 播放音量 | Pass | 播放器保持满音量；PCM16 WAV 在播放前做 `3.0x` 本地语音增益并安全削峰，覆盖 MiMo 返回的 WAV，不改写云端缓存原始音频；单测覆盖增益和削峰 |
| MiMo 声音克隆 | Pass | 声音页支持授权确认、上传/录制 mp3/wav 样本、保存本机授权样本引用并加入音色下拉；MiMo adapter 对 `voiceclone:<id>` 自动使用 `mimo-v2.5-tts-voiceclone`，合成时把样本 data URI 放入 `audio.voice`；命令行 `--smoke-mimo-voiceclone /path/to/sample.wav` 可做真实接口验收 |
| TTS 本地清理 | Pass | 产品内不再提供本地 TTS 下载、安装、helper 打包或 smoke 入口；本轮 CosyVoice3 本地模型目录、Hugging Face cache 和 helper/cache 已从本机清理 |
| TTS 本地缓存 | Pass | 仅缓存云端 TTS 返回的音频，按 model、voice、language、text 隔离；早前 Qwen TTS、本轮 CosyVoice3 benchmark/cache 和通用 TTS 音频缓存已清理 |
| Provider 可配置 | Pass | 设置页中 ASR/LLM/TTS 三类能力可独立配置；ASR 默认展示云端 API，ASR 分段顺序为“云端 API / 本地模型”；旧版本保存过本地 ASR 的用户会一次性迁移回云端 API，之后用户再手动切换本地模型则按用户选择保留；历史配置选择本地 ASR 但模型或 runtime 未就绪时加载归一回云端 API；ASR/LLM/TTS 云端模式为厂商下拉、可编辑模型 ID 和 API Key，厂商选项只显示厂商名；内置厂商的 Base URL、鉴权头、region、语言提示由 adapter 模板自动处理；每类都提供自定义厂商，可填厂商名、Base URL、模型 ID 和 API Key；仅 ASR 提供本地模型下载入口；开始监督、开始时长任务、麦克风对话和 Provider 测试会先校验 ASR/LLM/TTS，未配好时弹窗列出缺失项并引导去 AI 配置 |
| AI 监工角色 | Pass | 支持学习监督、工作监督、自定义，prompt 已按学习/工作场景注入任务语境，并兼容旧设置迁移；自定义提示词输入使用本地草稿和防抖保存，编辑中不会被页面刷新或状态回灌覆盖，避免光标回退或丢字 |
| 允许强制关闭 | Partial | 开启独立开关后，Hunter 会先弹出抓包卡片并播放包含“我现在就把它关掉”语义的 TTS，播完后网站规则才尝试关闭当前支持浏览器标签页，App 规则才请求退出当前前台 App；仍需 Chrome/Safari 自动化授权后的桌面验收 |
| 吐槽边界配置 | Pass | 支持允许/禁止粗口和禁用词；prompt 已升级为“识别当前内容 -> 输出现场短句”，中文目标 12-26 字、英文目标 7-14 词；若用户允许粗口，prompt 仍按当前强度约束，主要在凶狠模式使用普通脏话增强节目效果；禁用词同时进入 prompt，并对 LLM 输出做本地过滤 |
| 吐槽播报文本清洗 | Pass | LLM 输出进入 TTS 前会本地移除 URL、域名、长 ID 和符号串，并压缩过长中文吐槽；清洗后为空会回退为短提醒，避免把 B 站 BV 号、网页链接或 query 参数逐字念出来 |
| TTS 输出音量 | Pass | 声音页提供输出音量滑块，默认 100%，范围 50%-250%；该值持久化到本机设置，并同时作用于音色试听、抓包播报、语音对喷和总结播报的本地播放增益 |
| 语音对喷链路 | Partial | 代码已从单次回击升级为多轮同上下文对话：用户说完 -> Hunter 生成并播报 -> 播报结束后等待用户再次按住快捷键继续下一轮；不再后台自动开始下一轮录音，避免第二次手动按键和自动录音抢麦克风；抓包卡片按钮改为“按住 {当前快捷键} 对话”，默认 `Option + Space`；设置页快捷键改为单个录制框，点击后直接按新的组合键或单键即可保存，支持右侧 `Option` 这类 modifier-only 单键，并为 modifier-only 全局快捷键补充 `flagsChanged` 监听；按钮本身已改为按下录音、松开发送；用户按住回击键时会先停止当前 TTS 播放再收音，当前抓包卡片、播报、识别、LLM 回击未结束时会延后新的黑名单抓包，避免两段语音重叠；手动回击补充按下/松开/麦克风授权状态/录音诊断和 9 秒安全兜底，已授权时跳过重复权限请求直接录音，未授权弹窗无响应时 2.5 秒后给出可见权限提示；ASR/LLM/TTS 子链路已测，仍需真人靠近麦克风复测按住说话 |
| 前台 App 检测 | Partial | 代码使用 `NSWorkspace.didActivateApplicationNotification` 事件驱动；真实黑名单命中需桌面交互验收 |
| Chrome/Safari/Brave/Edge/Arc URL 检测 | Partial | 仅浏览器前台时启动后台 AppleScript URL/标签标题 watcher；监控循环只做静默自动化权限检查，未授权时跳过读取不弹窗；需浏览器自动化授权后验收 |
| 今日历史统计与清理 | Pass | 历史页展示今日抓包、今日最多命中和清除日志；GUI 验证演示抓包从 10 增至 11，且同次 LLM 升级不重复插入 |
| 本地通知降级反馈 | Pass | 通知授权后，抓包/回击成功会发送无声本地通知 |
| 安全与隐私 | Pass | `.env.local` 被忽略，API Key 写入本机 Application Support `.env.local` 并缓存到内存，运行和保存都不访问 Keychain；第一版已移除联网搜索增强，抓包链路不向搜索服务发送页面标题或域名；仓库未发现明文 key |
| 音色克隆 | Partial | MVP 已移除本地 TTS 克隆入口；声音页按当前 TTS Provider/Model 展示云端授权克隆流程，不再单独选择克隆厂商。MiMo inline 授权样本已有 smoke 路径；阿里 `qwen3-tts-vc*` enrollment 已接入代码路径和 UI 门控；阿里 CosyVoice `voice-enrollment` 已接入百炼临时 `oss://` URL 上传、`create_voice`、`query_voice` 到 `OK` 后保存长期 `voice_id`，正式推荐 `cosyvoice-v3.5-flash`。克隆名称为空时红框提示；点击“设为当前音色”后会有 toast/状态反馈，并清空授权、样本、克隆名称、进度和成功态，方便继续创建新音色。其他厂商/模型显示未适配状态，后续按各厂商克隆 API 单独接入；仍需用真实阿里 Key 和授权样本完成端到端云端验收 |
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
./.build/debug/Hunter --smoke-cloud-asr /tmp/hunter-asr.wav
./.build/debug/Hunter --smoke-cloud-voice-focus /tmp/hunter-asr.wav
./.build/debug/Hunter --smoke-current-context
./scripts/package_app.sh
./scripts/package_dmg.sh
codesign --verify --deep --strict build/Hunter.app
hdiutil verify build/Hunter.dmg
tail -n 40 "$HOME/Library/Application Support/Hunter/Logs/tts.log"
tail -n 40 "$HOME/Library/Application Support/Hunter/Logs/asr.log"
open build/Hunter.app
```
