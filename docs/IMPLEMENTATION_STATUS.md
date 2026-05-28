# Hunter Implementation Status

日期：2026-05-28
状态：MVP 主链路可运行，本地 ASR 已接入并通过烟测，TTS 本地克隆 worker 已接入调用路径并保留系统语音降级

## 已完成

- Swift Package 原生 macOS 工程骨架。
- 可打包 `.app`：`./scripts/package_app.sh` -> `build/Hunter.app`。
- 可打包 DMG：`./scripts/package_dmg.sh` -> `build/Hunter.dmg`。
- 菜单栏状态入口。
- SwiftUI 设置窗口：General、Watchlist、AI、Voice、History。
- AppKit 浮动监督窗：悬浮球、抓包卡片、时长任务 toast。
- 工作时段配置：支持全天监督或多个开始/结束时间段，支持工作日/周末开关，跨午夜时段可用。
- 时长任务控制：支持暂停、恢复、延长 10 分钟和结束；语音指令可识别暂停/恢复/结束/延长。
- 黑名单配置：支持新增、删除、启用/停用网站和 App 规则，内置常见平台预设。
- 前台 App 检测：`NSWorkspace.didActivateApplicationNotification` 事件驱动，切换 App 后立即匹配 App 黑名单。
- Chrome/Safari/Brave/Edge/Arc URL/标题读取：仅当前台是支持的浏览器且监督生效时启动 1.5 秒 URL watcher，AppleScript 在后台任务执行并按 URL + 标签标题去重；非浏览器前台不读取 URL。
- 黑名单命中、冷却、事件日志。
- 历史记录：展示今日抓包次数、今日最多命中对象和本地事件列表，支持清除本地日志；同一次抓包的 fallback/LLM 升级会按事件 ID 更新，避免重复插入。
- 语音时长任务解析：中文/英文样例已加测试。
- Option+Space 全局事件监听入口，未授权时只提示需要辅助功能权限，不在启动时反复弹系统授权请求。
- 麦克风短录音入口：悬浮球/快捷键默认 4 秒，设置页“录制测试”使用 7 秒窗口便于桌面验收。
- 抓包语音回击已升级为连续对喷：用户回击后，Hunter 等待自己播报结束再自动继续监听；若下一轮录音为空或识别不到语音，则自动结束对喷。
- 录音音量检测：录到明显静音时先给本地提示，减少无效 ASR 请求；ASR 空结果会提示靠近麦克风重试。
- 权限引导：设置页展示辅助功能、麦克风、通知状态；支持打开对应系统设置或请求通知权限。
- 本地通知：如果用户授权通知，抓包/回击成功时会发送无声本地通知作为可见降级反馈。
- 阿里 Paraformer WebSocket ASR 代码路径。
- OpenAI-compatible LLM 抓包吐槽和语音回击代码路径；当前本机默认 LLM 配置为 DeepSeek `deepseek-v4-flash`，请求体会对 DeepSeek V4 自动关闭 thinking 以保证短吐槽直接出现在 `content`。
- 抓包 prompt 已升级：输入包含 App、URL、标签页标题和可选搜索摘要，要求模型先识别用户正在看的具体内容，再把它和逃避工作连接起来，最后输出短 punchline；允许粗口时可使用普通脏话，但仍过滤禁用词和受保护属性攻击。
- 阿里 CosyVoice HTTP TTS 代码路径，默认 `cosyvoice-v3-flash + longanyang`。
- 播报音量已调到产品可用级：本地系统朗读、云端音频播放器均使用满音量；云端 TTS 请求音量参数提高到 `100`。
- TTS 音频本地缓存：按 model、voice、language、text 缓存 WAV，减少重复云端调用和延迟。
- ASR / LLM / TTS / Search Provider 配置在设置页可编辑，四类能力互不联动；每类只展示 Provider、Base URL、Model 和 API Key。
- ASR / TTS 增加“本地模型 / 云端 API”切换；默认新配置优先本地模式，本地 ASR 推荐 SenseVoice Small INT8，本地 TTS 推荐 Qwen3-TTS 0.6B Base，并提供下载到本机按钮。
- 本地 SenseVoice ASR runtime：下载模型后创建 Hunter 私有 Python runtime，通过 `sherpa_onnx` 本地识别短 WAV，不上传用户录音。
- 本地 Qwen3-TTS 克隆 worker：已接入本地模型、授权样本和参考文本参数；未配置样本/模型或运行失败时，使用 macOS 系统语音本地降级。
- Search 增强：默认关闭；开启后可选 Brave Search 或 Tavily，用当前页面标题/域名做 query，取 3 条摘要给 LLM 增强吐槽。
- Provider 面板提供测试 LLM、测试 TTS、测试 ASR（选择本地音频文件）、测试搜索和端到端测试入口。
- 设置页可把每类模型/搜索的 API Key 分别写入本机 `Application Support/Hunter/.env.local`；运行期热路径只读 `.env.local` / 环境变量 / 内存缓存，不再访问 macOS Keychain。
- 浏览器 URL/标签标题读取已改成先做静默自动化权限检查；未授权时跳过读取，不在监控循环里弹 Chrome/Safari 自动化授权框。
- 声音页支持预置音色和克隆声音入口；用户可选择本地音频样本或直接录制声音样本，样本保存到本机 Application Support。
- 本机密钥读取：仓库 `.env.local` / App Support `.env.local` / 环境变量，仓库忽略 `.env.local`。
- 设置页、菜单栏、悬浮小组件和主要运行时状态文案支持中文/英文切换；主要可见控件、枚举标签和 Provider 表单已补齐双语。
- 设置页通用页把“监督状态”和“悬浮小组件显示”拆成两个独立开关；开启监督或时长任务会自动显示悬浮小组件。
- AI 监工角色：自律教练、办公室老板、冷面助理、脱口秀损友。
- 吐槽边界配置：支持允许/禁止轻度粗口，并支持用户配置禁用词；禁用词会进入 prompt，并在本地对模型输出再过滤一次。
- 登录时启动：已接 `SMAppService` 注册/取消。
- 命令行烟测入口：
  - `./.build/debug/Hunter --smoke-llm-tts`
  - `./.build/debug/Hunter --smoke-llm`
  - `./.build/debug/Hunter --smoke-asr /path/to/audio.wav`
  - `./.build/debug/Hunter --smoke-voice-focus /path/to/audio.wav`
  - `./.build/debug/Hunter --install-local-asr`
  - `./.build/debug/Hunter --smoke-local-asr /path/to/audio.wav`
  - `./.build/debug/Hunter --smoke-local-voice-focus /path/to/audio.wav`
  - `./.build/debug/Hunter --install-local-tts`
  - `./.build/debug/Hunter --smoke-local-tts "文本" /path/to/ref-audio.wav`
  - `./.build/debug/Hunter --smoke-current-context`

