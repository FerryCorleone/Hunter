# Hunter Technical Evaluation

版本：v1.0.0
日期：2026-06-16
状态：第一版公开发布，TTS 只走云端 API

## Decision Summary

第一版架构建议采用 **用户可配置 Provider Registry**。ASR、LLM、TTS 都允许用户填写自己的供应商、模型/模式、endpoint 和 API key；项目内置推荐模板用于降低上手成本，但不能把模型供应商写死。

当前默认测试链路调整为 **DeepSeek LLM + 云端 ASR + 云端 TTS**，本地 SenseVoice 作为用户主动切换后的隐私/成本选项：

- LLM：DeepSeek API，`deepseek-v4-flash`，OpenAI-compatible `https://api.deepseek.com`。
- 默认云端 ASR：阿里百炼 `paraformer-realtime-v2`，保留 OpenAI `gpt-4o-mini-transcribe` 和 Xiaomi MiMo `mimo-v2.5-asr` 模板；用户先填写自己的 API Key。
- 可选本地 ASR：`SenseVoice Small INT8` via `sherpa-onnx`，用户切换到本地模型后在客户端内下载，支持普通话、粤语、英文、日文、韩文，Mac arm64/x64 可用。
- TTS：本地 TTS 路线回滚，MVP 统一走云端 TTS Provider，当前默认 Xiaomi MiMo `mimo-v2.5-tts + 白桦`，保留 OpenAI `gpt-4o-mini-tts + coral` 和阿里百炼 `cosyvoice-v3.5-flash` 模板；阿里正式声音复刻链路优先使用克隆/设计后的 `voice_id`。
- 本地声音克隆：MVP 不做；后续只考虑云端授权音色 enrollment/design。
- 云端声音克隆：产品侧只评估国内厂商。MVP 继续保留已接通的 Xiaomi MiMo inline 授权样本方案；下一优先级是阿里百炼 Qwen/CosyVoice 的长期 `voice_id` enrollment。MiniMax、阶跃星辰、豆包语音作为表现力 benchmark 候选；百度、腾讯、讯飞、华为偏企业/专用 adapter，暂不进入普通下拉。
- 云端 ASR/TTS 保留阿里百炼模板：`paraformer-realtime-v2`、`cosyvoice-v3.5-flash`；OpenAI 模板为 `gpt-4o-mini-transcribe` / `gpt-4o-mini-tts + coral`；MiMo 模板使用 `https://api.xiaomimimo.com/v1`、`MIMO_API_KEY`、`api-key` 鉴权头，ASR 模型为 `mimo-v2.5-asr`，TTS 默认模型为 `mimo-v2.5-tts`。
- 第一版移除联网搜索增强，抓包 prompt 只使用本机可见的 App、URL host 和浏览器标签标题。

理由：DeepSeek 的文本接口符合 OpenAI Chat Completions 形态，接入成本低；本地 SenseVoice ASR 的短音频识别延迟稳定在 1 秒以内；本地 Qwen3-TTS 在真实抓包链路中首次合成约 28-32 秒，明显破坏节目效果；本地 CosyVoice3 0.5B MLX 4bit 虽能跑通，但实际音质不符合产品要求，因此 TTS 回滚为云端 API。第一版为了保持设置页和运行链路简洁，不保留联网搜索增强。

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
- 本地部署：ASR 支持用户在设置页选择“本地模型”，并下载官方/开源模型到本机；TTS 不提供本地模型模式。
- 可控边界：能在 LLM prompt 和产品层限制辱骂边界。
- 用户可配置：ASR/LLM/TTS 可以分别切换 Provider。

## Provider Registry

### Configuration Model

云端 provider 配置在 MVP UI 中只暴露模板化字段：

```text
厂商下拉 / 可编辑模型 ID 下拉 / API Key
```

厂商下拉只表示 vendor，不把厂商名和推荐模型拼成同一个选项；模型 ID 是独立可编辑下拉字段，内置厂商给出常用模型建议，用户可以按厂商支持情况改模型 ID 或直接输入自定义模型名。ASR、LLM、TTS 都必须提供“自定义厂商”，自定义时展示厂商名、Base URL、模型 ID 和 API Key。内部配置仍保留 Base URL、鉴权 scheme、headers、region、语言提示、流式能力等字段，用于 adapter 默认值和自定义 Provider。每个 provider 完整配置模型至少包含：

