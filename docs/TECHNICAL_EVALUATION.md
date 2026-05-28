# Hunter Technical Evaluation

版本：v0.6
日期：2026-05-29
状态：已进入实现验收

## Decision Summary

第一版架构建议采用 **用户可配置 Provider Registry**。ASR、LLM、TTS 和 Web Search 都允许用户填写自己的供应商、模型/模式、endpoint 和 API key；项目内置推荐模板用于降低上手成本，但不能把模型供应商写死。

当前本机测试链路调整为 **DeepSeek LLM + 本地 ASR + 云端 TTS**：

- LLM：DeepSeek API，`deepseek-v4-flash`，OpenAI-compatible `https://api.deepseek.com`。
- 本地 ASR 首选：`SenseVoice Small INT8` via `sherpa-onnx`，支持普通话、粤语、英文、日文、韩文，Mac arm64/x64 可用。
- TTS：本地 Qwen3-TTS 方案已否掉；MVP 统一走云端 TTS Provider，当前默认阿里百炼 `cosyvoice-v3-flash + longanyang`。
- 本地声音克隆：MVP 移除，不再下载本机 TTS 模型或保存克隆样本入口；后续只考虑云端授权音色 enrollment/design。
- 云端 ASR/TTS 保留阿里百炼模板：`paraformer-realtime-v2`、`cosyvoice-v3-flash + longanyang`。
- Web Search 首选：Brave Search API；Tavily 作为“AI-ready 搜索摘要”备选。

理由：DeepSeek 的文本接口符合 OpenAI Chat Completions 形态，接入成本低；本地 SenseVoice ASR 的短音频识别延迟稳定在 1 秒以内；本地 Qwen3-TTS 在真实抓包链路中首次合成约 28-32 秒，明显破坏节目效果，因此移除；Brave 的 raw search snippets 足够给 LLM 做页面语境增强，成本低于 Tavily。

## Requirements

Hunter 的语音链路不是端到端实时大模型，第一版明确采用：

```text
用户语音 -> ASR -> 用户文本 -> LLM 生成回应 -> TTS 播报
```

核心要求：

- 便宜：单用户日常成本要低，尤其 ASR 和 TTS。
- 中英文自然：吐槽要像真人口语，不像客服播报。
- 低延迟：抓包后越快播报越有节目效果。
- 可选音色：至少支持多默认音色，最好支持授权音色复刻。
- 本地部署：ASR 支持用户在设置页选择“本地模型”，并下载官方/开源模型到本机；TTS 不再提供本地模型模式。
- 可选搜索：联网搜索默认关闭，只在用户开启后用当前页面标题/域名生成 query，不上传完整历史。
- 可控边界：能在 LLM prompt 和产品层限制辱骂边界。
- 用户可配置：ASR/LLM/TTS 可以分别切换 Provider。

## Provider Registry

### Configuration Model

云端 provider 配置在 MVP UI 中只暴露四个字段：

```text
Provider / Base URL / Model / API Key
```

内部配置仍可保留鉴权 scheme、headers、region、语言提示、流式能力等字段，用于 adapter 默认值和后续高级模式。每个 provider 完整配置模型至少包含：

```json
{
  "id": "aliyun-qwen-turbo",
  "type": "llm",
  "displayName": "Aliyun Bailian / Qwen Turbo",
  "baseURL": "https://dashscope.aliyuncs.com/compatible-mode/v1",
  "model": "qwen-turbo",
  "authType": "bearer",
  "apiKeyRef": "keychain://hunter/providers/aliyun-qwen-turbo",
  "headers": {},
  "supportsStreaming": true,
  "languages": ["zh-CN", "en-US", "mixed"],
  "costHint": "0.3/0.6 CNY per 1M input/output tokens",
  "enabled": true
}
```

### Built-in Templates

MVP 内置模板只提供默认字段，不提供密钥：

- DeepSeek：LLM，`deepseek-v4-flash`。
- Aliyun Bailian：ASR、LLM、TTS、voice enrollment/design。
- OpenAI-compatible：LLM/TTS/ASR 可按兼容接口自填。
- Custom HTTP：给高级用户填写 endpoint、headers、body mapping。
- Volcengine：作为语音效果增强候选模板。
- Tencent Cloud：作为声音复刻候选模板。

本地模型模板：

- ASR：`SenseVoice Small INT8 (sherpa-onnx)`，下载到 `Application Support/Hunter/LocalModels/asr`。
- TTS：无本地模板；统一配置云端 Provider、Model、API Key 和 voice id。

### Runtime Rules

