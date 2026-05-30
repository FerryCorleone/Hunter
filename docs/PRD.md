# Hunter PRD

版本：v0.9
日期：2026-05-30
状态：页面结构契约锁定，设置页重构中

## 0. Discovery Notes

已知输入：

- 目标平台：Mac 桌面端。
- 核心玩法：工作时间内通过桌面悬浮球/小组件监控摸鱼网站/App，命中后 AI 语音高强度吐槽。
- 语音互动路线：`ASR -> LLM -> TTS`；ASR 支持云端 API 和本地模型，TTS 统一走云端 Provider。
- ASR、LLM、TTS 均需要做成用户可配置 Provider；当前本机 LLM 测试链路先用 DeepSeek `deepseek-v4-flash`。
- ASR 要提供本地模型下载入口；首选本地 ASR 为 SenseVoice Small INT8。
- TTS 需要支持用户指定云端音色 ID；本地 TTS 方案已否掉，MVP 不再提供本地 TTS 下载、Qwen worker 或本机声音克隆入口。
- 软件界面需要支持中英文。
- AI 监督和语音对喷内容需要支持中文和英文。
- 悬浮球需要支持语音快速创建时长任务，例如“监督我接下来的 40 分钟”。
- 当前阶段产出可运行原生 macOS App、PRD、设计稿、技术评估、验收清单和可打包 DMG。

待确认问题：

- 第一批黑名单是否以中文互联网内容平台为主，还是同时覆盖海外网站和游戏类 App？
- 吐槽“脏话”边界要做到什么程度：轻粗口、强羞辱、还是只允许用户自定义角色包？
- 第一版是否需要真的阻断摸鱼行为，还是只做语音抓包和日志？
- 首批 Provider 模板除阿里外，是否需要预置 OpenAI、火山引擎、腾讯云、MiniMax 等？

## 1. Executive Summary

**Problem Statement**  
普通效率工具太严肃、太弱提醒，用户容易忽略；而“被 AI 当场抓包并开骂”的强冲突体验更容易制造自律压力和传播素材。

**Proposed Solution**  
开发一个 Mac 端轻量 AI 监工应用。主体验是桌面悬浮球/小组件：用户配置工作时间、黑名单和 ASR/LLM/TTS Provider 后，Hunter 在后台检测前台 App、浏览器 URL 与标签页标题；一旦命中摸鱼目标，先在后台调用 LLM 和 TTS 准备第一句吐槽音频，音频可播放后再展开悬浮小组件并同步播报。用户可开启联网搜索增强，让 Hunter 用当前页面标题/域名取少量搜索摘要，使吐槽更贴合用户正在看的内容。用户可以用快捷键或悬浮卡片按钮语音反驳，系统通过 ASR 转写后继续生成语音回应。主窗口只承载设置、Provider、历史记录和语言/音色配置。

**Success Criteria**

- 黑名单命中后 2 秒内出现可见抓包反馈，5 秒内完成首句语音播报。
- 悬浮球常驻桌面时不遮挡主要工作内容，默认尺寸 <= 64px；抓包展开态宽度 <= 360px。
- Chrome/Safari/App 三类检测在本机测试中命中准确率 >= 95%。
- 用户完成从安装、授权、配置黑名单到启动监控的时间 <= 3 分钟。
- 日常 30 次抓包 + 10 分钟语音反驳的云端成本目标 < 1 元/天。
- MVP 内部测试中，80% 以上的抓包事件能产生可用于录屏传播的短句。
- ASR/LLM/TTS Provider 可以分别切换，用户可以用自己的 API Key 跑通完整语音链路。
- 界面中英文切换覆盖 100% MVP 可见文案；AI 监督语言可独立选择中文或英文。

## 2. User Experience & Functionality

### User Personas

- 内容创作者：想拍“AI 监督挑战”“办公室自律实验”类视频，需要强节目效果。
- 自律困难用户：希望通过羞耻感、冲突感和声音提醒减少摸鱼。
- AI 工具玩家：想体验可对喷的桌面 AI 角色，不只是普通提醒工具。

### Core User Flow