```json
{
  "id": "aliyun-qwen-turbo",
  "type": "llm",
  "displayName": "Aliyun Bailian / Qwen Turbo",
  "baseURL": "https://dashscope.aliyuncs.com/compatible-mode/v1",
  "model": "qwen-turbo",
  "authType": "bearer",
  "apiKeyRef": "env.local://DASHSCOPE_API_KEY",
  "headers": {},
  "supportsStreaming": true,
  "languages": ["zh-CN", "en-US", "mixed"],
  "costHint": "0.3/0.6 CNY per 1M input/output tokens",
  "enabled": true
}
```

### Built-in Templates

MVP 内置模板只提供默认字段，不提供密钥。设置页模型字段是可编辑下拉：默认值保持稳定，候选项跟随厂商官方模型 ID 维护；用户输入自定义模型 ID 后写入本机配置草稿，API Key 通过输入框后的保存/更新按钮提交并获得 toast/状态反馈。

- DeepSeek：默认 LLM `deepseek-v4-flash`；候选包含 `deepseek-v4-flash`、`deepseek-v4-pro`、`deepseek-chat`。
- Xiaomi MiMo：默认 LLM `mimo-v2.5`，候选包含 `mimo-v2.5-pro`、`mimo-v2.5`、`mimo-v2-pro`、`mimo-v2-flash`；ASR 候选 `mimo-v2.5-asr`；TTS 候选 `mimo-v2.5-tts`、`mimo-v2.5-tts-voicedesign`、`mimo-v2.5-tts-voiceclone`，支持预置音色和 inline 授权样本克隆。
- OpenAI：默认 LLM `gpt-4.1-mini`，候选包含 `gpt-5.5`、`gpt-5.4-mini`、`gpt-5.4-nano`、`gpt-5.1`、`gpt-5-mini`、`gpt-5-nano`、`gpt-4.1-mini`、`gpt-4.1`；ASR `gpt-4o-mini-transcribe` / `gpt-4o-transcribe`；TTS `gpt-4o-mini-tts + coral`。
- Aliyun Bailian：默认 ASR `paraformer-realtime-v2`，候选包含 `paraformer-realtime-v2`、`paraformer-realtime-8k-v2`、`paraformer-v2`、`paraformer-8k-v2`；默认 LLM `qwen-turbo`，候选包含 `qwen3.7-plus`、`qwen3.6-plus`、`qwen3.6-flash`、`qwen3.5-plus`、`qwen-plus`、`qwen-turbo`、`qwen-max`；默认 TTS `cosyvoice-v3.5-flash`，候选包含 `cosyvoice-v3.5-flash`、`cosyvoice-v3.5-plus`、`cosyvoice-v3-flash`、`cosyvoice-v3-plus`、`qwen3-tts-flash`、`qwen3-tts-instruct-flash`、`qwen3-tts-vc*`、`qwen3-tts-vd*`。
- Moonshot Kimi：默认 LLM `kimi-k2.5`，候选优先 `kimi-k2.6`、`kimi-k2.5`；`kimi-latest` 不再作为推荐候选。
- Zhipu GLM：默认 LLM `glm-4.7`，候选包含 `glm-5.1`、`glm-5`、`glm-5-turbo`、`glm-4.7`、`glm-4.7-flashx`、`glm-4.7-flash`、`glm-4.6`、`glm-4.5-air`、`glm-4-flash-250414`。
- Volcengine Ark：默认 LLM `doubao-seed-2-0-lite-260215`，候选包含 `doubao-seed-2-0-pro-260215`、`doubao-seed-2-0-lite-260215`、`doubao-seed-2-0-mini-260215`、`doubao-seed-2-0-code-preview-260215`、`doubao-seed-1-8-251228`。
- Tencent Hunyuan：默认 LLM `hunyuan-turbos-latest`，候选包含 `hunyuan-t1-latest`、`hunyuan-a13b`、`hunyuan-turbos-latest`、`hunyuan-lite`、`hunyuan-large-role-latest`。
- Custom HTTP：给高级用户填写 endpoint、headers、body mapping。
- 国内语音克隆候选：MiniMax、StepFun、火山引擎豆包语音、百度大模型声音复刻、腾讯云声音复刻、讯飞一句话复刻、华为云 SIS 声音复刻。它们需要专用签名、region、app id、voice id 或 WebSocket adapter，补齐真实 smoke 后再进入普通下拉。

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
| 本地 SenseVoice | 可选本地 ASR | 模型免费下载，本机推理 | 中英日韩粤，sherpa-onnx 有 macOS/Python wheel；隐私和成本好；不增加初始安装包体积 | 标点和口语纠错需后处理；首次下载约 493 MB 解压 |
| 本地 CosyVoice3 0.5B MLX 4bit | Rejected | 模型免费下载，本机推理 | 模型体积相对可控，短句可跑通 | 本机实测音质不符合 Hunter 抓包播报要求，且需要额外 helper/runtime，MVP 已回滚 |
| 本地 Qwen3-TTS CustomVoice | Rejected | 模型免费下载，本机推理 | 中英文、多语言、9 个预置音色、语气控制，Apache-2.0 | 本机实测首次合成约 28-32 秒，抓包后等待太久，MVP 已移除 |
| 本地 Qwen3-TTS Base | Rejected | 模型免费下载，本机推理 | 短参考音频声音克隆；不需要云端上传样本 | 同样受本地推理延迟影响，且授权样本 UI 让 MVP 复杂度过高，已移除 |
| OpenAI | 通用 ASR/LLM/TTS 模板 | 按 OpenAI 官方 API 计费 | 官方提供 Transcriptions、Chat Completions 和 audio/speech，协议清晰，适合海外用户或已有 OpenAI key 的用户 | 国内网络可用性和成本取决于用户环境；TTS 不接 Hunter 当前 MiMo 声音克隆流程 |
| 阿里云百炼 | 云端 ASR/TTS fallback、长期 voice id 克隆首选 | ASR 约 0.00024 元/秒；CosyVoice v3.5 Flash 0.8 元/万字符；`qwen-voice-enrollment` 0.01 元/音色；`qwen-voice-design` 0.2 元/音色 | 便宜，统一入口，音色 enrollment/design 价格明确；可返回长期 `voice_id`，更适合跨 Provider 抽象 | TTS 情绪表现要实测；Qwen-TTS VC 与 CosyVoice 克隆 API 形态不同，adapter 不能只按一个 endpoint 写 |
| Xiaomi MiMo | ASR 候选 / MVP 默认云端 TTS / inline 授权样本克隆 | 定价页显示 V2.5 TTS、VoiceClone、VoiceDesign 当前限时免费 | V2.5 ASR 官方模型 ID 为 `mimo-v2.5-asr`；V2.5 TTS 支持预置音色、文本音色设计、inline 音频样本复刻，当前实现已接通，Chat Completions 形态便于接入 | ASR 云端协议仍需真实平台 smoke 确认；免费策略可能变；inline clone 每次请求携带授权样本，不是长期 `voice_id`；鉴权使用 `api-key` header；音频以 base64 返回；V2.5 流式目前为兼容模式 |
| Moonshot / Zhipu / Volcengine Ark / Tencent Hunyuan | LLM 下拉扩展 | 按各厂商官方 API 计费 | 均有 OpenAI-compatible Chat Completions，可直接复用 Hunter LLM adapter，用户只填对应 API Key | 只覆盖 LLM；不同厂商 thinking、temperature、上下文和错误格式细节仍要继续实测 |
| MiniMax | 表现力 benchmark / 付费高质音色候选 | 官方直连：Speech 2.8 Turbo 60 美元/百万字符、HD 100 美元/百万字符、快速克隆 1.5 美元/音色；阿里百炼 MiniMax 入口：Turbo 2 元/万字符、HD 3.5 元/万字符、复刻 9.9 元/音色 | 音色表现力强，官方支持快速克隆；通过阿里百炼接入时人民币计费且国内部署 | 直连美元价格偏高；直连和百炼入口 API/计费口径不同，需要明确选一个 adapter |
| StepFun 阶跃星辰 | 表现力 benchmark / 语境控制候选 | `stepaudio-2.5-tts` 0.85 美元/万字符；`step-tts-2` 0.40 美元/万字符；voice cloning 1.50 美元/音色 | 官方明确推荐新项目使用 `stepaudio-2.5-tts`，支持 zero-shot voice cloning 和自然语言情绪风格控制，适合 Hunter 的“演文本”吐槽 | 单价高于阿里/豆包；单次输入上限 1,000 字符；需实测中文短句首包延迟 |
| 火山引擎豆包语音 | 语音增强 / 大厂生产候选 | 豆包声音复刻模型 2.0 资源包 2.1-2.8 元/万字符，后付费 3 元/万字符；音色槽位 28-138 元/音色；大模型声音复刻后付费 8 元/万字符 | 字节语音生态强，情绪/节目化效果值得 benchmark；并发和资源包信息完整 | 比阿里贵；音色槽位另计；专用签名、控制台配置和商品口径复杂，普通下拉不宜过早暴露 |
| 百度智能云 | 企业级声音复刻备选 | 创建音色后付费 8.8 元/音色，预付费 4-8 元/音色；复刻合成后付费 7 元/万字符，预付费 4.5-6.5 元/万字符 | 支持 5 秒极速复刻、双流式合成、跨语种/方言复刻，价格公开 | 合成单价偏高；云厂商 API/签名和控制台开通流程较重 |
| 腾讯云 | 成熟企业音色复刻备选 | 一句话版训练 12-39 元/音色，合成 6.4-8 元/万字符；基础版训练 2,500-4,500 元/音色，合成 0.15-0.3 元/万字符 | 声音复刻产品成熟，免费额度和文档完整，适合批量企业音色 | 个人/MVP 阶段偏贵；基础版训练成本高；存储和并发费用也要纳入 |
| 讯飞开放平台 | 方言/多风格企业备选 | 官方 API 文档说明按训练次数和合成字符数授权，但公开文档未直接给出价格，需控制台购买/商务确认 | 一句话复刻标准版和多风格版成熟，支持流式合成、多语种和多风格/方言 | 价格透明度不足；鉴权、训练任务、WebSocket 合成链路较重 |
| 华为云 SIS | 政企/合规备选 | SIS 声音复刻公开 API 有注册/合成/流式合成；价格需以控制台/商务为准 | 零样本、5 秒样本、秒级注册，适合政企合规场景 | 公开价格不完整；对 Hunter 个人工具不是优先路线 |
| Custom OpenAI-compatible | 高级用户自带 | 取决于用户 endpoint | 生态广，很多代理和私有网关兼容；普通 UI 已开放自定义厂商名、Base URL、模型和 API Key | 当前只按 LLM `/chat/completions`、ASR `/audio/transcriptions`、TTS `/audio/speech` 调用，字段差异大的供应商仍需专用 adapter |

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
- 抓包 prompt 保留完整网页标题作为 LLM 上下文，用来判断用户具体在看什么；系统提示词必须限制最终吐槽为一句短播报，禁止照读标题、URL、query string、长 ID 或符号串。

