# AGENTS.md

## Browser And Computer Use

- 当需要操作 Chrome、飞书网页、开放平台、登录态网页或其他浏览器页面时，优先为 Codex 单独打开一个独立窗口或新窗口中的目标页面，不要复用用户正在使用的浏览器窗口或标签页。
- 在使用 Computer Use 控制本机应用或浏览器时，尽量保持 Codex 的操作上下文固定在自己打开的窗口里，避免因为用户切换到自己的窗口而影响页面定位、截图、点击和状态读取。
- 只有在用户明确要求接管当前窗口、目标页面只能在当前窗口访问，或登录/权限状态必须依赖当前窗口时，才操作用户正在使用的窗口；这种情况下先简短说明原因。

## Project Mission

Hunter 是一个 Mac 端 AI 摸鱼监工工具。它不是传统效率软件，而是一个自愿开启的个人监督和整活互动产品：

- 用户设定工作时间、摸鱼网站黑名单和 App 黑名单。
- 监控启动后持续检测前台 App 与浏览器当前 URL。
- 命中黑名单后立刻触发云端 AI 生成吐槽，并用 TTS 语音播报。
- 用户可以语音反驳，系统走 `ASR -> LLM -> TTS` 流程继续对喷。
- 产品重点是“被 AI 当场抓包”的冲突感、节目效果和可录屏传播性。
- 产品需要支持中英文界面，以及中文/英文两种监督和对喷语言。

## Product And Design Direction

- Hunter 的主体验是桌面悬浮球/小组件，不是复杂后台控制台。
- 默认界面要接近 Apple 原生软件：轻、简约、留白充足、低饱和、高质感，不走暗黑赛博风、监控大屏风或复杂仪表盘风。
- HTML 设计稿里的 macOS 桌面壁纸、系统菜单栏和 Dock 只是审稿用 presentation shell，用来说明应用出现的环境；开发时不要实现、复刻或控制系统桌面背景、Dock、菜单栏。
- 真正需要实现的产品 UI 只有：Hunter 悬浮球、抓包展开小组件、时长任务 toast、设置主窗口、菜单栏状态入口。
- 主窗口只承载必要设置：工作时间、黑名单、Provider/API Key、语言与音色、历史记录。
- 抓包时悬浮球展开成小组件并直接语音吐槽；用户可用快捷键回击。
- 悬浮球必须支持语音快速创建时长任务，例如用户说“监督我接下来的 40 分钟”，系统立刻开启 40 分钟监督。
- 所有次级能力先隐藏在设置页，不要把 Provider、统计、日志、语音会话同时堆在第一屏。

## Product Boundaries

- 默认定位为个人自愿使用工具，不做老板监控员工、隐身采集、远程上报或不可关闭的监控。
- 黑名单、日志、工作时段、音色设置默认存储在本机。
- 浏览器 URL 和 App 使用记录默认不上传；只有被抓包事件所需的最小上下文进入 LLM。
- 粗口/高强度吐槽必须由用户主动选择档位。不得生成针对种族、性别、地域、疾病、身体特征、真实身份等受保护属性的攻击。
- TTS 音色复刻必须要求用户确认授权，不支持复刻公众人物、同事、老板或任何未授权第三方声音。

## Technical Direction

- 首选原生 macOS 应用路线：SwiftUI + AppKit 菜单栏应用。
- 前台 App 检测优先使用 `NSWorkspace.shared.frontmostApplication`。
- 浏览器 URL 检测第一阶段支持 Chrome 和 Safari，可通过 AppleScript/ScriptingBridge 获取当前标签 URL；后续再评估浏览器扩展。
- 麦克风采集使用 `AVAudioEngine` 或系统音频 API；模型链路按 `ASR -> LLM -> TTS` 拆成 provider abstraction，避免供应商锁死。
- ASR、LLM、TTS 都必须支持用户自定义 Provider 配置；MVP 云端 UI 只展示 Provider、Base URL、Model、API Key，headers/region/language hint 等高级字段由 adapter 默认处理或后续高级模式承载。
- ASR/TTS 支持本地模型模式，用户可在设置页下载模型到本机；当前本地推荐为 `SenseVoice Small INT8 (sherpa-onnx)` 和 `Qwen3-TTS-12Hz-0.6B-Base`。
- 内置推荐配置仅作为模板。当前默认测试链路为本地 SenseVoice ASR -> DeepSeek `deepseek-v4-flash` -> 本地 Qwen3-TTS 克隆 worker；若本地 TTS 样本或模型未就绪，使用 macOS 系统语音本地降级，不上传音频。云端 ASR/TTS fallback 保留阿里百炼链路：`paraformer-realtime-v2 -> cosyvoice-v3-flash`。
- 云端模型评估维度是价格、中英文效果、流式能力、延迟、音色选择、音色复刻、SDK/HTTP 接入复杂度和合规边界。
- API Key、Secret、Token 等敏感信息必须进入 macOS Keychain 或本机 `.env.local`，不得提交到仓库。
- 界面文案必须经过 i18n key 管理，不要把中英文文案散落在视图里。

## Documentation Source Of Truth

- PRD 真源：`docs/PRD.md`
- 设计稿真源：`docs/DESIGN.md`
- 模型/API 技术评估：`docs/TECHNICAL_EVALUATION.md`
- 若产品范围、模型选型、权限策略或关键交互发生变化，同步更新上述文档。

## Development Workflow

- 开始编码前先读 `docs/PRD.md` 和 `docs/DESIGN.md`，确认当前阶段范围。
- 看到 HTML 设计稿时要把系统级背景、Dock、Finder 菜单栏视为展示背景；不要把它们转成 App 代码或产品需求。
- 默认先跑通 MVP 主链路：工作时间判断 -> 前台 App/URL 检测 -> 黑名单命中 -> AI 文案生成 -> TTS 播报 -> 本地日志。
- UI 先实现悬浮监督小组件，再实现主窗口设置页。
- 悬浮球语音命令先实现时长任务解析，再扩展更复杂的自然语言控制。
- Provider 配置框架要先于单个供应商深度适配；可以先实现本地 SenseVoice、DeepSeek、阿里默认模板，但数据结构不能写死任何一家。
- 不要用假数据或静态 UI 冒充真实闭环；如果模型或系统权限未接通，要在状态里明确标注。
- 优先实现可验证的小闭环，再扩展角色包、排行榜、挑战模式、分享视频等传播功能。
- 每次提交前检查是否引入敏感日志、明文密钥、未授权音色样本或过度采集浏览历史。

## Testing Expectations

- 未来有 Xcode 工程后，优先使用 xcodebuild 或项目约定命令构建验证。
- App/URL 检测需要至少覆盖：普通 App、Chrome 当前 URL、Safari 当前 URL、黑名单命中、白名单不触发、工作时间外不触发。
- AI 链路需要覆盖：正常生成、模型超时、ASR 空结果、TTS 失败、粗口强度限制、音色不可用降级。
- Provider 配置需要覆盖：缺失 Key、无效 base URL、模型 ID 错误、ASR/LLM/TTS 分别切换供应商。
- i18n 需要覆盖：界面中英文切换、AI 输出语言切换、英文黑名单命中后的英文吐槽。
- UI 改动需要用截图或可运行应用状态验证，不只汇报代码已改。