1. 用户首次打开 Hunter。
2. 完成权限引导：辅助功能、自动化、麦克风、通知。
3. 设置工作时间。
4. 添加网站/App 黑名单。
5. 选择界面语言和 AI 监督语言。
6. 配置 ASR/LLM/TTS；默认 LLM 使用 DeepSeek API，默认 ASR 使用本地 SenseVoice，TTS 使用云端 Provider。
7. 选择 AI 监工角色、吐槽强度和 TTS 音色。
8. 点击“开始监督”，桌面出现轻量悬浮球。
9. 用户也可以按住快捷键说“监督我接下来的 40 分钟”，Hunter 解析出时长并立刻开启一个 40 分钟 Focus Session。
10. 用户进入黑名单 App 或网站。
11. LLM + TTS 准备好第一句音频后，悬浮球展开成小组件并同步开始语音吐槽。
12. 用户按住快捷键语音反驳。
13. Hunter 转写用户语音，生成反击文案，并继续播报。
14. 主窗口历史记录展示抓包次数、摸鱼时长、命中目标和经典语录。

### User Stories And Acceptance Criteria

**Story 1：配置工作时间**  
As a user, I want to define my work schedule so that Hunter only supervises me during the periods I care about.

Acceptance Criteria:

- 支持添加多个工作时间段。
- 支持工作日/周末开关。
- 工作时间外不触发语音吐槽。
- 临时暂停后不清空原配置。

**Story 2：配置网站和 App 黑名单**  
As a user, I want to define websites and apps that count as slacking so that Hunter can detect meaningful violations.

Acceptance Criteria:

- 支持按域名、URL 关键词、App 名称配置。
- App 黑名单支持读取本机已安装应用列表，用户可以搜索 App 名称或 Bundle ID 并一键加入黑名单。
- 支持快速添加常见平台预设。
- 支持每条规则启用/停用。
- 命中日志能展示具体命中的规则。

**Story 3：被抓包时收到语音吐槽**  
As a user, I want Hunter to roast me immediately when I slack off so that the interruption feels dramatic and hard to ignore.

Acceptance Criteria:

- 监督中桌面显示一个可拖动悬浮球或小组件。
- 未命中黑名单时，悬浮球保持低干扰状态，只显示监督状态；时长任务进行中用圆形头像边缘倒计时环表示剩余时间，不使用右下角红黄绿状态点，也不允许出现方形半透明窗口底板；头像必须收在倒计时环内侧，倒计时环必须完整显示，不能被窗口边缘裁切。
- 用户点击悬浮球时可展开快捷控制菜单，直接开始 15/25/40 分钟监督、查看当前倒计时、暂停/恢复或取消监督，不需要打开主窗口；取消会立即结束当前时长任务并停止监督，不再保留后台倒计时。
- 命中黑名单后先在后台准备吐槽音频；音频准备好后，悬浮球在原位置展开成小组件并开始播报。
- 小组件只展示抓包对象、吐槽文案和用户可操作按钮，不展示 LLM、ASR、TTS、Provider、模型组合或“正在播放中”等内部状态；卡片背景必须是实体 popover 质感，不出现灰色半透明外圈。
- 抓包小组件在播报和用户录音期间显示动态声波；没有播放或录音时声波静止。
- 抓包小组件播报结束且用户几秒内没有继续操作时自动收起，不要求用户手动关闭。
- 命中黑名单后生成一条 10-25 秒内可播完的吐槽。
- 每次吐槽包含命中对象、当前工作状态和角色语气。
- 悬浮球头像固定为圆形裁切，支持用户上传自定义头像并恢复默认头像，不允许头像超出圆环，也不允许出现方形或半透明底板。
- 支持吐槽强度：温柔提醒、阴阳怪气、老板附体、破防模式。
- 同一网站连续命中时有冷却时间，避免每秒重复播报。

**Story 4：语音对喷**  
As a user, I want to talk back to Hunter so that the product feels like a live confrontation rather than a static reminder.

Acceptance Criteria:

- 用户可通过快捷键或界面按钮进入录音。
- 用户按住对话快捷键时，悬浮球外侧出现绿色呼吸圆环，明确反馈正在收音。
- 默认对话快捷键为 `Option + Space`，用户可以在设置页点击快捷键输入框后直接按下新的组合键或单键完成录制；单独的修饰键也要支持，例如右侧 `Option`；抓包卡片按钮展示“按住 {当前快捷键} 对话 / Hold {shortcut} to talk”，并按“按下开始录音、松开发送”执行。
- ASR 返回后，界面展示用户转写文本。
- LLM 根据用户狡辩内容继续回应。
- TTS 播报回应，且日志保存这一轮对话。
- Hunter 播报完成后保持同一抓包上下文，等待用户再次按住快捷键继续下一轮；不得后台自动抢麦克风导致手动按键冲突。
- ASR/LLM/TTS 任一失败时给出可见降级状态；诊断细节只出现在设置/诊断区域，不塞进抓包小组件。