升级候选：

- 阿里云百炼 `qwen-turbo`：如果用户已持有百炼额度，可继续使用。
- `qwen-plus`：当吐槽质量不够时用于高强度角色包。
- 火山豆包文本模型：如果后续统一切到火山语音生态，可同步评估。

### TTS

默认：Xiaomi MiMo `mimo-v2.5-tts + 白桦`

- 用途：抓包播报和 AI 回怼。
- 官方计费：MiMo 定价页显示 `mimo-v2.5-tts`、`mimo-v2.5-tts-voiceclone`、`mimo-v2.5-tts-voicedesign` 当前限时免费；不能把限免当长期商业价格。
- MVP 建议：单句吐槽控制在 40-120 个中文字符，既便宜又有节奏。
- 阿里系统音色：`longanyang` 支持普通话和英文，仅作为 `cosyvoice-v3-flash` / `cosyvoice-v3-plus` 等支持系统音色模型的可选模板；`cosyvoice-v3.5-flash` / `cosyvoice-v3.5-plus` 官方无系统音色，必须先使用声音复刻或声音设计生成 `voice_id`。
- 方案边界：TTS 不支持本地模型模式；如果用户想换音色，选择云端 Provider 支持的 voice id。

Xiaomi MiMo V2.5 TTS:

- 接入：`POST https://api.xiaomimimo.com/v1/chat/completions`，Header 使用 `api-key: $MIMO_API_KEY`。
- 预置音色模型：`mimo-v2.5-tts`；文本音色设计：`mimo-v2.5-tts-voicedesign`；音频样本复刻：`mimo-v2.5-tts-voiceclone`。
- 请求形态：目标播报文本放在 `role=assistant` 的 message；`role=user` 可放自然语言风格指令。
- 方言控制：普通话/英文以语言提示处理；粤语、四川话、东北话、河南话等方言必须同时在 `role=user` 放强约束风格说明，并在 `role=assistant` 播报文本前加官方 tag，例如 `(河南话)抓到你了`，避免只靠自然语言风格说明时回退成普通话。
- 响应形态：非流式返回 `choices[0].message.audio.data`，内容为 base64 音频；Hunter 需本地解码后播放/缓存。
- 预置音色仅适用于 `mimo-v2.5-tts`：`mimo_default`、`冰糖`、`茉莉`、`苏打`、`白桦`、`Mia`、`Chloe`、`Milo`、`Dean`；`mimo-v2.5-tts-voiceclone` 必须选择授权样本克隆音色，不展示普通预置音色。
- 当前本机 smoke 中 `白桦` 的 SenseVoice 回读最稳定，因此作为 MiMo 默认音色。
- 当前限制：V2.5 低延迟流式暂未上线；流式调用目前在所有推理完成后以兼容流格式返回一次。