- 监督检测不依赖 Provider；Provider 缺失时仍记录抓包，但不播报。
- 抓包播报依赖 LLM + TTS；语音反驳依赖 ASR + LLM + TTS。
- Provider 测试分为单项测试和端到端测试。
- 失败统一归一化为：auth error、network error、model error、quota error、unsupported language、unsupported voice。

## Monitoring Strategy

MVP 监控链路采用 **事件驱动 + 浏览器局部轮询**，避免全局固定频率读取前台状态：

- App 切换：使用 `NSWorkspace.didActivateApplicationNotification`，用户切到新 App 后立即检查 App 黑名单。
- 浏览器 URL：macOS 不直接提供标签 URL 变更事件；只有当前台 App 是 Chrome、Safari、Brave、Edge 或 Arc 且监督生效时，启动 1.5 秒 URL watcher。
- URL 读取：AppleScript 在后台任务中执行，不阻塞设置窗口和悬浮窗 UI。
- 去重：浏览器 URL 未变化时不重复触发网站规则。
- 低频生命周期检查：保留 15 秒 timer 只处理时长任务过期、工作时段状态变化和 watcher 启停，不做全局 URL 读取。
- 后续升级：如果网站监控需要更实时和更低成本，优先做 Chrome/Safari Web Extension + Native Messaging，把 URL 变更也改成事件通知。

## Provider Comparison

| 供应商 | 推荐用途 | 价格观察 | 优点 | 风险 |
|---|---|---:|---|---|
| DeepSeek | 本机 LLM 测试默认 | 按 DeepSeek 官方 API 计费 | OpenAI-compatible，`deepseek-v4-flash` 文本接入简单，中英文吐槽成本低 | 只覆盖 LLM，不覆盖 ASR/TTS |
| 本地 SenseVoice | 本地 ASR 默认 | 模型免费下载，本机推理 | 中英日韩粤，sherpa-onnx 有 macOS/Python wheel；隐私和成本好 | 标点和口语纠错需后处理；首次下载约 493 MB 解压 |
| 本地 Qwen3-TTS CustomVoice | Rejected | 模型免费下载，本机推理 | 中英文、多语言、9 个预置音色、语气控制，Apache-2.0 | 本机实测首次合成约 28-32 秒，抓包后等待太久，MVP 已移除 |
| 本地 Qwen3-TTS Base | Rejected | 模型免费下载，本机推理 | 短参考音频声音克隆；不需要云端上传样本 | 同样受本地推理延迟影响，且授权样本 UI 让 MVP 复杂度过高，已移除 |
| 阿里云百炼 | 云端 ASR/TTS fallback | ASR 约 0.00024 元/秒，Qwen Turbo 0.3/0.6 元每百万 Token，CosyVoice Flash 0.8 元/万字符 | 便宜，统一入口，音色 enrollment/design 价格明确 | TTS 情绪表现要实测，Mac 端 SDK 可能主要走 HTTP/WebSocket |
| 火山引擎豆包语音 | 第二候选/语音增强 | 后付费豆包流式 ASR 2.0 为 1 元/小时，豆包 TTS/声音复刻 3 元/万字符 | 字节语音生态强，适合节目化声音效果 | TTS 成本高于阿里；需区分豆包语音模型和普通流式识别商品 |
| 腾讯云 | 音色复刻备选 | 一句话声音复刻训练约 12-39 元/音色，复刻合成后付费 6.4-8 元/万字符 | 声音复刻产品成熟，文档完整 | MVP 阶段偏贵，基础版训练成本高 |
| Brave Search API | 默认搜索增强 | 官方页显示 Web Search API $5 / 1,000 requests，且有 $5 monthly credits | 成本低、返回 title/url/description，正好用于给吐槽 prompt 补页面语境 | 返回的是 raw snippets，需要 LLM 自己组织逻辑 |
| Tavily Search API | 搜索增强备选 | 官方 pricing 显示 Researcher 免费 1,000 API credits/月，Pay As You Go $0.008/credit，Project $30/月含 4,000 credits | 面向 AI agent/RAG，结果更“LLM-ready”，还有 extract/crawl 能力 | 单价高于 Brave，Hunter MVP 只需要少量 snippets，默认用它有点重 |
| OpenAI-compatible | 用户自带 | 取决于用户 endpoint | 生态广，很多代理和私有网关兼容 | TTS/ASR 字段差异大，需要自定义 mapping |

## Recommended MVP Stack

### ASR

本地首选：`SenseVoice Small INT8` via `sherpa-onnx`

- 用途：用户按住快捷键反驳时，短音频本地转写。
- 优点：支持普通话、粤语、英文等 5 种语言；sherpa-onnx 提供 Swift API 和 macOS arm64/x64 支持；模型 `model.int8.onnx` 约 226 MB。
- MVP 用法：设置页下载模型后，Hunter 会创建本机私有 ASR runtime，并通过 `sherpa_onnx.OfflineRecognizer.from_sense_voice` 做本地识别；命令行 `--smoke-local-voice-focus` 已验证中文时长任务。

