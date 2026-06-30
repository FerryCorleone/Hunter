# 监管者（Hunter）

一个桌面端 AI 摸鱼监工。你主动开启监督后，它会盯着你当前打开的 App 和网站；一旦发现你进了黑名单，就会当场弹出悬浮小组件，用 AI 语音吐槽你。你还可以按住快捷键语音反驳，和它继续对喷。

它不是老板监控员工的软件，也不会偷偷上传你的浏览历史。它更像一个自愿开启的桌面整活工具：好玩、有点压力、适合录屏，也适合给自己来一点“别刷了”的外部刺激。

## 下载

目前提供 Mac 和 Windows 两个桌面版本：

- Mac：`Hunter.dmg`，支持 macOS 14 Sonoma 及以上，支持 Apple Silicon 和 Intel 芯片 Mac。
- Windows：`Hunter-Windows-win-x64.zip`，支持 Windows 10 / 11 x64。
- 下载 Mac 版：[Hunter.dmg](https://github.com/FerryCorleone/Hunter/releases/latest/download/Hunter.dmg)
- 下载 Windows 版：[Hunter-Windows-win-x64.zip](https://github.com/FerryCorleone/Hunter/releases/latest/download/Hunter-Windows-win-x64.zip)
- 查看发布页：[GitHub Releases](https://github.com/FerryCorleone/Hunter/releases/latest)

暂不支持 iPhone、iPad、Android，也没有浏览器插件版。

## 安装

### Mac

1. 下载 `Hunter.dmg`。
2. 双击打开 DMG。
3. 把里面的 `监管者.app` 拖到 `Applications`。
4. 第一次打开时，如果 macOS 提示“无法验证开发者”，可以在 Finder 里右键 `监管者.app`，选择“打开”。
5. 按提示允许麦克风、浏览器自动化和通知权限。

浏览器自动化权限只用于读取当前 Chrome / Safari 等浏览器的当前标签页 URL，用来判断有没有命中你自己设置的黑名单。

### Windows

1. 下载 `Hunter-Windows-win-x64.zip`。
2. 解压到一个固定目录，例如 `C:\Users\你\Apps\Hunter`。
3. 双击 `Hunter.Windows.exe`。
4. 按系统提示允许麦克风和通知权限。
5. 如果 Windows SmartScreen 提示未知发布者，选择“更多信息”后继续运行。

Windows 版会尝试通过系统前台窗口和 UI Automation 读取当前 App / 浏览器地址栏，用来匹配你自己设置的黑名单。

## 它好玩在哪

- **当场抓包**：你刚切到 B 站、YouTube、Steam 或其他黑名单 App，它就会弹出来。
- **AI 语音吐槽**：不是冷冰冰的通知，而是会说话的 AI 监工。
- **可以语音反驳**：按住快捷键说一句，它会听、会回、会继续怼。
- **时长监督**：可以说“监督我接下来的 40 分钟”，它会直接开始倒计时。
- **网站和 App 都能管**：网页、浏览器标签页、本机 App 都可以加黑名单。

## 三分钟上手

1. 打开 `监管者`。
2. 进入“黑名单”，添加你最容易摸鱼的网站或 App。
3. 进入“AI”，填好 ASR、LLM、TTS 的 API Key。
4. 进入“声音”，选择监督语言、吐槽强度和音色。
5. 打开监督，或者点悬浮球选择 15 / 25 / 40 分钟。
6. 故意打开一个黑名单网站，听听它怎么抓你。

## 模型配置怎么理解

监管者需要三类 AI 能力，理解成“耳朵、大脑、嘴巴”就行：

- **ASR 语音识别**：听懂你说了什么。
- **LLM 语言模型**：生成吐槽和回击。
- **TTS 语音合成**：把吐槽念出来。

设置页里每一块都可以选厂商、选模型、填 API Key。普通用户不用理解 Base URL、鉴权头这些东西，内置厂商会自动处理。你只需要：

1. 选择一个厂商。
2. 选择推荐模型，或者保持默认。
3. 粘贴自己的 API Key。
4. 点击 API Key 输入框后面的“保存/更新”。
5. 点“测试 ASR / LLM / TTS”确认能跑通。

如果你暂时不想用云端 ASR，也可以在 ASR 里切到本地模型，下载 SenseVoice 到本机识别短语音。TTS 目前只支持云端。
我自己测试千问云和小米mimo的ASR和TTS模型效果不错，而且价格很便宜，尤其是是小米，填邀请码会得10元额度，能用无敌久，可以填我的邀请码试试：D7WG2L。

## 隐私边界

- 黑名单、历史记录、设置和 API Key 默认保存在本机。
- 浏览器 URL 和 App 使用记录不会被 Hunter 批量上传。
- 只有命中黑名单、需要 AI 生成吐槽时，才会把最小必要上下文发给你选择的模型服务。
- 如果你使用云端 ASR/TTS，你的语音片段或合成文本会发送给对应模型厂商；如果切换本地 ASR，短语音识别会在本机完成。
- 监管者是自愿开启的个人工具，不做隐身监控、远程上报或不可关闭的管控。

## 当前版本

当前最新版：`v1.1.0`，提供 Mac Universal DMG 和 Windows x64 zip。

- 面向普通用户的项目报告：[docs/REPORT.md](docs/REPORT.md)
- 更新记录：[docs/RELEASE_NOTES.md](docs/RELEASE_NOTES.md)
- 产品需求文档：[docs/PRD.md](docs/PRD.md)
- 设计说明：[docs/DESIGN.md](docs/DESIGN.md)

## 开发者

本项目包含两个原生桌面端：

- Mac：SwiftUI + AppKit。
- Windows：WPF + Win32 / Windows UI Automation。

```bash
swift test
./scripts/package_app.sh
./scripts/package_dmg.sh
open build/Hunter.app
```

Windows 构建需要在 Windows 环境执行：

```powershell
./windows/build-windows.ps1
```

本地开发密钥放在 `.env.local` 或 Hunter 的 Application Support 目录，不要提交到仓库。