音色复刻/指定音色：

- 阿里 `qwen-voice-enrollment`：官方计费 0.01 元/音色，适合作为低成本授权音色录入入口；当前 Hunter 只把它用于 `qwen3-tts-vc*` 系列，避免把 Qwen 与 CosyVoice 的不同创建接口混用。
- 阿里 `qwen-voice-design`：官方计费 0.2 元/音色，适合让用户生成“学习监督”“工作监督”等场景化音色。
- 阿里 CosyVoice 声音复刻/声音设计：创建音色后返回 `voice_id`，再用于 `cosyvoice-v3.5-plus` / `cosyvoice-v3.5-flash` / `cosyvoice-v3-plus` / `cosyvoice-v3-flash` 等模型合成；这是更接近 Hunter `providerVoice(id)` 抽象的长期音色方案。Hunter 正式优先接 `cosyvoice-v3.5-flash`：本地样本先上传到百炼免费临时存储，获得 48 小时有效的 `oss://dashscope-instant/...` URL；随后调用 `voice-enrollment/create_voice`，并在 HTTP Header 中加入 `X-DashScope-OssResourceResolve: enable` 让百炼解析临时 URL；创建后查询 `query_voice`，只有状态为 `OK` 才保存 `voice_id`。声音设计不需要样本，调用同一个 customization endpoint，传入 `voice_prompt`、`preview_text`、`prefix`、`language_hints` 和当前 TTS 模型作为 `target_model`，返回 `voice_id` 后同样查询到 `OK` 才保存。Hunter 只暴露单个声音设计表单，让用户自行输入音色名称和声音描述提示词；生成时只追加轻量正向质量约束，要求近距离清晰人声、口齿清楚、音色干净自然，避免把“底噪/电流声/混响/失真”等负面词堆进提示导致模型过度处理。生成结果保存为 `promptDesignedVoice` 并进入同一音色下拉，不预置或批量生成角色包。CosyVoice 合成默认以干净复现音色为优先：不默认启用 SSML，不默认传强情感 `instruction`，`rate` / `pitch` 保持中性；只有明确方言/口音等需要时才传入短指令。CosyVoice 后续合成按所选 CosyVoice 模型的文本字符数计费；Qwen-TTS 声音设计单价为 0.2 元/音色，中国内地有 10 个音色/账号免费额度。官方当前推荐 `cosyvoice-v3.5-plus` 做自定义音色高质合成，`cosyvoice-v3.5-flash` 适合低延迟和成本优先场景。
- MiMo `mimo-v2.5-tts-voiceclone`：上传前将授权样本转成 `data:{MIME_TYPE};base64,$BASE64_AUDIO` 放入 `audio.voice`，支持 mp3/wav，base64 字符串大小不超过 10 MB；它更像“每次请求携带授权样本”的 inline clone，不是先 enrollment 再返回长期 voice id。
- MiMo `mimo-v2.5-tts-voicedesign`：通过 user message 的音色描述生成定制声音，适合 Hunter 角色包快速试音。
- Hunter 当前实现：`VoiceReference.kind = inlineAuthorizedSample` 时只把授权样本复制到 `~/Library/Application Support/Hunter/VoiceSamples/`，保存 MIME、大小和授权标记；合成时 adapter 自动切到 `mimo-v2.5-tts-voiceclone` 并构造 data URI，音频结果按 model/voice/language/style/text 走本地缓存，避免河南话等方言设置复用旧普通话音频。首次 clone 合成会比预置音色多一次样本读取、base64 编码和上传 payload，重复同文本同风格命中缓存后不再请求云端。
- MiniMax：快速克隆生成的音色 7 天内如果未用于 T2A 合成会删除；首次用克隆音色合成时收费。适合作为高表现力 benchmark，不建议优先替换 MiMo/阿里。
- StepFun：`stepaudio-2.5-tts` 支持 3 秒参考音频 zero-shot clone 和自然语言风格控制；适合测“控制狂/暴躁老哥/正能量天使”角色播报表现力。
- 火山豆包：需要把“豆包声音复刻模型 2.0”“大模型声音复刻”“音色槽位”三个计费口径分清楚；适合 v1 后做生产级 benchmark。
- 百度/腾讯/讯飞/华为：作为企业备选，不进入 MVP 默认模板；除非用户明确要用对应云账号或场景要求方言/合规/政企部署。

