# Hunter Implementation Status

日期：2026-06-01
状态：MVP 主链路可运行，ASR 默认云端 API，本地 ASR 已接入为可选下载，TTS 已回滚为云端 API only

## 已完成

- Swift Package 原生 macOS 工程骨架。
- 可打包 `.app`：`./scripts/package_app.sh` -> `build/Hunter.app`。
- 可打包 DMG：`./scripts/package_dmg.sh` -> `build/Hunter.dmg`。
- 菜单栏状态入口。
- SwiftUI 设置窗口：General、Watchlist、AI、Voice、History。
- Hunter 打包后已改为普通 macOS App：不再写入 `LSUIElement`，Dock 中会显示 App 图标；状态栏入口继续保留，点击 Dock 图标会重新打开设置窗口。
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
- 对话快捷键默认 `Option + Space`，设置页改为单个可点击快捷键输入框，用户点击后直接按新的组合键或单键即可录制；组合键全局监听走 Carbon HotKey，不依赖辅助功能；抓包卡片按钮改为真正按下录音、松开发送。
- 麦克风短录音入口：悬浮球/快捷键默认 4 秒，设置页“测试语音指令”使用 7 秒窗口便于桌面验收。
- 抓包语音回击支持多轮同上下文对话：用户回击后，Hunter 播报回应并等待用户再次按住快捷键继续下一轮；不再后台自动开始下一轮录音，避免第二次手动按键和自动录音抢麦克风。手动按住回击现在记录按下、松开、麦克风授权状态、录音启动和录音结束诊断；已授权时跳过重复权限请求直接录音，未授权弹窗若无响应会在 2.5 秒后给出可见权限提示；若松开事件丢失，9 秒安全兜底会自动结束本轮录音。
- 抓包卡片展示时机已调整：命中黑名单后先在后台生成吐槽并完成 TTS 合成，音频可播放时才显示抓包卡片并开始播放，避免用户先看到等待状态。
- 抓包卡片已移除内部诊断文案，不再展示本地/云端模型组合、Provider、合成中、播放中等面向开发者的状态；这些信息只保留在设置页 Provider 状态或日志里。卡片和时长任务 toast 改为实体白色 popover 背景并去掉厚重阴影，避免出现灰色半透明外圈；toast 会在约 3.8 秒后自动消失，抓包卡片会在播报结束且用户无操作后自动收起。
- 抓包卡片声波条已接入语音状态：Hunter 播放 TTS 和用户按住录音时动态起伏；转写、思考或空闲时保持静态。
- 录音音量检测：录到明显静音时先给本地提示，减少无效 ASR 请求；ASR 空结果会提示靠近麦克风重试。
- 权限引导：设置页只展示麦克风、浏览器自动化和通知状态；辅助功能不是当前 MVP 主链路所需权限，已从通用权限区移除。麦克风可直接请求或打开系统设置，浏览器自动化优先检查当前浏览器，若设置窗口在前台则回退检查 Chrome，且只在用户点击授权时触发系统弹窗；通知可请求授权，按钮布局改为自适应宽度避免文字裁切。
- 本地通知：如果用户授权通知，抓包/回击成功时会发送无声本地通知作为可见降级反馈。
- 阿里 Paraformer WebSocket ASR 代码路径。
- OpenAI-compatible LLM 抓包吐槽和语音回击代码路径；当前代码默认仍为 DeepSeek `deepseek-v4-flash`，同时预置 Xiaomi MiMo、OpenAI、阿里百炼、Moonshot Kimi、智谱 GLM、火山方舟、腾讯混元的官方模型 ID 候选，例如 `mimo-v2.5-pro`、`qwen3.7-plus`、`kimi-k2.6`、`glm-5.1`、`doubao-seed-2-0-pro-260215`、`hunyuan-t1-latest`；请求体会对 DeepSeek/MiMo/Kimi/GLM/方舟这类 thinking 模型自动关闭 thinking 以保证短吐槽直接出现在 `content`；抓包和回击链路的 Provider 状态会显示实际 `Provider / Model`。
- 抓包 prompt 已升级：输入包含 App、URL host 和标签页标题，要求模型识别用户正在看的具体内容，并输出适合 TTS 的现场短句；中文目标 12-26 字、英文目标 7-14 词，明确禁止输出 URL、域名、query、长 ID、时间戳和符号串；允许粗口时仍按当前强度约束，主要在凶狠/强制档使用普通脏话增强节目效果，并继续过滤禁用词、仇恨辱骂和受保护属性攻击。
- TTS 前文本清洗已接入：LLM 输出进入播报前会本地移除 URL、域名、长 ID 和符号串，并把过长中文吐槽压到短播报长度；如果清洗后只剩空文本，会回退到一句短提醒，避免把网页链接、BV 号或 query 参数逐字念出来。
- 阿里 CosyVoice HTTP TTS 代码路径默认模板已切到 `cosyvoice-v3.5-flash`；正式声音复刻路径优先使用该模型 + 克隆 `voice_id`。
- Xiaomi MiMo V2.5 TTS 代码路径已接入并作为默认 TTS：`https://api.xiaomimimo.com/v1/chat/completions`，模型 `mimo-v2.5-tts`，鉴权头 `api-key`，默认音色 `白桦`，音频从 `choices[0].message.audio.data` base64 解码为 WAV；OpenAI TTS 预设已接入 `POST /audio/speech`，模型 `gpt-4o-mini-tts`，默认音色 `coral`；声音页会按当前 TTS Provider 展示 MiMo、OpenAI 或阿里预置音色，以及与当前 TTS 兼容的已保存克隆音色。
- 声音克隆卡片已改为跟随当前 TTS Provider/Model，不再提供克隆 Provider 下拉。TTS 未配好时展示锁定说明；当前可直接创建的流程支持 MiMo inline 授权样本、阿里 `cosyvoice-v3.5-flash` / `cosyvoice-v3.5-plus` / `cosyvoice-v3-flash` / `cosyvoice-v3-plus` 的 CosyVoice enrollment，以及阿里 `qwen3-tts-vc*` voice enrollment。MiMo 样本复制到本机 `Application Support/Hunter/VoiceSamples/`，合成时自动使用 `mimo-v2.5-tts-voiceclone` 并把样本 data URI 放入 `audio.voice`；阿里 Qwen3-TTS-VC 创建成功后保存 Provider 返回的长期 `voice` id 并用于后续 TTS；阿里 CosyVoice 路径会先把本地样本上传为百炼临时 `oss://` URL，再调用 `voice-enrollment/create_voice`，查询状态为 `OK` 后保存长期 `voice_id`。阿里克隆音色会保存创建时的 `targetModel`，切换到不同 CosyVoice/Qwen TTS 模型时不会误展示或误用旧音色；点击“设为当前音色”后会展示 toast/状态反馈，并清空克隆名称、授权、样本、进度和成功态，回到可继续克隆新音色的状态。
- CosyVoice 返回 `http` 音频文件地址时，运行时会升级为 `https` 再下载，避免打包 App 被 macOS ATS 拦截后无声。
- 播报音量已调到产品可用级：声音页提供“输出音量”滑块，默认 100%，范围 50%-250%，试听和真实抓包/对喷/总结播报共用该值；TTS 音频播放器使用满音量；云端 TTS 请求音量参数提高到 `100`；MiMo 等返回的 PCM16 WAV 会在本地播放前做动态语音增益，默认 `4.5x`，会叠加用户输出音量，低峰值音频会自动补到目标峰值并最高限制在 `14.0x`，同时安全削峰，诊断日志记录 `AUDIO_PLAYER_GAIN_APPLIED`。
- 抓包/对喷播报链路不再静默降级到 macOS 系统朗读；LLM 失败后的兜底吐槽也会继续走当前配置的 TTS，TTS 合成或播放失败会在状态里明确报错。
- TTS 路径诊断日志已接入：`~/Library/Application Support/Hunter/Logs/tts.log` 会记录 `CLOUD_TTS_START` / `CLOUD_TTS_SUCCESS`，并在播放阶段记录 `AUDIO_PLAYER_PLAYING`；当前构建不应再出现 `SYSTEM_SPEECH_START` 或 `LOCAL_TTS_*`，否则代表仍在运行旧版路径。
- TTS 音频本地缓存：只缓存云端 TTS 返回的音频，按 model、voice、language、text 隔离，减少重复合成和延迟。
- ASR / LLM / TTS Provider 配置在设置页独立切换；ASR 默认展示云端 API，分段顺序为“云端 API / 本地模型”；旧版本保存过本地 ASR 的用户会一次性迁移回云端 API，之后用户再手动切换本地模型则按用户选择保留；历史配置若选择本地 ASR 但模型或 runtime 未就绪，会在加载时归一回云端 API。ASR/LLM/TTS 云端能力现在展示厂商下拉、可编辑模型 ID、自动配置摘要和 API Key，厂商选项只显示厂商名；内置厂商的 Base URL、鉴权头、region 与语言提示由 adapter 模板自动处理；每类都提供自定义厂商，可填厂商名、Base URL、模型 ID 和 API Key。ASR 预设包含阿里 Paraformer、OpenAI Transcriptions 和 MiMo ASR，LLM 预设包含 DeepSeek、Xiaomi MiMo、OpenAI、阿里百炼、Moonshot Kimi、智谱 GLM、火山方舟、腾讯混元，TTS 预设包含 Xiaomi MiMo、OpenAI、阿里 CosyVoice 和 Qwen3-TTS 相关模型。用户选择或输入新的模型 ID 后，“更新配置”按钮会变为可点击，点击后保存当前配置并展示成功或失败 toast；API Key 保存/更新也会给出反馈。开始监督、开始时长任务、麦克风对话和 Provider 测试会先校验 ASR/LLM/TTS；任一配置不完整或本地 ASR 未就绪时弹窗列出缺失项并引导去 AI 配置，不进入长时间空转。
- ASR 增加“云端 API / 本地模型”切换；默认新 ASR 配置优先云端 API，让用户先填写自己的 API Key；切换到本地模型后再下载 SenseVoice Small INT8。TTS 只保留云端 API Provider，不提供本地模型下载、安装或切换入口。
- 本地 SenseVoice ASR runtime：下载模型后创建 Hunter 私有 Python runtime，通过 `sherpa_onnx` 本地识别短 WAV，不上传用户录音。
- 本地 ASR 诊断日志已接入：`~/Library/Application Support/Hunter/Logs/asr.log` 记录 `LOCAL_ASR_START` / `LOCAL_ASR_SUCCESS elapsed=...` / `LOCAL_ASR_FAILED`。
- 第一版已移除 Search 增强：设置页不再展示 Search Provider，抓包链路不再调用搜索 API，Voice Agent 不再允许 `set_web_search` 工具。
- Provider 面板提供测试 LLM、测试 TTS、测试 ASR（点击后录一小段麦克风语音并转录）和端到端测试入口。
- 设置页可把每类模型 API Key 分别写入本机 `Application Support/Hunter/.env.local`；运行期热路径只读 `.env.local` / 环境变量 / 内存缓存，不再访问 macOS Keychain。
- 浏览器 URL/标签标题读取已改成先做静默自动化权限检查；未授权时跳过读取，不在监控循环里弹 Chrome/Safari 自动化授权框。
- 声音页保留界面语言、监督语言、吐槽强度、角色、禁用词、TTS 音色选择、声音设计和授权声音克隆；角色为学习监督、工作监督、自定义，强度为温柔、鼓励、正经、凶狠、强制；TTS 音色展示当前云端 Provider 的 voice id 或 voice reference，例如 MiMo `白桦` / `苏打` / `voiceclone:<id>`、OpenAI `coral/alloy/nova`、阿里 `cosyvoice-v3-flash` / `cosyvoice-v3-plus` 的 `longanyang`、已注册的阿里云端克隆 voice id，或用户声音设计生成的 `promptDesignedVoice`。阿里 `cosyvoice-v3.5-flash` / `cosyvoice-v3.5-plus` 不展示系统音色；未选择有效 `voice_id` 时，音色区提示先设置音色，开始监督和麦克风对话会弹窗提示“请先设置音色”。声音设计位于声音克隆上方，用户填写音色名称和声音描述提示词后生成长期 `voice_id`；音色名称必填，提示词 placeholder 聚焦时隐藏；生成时追加轻量正向清晰人声约束，成功后自动设为当前音色并清空表单；不提供预设角色包或批量生成入口。音色列表已移入“音色”卡片，声音克隆卡片只保留克隆流程和简短安全提示。音色按钮已改为试听：点击后合成并播放当前音色短样例，状态区用正文级状态条展示合成、播放、成功或失败。阿里 CosyVoice 合成阶段默认不启用 SSML，也不注入强情感 `instruction`；rate/pitch 保持中性，优先保证克隆和设计音色干净。本地预置 speaker 和本地 TTS 克隆入口仍不开放。
- 本机密钥读取：仓库 `.env.local` / App Support `.env.local` / 环境变量，仓库忽略 `.env.local`。
- 设置页、菜单栏、悬浮小组件和主要运行时状态文案支持中文/英文切换；主要可见控件、枚举标签和 Provider 表单已补齐双语。
- 设置页通用页把“监督状态”和“悬浮小组件显示”拆成两个独立开关；开启监督或时长任务会自动显示悬浮小组件。
- AI 监工角色：学习监督、工作监督、自定义；学习监督和工作监督分别注入学习/工作场景的任务语境，旧设置会迁移到最接近的新角色。
- 自定义人格提示词输入改为本地草稿 + 550ms 防抖持久化；输入框不再每个字符直接写回全局状态，避免 TextEditor 光标回退和丢字。
- 悬浮小组件拖拽改为鼠标绝对位置 + 初始点击偏移，拖动期间冻结自动布局刷新，避免拖动中因 toast/抓包卡片状态变化导致组件偏移或闪跳。
- 抓包和回击语音增加互斥：当前抓包卡片、播报、识别、LLM 回击未结束时延后新的黑名单抓包；用户按住回击键会先停止当前 TTS 播放再收音，避免 Hunter 播报和用户回复/下一次抓包重叠。
- 重复抓包：任意黑名单命中在一次播报流程结束后进入 18 秒全局短冷却；当前卡片未收起、TTS 播放中或用户正在语音回复时也会全局延后新抓包，避免不同 App/网站之间两段语音重叠。
- 强制档：命中后先弹出抓包卡片并播报完整 TTS，文案末尾追加“我现在就把它关掉”语义；播放完成后，网站规则才尝试关闭当前支持浏览器标签页，App 规则才请求退出当前前台 App。关闭动作不绕过全局短冷却；不做断网、远程控制或强杀，仍需真实桌面验收。
- 吐槽边界配置：支持允许/禁止轻度粗口，并支持用户配置禁用词；禁用词会进入 prompt，并在本地对模型输出再过滤一次。
- 登录时启动：已接 `SMAppService` 注册/取消。
- 命令行烟测入口：
  - `./.build/debug/Hunter --smoke-llm-tts`
  - `./.build/debug/Hunter --smoke-llm`
  - `./.build/debug/Hunter --smoke-cloud-asr /path/to/audio.wav`
  - `./.build/debug/Hunter --smoke-cloud-voice-focus /path/to/audio.wav`
  - `./.build/debug/Hunter --install-local-asr`
  - `./.build/debug/Hunter --smoke-local-asr /path/to/audio.wav`
  - `./.build/debug/Hunter --smoke-local-voice-focus /path/to/audio.wav`
  - `./.build/debug/Hunter --smoke-current-context`