## 已验证

- `swift build` 通过。
- `swift test` 通过，21 个测试覆盖时长任务解析、语音控制命令、时长任务暂停/恢复/延长、多时段工作时段、工作日/周末开关、黑名单匹配、支持浏览器识别、Provider headers、Provider 默认值、Search 默认配置与 key 分流、TTS 缓存、禁用词过滤、可见标签双语、事件去重和录音音量检测。
- `swift build -c release` 通过。
- `codesign --verify --deep --strict build/Hunter.app` 通过。
- `./scripts/package_app.sh` 可产出 `build/Hunter.app`。
- `./scripts/package_dmg.sh` 可产出 `build/Hunter.dmg`。
- `hdiutil verify build/Hunter.dmg` 通过。
- `open build/Hunter.app` 可启动 App；CoreGraphics 窗口列表能看到设置窗 `Hunter` 和悬浮窗已创建并 onscreen。
- 本机 GUI 基础验收通过：Computer Use 可读取设置窗；点击 `40 分钟` 后时长任务显示 `40 分钟`，暂停、+10、结束按钮可用。
- 本机 GUI 演示抓包验收通过：历史页今日抓包从 10 增至 11，新增 12:29 YouTube 抓包仅一条，说明 fallback/LLM 升级去重生效；截图证据在 `/tmp/hunter-history-1229.png`。
- 本机权限验收：辅助功能和麦克风均已允许；设置页“录制测试”可触发录音、识别中和 ASR 空结果提示。
- 本机正常音量 `say -v Tingting '监督我接下来的四十分钟'` 未被麦克风稳定拾取，界面正确提示“没有识别到语音，请靠近麦克风再试”；仍需真人靠近麦克风做最终语音输入验收。
- 本地 ASR 安装通过：`--install-local-asr` 下载 SenseVoice Small INT8 并安装 ASR runtime。
- 本地 ASR 烟测通过：系统生成 WAV `监督我接下来的四十分钟` -> `--smoke-local-asr` 识别为 `监督我接下来的四十分钟`。
- 本地语音时长任务烟测通过：同一段 WAV -> 本地 SenseVoice -> `DurationParser` -> `focus_minutes=40`。
- 阿里 `qwen-turbo` 抓包吐槽烟测曾通过；本机默认 LLM 已切到 DeepSeek `deepseek-v4-flash`，早前 `--smoke-llm` 已用旧本机密钥验证通过。Keychain 访问完全移除后，如果密钥只存在旧钥匙串里，需要在设置页重新保存一次 API Key，或写入 `.env.local` 后再跑烟测。
- 阿里 `cosyvoice-v3-flash + longanyang` 极短文本烟测通过，TTS 用量 2 字符。
- 阿里 `paraformer-realtime-v2` ASR 烟测通过：系统生成 WAV `监督我接下来的四十分钟` -> 识别为 `监督我接下来的40分钟。`
- 语音时长任务烟测通过：同一段 WAV -> ASR -> `DurationParser` -> `focus_minutes=40`。
- 阿里 LLM/TTS 烟测已验证角色 prompt 生效：老板口吻输出可用。
- 吐槽边界改动后，阿里 LLM/TTS 烟测再次通过：`llm_ok=true`、`tts_ok=true`。
- 默认 Provider 配置改为可编辑后，阿里默认链路再次通过 LLM/TTS/ASR 烟测；DeepSeek 默认 LLM 配置已落到代码路径并完成 LLM 单项烟测。