跨 Provider voice clone 交互抽象：

- `presetVoice(id)`：Provider 内置音色，例如 `longanyang`、`苏打`。
- `providerVoice(id)`：Provider enrollment 返回的长期 voice id，例如阿里/腾讯类克隆音色。
- `inlineAuthorizedSample(fileRef, mimeType, consent)`：MiMo 这类每次请求携带样本的复刻模式；本机只保存样本引用、授权确认、hash 和来源，不把样本上传到 Hunter 自有服务。
- `promptDesignedVoice(prompt)`：文本音色设计模式；保存 prompt 和一次测试结果，不伪装成真实授权克隆。

## Cost Estimate

假设单用户每天：

- 被抓包 30 次。
- 每次 AI 播报 100 字。
- 语音反驳总计 10 分钟。
- LLM 每轮 500 输入 Token + 120 输出 Token。

低成本云端 ASR + 阿里 CosyVoice TTS + DeepSeek LLM 估算：

- ASR：600 秒 × 0.00024 元/秒 = 0.144 元。
- TTS：3,000 字 × 0.8 元/万字 = 0.24 元。
- LLM：约 18,600 Token，按 DeepSeek 官方价格折算，通常会低于语音云服务成本。

可选本地 ASR 估算：

- ASR：本地推理，云端成本 0。
- LLM：约 18,600 Token，低于 0.02 元。
- TTS：3,000 字 × 0.8 元/万字 = 0.24 元。
- 合计：约 0.24 元/天/重度用户，不含免费额度和失败重试。

