# Hunter Implementation Status

日期：2026-05-30
状态：MVP 主链路可运行，本地 ASR 已接入并通过耗时烟测，本地 TTS 方案已移除，TTS 统一走云端 Provider

## 已完成

- Swift Package 原生 macOS 工程骨架。
- 可打包 `.app`：`./scripts/package_app.sh` -> `build/Hunter.app`。
- 可打包 DMG：`./scripts/package_dmg.sh` -> `build/Hunter.dmg`。
- 菜单栏状态入口。
- SwiftUI 设置窗口：General、Watchlist、AI、Voice、History。
- 设置窗口视觉整理：sidebar 改为整行导航和低饱和选中态；右侧内容限制最大宽度；设置卡片统一图标、说明和控件区；Watchlist 新增规则和 AI Provider 表单改为上标签字段；Provider 测试按钮改为自适应网格，减少字段挤压和布局跳动。
- AppKit 浮动监督窗：悬浮球、抓包卡片、时长任务 toast。
- 悬浮球图标固定为圆形裁切，默认使用 Hunter 墨镜图标；设置页支持上传自定义头像并复制到 Hunter Application Support 目录，也可恢复默认头像；右下角状态点已移除，时长任务改为头像边缘倒计时环；空闲态 NSPanel 使用 72×72 透明 HostingView，头像缩到 56×56 收在圆环内侧，并把圆环向内绘制，避免圆形图标背后出现方形半透明底板、头像超出圆环或四边裁切。
- 悬浮球现在可拖动到任意屏幕位置，也可点击展开快捷控制菜单：展示当前监督/倒计时状态，支持一键开始 15/25/40 分钟监督、暂停/恢复和取消监督；菜单倒计时进度条用蓝色显示剩余时间，取消会立即结束当前时长任务并停止监督，不再保留语义模糊的“停止”按钮；菜单保持实体白色 popover 质感，不打开主设置窗口。
- 按住全局对话快捷键或抓包卡片按钮录音时，悬浮球外侧会出现绿色呼吸圆环，给用户明确的收音反馈；语音说“帮我开始一个15分钟的监督任务”会直接创建时长任务。
- 悬浮窗位置现在尊重用户拖动后的窗口 origin；toast、抓包卡片和状态变化只调整窗口尺寸，不再把窗口强行拉回默认坐标。
- 工作时段配置：支持全天监督或多个开始/结束时间段，支持工作日/周末开关，跨午夜时段可用。
- 时长任务控制：支持暂停、恢复、延长 10 分钟和结束；语音指令可识别暂停/恢复/结束/延长。
- 黑名单配置：支持新增、删除、启用/停用网站和 App 规则，内置常见平台预设。
- 前台 App 检测：`NSWorkspace.didActivateApplicationNotification` 事件驱动，切换 App 后立即匹配 App 黑名单。
- Chrome/Safari/Brave/Edge/Arc URL/标题读取：仅当前台是支持的浏览器且监督生效时启动 1.5 秒 URL watcher，AppleScript 在后台任务执行并按 URL + 标签标题去重；非浏览器前台不读取 URL。
- 黑名单命中、冷却、事件日志。
- 历史记录：展示今日抓包次数、今日最多命中对象和本地事件列表，支持清除本地日志；同一次抓包的 fallback/LLM 升级会按事件 ID 更新，避免重复插入。
- 语音时长任务解析：中文/英文样例已加测试。
- 对话快捷键默认 `Option + Space`，设置页改为单个可点击快捷键输入框，用户点击后直接按新的组合键或单键即可录制；全局快捷键已从辅助功能 event tap 改为 Carbon HotKey 注册，降低签名变化后权限失效导致“按键没反应”的风险；抓包卡片按钮改为真正按下录音、松开发送。
- 麦克风短录音入口：悬浮球/快捷键默认 4 秒，设置页“测试语音指令”使用 7 秒窗口便于桌面验收。
- 抓包语音回击支持多轮同上下文对话：用户回击后，Hunter 播报回应并等待用户再次按住快捷键继续下一轮；不再后台自动开始下一轮录音，避免第二次手动按键和自动录音抢麦克风。手动按住回击现在记录按下、松开、麦克风授权状态、录音启动和录音结束诊断；已授权时跳过重复权限请求直接录音，未授权弹窗若无响应会在 2.5 秒后给出可见权限提示；若松开事件丢失，9 秒安全兜底会自动结束本轮录音。
- 抓包卡片展示时机已调整：命中黑名单后先在后台生成吐槽并完成 TTS 合成，音频可播放时才显示抓包卡片并开始播放，避免用户先看到等待状态。
- 抓包卡片已移除内部诊断文案，不再展示本地/云端模型组合、Provider、合成中、播放中等面向开发者的状态；这些信息只保留在设置页 Provider 状态或日志里。卡片和时长任务 toast 改为实体白色 popover 背景并去掉厚重阴影，避免出现灰色半透明外圈；toast 会在约 3.8 秒后自动消失，抓包卡片会在播报结束且用户无操作后自动收起。
- 抓包卡片声波条已接入语音状态：Hunter 播放 TTS 和用户按住录音时动态起伏；转写、思考或空闲时保持静态。
- 录音音量检测：录到明显静音时先给本地提示，减少无效 ASR 请求；ASR 空结果会提示靠近麦克风重试。
- 权限引导：设置页展示麦克风、浏览器自动化、通知和辅助功能（可选）状态；麦克风可直接请求或打开系统设置，浏览器自动化优先检查当前浏览器，若设置窗口在前台则回退检查 Chrome，且只在用户点击授权时触发系统弹窗；通知可请求授权，按钮布局改为自适应宽度避免文字裁切。
- 本地通知：如果用户授权通知，抓包/回击成功时会发送无声本地通知作为可见降级反馈。
- 阿里 Paraformer WebSocket ASR 代码路径。
- OpenAI-compatible LLM 抓包吐槽和语音回击代码路径；当前本机默认和已保存运行配置均为 DeepSeek `deepseek-v4-flash`，请求体会对 DeepSeek V4 自动关闭 thinking 以保证短吐槽直接出现在 `content`；抓包和回击链路的 Provider 状态会显示实际 `Provider / Model`，避免和千问云 TTS 额度混淆。
- 抓包 prompt 已升级：输入包含 App、URL、标签页标题和可选搜索摘要，要求模型识别用户正在看的具体内容，并输出适合 TTS 的现场短句；中文目标 12-26 字、英文目标 7-14 词，明确禁止输出 URL、域名、query、长 ID、时间戳和符号串；允许粗口时测试阶段会明确要求使用普通脏话增强节目效果，但仍过滤禁用词、仇恨辱骂和受保护属性攻击。
- TTS 前文本清洗已接入：LLM 输出进入播报前会本地移除 URL、域名、长 ID 和符号串，并把过长中文吐槽压到短播报长度；如果清洗后只剩空文本，会回退到一句短提醒，避免把网页链接、BV 号或 query 参数逐字念出来。
- 阿里 CosyVoice HTTP TTS 代码路径，默认 `cosyvoice-v3-flash + longanyang`。
- CosyVoice 返回 `http` 音频文件地址时，运行时会升级为 `https` 再下载，避免打包 App 被 macOS ATS 拦截后无声。
- 播报音量已调到产品可用级：本地/云端音频播放器均使用满音量；云端 TTS 请求音量参数提高到 `100`。
- 抓包/对喷播报链路不再静默降级到 macOS 系统朗读；LLM 失败后的兜底吐槽也会继续走当前配置的 TTS，TTS 合成或播放失败会在状态里明确报错。
- TTS 路径诊断日志已接入：`~/Library/Application Support/Hunter/Logs/tts.log` 会记录 `CLOUD_TTS_START` / `CLOUD_TTS_SUCCESS` 和 `AUDIO_PLAYER_PLAYING`；当前构建不应再出现 `SYSTEM_SPEECH_START` 或 `LOCAL_TTS_START`，若出现代表仍在运行旧版。
- TTS 音频本地缓存：按 model、voice、language、text 缓存云端生成的 WAV，减少重复云端调用和延迟。
- ASR / LLM / TTS / Search Provider 配置在设置页可编辑，四类能力互不联动；云端能力只展示 Provider、Base URL、Model 和 API Key。
- ASR 增加“本地模型 / 云端 API”切换；默认新配置优先本地 SenseVoice Small INT8，并提供下载到本机按钮。TTS 不再提供本地模型模式。
- 本地 SenseVoice ASR runtime：下载模型后创建 Hunter 私有 Python runtime，通过 `sherpa_onnx` 本地识别短 WAV，不上传用户录音。
- 本地 ASR 诊断日志已接入：`~/Library/Application Support/Hunter/Logs/asr.log` 记录 `LOCAL_ASR_START` / `LOCAL_ASR_SUCCESS elapsed=...` / `LOCAL_ASR_FAILED`。
- Search 增强：默认关闭；开启后可选 Brave Search 或 Tavily，用当前页面标题/域名做 query，取 3 条摘要给 LLM 增强吐槽。
- Provider 面板提供测试 LLM、测试 TTS、测试 ASR（选择本地音频文件）、测试搜索和端到端测试入口。
- 设置页可把每类模型/搜索的 API Key 分别写入本机 `Application Support/Hunter/.env.local`；运行期热路径只读 `.env.local` / 环境变量 / 内存缓存，不再访问 macOS Keychain。
- 浏览器 URL/标签标题读取已改成先做静默自动化权限检查；未授权时跳过读取，不在监控循环里弹 Chrome/Safari 自动化授权框。
- 声音页仅保留界面语言、监督语言、吐槽强度、角色、禁用词和云端 TTS voice id；本地预置 speaker、声音样本上传/录制和本地克隆入口已移除。
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
  - `./.build/debug/Hunter --smoke-current-context`