## 未完成 / 下一步

- 继续补完整悬浮窗抓包卡片和状态栏菜单验收。
- 验证 Option+Space 辅助功能授权后的真实按住说话流程。
- 验证连续对喷真实体验：抓包后回击一句 -> Hunter 回击 -> 自动继续监听 -> 用户静音后结束。
- 使用真实 Brave/Tavily API Key 验证搜索增强：命中 YouTube/Bilibili 后拿到搜索摘要并进入 prompt。
- 真人麦克风端到端验证：语音说“监督我接下来的 40 分钟” -> 生成 Focus Session。
- 端到端验证：进入 YouTube/Bilibili 黑名单 -> LLM 生成吐槽 -> CosyVoice 播放。
- Provider 配置当前是“内置适配器 + 可编辑端点”模式：LLM 按 OpenAI-compatible Chat Completions 形态调用，ASR/TTS 按阿里适配器形态调用；后续要支持完全不同协议的供应商时，需要新增 adapter。
- 本地 Qwen3-TTS 模型体积大，需继续在 Apple Silicon 低/中/高配机器上压测首次合成延迟和内存占用。
- 声音克隆目前已支持授权确认、本机样本上传/录制、参考文本和样本路径持久化；云端克隆生成音色 ID 仍需接入对应 TTS Provider adapter。

## 注意

- HTML 原型中的桌面壁纸、Dock、系统菜单栏不是开发范围。
- 本轮按正常系统音量测试；系统 `say` 播报无法代表真人麦克风输入，最终仍以真人靠近麦克风复测为准。
- 云端测试只用极短文本，避免消耗过多免费额度。