结论：MVP 如果采用 push-to-talk，而不是全天候 ASR，成本可控。MiMo 当前限时免费时日常成本更低，但商业估算仍按阿里/豆包这类公开字符单价保守计算。

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

- “允许强制关闭”必须是用户主动开启的独立开关，只关闭当前命中的浏览器标签页或请求退出当前前台 App；不做断网、强杀、不可关闭监督或远程控制。
- 用户可以自定义禁用词。
- LLM 输出进入本地 safety pass 后再交给 TTS；safety pass 必须移除 URL、长 ID、query string 和用户配置禁用词，并压缩过长文本，避免 TTS 播报变成读链接或长篇解释。
- 禁止对受保护属性、人身安全、自伤、真实威胁进行辱骂。
- 音色复刻必须展示授权声明，不支持上传第三方未授权样本。
- 英文粗口同样按强度档位限制，不能绕过中文安全策略。

## Open Questions

- MVP 内置 Provider 模板要覆盖到哪些国内语音供应商？
- 云端 TTS 音色复刻继续用 MiMo inline 样本，还是优先补阿里 `providerVoice(id)` 长期音色 adapter？
- 对喷模式使用 push-to-talk 还是 always-listening？从成本和隐私角度，MVP 建议 push-to-talk。

## Sources

- DeepSeek API 快速开始：<https://api-docs.deepseek.com/zh-cn/>
- sherpa-onnx SenseVoice：<https://k2-fsa.github.io/sherpa/onnx/sense-voice/index.html>
- sherpa-onnx SenseVoice 模型下载：<https://k2-fsa.github.io/sherpa/onnx/sense-voice/pretrained.html>
- Qwen3-TTS GitHub：<https://github.com/QwenLM/Qwen3-TTS>
- Qwen3-ASR 0.6B：<https://huggingface.co/Qwen/Qwen3-ASR-0.6B>
- OpenAI Text generation / Audio docs：<https://platform.openai.com/docs/guides/text>、<https://platform.openai.com/docs/guides/speech-to-text>、<https://platform.openai.com/docs/guides/text-to-speech>
- 阿里云百炼模型价格：<https://help.aliyun.com/zh/model-studio/model-pricing>
- 阿里云百炼声音复刻：<https://www.alibabacloud.com/help/zh/model-studio/voice-cloning-user-guide>
- 阿里云百炼 OpenAI 兼容模式：<https://help.aliyun.com/zh/model-studio/openai-compatible>
- 火山引擎豆包语音计费说明：<https://www.volcengine.com/docs/6561/1359370?lang=zh>
- 火山方舟模型推理 API：<https://www.volcengine.com/docs/82379/1298454>
- MiniMax API 计费：<https://platform.minimax.io/docs/guides/pricing-paygo>
- MiniMax 语音订阅：<https://platform.minimax.io/docs/guides/pricing-speech>
- MiniMax Voice Cloning：<https://minimax-cac98058.mintlify.dev/docs/api-reference/voice-cloning-intro>
- StepFun Pricing and Rate Limits：<https://platform.stepfun.ai/docs/en/guides/pricing/details>
- StepFun Audio Models：<https://platform.stepfun.com/docs/zh/guides/models/audio>
- 百度大模型声音复刻计费：<https://cloud.baidu.com/doc/SPEECH/s/vm9sbp4z9>
- 百度大模型声音复刻产品页：<https://cloud.baidu.com/product/speech/voicecloning>
- Moonshot/Kimi API 文档：<https://platform.moonshot.cn/docs>
- 智谱 BigModel API 文档：<https://docs.bigmodel.cn/cn/guide/start/introduction>
- 腾讯混元 OpenAI 兼容接口：<https://cloud.tencent.com/document/product/1729/111007>
- 腾讯云声音复刻计费概述：<https://cloud.tencent.com/document/product/1283/93105>
- 讯飞一句话复刻标准版 API：<https://www.xfyun.cn/doc/spark/reproduction.html>
- 讯飞一句话复刻多风格版 API：<https://www.xfyun.cn/doc/spark/voiceclone.html>
- 华为云 SIS 声音复刻接口：<https://support.huaweicloud.com/api-sis/sis_03_0153.html>
- Xiaomi MiMo OpenAI-compatible Chat API：<https://platform.xiaomimimo.com/docs/en-US/api/chat/openai-api>
- Xiaomi MiMo V2.5 TTS 文档：<https://platform.xiaomimimo.com/docs/usage-guide/speech-synthesis-v2.5>
- Xiaomi MiMo 定价：<https://platform.xiaomimimo.com/docs/zh-CN/pricing>

价格与模型快照复核日期：2026-06-06；本地 TTS 回滚日期：2026-06-01。