**Story 4.1：语音创建时长监督任务**  
As a user, I want to quickly tell Hunter how long to supervise me so that I can start a focused work session without opening the main window.

Acceptance Criteria:

- 用户按住快捷键后可以说：“监督我接下来的 40 分钟”“帮我开始一个 15 分钟的监督任务”“盯我 25 分钟”“keep me focused for one hour”。
- Hunter 使用自动中英混合 ASR + duration parser 解析出时长和意图；ASR 语言提示不得跟随“AI 监督语言”，避免用户用中文下指令但监督语言设为 English 时识别失败。
- 时长解析需覆盖常见口语表达，例如“三十五分钟”“半小时”“一个半小时”。
- 解析成功后，悬浮球显示确认态，例如“40 分钟监督已开始”；确认 toast 使用实体 popover 背景，不出现半透明灰色矩形底板，并在数秒后自动消失。
- 时长任务期间，黑名单命中会触发抓包吐槽；时长结束后自动回到普通待机/按工作时间监督。
- 解析不确定时，悬浮球展示轻量确认，而不是打开主窗口。
- 时长任务可暂停、延长、结束，并写入历史记录。

**Story 4.2：监督结束后的语音总结**
As a user, I want Hunter to react to the outcome of a focus session so that finishing a session feels like a moment, not just a timer disappearing.

Acceptance Criteria:

- 时长监督正常倒计时结束后，Hunter 根据本轮抓包次数给出一条短语音反馈。
- 0 次抓包：直接彩虹屁式表扬。
- 1-3 次抓包：承认中间摸鱼，但鼓励用户最终完成。
- 4 次及以上：根据粗口开关和语言设置，给出更强的吐槽式总结。
- 总结语音走当前 TTS Provider，不使用 macOS 系统朗读；若 TTS 失败，只在状态中报错，不伪装成功。

**Story 5：查看今日抓包记录**  
As a user, I want to review what happened today so that I can use the data as 自律反馈 or video 素材.

Acceptance Criteria:

- 展示今日抓包次数、摸鱼总时长、Top 黑名单对象。
- 展示每次抓包时间、命中对象、AI 吐槽文案。
- 支持一键清除本地日志。

**Story 6：配置模型 Provider**  
As a user, I want to configure my own ASR, LLM, and TTS providers so that I can choose the cost and voice quality that fits me.

Acceptance Criteria:

- ASR、LLM、TTS、Web Search Provider 可独立配置和启用。
- 每类 Provider 的 MVP UI 只展示四个必填项：Provider、Base URL、Model、API Key。
- ASR 额外支持“本地模型 / 云端 API”模式切换；选择本地模型时展示推荐模型、来源和下载按钮。
- 本地 ASR 使用 SenseVoice Small INT8，下载后可在本机完成短音频识别，不上传用户录音。
- TTS 仅走云端 Provider，声音页只配置云端音色 ID；云端音色克隆/音色设计后续由对应 Provider adapter 接入。
- API Key 进入本机 `Application Support/Hunter/.env.local` 和进程内缓存，不提交仓库、不进入日志；运行热路径不访问 Keychain，避免系统钥匙串授权弹窗。
- 提供“测试 ASR”“测试 LLM”“测试 TTS”“测试搜索”“端到端测试”五类检查。
- 内置 DeepSeek LLM、阿里云百炼云端 ASR/TTS、本地 SenseVoice ASR、Brave Search 模板；用户可以新增 OpenAI-compatible 或 custom HTTP provider。
- 任一 Provider 未配置时，监督检测仍可运行，但语音链路显示明确缺失状态。

**Story 7：中英文界面和监督语言**  
As a user, I want the app and AI supervisor to work in Chinese or English so that different users can use Hunter in their own language.

Acceptance Criteria:

- UI 支持 Simplified Chinese 和 English。
- AI 监督语言可选择：跟随界面、中文、English。
- ASR 语言提示由 provider/local adapter 默认处理；后续高级模式再展示自动、中文、English、中英混合。
- LLM prompt 必须显式传入目标输出语言；如果模型仍返回明显错误语言，Hunter 需要用目标语言兜底短句，避免用户把监督语言改成 English 后仍听到中文抓包。
- TTS 音色以云端 Provider 的 voice id 为准，默认 `longanyang`。
- MVP 不提供本地声音克隆入口；云端克隆/音色设计进入后必须要求用户确认授权，且不复刻未授权第三方声音。

## 2A. Frontend Page Contract

本节是设计和实现的页面结构真源。设计稿、SwiftUI 页面和验收清单不得新增未在本节定义的入口、卡片、字段或操作；如发现必要元素缺失，先更新本节再实现。

### Page Tree & Entry Points

| Level | Surface / Screen | Entry Point | Global Navigation | Purpose |
| --- | --- | --- | --- | --- |
| L1 | Floating Orb | App launch, menu bar “Show Widget”, setting toggle | No | 日常主入口，展示监督状态、倒计时、收音/播报反馈 |
| L2 | Quick Control Popover | Click floating orb | No | 快速开始 15/25/40 分钟监督、暂停/恢复、取消、查看倒计时 |
| L2 | Catch Popover | Blacklist hit after TTS is ready | No | 展示抓包对象、短吐槽、声波、按住快捷键对话 |
| L2 | Focus Toast | Voice duration command, session start/end | No | 2-4 秒自动消失的结果确认 |
| L1 | Menu Bar Menu | macOS menu bar icon | No | 开始/暂停、显示设置、显示/隐藏悬浮球、退出 |
| L1 | Settings Window / General | Menu bar “Settings”, first launch | Yes, sidebar | 监督开关、时长任务、工作时段、悬浮球、快捷键、权限 |
| L1 | Settings Window / Watchlist | Sidebar | Yes, sidebar | 网站/App 黑名单、本机 App 选择器、规则管理 |
| L1 | Settings Window / AI Providers | Sidebar | Yes, sidebar | ASR、LLM、TTS、Search 独立 Provider 配置和测试 |
| L1 | Settings Window / Voice & Language | Sidebar | Yes, sidebar | 界面语言、监督语言、角色、强度、粗口、音色、音色克隆占位 |
| L1 | Settings Window / History | Sidebar | Yes, sidebar | 今日事件摘要、事件列表、清除日志 |

### Navigation Contract

- Settings Window 左侧 sidebar 固定 196px 宽，入口顺序固定为：General、Watchlist、AI、Voice、History。每个导航项整行可点，选中态使用低饱和蓝色背景、蓝色 SF Symbol 和半粗体文字。
- Settings Window 右侧内容区使用单列 section 列表，内容应充分利用右侧可用宽度，不再固定窄列造成大面积空白；不使用顶部横向菜单，也不在内容区重复展示当前 sidebar 已选中的页面大标题。
- Settings Window 底部 sidebar 固定两个主操作：`Start/Pause` 监督按钮、`Demo Catch` 演示抓包按钮。
- Floating Orb 点击只打开 Quick Control Popover，不打开 Settings Window。Settings Window 只能通过 menu bar、sidebar 或系统窗口操作打开。
- Quick Control Popover 和 Catch Popover 均为桌面浮层，6 秒无操作自动收起；用户再次点击 orb 手动收起时，orb 位置不得跳动。
- 权限按钮只能打开系统设置或触发明确的系统授权请求；Hunter 设置窗口在切到 System Settings 后保持可重新打开，回到前台时自动刷新权限状态。

### Shared Component Contract

| Component | Required Structure | States |
| --- | --- | --- |
| SettingsSection | 标题、说明在卡片外上方；下方是一张白色/系统 surface 卡片，卡片内承载该设置的控件、列表或表单；不得把标题说明和控件做成左右分栏 | default, disabled, error, saved/unsaved |
| SettingsCard | 白色/系统 surface，12-14px 圆角，1px 低透明描边；内部内容可按控件需要做横向或纵向布局，但 section 层级必须保持上下分布 | default, empty |
| KeyCaptureBox | 单个可点击输入框，只显示当前快捷键，例如 `Option + Space` 或 `Right Option`；点击后同一个框进入 capturing 状态并显示 `Press new shortcut`，不得同时并排展示“当前值”和“录制中”两个框 | default, capturing, saved, error |
| ProviderCard | Header：Provider role + mode/status；Body：Provider、Base URL、Model、API Key 四字段；Footer：测试按钮与状态 | collapsed, expanded, saved, testing, error, missing key |
| PermissionRow | 权限名称、一个状态 pill、未允许时的单个操作按钮；不得同时出现绿点、对勾和状态标签 | allowed, notDetermined, denied, optional, unknown |
| InstalledAppRow | App 图标、App 名称、Bundle ID 或路径、Add/Added 按钮 | default, added, loading icon |
| Waveform | 5-9 根细圆角条，播报/录音时动画，空闲时静态 | idle, speaking, listening |
| OrbProgressRing | 头像外侧 3px 圆环，蓝色表示剩余时长，绿色呼吸表示收音 | idle, focus, paused, listening, speaking, caught |

