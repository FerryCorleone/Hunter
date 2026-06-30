# v1.1.0 验收清单

日期：2026-06-30
目标：发布 Mac Universal DMG 和 Windows x64 zip，让当前 Hunter 版本覆盖 Mac Apple Silicon、Mac Intel 和 Windows x64。

## 结论

v1.1.0 的验收重点是在不改变用户主玩法的前提下完成跨平台桌面分发。Mac 版继续使用 Universal binary；由于当前没有 Intel Mac 真机，本次使用 Apple Silicon 本机 + Rosetta 验证 `x86_64` slice。Windows 版使用 GitHub-hosted `windows-latest` Runner 完成构建、测试、打包和 UI smoke，作为没有 Windows 真机时的自动化验收门槛。

## 用户侧验收

| 项目 | 状态 | 说明 |
| --- | --- | --- |
| macOS Universal DMG 安装包 | Pass | `./scripts/package_dmg.sh` 产出 `build/Hunter.dmg` |
| Apple Silicon 架构 | Pass | `lipo -info build/Hunter.app/Contents/MacOS/Hunter` 包含 `arm64` |
| Intel Mac 架构 | Pass | `lipo -info build/Hunter.app/Contents/MacOS/Hunter` 包含 `x86_64` |
| Intel slice 烟测 | Pass | `arch -x86_64 build/Hunter.app/Contents/MacOS/Hunter --parse-voice-control --defaults '监督我接下来的 40 分钟'` |
| Windows x64 zip | Pass | GitHub Actions `windows-latest` 产出 `Hunter-Windows-win-x64.zip` |
| Windows core tests | Pass | `windows/build-windows.ps1` 跑 `Hunter.Windows.Tests` |
| Windows package smoke | Pass | `Hunter.Windows.exe --smoke-core`、`--smoke-voice-control`、`--smoke-package-info` |
| Windows foreground smoke | Pass | `Hunter.Windows.exe --smoke-foreground` |
| Windows UI render smoke | Pass | `Hunter.Windows.exe --smoke-ui-render artifacts/hunter-windows-ui-smoke.png` |
| App 显示名称 | Pass | Mac 显示“监管者”；Windows 设置和小组件使用 Hunter / 监管者 |
| 黑名单网站 | Pass | 支持新增、启用/停用、删除网站规则 |
| 黑名单 App | Pass | 支持 App 名称规则和前台 App 检测 |
| 开始监督时前台已命中 | Pass | 开启监督后会重新检查当前前台 App / 浏览器上下文 |
| AI 配置说明 | Pass | 用户只需要配置 ASR / LLM / TTS 的厂商、模型和 API Key |
| 模型保存交互 | Pass | 每类 API Key 独立保存/更新 |
| 时长监督 | Pass | 支持悬浮入口和语音创建监督时长 |
| 语音对喷 | Pass | 支持快捷键录音、ASR 转写、LLM 回击和 TTS 播报链路 |
| 历史记录 | Pass | 本地展示抓包记录，可清除 |

## 分发验收命令

Mac：

```bash
swift test
./scripts/package_dmg.sh
lipo -info build/Hunter.app/Contents/MacOS/Hunter
arch -x86_64 build/Hunter.app/Contents/MacOS/Hunter --parse-voice-control --defaults '监督我接下来的 40 分钟'
codesign --verify --deep --strict build/Hunter.app
hdiutil verify build/Hunter.dmg
```

Windows：

```powershell
./windows/build-windows.ps1
./artifacts/Hunter-Windows/Hunter.Windows.exe --smoke-ui-render artifacts/hunter-windows-ui-smoke.png
./artifacts/Hunter-Windows/Hunter.Windows.exe --smoke-foreground
```

GitHub Actions 验证记录：

- Workflow：`Windows Build`
- Run：`28452102114`
- Job：`84316868613`
- 结论：Success
- 产物：`Hunter-Windows-win-x64.zip`
- UI 截图：`hunter-windows-ui-smoke.png`

## 发布边界

- 发布 Mac Universal DMG，支持 Apple Silicon 和 Intel Mac。
- 发布 Windows win-x64 zip，支持 Windows 10 / 11 x64。
- 不包含 API Key，用户需要填写自己的模型服务 Key。
- 不支持 iOS、Android 或浏览器插件。
- 不做老板监控员工、隐身采集、远程上报或不可关闭监督。
- 云端模型调用只发送当前抓包或语音交互所需的最小上下文。
- Windows CI 自动化验收不等同于带真实用户 API Key 的完整人工 QA；最终人工补测仍应在真实 Windows 桌面环境中执行。
