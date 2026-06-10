# Hunter Test Report - 2026-05-31

测试时间：2026-05-31 14:00-15:20 CST
测试对象：当前工作区 `/Users/wumu/Documents/开发/AI编程项目/Hunter`
测试方式：命令行质量门、打包校验、Provider 烟测、桌面 UI 验收、独立 Chrome 窗口浏览器 URL 读取验证、源码审阅。

## 1. 结论

当前版本具备可运行基础，但不建议标记为完整验收通过。

基础工程质量门通过，ASR / LLM / 默认 TTS 命令行链路通过，设置窗口和悬浮球基础呈现可用。阻断点集中在真实用户保存配置与验收命令不一致：当前 App 保存音色为 `longwanqing`，UI TTS 测试和真实 Bilibili 抓包 TTS 均失败，导致实际抓包无法完成语音播报和抓包卡片展示。

## 2. 测试范围

- Swift Package 构建与测试。
- `.app` 打包、签名校验、DMG 校验。
- 本地 SenseVoice ASR 与云端 ASR 语音时长解析。
- DeepSeek LLM 与 Aliyun Bailian CosyVoice TTS 烟测。
- 设置页 General / Watchlist / AI / Voice / History 桌面 UI 检查。
- Chrome 当前 URL 读取验证。
- 当前保存 Provider 配置与运行时日志核对。
- 敏感信息仓库扫描。

未完成项：

- 未做真人麦克风靠近说话测试。
- 未做真实 Brave / Tavily Search Key 验收。
- 未做真实云端声音克隆 Provider 验收。

## 3. 环境与当前状态

- macOS：本机环境。
- 构建方式：Swift Package。
- App Bundle：`build/Hunter.app`
- Bundle ID：`com.hunter.focus`
- 测试时 App 当前保存配置：
  - ASR：local model，SenseVoice Small INT8 已安装。
  - LLM：DeepSeek / `deepseek-v4-flash`
  - TTS：Aliyun Bailian / `cosyvoice-v3-flash`
  - Voice：`longwanqing`
  - Search：Brave Search，保存状态为 enabled，但未保存 Search API Key。
- 测试结束后已退出 Hunter，并关闭测试用 Chrome 窗口。

## 4. 通过项

| ID | 验收项 | 结果 | 证据 |
| --- | --- | --- | --- |
| HPASS-001 | 单元测试 | Pass | `swift test` 通过，38 tests passed |
| HPASS-002 | Release 构建 | Pass | `swift build -c release` 通过 |
| HPASS-003 | `.app` 打包 | Pass | `./scripts/package_app.sh` 产出 `build/Hunter.app` |
| HPASS-004 | `.app` 签名校验 | Pass | `codesign --verify --deep --strict build/Hunter.app` 无错误 |
| HPASS-005 | Debug DMG 校验 | Pass | `./scripts/package_dmg.sh` + `hdiutil verify build/Hunter.dmg` 通过 |
| HPASS-006 | Release DMG 校验 | Pass | `CONFIGURATION=release DMG_PATH=build/Hunter-release.dmg ./scripts/package_dmg.sh` + `hdiutil verify build/Hunter-release.dmg` 通过 |
| HPASS-007 | 本地 ASR | Pass | `--smoke-local-asr /tmp/hunter-asr.wav` 输出 `local_asr_ok=true`，识别为 `监督我接下来的四十分钟` |
| HPASS-008 | 本地语音创建时长任务 | Pass | `--smoke-local-voice-focus /tmp/hunter-asr.wav` 输出 `focus_minutes=40` |
| HPASS-009 | 云端 ASR | Pass | `--smoke-asr /tmp/hunter-asr.wav` 输出 `asr_ok=true`，识别为 `监督我接下来的40分钟。` |
| HPASS-010 | 云端语音创建时长任务 | Pass | `--smoke-voice-focus /tmp/hunter-asr.wav` 输出 `focus_minutes=40` |
| HPASS-011 | LLM 命令行烟测 | Pass | `--smoke-llm` 输出 `llm_ok=true`，provider 为 DeepSeek，model 为 `deepseek-v4-flash` |
| HPASS-012 | 默认 LLM + TTS 命令行烟测 | Pass | `--smoke-llm-tts` 输出 `llm_ok=true`、`tts_ok=true`、`tts_bytes=61484` |
| HPASS-013 | UI LLM 测试 | Pass | AI 设置页点击“测试 LLM”后显示“连接成功，已收到模型回复。” |
| HPASS-014 | 浏览器 URL 读取 | Pass | 独立 Chrome 窗口打开 Bilibili 后，`--smoke-current-context` 输出 `browser_url=https://www.bilibili.com/` |
| HPASS-015 | 基础设置页 UI | Pass | General / Watchlist / AI / Voice / History 均可打开，未见主布局遮挡 |
| HPASS-016 | 悬浮球基础呈现 | Pass | CGWindow 检测到 72x72 floating window，截图显示圆形头像和进度环未被裁切 |
| HPASS-017 | 仓库敏感信息扫描 | Pass | 未发现明文 API Key；只命中源码中的环境变量名和普通文本 |