### Settings / General Structure

1. **Monitoring Section**
   - Visible elements：section 标题“监督开关”、说明、卡片内 `Start/Pause` toggle 和当前状态 pill。
   - Dynamic fields：`isMonitoring`、`workSchedule.enabled`。
   - States：off、on、disabled by missing setup、transitioning。

2. **Focus Session Section**
   - Visible elements：section 标题“时长任务”、说明、卡片内当前会话状态、剩余时间、15/25/40/60/90 分钟 preset chips、自定义时长输入框（数字 + 单位分钟）、`Start Focus` 或 `Pause/Resume + Cancel`。
   - Dynamic fields：`focusSession.duration`、`focusSession.customDurationMinutes`、`focusSession.remaining`、`focusSession.isPaused`、`focusSession.catchCount`。
   - Validation：自定义时长支持 1-240 分钟，非法值禁用开始按钮并展示轻量错误提示。
   - Empty state：无时长任务时展示“临时监督一段时间；到点自动结束”。

3. **Floating Widget Section**
   - Visible elements：圆形头像预览、`Show Widget` toggle、`Upload Avatar`、`Reset`。
   - Dynamic fields：`showFloatingWidget`、`floatingAvatarPath`。
   - Validation：头像必须圆形裁切，预览不得超出倒计时环。

4. **Work Schedule Section**
   - Visible elements：section 标题“工作时段”、说明、卡片内 `Enable schedule` toggle、工作日/周末 checkbox、时间段列表、每个时间段的开始时间输入、结束时间输入、启用开关、删除按钮、`Add Period`。
   - Dynamic fields：`workSchedule.periods`、`workSchedule.periods[].start`、`workSchedule.periods[].end`、`workSchedule.periods[].enabled`、`enabledWeekdays`、`enabledWeekend`。
   - Validation：开始时间必须早于结束时间；时间段冲突时展示轻量错误提示。
   - States：disabled 时所有时间控件禁用但仍可读。

5. **Talk Shortcut Section**
   - Visible elements：section 标题“对话快捷键”、说明、卡片内一个 KeyCaptureBox、Reset、`Test Voice Command`、一句交互提示“点击输入框后按下新的快捷键；松开后保存”。
   - Dynamic fields：`replyShortcut`、`isCapturingShortcut`、`permission.microphone`。
   - Required behavior：点击框后按任意组合键或单键保存；支持 `Right Option` 等 modifier-only key。

6. **Permissions Section**
   - Visible elements：section 标题“权限”、说明、卡片内四条 PermissionRow：Microphone、Browser Automation、Notifications、Accessibility (Optional)，以及 `Re-check`。
   - Dynamic fields：`permissions.microphone`、`permissions.browserAutomation`、`permissions.notifications`、`permissions.accessibility`。
   - UI rule：每条权限只保留一个状态 pill；未允许才显示操作按钮。

7. **Launch Section**
   - Visible elements：`Launch at Login` toggle。
   - Dynamic fields：`launchAtLogin`。

### Settings / Watchlist Structure

1. **Add Rule Row**
   - Elements：Rule type picker (`Website/App`)、Name text field、Pattern text field、`Add`。
   - Validation：Pattern 为空时禁用 Add；Name 为空时使用 Pattern。

2. **Preset Row**
   - Elements：YouTube、Bilibili、Douyin、X/Twitter、Reddit、Steam、Discord chips。
   - States：未添加、已添加 disabled。

3. **Installed Apps Row**
   - Elements：section title、description、Refresh、search field、InstalledAppRow list。
   - Dynamic fields：installed app `name`、`bundleIdentifier`、`path` from `/Applications`、`~/Applications`、`/System/Applications`。
   - States：loading、empty、filtered empty、loaded、added。

