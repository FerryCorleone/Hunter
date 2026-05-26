# Hunter Technical Evaluation

版本：v0.2  
日期：2026-05-27  
状态：待审阅

## Decision Summary

第一版架构建议采用 **用户可配置 Provider Registry**。ASR、LLM、TTS 三段都允许用户填写自己的供应商、模型、endpoint 和 API key；项目内置推荐模板用于降低上手成本，但不能把模型供应商写死。

内部测试默认使用 **阿里云百炼全家桶**：

- ASR：`paraformer-realtime-v2`
- LLM：`qwen-turbo` 或 `qwen-turbo-latest`
- TTS：`cosyvoice-v3.5-flash`
- 音色复刻/设计：`qwen-voice-enrollment` / `qwen-voice-design`

理由：价格低、中英文能力够用、音色相关能力明确、API 归属统一，适合先把 MVP 闭环跑通。火山引擎作为第二候选，尤其适合后续追求更强语音表现力；腾讯云声音复刻能力完整，但对 MVP 来说训练和复刻 TTS 成本更重。

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
- 可控边界：能在 LLM prompt 和产品层限制辱骂边界。
- 用户可配置：ASR/LLM/TTS 可以分别切换 Provider。

## Provider Registry

### Configuration Model

每个 provider 配置至少包含：

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

- Aliyun Bailian：ASR、LLM、TTS、voice enrollment/design。
- OpenAI-compatible：LLM/TTS/ASR 可按兼容接口自填。
- Custom HTTP：给高级用户填写 endpoint、headers、body mapping。
- Volcengine：作为语音效果增强候选模板。
- Tencent Cloud：作为声音复刻候选模板。

### Runtime Rules

- 监督检测不依赖 Provider；Provider 缺失时仍记录抓包，但不播报。
- 抓包播报依赖 LLM + TTS；语音反驳依赖 ASR + LLM + TTS。
- Provider 测试分为单项测试和端到端测试。
- 失败统一归一化为：auth error、network error、model error、quota error、unsupported language、unsupported voice。

## Provider Comparison

| 供应商 | 推荐用途 | 价格观察 | 优点 | 风险 |
|---|---|---:|---|---|
| 阿里云百炼 | MVP 默认 | ASR 约 0.00024 元/秒，Qwen Turbo 0.3/0.6 元每百万 Token，CosyVoice Flash 0.8 元/万字符 | 便宜，统一入口，音色 enrollment/design 价格明确 | TTS 情绪表现要实测，Mac 端 SDK 可能主要走 HTTP/WebSocket |
| 火山引擎豆包语音 | 第二候选/语音增强 | 后付费豆包流式 ASR 1 元/小时，豆包 TTS/声音复刻 3 元/万字符 | 字节语音生态强，适合节目化声音效果 | TTS 成本高于阿里，部分能力可能需要控制台开通和配额 |
| 腾讯云 | 音色复刻备选 | 一句话声音复刻训练约 12-39 元/音色，复刻合成后付费 6.4-8 元/万字符 | 声音复刻产品成熟，文档完整 | MVP 阶段偏贵，基础版训练成本高 |
| OpenAI-compatible | 用户自带 | 取决于用户 endpoint | 生态广，很多代理和私有网关兼容 | TTS/ASR 字段差异大，需要自定义 mapping |

## Recommended MVP Stack

### ASR

内部测试首选：阿里云百炼 `paraformer-realtime-v2`

- 用途：用户按住快捷键反驳时，实时或准实时转写。
- 官方计费：实时语音识别按输入音频秒数计费，`paraformer-realtime-v2` 为 0.00024 元/秒，并有每月 36,000 秒免费额度。
- MVP 用法：Push-to-talk，每次 3-15 秒，避免常开麦克风导致成本和隐私压力。

备选：火山引擎豆包流式语音识别模型 2.0

- 官方后付费：1 元/小时。
- 适合后续如果阿里实时识别效果不稳定时替换。

### LLM

内部测试首选：阿里云百炼 `qwen-turbo`

- 用途：生成抓包吐槽、处理用户狡辩、多轮对喷。
- 官方计费：中国内地输入 0.3 元/百万 Token，输出 0.6 元/百万 Token；思考模式输出 3 元/百万 Token。
- MVP 建议：默认非思考模式，单轮控制在 500 输入 Token、120 输出 Token 以内。

升级候选：

- `qwen-plus`：当吐槽质量不够时用于高强度角色包。
- 火山豆包文本模型：如果后续统一切到火山语音生态，可同步评估。

### TTS

内部测试首选：阿里云百炼 `cosyvoice-v3.5-flash`

- 用途：抓包播报和 AI 回怼。
- 官方计费：中国内地按输入字符计费，`cosyvoice-v3.5-flash` 为 0.8 元/万字符。
- MVP 建议：单句吐槽控制在 40-120 个中文字符，既便宜又有节奏。

音色复刻/指定音色：

- 阿里 `qwen-voice-enrollment`：官方计费 0.01 元/音色，适合作为低成本授权音色录入入口。
- 阿里 `qwen-voice-design`：官方计费 0.2 元/音色，适合让用户生成“老板附体”“毒舌同事”等角色化音色。
- 腾讯云一句话声音复刻：可作为更成熟但更贵的备选，适合 v1.1 后做付费能力。

## Cost Estimate

假设单用户每天：

- 被抓包 30 次。
- 每次 AI 播报 100 字。
- 语音反驳总计 10 分钟。
- LLM 每轮 500 输入 Token + 120 输出 Token。

阿里百炼测试模板估算：

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

- API Key 使用 macOS Keychain。
- 本地开发可使用 `.env.local`，必须加入 `.gitignore`。
- 日志中禁止打印完整 Key、Secret、Authorization header。
- Provider 导出不包含密钥，只导出 `apiKeyRef` 占位和非敏感字段。

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

- 阿里云百炼模型价格：<https://help.aliyun.com/zh/model-studio/model-pricing>
- 火山引擎豆包语音计费说明：<https://www.volcengine.com/docs/6561/1359370?lang=zh>
- 腾讯云声音复刻计费概述：<https://cloud.tencent.com/document/product/1283/93105>