云端 fallback：阿里云百炼 `paraformer-realtime-v2`

- 用途：用户按住快捷键反驳时，实时或准实时转写。
- 官方计费：实时语音识别按输入音频秒数计费，`paraformer-realtime-v2` 为 0.00024 元/秒，并有每月 36,000 秒免费额度。
- MVP 用法：Push-to-talk，每次 3-15 秒，避免常开麦克风导致成本和隐私压力。

备选：火山引擎豆包流式语音识别模型 2.0

- 官方后付费：豆包流式语音识别模型 2.0 为 1 元/小时；普通“流式语音识别”后付费为 3.5 元/小时起，不能混用口径。
- 适合后续如果阿里实时识别效果不稳定时替换。

### LLM

内部测试首选：DeepSeek `deepseek-v4-flash`

- 用途：生成抓包吐槽、处理用户狡辩、多轮对喷。
- 接入：OpenAI-compatible Chat Completions，base URL `https://api.deepseek.com`。
- MVP 建议：默认非思考模式，请求体显式传 `thinking: {"type": "disabled"}`，单轮控制在 500 输入 Token、120 输出 Token 以内。

升级候选：

- 阿里云百炼 `qwen-turbo`：如果用户已持有百炼额度，可继续使用。
- `qwen-plus`：当吐槽质量不够时用于高强度角色包。
- 火山豆包文本模型：如果后续统一切到火山语音生态，可同步评估。

### TTS

默认：阿里云百炼 `cosyvoice-v3-flash`

- 用途：抓包播报和 AI 回怼。
- 官方计费：中国内地按输入字符计费，`cosyvoice-v3-flash` 为 0.8 元/万字符。
- MVP 建议：单句吐槽控制在 40-120 个中文字符，既便宜又有节奏。
- 默认音色：`longanyang`，支持普通话和英文，适合先跑通系统音色闭环。
- 方案边界：TTS 不再支持本地模型模式；如果用户想换音色，填写云端 Provider 支持的 voice id。

音色复刻/指定音色：

- 阿里 `qwen-voice-enrollment`：官方计费 0.01 元/音色，适合作为低成本授权音色录入入口。
- 阿里 `qwen-voice-design`：官方计费 0.2 元/音色，适合让用户生成“老板附体”“毒舌同事”等角色化音色。
- 腾讯云一句话声音复刻：可作为更成熟但更贵的备选，适合 v1.1 后做付费能力。

### Web Search

默认首选：Brave Search API

- 用途：抓包时把浏览器标签标题、域名和路径压成短 query，取前 3 条 title/url/description 交给 LLM，让吐槽能点名当前页面内容。
- 接入：`GET https://api.search.brave.com/res/v1/web/search?q=...&count=3`，Header 使用 `X-Subscription-Token`。
- 价格判断：官方页显示 Web Search API $5 / 1,000 requests，并有 $5 monthly credits；Hunter 只有命中黑名单时才搜索，默认免费额度足够小规模测试。
- MVP 建议：默认关闭；用户填 `BRAVE_SEARCH_API_KEY` 后手动打开。请求不带完整浏览历史，只带当前页标题/域名。

备选：Tavily Search API

- 用途：当用户希望搜索结果更适合 Agent/RAG，或后续要做页面 extract/crawl 时启用。
- 接入：`POST https://api.tavily.com/search`，请求体包含 `query`、`search_depth=basic`、`max_results=3`。
- 价格判断：官方 pricing 显示 Researcher 免费 1,000 API credits/月，Pay As You Go $0.008/credit，Project $30/月含 4,000 credits。
- MVP 建议：作为可选 Provider，不做默认推荐；普通抓包吐槽用 Brave snippets 更划算。

## Cost Estimate

假设单用户每天：

- 被抓包 30 次。
- 每次 AI 播报 100 字。
- 语音反驳总计 10 分钟。
- LLM 每轮 500 输入 Token + 120 输出 Token。

本地 ASR + 云端 TTS + DeepSeek LLM 估算：

- ASR：本地推理，云端成本 0。
- TTS：3,000 字 × 0.8 元/万字 = 0.24 元。
- LLM：约 18,600 Token，按 DeepSeek 官方价格折算，通常会低于语音云服务成本。
- 注意：本地 TTS 已移除，避免把“免费”成本转嫁成 20 秒以上等待时间。

阿里百炼云端 fallback 估算：

- ASR：600 秒 × 0.00024 元/秒 = 0.144 元。
- LLM：约 18,600 Token，低于 0.02 元。
- TTS：3,000 字 × 0.8 元/万字 = 0.24 元。
- 合计：约 0.4 元/天/重度用户，不含免费额度和失败重试。