4. **Rule List Row**
   - Elements：规则名称、kind pill、pattern、enabled toggle、delete。
   - States：enabled、disabled、empty。

### Settings / AI Providers Structure

AI 页面不得出现“基础配置”或跨模型联动配置。ASR、LLM、TTS、Search 四块独立配置。

1. **ASR ProviderCard**
   - Fields：Mode (`Local model/Cloud API`)、Provider、Base URL、Model、API Key。
   - Local mode elements：SenseVoice Small INT8 descriptor、download/status button、local path/status。
   - Actions：Test ASR。

2. **LLM ProviderCard**
   - Fields：Provider、Base URL、Model、API Key。
   - Default template：DeepSeek / `deepseek-v4-flash`。
   - Actions：Test LLM。

3. **TTS ProviderCard**
   - Fields：Provider、Base URL、Model、API Key。
   - No local TTS mode.
   - Actions：Test TTS。

4. **Search ProviderCard**
   - Elements：Enable toggle、Provider (`Brave/Tavily/Custom`)、Base URL、Model/query preset、API Key、privacy note。
   - Actions：Test Search。

5. **End-to-End Test Row**
   - Elements：`Run E2E Test`、status text。
   - States：idle、running、success、failure。

### Settings / Voice & Language Structure

1. **Language Row**
   - Elements：Interface Language picker、Roast Language picker。
   - Dynamic fields：`interfaceLanguage`、`aiLanguage`。
   - Behavior：Roast Language 控制 LLM output language and TTS language hint；模型返回明显错误语言时本地兜底。

2. **Persona Row**
   - Elements：Persona picker、Intensity picker、Allow Profanity toggle、Banned Terms text field。
   - Dynamic fields：`persona`、`intensity`、`allowProfanity`、`bannedTerms`。

3. **Voice Row**
   - Elements：TTS Voice ID text field、Test Voice button。
   - Dynamic fields：`voice`。

4. **Voice Clone Row**
   - Elements：title、copy、disabled Upload Sample、disabled Record Sample、status pill `Cloud clone pending`。
   - Behavior：MVP 不允许上传或录制样本；后续只保存云端 Provider 返回的授权 voice id。

### Settings / History Structure

1. **Today Summary Row**
   - Elements：抓包次数、今日最多命中对象、最近一次抓包时间。
   - Dynamic fields：`eventsForToday.count`、group by `targetName`、latest date。
   - Empty state：无事件时显示“今天还没抓到你”。

2. **Incident List Row**
   - Elements：time、target、rule/source、roast quote。
   - Dynamic fields：`Incident.date`、`targetName`、`matchedRule`、`roastText`。
   - No copy quote button in MVP;用户没有明确需要，不做。

3. **Clear Logs Row**
   - Elements：`Clear Today` 或 `Clear All Local Logs` button、confirmation text。
   - Behavior：需二次确认或显著危险样式。

### Floating Surface Structure

**Orb**

- Frame：72x72 transparent panel with at least 4px safe inset.
- Elements：progress ring、round avatar、optional animated ring/waveform.
- Forbidden：square translucent backing, clipped ring, green status dot.

**Quick Control Popover**

- Elements：title (`Focus`)、remaining countdown、blue remaining progress bar、15/25/40 minute buttons、Pause/Resume、Cancel、shortcut hint。
- States：no session、running、paused、listening、auto-dismiss.

**Catch Popover**

- Elements：caught target, timestamp, roast text max 3 lines, waveform, hold-to-talk button, optional pause action。
- States：speaking、listening、thinking、idle waiting、auto-dismiss、TTS failure。
- Forbidden：provider/model/internal status copy。

**Focus Toast**

- Elements：short title, optional one-line detail, no controls.
- States：session started、session completed praised/encouraged/roasted、parse failed。

### Field Source Matrix

