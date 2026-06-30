# v1.0.1 验收清单

日期：2026-06-30
目标：发布 Mac Universal DMG，让当前 Hunter 版本同时支持 Apple Silicon 和 Intel 芯片 Mac。

## 结论

v1.0.1 的验收重点是在不改变 v1.0.0 用户主链路的前提下，把公开安装包更新为 Universal binary。由于当前没有 Intel Mac 真机，本次使用 Apple Silicon 本机 + Rosetta 验证 `x86_64` slice，并保留后续 Intel 真机补测空间。

## 用户侧验收

| 项目 | 状态 | 说明 |
| --- | --- | --- |
| macOS Universal DMG 安装包 | Pass | `./scripts/package_dmg.sh` 产出 `build/Hunter.dmg` |
| Apple Silicon 架构 | Pass | `lipo -info build/Hunter.app/Contents/MacOS/Hunter` 包含 `arm64` |
| Intel Mac 架构 | Pass | `lipo -info build/Hunter.app/Contents/MacOS/Hunter` 包含 `x86_64` |
| Intel slice 烟测 | Pass | `arch -x86_64 build/Hunter.app/Contents/MacOS/Hunter --parse-voice-control --defaults '监督我接下来的 40 分钟'` |
| App 显示名称 | Pass | App 内和打包信息显示“监管者” |
| 黑名单网站 | Pass | 支持新增、启用/停用、删除网站规则 |
| 黑名单 App | Pass | 支持搜索本机 App；已添加 App 仍可搜到，按钮显示“已添加” |
| 开始监督时前台已命中 | Pass | 开启监督后会重新检查当前前台 App / 浏览器上下文 |
| AI 配置说明 | Pass | 删除普通用户看不懂的自动配置摘要说明 |
| 模型保存交互 | Pass | 每类 API Key 独立保存/更新；不再保留额外“更新配置”按钮 |
| 时长监督 | Pass | 支持悬浮球快捷开始和语音创建监督时长 |
| 语音对喷 | Pass | 支持快捷键录音、ASR 转写、LLM 回击和 TTS 播报链路 |
| 历史记录 | Pass | 本地展示抓包记录，可清除 |

## 分发验收命令

```bash
swift test
./scripts/package_dmg.sh
lipo -info build/Hunter.app/Contents/MacOS/Hunter
arch -x86_64 build/Hunter.app/Contents/MacOS/Hunter --parse-voice-control --defaults '监督我接下来的 40 分钟'
codesign --verify --deep --strict build/Hunter.app
hdiutil verify build/Hunter.dmg
```

## 发布边界

- 只发布 macOS Universal DMG，支持 Apple Silicon 和 Intel Mac。
- 不包含 API Key，用户需要填写自己的模型服务 Key。
- 不支持 Windows、iOS、Android 或浏览器插件。
- 不做老板监控员工、隐身采集、远程上报或不可关闭监督。
- 云端模型调用只发送当前抓包或语音交互所需的最小上下文。