## 已验证

- `swift build` 通过。
- `swift test` 通过，测试覆盖时长任务解析、语音控制命令、时长任务暂停/恢复/延长、倒计时环进度、多时段工作时段、工作日/周末开关、黑名单匹配、支持浏览器识别、Provider headers、Provider 默认值、头像和快捷键配置兼容迁移、快捷键组合/单键展示、旧本地音色迁移、TTS 缓存、TTS 下载 URL HTTPS 升级、吐槽 URL/长 ID 清洗、短播报压缩、粗口 opt-in prompt、空文本兜底、禁用词过滤、可见标签双语、语音活动状态、时长任务 toast、事件去重和录音音量检测。
- `swift build -c release` 通过。
- `codesign --verify --deep --strict build/Hunter.app` 通过。
- `./scripts/package_app.sh` 可产出 `build/Hunter.app`。
- `./scripts/package_dmg.sh` 可产出 `build/Hunter.dmg`。
- `hdiutil verify build/Hunter.dmg` 通过。
- `open build/Hunter.app` 可启动 App；CoreGraphics 窗口列表能看到设置窗 `Hunter` 和悬浮窗已创建并 onscreen。已移除打包 App 启动时会卡住的 `Bundle.module` 资源 fallback，悬浮图标资源只从 main bundle 加载。
- 本机 GUI 基础验收通过：Computer Use 可读取设置窗；点击 `40 分钟` 后时长任务显示 `40 分钟`，暂停、+10、结束按钮可用。
- 本机 GUI 演示抓包验收通过：历史页今日抓包从 10 增至 11，新增 12:29 YouTube 抓包仅一条，说明 fallback/LLM 升级去重生效；截图证据在 `/tmp/hunter-history-1229.png`。
- 本机权限验收：麦克风、浏览器自动化和通知状态可在设置页展示；设置页“录制测试”可触发录音、识别中和 ASR 空结果提示。
- 本机正常音量 `say -v Tingting '监督我接下来的四十分钟'` 未被麦克风稳定拾取，界面正确提示“没有识别到语音，请靠近麦克风再试”；仍需真人靠近麦克风做最终语音输入验收。
- 本地 ASR 历史验收通过：`--install-local-asr` 下载 SenseVoice Small INT8 并安装 ASR runtime；系统生成 WAV `监督我接下来的四十分钟` -> `--smoke-local-asr` 识别为 `监督我接下来的四十分钟`；同一段 WAV -> 本地 SenseVoice -> `DurationParser` -> `focus_minutes=40`。2026-06-02 已按首次下载复验需求删除本机 `LocalModels/asr`，需要重新通过设置页或 `--install-local-asr` 做干净下载验收。
- 本地 ASR 耗时历史验收通过：系统生成 WAV `监督我接下来的四十分钟`，`--smoke-local-asr` 5 次结果首轮约 1.05 秒，后续约 0.58-0.64 秒；`--smoke-local-voice-focus` 3 次均解析 `focus_minutes=40`。删除模型后首次下载和冷启动耗时需重新记录。
- 早前 Qwen3-TTS 本地方案已否掉并清理：删除旧 `venv-tts`、`qwen3_tts_clone.py` 和旧 TTS 缓存。
- 2026-06-01 CosyVoice3 0.5B MLX 4bit 本地 TTS 实测后因音质不符合 Hunter 抓包播报要求已回滚；产品内删除本地 TTS 安装、smoke、helper 打包和设置页入口。
- 本机本轮 CosyVoice3 模型目录 `~/Library/Application Support/Hunter/LocalModels/tts`、Hugging Face cache 中的 CosyVoice3 MLX 4bit/8bit、TTS benchmark/cache 目录 `~/Library/Caches/HunterTTSBench` 和通用 TTS 音频缓存 `~/Library/Caches/Hunter/TTS` 已清理；打包 App 不再包含 `speech` helper。
- 阿里 `qwen-turbo` 抓包吐槽烟测曾通过；本机默认 LLM 已切到 DeepSeek `deepseek-v4-flash`，早前 `--smoke-llm` 已用旧本机密钥验证通过。Keychain 访问完全移除后，如果密钥只存在旧钥匙串里，需要在设置页重新保存一次 API Key，或写入 `.env.local` 后再跑烟测。
- 阿里旧 `cosyvoice-v3-flash + longanyang` 极短文本烟测曾通过，TTS 用量 2 字符；当前正式模板已改为 `cosyvoice-v3.5-flash`，需配合克隆/设计 `voice_id` 做新的端到端验收。
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
- 2026-05-30 设置与黑名单补强：快捷键录制补充 `flagsChanged`，支持右侧 `Option` 等单独修饰键，并为 modifier-only 全局快捷键增加按下/松开监听；权限区移除绿点/对勾重复状态，只保留状态标签和未授权操作按钮，增加自动刷新和“重新检查”；黑名单页新增本机 App 扫描、搜索和一键加入 App 黑名单；英文监督语言增加本地兜底，模型返回明显中文时改用英文短句，避免 English 模式仍播中文。
- 2026-05-30 设计开发流程重走：按 `vibe-product-builder` / `prd` / `imagegen-to-html-design` 补全 `docs/PRD.md` 2A 页面结构契约，生成并保存 `docs/design-prototype/redesign-2026-05-30/` 三张参考图和 HTML/覆盖矩阵；SwiftUI 设置窗口改为 196px sidebar、760px 内容宽度、实体白色 settings row、低饱和蓝色选中态和统一 Provider/Watchlist/History 表面；Settings Window 设置为不随失焦隐藏，并保留窗口实例。
- 2026-05-30 HTML 设计稿补齐：重新按 `imagegen-to-html-design` 质量门生成设计系统板、资产表、设置页全量参考图和悬浮组件状态板，并将 `docs/design-prototype/redesign-2026-05-30/index.html` 改为真实 DOM/CSS 可批阅原型；已用本地 HTTP 服务和 Chrome 渲染检查，生成图仅作为底部视觉参考，不再作为整页背景。