| Field Key | Label | Type | Source of Truth | Derivation / Freshness | Null Handling |
| --- | --- | --- | --- | --- | --- |
| `isMonitoring` | Supervision status | Boolean | `AppState.isMonitoring` | Immediate user toggle / menu bar | Off |
| `focusSession.remaining` | Remaining time | TimeInterval | `FocusSession` | Recomputed every tick | Hide countdown |
| `focusSession.catchCount` | Session catch count | Int | Incidents linked to session | Updated on incident | 0 |
| `showFloatingWidget` | Floating widget | Boolean | `AppState.showFloatingWidget` | Immediate | On by default |
| `replyShortcut` | Talk shortcut | Struct | `AppState.replyShortcut` | Persisted on capture | `Option + Space` |
| `permissions.*` | Permission state | Enum | `PermissionCenter.snapshot()` | Refresh on active + 1.5s timer while settings visible | Unknown |
| `rules[]` | Watchlist rules | Array | Local store | Immediate add/delete/toggle | Empty list with presets |
| `installedApps[]` | Installed apps | Array | `InstalledAppScanner` | On page load / refresh | Empty state |
| `providers.asr/llm/tts/search` | Provider config | Object | Local settings + `.env.local` secret | Persist on edit | Missing key pill |
| `interfaceLanguage` | Interface language | Enum | Local settings | Immediate | Chinese |
| `aiLanguage` | Roast language | Enum | Local settings | Used per LLM/TTS request | Follow interface |
| `voice` | TTS voice ID | String | Local settings | Used per TTS request | `longanyang` |
| `eventsForToday` | Today incidents | Array | Local incident store | Filter by local calendar day | Empty summary |

### Interaction & Error Contract

- Settings 表单字段编辑后立即保存本地设置；API Key 字段失焦或点击保存时写入本地 secret store，显示 `•••••••• + saved`，不回显明文。
- Provider 测试按钮进入 running state，成功显示 bytes/model/provider 摘要，失败显示用户可读错误；详细日志只写诊断文件。
- Voice command 解析失败时只显示轻 toast，不打开设置窗口。
- TTS 失败不得回退到系统朗读；必须显示可见错误状态并写入诊断。
- Browser automation 未授权时监控循环跳过 URL 读取，不弹系统框；只有用户点击授权按钮才请求。
- Accessibility 在 MVP 是可选增强；即使未开启也不得阻断核心功能或显示成严重错误。

### Design Coverage Gate

- 每个 L1/L2 surface 必须至少有一个视觉稿或组件状态样例。
- 每个 Settings 页面必须有页面级结构图、字段列表和至少一个主要错误/空状态说明。
- 每个浮层状态必须在设计稿或组件板中出现：idle、quick control、caught speaking、listening、focus toast。
- SwiftUI 实现不得引入 PRD 未定义的字段、按钮或统计指标。

### Non-Goals

- 不做老板/管理员远程监控员工。
- 不做隐身后台采集或不可关闭监控。
- MVP 不做跨设备同步、团队排行、远程管理后台。
- MVP 不做强制断网、强制关闭 App 或系统级拦截。
- MVP 不做公开视频自动生成，只提供适合录屏的 UI 和日志。
- MVP 不内置任何云端 API Key，也不提供代付模型额度。

## 3. AI System Requirements

### Tool Requirements

- ASR：实时或准实时语音识别，支持普通话、英语、中英混合、口语化表达、短音频低延迟。
- LLM：中英文吐槽、角色扮演、上下文记忆、粗口边界控制、低成本。
- TTS：中英文自然语音，支持指定音色；优先支持音色复刻或音色设计。
- Web Search：可选增强，只用页面标题/域名发起查询，返回少量搜索摘要给 LLM，不上传完整浏览历史。
- Provider 层：统一封装 `transcribe(audio, options)`, `generateRoast(context, options)`, `speak(text, voice, options)`, `search(query, options)`。
- Provider 配置层：支持内置模板、自定义 provider、连接测试、启停、成本备注和能力标签。

### Prompt Requirements

LLM 输入最少包含：

- 命中对象：App 名称、URL 域名或规则名。
- 页面上下文：浏览器标签标题、URL、可选搜索摘要。
- 当前阶段：首次抓包、连续摸鱼、用户反驳。
- 用户配置：吐槽强度、角色、禁用词、是否允许粗口、输出语言。测试阶段若用户已允许粗口，prompt 应明确要求使用普通脏话增强节目效果，但仍禁止仇恨辱骂、真实威胁和受保护属性攻击。
- Provider 能力：模型名称、语言支持、TTS 音色语言、是否支持流式。
- 安全边界：不攻击受保护属性，不鼓励自伤，不输出真实威胁。

### Evaluation Strategy