## 已验证

- `swift build` 通过。
- `swift test` 通过，34 个测试覆盖时长任务解析、语音控制命令、时长任务暂停/恢复/延长、倒计时环进度、多时段工作时段、工作日/周末开关、黑名单匹配、支持浏览器识别、Provider headers、Provider 默认值、Search 默认配置与 key 分流、头像和快捷键配置兼容迁移、快捷键组合/单键展示、旧本地音色迁移、TTS 缓存、TTS 下载 URL HTTPS 升级、吐槽 URL/长 ID 清洗、短播报压缩、粗口 opt-in prompt、空文本兜底、禁用词过滤、可见标签双语、语音活动状态、时长任务 toast、事件去重和录音音量检测。
- `swift build -c release` 通过。
- `codesign --verify --deep --strict build/Hunter.app` 通过。
- `./scripts/package_app.sh` 可产出 `build/Hunter.app`。
- `./scripts/package_dmg.sh` 可产出 `build/Hunter.dmg`。
- `hdiutil verify build/Hunter.dmg` 通过。
- `open build/Hunter.app` 可启动 App；CoreGraphics 窗口列表能看到设置窗 `Hunter` 和悬浮窗已创建并 onscreen。已移除打包 App 启动时会卡住的 `Bundle.module` 资源 fallback，悬浮图标资源只从 main bundle 加载。
- 本机 GUI 基础验收通过：Computer Use 可读取设置窗；点击 `40 分钟` 后时长任务显示 `40 分钟`，暂停、+10、结束按钮可用。
- 本机 GUI 演示抓包验收通过：历史页今日抓包从 10 增至 11，新增 12:29 YouTube 抓包仅一条，说明 fallback/LLM 升级去重生效；截图证据在 `/tmp/hunter-history-1229.png`。
- 本机权限验收：辅助功能和麦克风均已允许；设置页“录制测试”可触发录音、识别中和 ASR 空结果提示。
- 本机正常音量 `say -v Tingting '监督我接下来的四十分钟'` 未被麦克风稳定拾取，界面正确提示“没有识别到语音，请靠近麦克风再试”；仍需真人靠近麦克风做最终语音输入验收。
- 本地 ASR 安装通过：`--install-local-asr` 下载 SenseVoice Small INT8 并安装 ASR runtime。
- 本地 ASR 烟测通过：系统生成 WAV `监督我接下来的四十分钟` -> `--smoke-local-asr` 识别为 `监督我接下来的四十分钟`。
- 本地语音时长任务烟测通过：同一段 WAV -> 本地 SenseVoice -> `DurationParser` -> `focus_minutes=40`。
- 本地 ASR 耗时烟测通过：系统生成 WAV `监督我接下来的四十分钟`，`--smoke-local-asr` 5 次结果首轮约 1.05 秒，后续约 0.58-0.64 秒；`--smoke-local-voice-focus` 3 次均解析 `focus_minutes=40`。
- 本地 TTS 方案已否掉并清理：删除 `~/Library/Application Support/Hunter/LocalModels/tts`、`~/Library/Application Support/Hunter/LocalRuntime/venv-tts`、`qwen3_tts_clone.py` 和 `~/Library/Caches/Hunter/TTS`。
- 阿里 `qwen-turbo` 抓包吐槽烟测曾通过；本机默认 LLM 已切到 DeepSeek `deepseek-v4-flash`，早前 `--smoke-llm` 已用旧本机密钥验证通过。Keychain 访问完全移除后，如果密钥只存在旧钥匙串里，需要在设置页重新保存一次 API Key，或写入 `.env.local` 后再跑烟测。
- 阿里 `cosyvoice-v3-flash + longanyang` 极短文本烟测通过，TTS 用量 2 字符。
- 阿里 `paraformer-realtime-v2` ASR 烟测通过：系统生成 WAV `监督我接下来的四十分钟` -> 识别为 `监督我接下来的40分钟。`
- 语音时长任务烟测通过：同一段 WAV -> ASR -> `DurationParser` -> `focus_minutes=40`。
- 阿里 LLM/TTS 烟测已验证角色 prompt 生效：老板口吻输出可用。
- 吐槽边界改动后，阿里 LLM/TTS 烟测再次通过：`llm_ok=true`、`tts_ok=true`。
- 默认 Provider 配置改为可编辑后，阿里默认链路再次通过 LLM/TTS/ASR 烟测；DeepSeek 默认 LLM 配置已落到代码路径并完成 LLM 单项烟测。
- 2026-05-29 重新创建并保存千问云标准 API Key 后，千问云鉴权探测返回 HTTP 200；本机 App Support `.env.local` 同时保存 `DASHSCOPE_API_KEY` 和 `DEEPSEEK_API_KEY`。
- 2026-05-29 当前测试链路确认：`--smoke-llm` 使用 DeepSeek `deepseek-v4-flash` 且 `llm_ok=true`；`--smoke-llm-tts` 使用 DeepSeek 生成吐槽，并用千问云 CosyVoice 合成，`tts_ok=true`、`tts_bytes=61484`。
- 2026-05-29 短吐槽改动后，`--smoke-llm` 使用 DeepSeek 输出单句短吐槽，且未包含 URL 或长 ID。
- 2026-05-30 UI 修正验收：快捷键设置页展示单个录制框 `Option + Space`，权限按钮无文字裁切；悬浮球可拖动，拖动后窗口坐标从 `X=463,Y=720` 移到 `X=614,Y=724`；快捷菜单展示蓝色剩余进度条且只保留“暂停/取消”；点击“取消”后本机保存状态为 `isMonitoring=0`、`focusSession=nil`。
- 2026-05-30 LLM 链路复核：本机保存运行配置为 DeepSeek `https://api.deepseek.com` / `deepseek-v4-flash`；`./build/Hunter.app/Contents/MacOS/Hunter --smoke-llm` 返回 `llm_ok=true`、`llm_provider=DeepSeek`、`llm_model=deepseek-v4-flash`。千问云/DashScope 仍只用于当前 TTS Provider。
- 2026-05-30 设置页 UI QA：设置窗口最小宽度和可见区夹取已修正，重新打包启动后 sidebar 未再被裁切；通用、黑名单、AI、声音、历史页用 Computer Use 逐页检查，布局无明显遮挡；快捷键录制框实测点击后按 `A` 可写入单键快捷键，随后已重置回 `Option + Space`；AI 配置页已保存的 DeepSeek / DashScope API Key 显示为 `•••••••••• + 已保存`；声音页露出云端“音色克隆”区域，并将上传/录制样本标为待接入。
- 2026-05-30 悬浮与时长任务体验补强：快捷菜单 6 秒无操作自动收起，窗口尺寸变化时保留 top-left 锚点避免收起后跳位；手动语音命令 ASR 改为自动/中英混合，不再跟随 AI 监督语言；`DurationParser` 新增“三十五分钟”“半小时”“一个半小时”等口语时长；时长任务自然结束后生成本轮完成事件，生命周期检查收敛到约 2 秒，并按抓包次数播放 0 次夸奖、1-3 次鼓励、4 次以上吐槽式总结。