## 未完成 / 下一步

- 继续补完整悬浮窗抓包卡片和状态栏菜单验收。
- 验证 Option+Space 组合快捷键的真实按住说话流程。
- 验证连续对喷真实体验：抓包后按住回击一句 -> Hunter 回击 -> 再次按住继续下一轮 -> 用户不再操作后卡片自动收起。
- 真人麦克风端到端验证：语音说“监督我接下来的 40 分钟” -> 生成 Focus Session。
- 端到端验证：进入 YouTube/Bilibili 黑名单 -> LLM 生成吐槽 -> CosyVoice 播放。
- Provider 配置当前是“内置适配器 + 自定义 OpenAI-compatible 端点”模式：LLM 按 `/chat/completions`，ASR 自定义 HTTP 端点按 `/audio/transcriptions`，TTS 自定义 HTTP 端点按 `/audio/speech`；阿里 ASR/TTS 和 MiMo TTS 仍走专用 adapter。后续要支持完全不同协议的供应商时，需要新增 adapter。
- 云端 TTS 已通过命令行烟测；仍需在桌面抓包/对喷真实场景里验收首句等待时间、音量和真人感。
- 云端克隆/音色设计继续按对应 TTS Provider adapter 接入。MiMo `mimo-v2.5-tts-voiceclone` 使用 inline base64 音频样本作为 `audio.voice`，不返回长期 voice id；阿里 `qwen3-tts-vc*` enrollment 返回长期 `voice` id；Hunter 侧使用 `preset voice id / provider voice id / inline authorized sample / prompt voice design` 四类 voice reference，避免只适配单一平台。

## 注意

- HTML 原型中的桌面壁纸、Dock、系统菜单栏不是开发范围。
- 本轮按正常系统音量测试；系统 `say` 播报无法代表真人麦克风输入，最终仍以真人靠近麦克风复测为准。
- 打包脚本会优先使用 `CODESIGN_IDENTITY` 指定的签名身份；未指定时自动选择本机可用的 `Apple Development` 代码签名身份，找不到才回退 ad-hoc。若使用 ad-hoc 或更换签名身份，macOS 仍可能把 `build/Hunter.app` 当成新的麦克风、通知或浏览器自动化权限主体，需要再允许一次。正式分发应使用稳定 Developer ID 签名来避免频繁重授权。
- 云端测试只用极短文本，避免消耗过多免费额度。