结论：MVP 如果采用 push-to-talk，而不是全天候 ASR，成本可控。

## macOS Implementation Evaluation

### Foreground App Detection

推荐：

- `NSWorkspace.shared.frontmostApplication`
- 获取 App 名称、bundle identifier、activation time。

优点：原生、低成本、稳定。  
风险：只能知道前台 App，不能知道浏览器 URL。

### Browser URL Detection

MVP 支持：

- Chrome
- Safari

优先路线：

- AppleScript/ScriptingBridge 读取当前窗口当前标签 URL。

优点：实现快，适合 MVP。  
风险：需要自动化权限；多窗口、多 Profile、隐身窗口需要测试。

后续路线：

- 浏览器扩展主动上报当前域名。
- 适合提高准确率，但分发和授权成本更高。

### Local Storage

MVP 可选：

- SwiftData：适合纯 SwiftUI 新项目。
- SQLite：更容易后续跨语言脚本分析日志。

建议第一版用 SQLite 或轻量封装，数据表：

- `rules`
- `incidents`
- `voice_sessions`
- `provider_templates`
- `provider_configs`
- `provider_test_runs`
- `localization_settings`
- `settings`
- `provider_credentials_metadata`

### Secret Storage

- API Key 使用本机 `~/Library/Application Support/Hunter/.env.local` 作为当前运行真源，并在进程内缓存。
- 运行热路径和保存路径都不访问 macOS Keychain，避免签名变化、旧 ACL 或系统钥匙串策略导致反复弹窗。
- 本地开发仍可使用仓库根目录 `.env.local`，必须加入 `.gitignore`。
- 日志中禁止打印完整 Key、Secret、Authorization header。
- Provider 导出不包含密钥，只导出 `apiKeyRef` 占位和非敏感字段。
- 搜索增强默认关闭；开启后只发送当前页面标题、域名和少量路径信息生成 query，不上传连续浏览历史或全页内容。

### Browser Automation Permissions

- 前台浏览器 URL/标题读取需要 macOS 自动化权限。
- 监控循环先用 `AEDeterminePermissionToAutomateTarget(..., askUserIfNeeded: false)` 静默检查权限；未授权时跳过 URL 读取，不弹系统授权框。
- 后续如果需要主动引导授权，应放到设置页的用户点击动作里，不在抓包热路径里触发。

### Internationalization

- UI 语言：`zh-Hans`, `en`。
- AI 输出语言：follow UI, `zh-Hans`, `en`。
- ASR language hint：auto, Mandarin, English, mixed。
- i18n 字符串集中管理，SwiftUI 视图只引用 key。
- 默认 prompt 模板分中英文维护，但共享同一套安全边界。
- TTS voice metadata 必须包含 `supportedLanguages`，避免英文输出使用只支持中文的音色。

## Safety And Abuse Controls

- 破防模式需要二次确认。
- 用户可以自定义禁用词。
- LLM 输出进入本地 safety pass 后再交给 TTS。
- 禁止对受保护属性、人身安全、自伤、真实威胁进行辱骂。
- 音色复刻必须展示授权声明，不支持上传第三方未授权样本。
- 英文粗口同样按强度档位限制，不能绕过中文安全策略。

## Open Questions

- MVP 内置 Provider 模板要覆盖到哪些供应商？
- TTS 音色复刻是 MVP 必须上线，还是先做“默认音色 + 音色设计”，复刻放到 v1.1？
- 对喷模式使用 push-to-talk 还是 always-listening？从成本和隐私角度，MVP 建议 push-to-talk。

## Sources

- DeepSeek API 快速开始：<https://api-docs.deepseek.com/zh-cn/>
- sherpa-onnx SenseVoice：<https://k2-fsa.github.io/sherpa/onnx/sense-voice/index.html>
- sherpa-onnx SenseVoice 模型下载：<https://k2-fsa.github.io/sherpa/onnx/sense-voice/pretrained.html>
- Qwen3-TTS GitHub：<https://github.com/QwenLM/Qwen3-TTS>
- Qwen3-ASR 0.6B：<https://huggingface.co/Qwen/Qwen3-ASR-0.6B>
- 阿里云百炼模型价格：<https://help.aliyun.com/zh/model-studio/model-pricing>
- 火山引擎豆包语音计费说明：<https://www.volcengine.com/docs/6561/1359370?lang=zh>
- 腾讯云声音复刻计费概述：<https://cloud.tencent.com/document/product/1283/93105>

价格与模型快照复核日期：2026-05-28；本地 TTS 取舍更新日期：2026-05-29。