## 5. 阻断与缺陷

### HQA-001 - P0 - 当前保存 TTS 音色不可用，真实抓包无法播报

现象：

- Voice 页当前音色为 `longwanqing`。
- 点击 Voice 页“测试音色”失败：`Provider returned an invalid response`。
- 点击 AI 页“测试 TTS”失败：`TTS 测试失败：Provider returned an invalid response`。
- 独立 Chrome 打开 `https://www.bilibili.com/` 后，Hunter 真实命中 Bilibili 黑名单，但 TTS 日志记录失败：

```text
2026-05-31T06:15:10Z INCIDENT_TTS_REQUEST mode=cloud target=Bilibili provider=Aliyun Bailian model=cosyvoice-v3-flash voice=longwanqing
2026-05-31T06:15:10Z CLOUD_TTS_START provider=Aliyun Bailian model=cosyvoice-v3-flash voice=longwanqing
2026-05-31T06:15:10Z CLOUD_TTS_FAILED error=Provider returned an invalid response fallback=none
```

影响：

- 当前真实保存配置下，抓包链路会停在 TTS。
- 因为抓包卡片在 TTS 成功后才 reveal，用户可能没有可见抓包反馈。
- 命令行默认 TTS 通过不能代表 App 当前配置通过。

相关位置：

- `Sources/Hunter/Views.swift:2365`：Voice picker 暴露 `longwanqing`。
- `Sources/Hunter/DashScopeClient.swift:195`：TTS 非 2xx 或响应缺字段只返回 generic invalid response。
- `Sources/Hunter/IncidentController.swift:66`：LLM 成功后等待 TTS 成功才 reveal incident。

建议处理：

- 先把默认和可选音色收敛到已验证可用的 `longanyang`，或按 Provider 动态刷新可用 voice list。
- TTS 测试失败时展示 HTTP status / provider error code 的安全摘要，方便判断是 voice id、模型还是鉴权问题。
- 增加“读取当前保存配置”的端到端 smoke，不能只测代码默认值。

### HQA-002 - P0 - 命令行烟测未读取当前保存配置，导致验收假阳性

现象：

- `--smoke-llm`、`--smoke-llm-tts`、`--smoke-asr` 多处直接创建 `ProviderSettings()`。
- 测到的是代码默认配置，不是用户设置页里保存的运行配置。
- 本次就出现了命令行默认 `longanyang` TTS 通过，但 UI 当前 `longwanqing` TTS 失败的情况。

影响：

- `docs/ACCEPTANCE.md` 中命令行烟测证据会高估真实 App 可用性。
- 后续改 Provider 设置时，CLI 验收可能继续漏问题。

相关位置：

- `Sources/Hunter/CommandLineRunner.swift:16`
- `Sources/Hunter/CommandLineRunner.swift:52`
- `Sources/Hunter/CommandLineRunner.swift:70`
- `Sources/Hunter/CommandLineRunner.swift:129`

建议处理：

- 让 smoke 默认读取 `SettingsStore().load().providers`。
- 如需保留默认配置测试，新增显式参数，例如 `--smoke-llm-tts --defaults`。
- 输出中增加 `tts_voice`、`asr_mode` 等关键运行配置。

### HQA-003 - P1 - 抓包浮窗 AppKit 尺寸与 SwiftUI 内容尺寸不一致

现象：

- SwiftUI `FloatingOverlayView.overlaySize` 抓包态为：
  - incident only：`360x404`
  - toast + incident：`382x488`
- AppKit `FloatingWindowController.contentSize` 仍为：
  - incident only：`360x352`
  - toast + incident：`382x436`

影响：

- 抓包卡片窗口高度少 52px。
- 底部按钮、声波或回复状态可能被裁切。
- 这会影响“抓包小组件必须完整显示”的验收项。

相关位置：

- `Sources/Hunter/Views.swift:114`
- `Sources/Hunter/FloatingWindowController.swift:158`

建议处理：

- 把浮窗尺寸常量抽成单一来源，避免 SwiftUI 和 AppKit 双写。
- 修正后用真实抓包截图复验卡片底部按钮与声波。

### HQA-004 - P1 - 声音克隆 UI 是模拟闭环，违反当前 MVP 边界

现象：

- `cloneProgress` 初始值为 `0.68`，Voice 页显示“等待样本 68%”。
- 勾选授权后，“录制样本”会直接添加假样本。
- “开始克隆”只是本地定时器模拟进度。
- 成功后允许把 `voice_hunter_custom_01` 设为当前音色。

影响：

- 用户会以为云端克隆已经接入。
- 可能保存 Provider 不认识的 voice id，进一步导致 TTS 失败。
- 与项目要求“不要用假数据或静态 UI 冒充真实闭环”冲突。