## 未完成 / 下一步

- 继续补完整悬浮窗抓包卡片和状态栏菜单验收。
- 验证 Option+Space 辅助功能授权后的真实按住说话流程。
- 验证连续对喷真实体验：抓包后按住回击一句 -> Hunter 回击 -> 再次按住继续下一轮 -> 用户不再操作后卡片自动收起。
- 使用真实 Brave/Tavily API Key 验证搜索增强：命中 YouTube/Bilibili 后拿到搜索摘要并进入 prompt。
- 真人麦克风端到端验证：语音说“监督我接下来的 40 分钟” -> 生成 Focus Session。
- 端到端验证：进入 YouTube/Bilibili 黑名单 -> LLM 生成吐槽 -> CosyVoice 播放。
- Provider 配置当前是“内置适配器 + 可编辑端点”模式：LLM 按 OpenAI-compatible Chat Completions 形态调用，ASR/TTS 按阿里适配器形态调用；后续要支持完全不同协议的供应商时，需要新增 adapter。
- 云端 TTS 已用真实 Provider Key 通过命令行端到端烟测；仍需在桌面抓包/对喷真实场景里验收首句等待时间、音量和真人感。
- 云端克隆/音色设计如果要回归，需接对应 TTS Provider adapter，只保存授权 voice id，不恢复本地 TTS 模型。

## 注意

- HTML 原型中的桌面壁纸、Dock、系统菜单栏不是开发范围。
- 本轮按正常系统音量测试；系统 `say` 播报无法代表真人麦克风输入，最终仍以真人靠近麦克风复测为准。
- 当前本地包使用 ad-hoc 重新签名；每次重新打包后 macOS 可能把 `build/Hunter.app` 当成新的麦克风权限主体，需要再允许一次麦克风。正式分发应使用稳定 Developer ID 签名来避免频繁重授权。
- 云端测试只用极短文本，避免消耗过多免费额度。