- ASR：20 条用户反驳样本，普通话转写字错率目标 <= 10%。
- ASR：20 条英文反驳样本，英文转写词错率目标 <= 15%。
- LLM：100 条命中场景，人工评分“好笑/有冲突/不越界”，通过率 >= 80%。
- LLM：中英文输出语言遵循率 >= 98%。
- TTS：10 个默认音色 A/B 测试，选择清晰度、情绪表现、延迟综合最优的 3 个。
- 端到端：模拟 30 次抓包，平均首句播报延迟 <= 5 秒。

## 4. Technical Specifications

### Architecture Overview

```mermaid
flowchart LR
  A["Monitor Scheduler"] --> B["Foreground App Detector"]
  A --> C["Browser URL Detector"]
  B --> D["Blacklist Engine"]
  C --> D
  I["Push-to-talk Recorder"] --> J["ASR Provider"]
  J --> Q["Voice Command Parser"]
  Q --> A
  D --> E["Incident Controller"]
  E --> P["Provider Registry"]
  P --> S["Web Search Provider"]
  S --> F
  P --> F["LLM Roast Generator"]
  P --> G["TTS Player"]
  E --> H["Local Event Store"]
  P --> J
  J --> F
```

### macOS Components

- Menu Bar Controller：展示状态、开始/暂停、快速入口。
- Settings Window：工作时间、黑名单、声音、角色、隐私设置。
- Monitor Service：定时检测前台 App 和浏览器 URL。
- Incident Controller：处理命中、冷却、文案生成、播报和日志。
- Voice Session：负责录音、ASR、LLM 回应、TTS 播放。
- Voice Command Parser：解析“监督我接下来的 40 分钟”等时长任务意图。
- Focus Session Manager：管理临时时长监督任务、倒计时、暂停、延长和结束。
- Provider Registry：保存 ASR/LLM/TTS 的用户配置、内置模板和连接状态。
- Localization Manager：管理 UI 语言、AI 输出语言和 provider 语言提示。
- Local Store：保存配置、规则、日志和音色元数据。

### Integration Points

- macOS 权限：辅助功能、自动化、麦克风、通知。
- Chrome/Safari：通过脚本读取当前标签 URL；监控循环只做静默自动化权限检查，未授权时不主动弹系统授权框。
- 云端模型 API：ASR、LLM、TTS。
- Local Secret Store：保存 API Key 引用和本机 `.env.local` 密钥。
- i18n 资源：中英文 UI 文案、默认角色 prompt、默认吐槽模板。

### Security & Privacy

- 默认只上传被抓包时的最小上下文，不上传完整浏览历史。
- 用户反驳音频仅用于 ASR，默认不保留原始音频。
- 本地日志默认可清除。
- 音色复刻需要显式授权确认，并记录授权状态。
- 调试日志不得打印 API Key、完整 URL 查询参数或原始音频内容。
- Provider 导入/导出默认不包含 API Key。

## 5. Risks & Roadmap

### Phased Rollout

**MVP：抓包播报闭环**

- 桌面悬浮监督小组件。
- 语音快速创建时长监督任务。
- 菜单栏入口和轻量主窗口。
- 工作时间和黑名单配置。
- 前台 App + Chrome/Safari URL 检测。
- 命中后 LLM 文案 + TTS 播报。
- Provider 配置框架，内置阿里云百炼模板。
- 中英文 UI 与 AI 输出语言设置。
- 本地日志。

**v1.1：语音对喷**

- Push-to-talk 反驳。
- ASR 转写。
- 多轮对喷上下文。
- 角色包和强度细化。
- 更多 Provider 模板和音色复刻流程。

**v1.2：传播增强**

- 今日名场面榜单。
- 经典语录复制。
- 录屏友好的抓包浮窗。
- 可导出日报文案。

**v2.0：挑战模式**

- 8 小时不摸鱼挑战。
- 失败惩罚规则。
- 朋友监督/本地房间。
- 可选视频片段自动剪辑。

### Technical Risks

- macOS 浏览器 URL 读取需要自动化权限，用户授权路径可能影响转化。
- 不同浏览器和多窗口场景会增加检测复杂度。
- 云端 TTS 延迟可能削弱“当场抓包”效果，需要缓存常用吐槽或流式 TTS。
- 用户自定义 Provider 会带来鉴权、协议和错误格式差异，需要统一错误模型。
- 中英文对喷质量取决于供应商语言能力，需要在 Provider 能力标签里给出提示。
- 粗口吐槽需要可控，避免越界输出导致产品风险。
- 音色复刻涉及授权和合规，不能默认开放第三方声音复刻。