相关位置：

- `Sources/Hunter/Views.swift:2208`
- `Sources/Hunter/Views.swift:2427`
- `Sources/Hunter/Views.swift:2495`

建议处理：

- MVP 阶段要么隐藏声音克隆入口，要么明确禁用并标注“待接入”。
- 如果保留入口，必须接真实 Provider adapter，并只保存 Provider 返回的授权 voice id。

### HQA-005 - Resolved - 第一版已移除联网检索入口

处理结果：

- 第一版设置页仅保留 ASR、LLM、TTS 三条 Provider 配置。
- 抓包链路不再调用外部检索 API，也不再维护单独的检索 Provider 状态。
- 这条历史问题不再按“缺 Key 状态表达”方向处理。

### HQA-006 - P2 - 默认打包脚本生成 debug App / DMG

现象：

- `scripts/package_app.sh` 默认 `CONFIGURATION=debug`。
- `scripts/package_dmg.sh` 直接调用 `package_app.sh`，因此默认 DMG 也是 debug 构建。
- 本次 release DMG 需要手动执行 `CONFIGURATION=release DMG_PATH=build/Hunter-release.dmg ./scripts/package_dmg.sh`。

影响：

- 常规打包命令不适合作为分发验收命令。
- 可能混淆性能、权限和签名测试结果。

相关位置：

- `scripts/package_app.sh:5`
- `scripts/package_dmg.sh:10`

建议处理：

- 将默认配置改为 release。
- 或新增 `scripts/package_release_dmg.sh`，并在验收文档里只使用 release 包。

## 6. 复测清单

处理完成后，下一轮 Review 建议按以下顺序复测：

1. 清空或固定当前保存 Provider 配置，确认 `voice=longanyang` 或真实 Provider voice list。
2. 运行读取保存配置的 smoke：
   - saved LLM
   - saved TTS
   - saved ASR
   - saved LLM + TTS
3. UI 点击“测试 LLM / 测试 TTS / 测试音色”，全部必须成功或给出明确原因。
4. 独立 Chrome 打开 Bilibili / YouTube，确认真实抓包：
   - 命中黑名单
   - LLM 生成短吐槽
   - TTS 成功
   - 抓包卡片完整显示
   - 历史只记录一条
5. 抓包卡片截图检查：
   - 底部按钮未裁切
   - 声波完整显示
   - 没有内部 Provider 状态泄漏
6. 测试时长任务：
   - 15 / 25 / 40 分钟快捷开始
   - 暂停 / 恢复 / 取消
   - 到期总结走 TTS，不回退系统朗读
7. 测试真人麦克风：
   - 按住当前快捷键说“监督我接下来的 40 分钟”
   - 抓包后按住快捷键回击一句
   - Hunter 回击后等待下一轮，不自动抢麦克风
8. Search：
   - 无 Key 时必须显示 inactive 或缺 Key
   - 有 Key 后再验收摘要进入 prompt
9. Voice Clone：
   - 若未接真实 Provider，入口必须禁用或隐藏
   - 不允许再出现假样本、假进度、假成功
10. 打包：
   - 默认打包命令产出 release DMG
   - `codesign` 和 `hdiutil verify` 通过

## 7. 本轮测试命令摘要

```bash
swift test
swift build -c release
./scripts/package_app.sh
codesign --verify --deep --strict build/Hunter.app
./scripts/package_dmg.sh
hdiutil verify build/Hunter.dmg
CONFIGURATION=release DMG_PATH=build/Hunter-release.dmg ./scripts/package_dmg.sh
hdiutil verify build/Hunter-release.dmg
say -v Tingting -o /tmp/hunter-asr.aiff "监督我接下来的四十分钟"
afconvert -f WAVE -d LEI16@16000 -c 1 /tmp/hunter-asr.aiff /tmp/hunter-asr.wav
./build/Hunter.app/Contents/MacOS/Hunter --smoke-local-asr /tmp/hunter-asr.wav
./build/Hunter.app/Contents/MacOS/Hunter --smoke-local-voice-focus /tmp/hunter-asr.wav
./build/Hunter.app/Contents/MacOS/Hunter --smoke-asr /tmp/hunter-asr.wav
./build/Hunter.app/Contents/MacOS/Hunter --smoke-voice-focus /tmp/hunter-asr.wav
./build/Hunter.app/Contents/MacOS/Hunter --smoke-llm
./build/Hunter.app/Contents/MacOS/Hunter --smoke-llm-tts
./build/Hunter.app/Contents/MacOS/Hunter --smoke-current-context
```

## 8. 备注

- 本报告只记录测试结果，没有修改源码。
- 本轮 UI 测试会在本机 Hunter 日志里留下 TTS / ASR / Search 测试记录。
- 本轮额外生成 `build/Hunter-release.dmg` 作为 release DMG 验证产物。
- Hunter 已在测试结束后退出；测试用 Chrome Bilibili 窗口已关闭。
