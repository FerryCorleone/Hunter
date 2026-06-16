# 监管者（Hunter）

一个 Mac 端 AI 摸鱼监工。你主动开启监督后，它会盯着你当前打开的 App 和网站；一旦发现你进了黑名单，就会当场弹出悬浮小组件，用 AI 语音吐槽你。你还可以按住快捷键语音反驳，和它继续对喷。

它不是老板监控员工的软件，也不会偷偷上传你的浏览历史。它更像一个自愿开启的桌面整活工具：好玩、有点压力、适合录屏，也适合给自己来一点“别刷了”的外部刺激。

## 下载

目前只支持 **macOS 14 Sonoma 及以上**，并且只提供 Mac 版 DMG 安装包。

- 下载最新版：[Hunter.dmg](https://github.com/FerryCorleone/Hunter/releases/latest/download/Hunter.dmg)
- 查看发布页：[GitHub Releases](https://github.com/FerryCorleone/Hunter/releases/latest)

暂不支持 Windows、iPhone、iPad、Android，也没有浏览器插件版。

## 安装

1. 下载 `Hunter.dmg`。
2. 双击打开 DMG。
3. 把里面的 `监管者.app` 拖到 `Applications`。
4. 第一次打开时，如果 macOS 提示“无法验证开发者”，可以在 Finder 里右键 `监管者.app`，选择“打开”。
5. 按提示允许麦克风、浏览器自动化和通知权限。

浏览器自动化权限只用于读取当前 Chrome / Safari 等浏览器的当前标签页 URL，用来判断有没有命中你自己设置的黑名单。

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

当前把最新版整理为第一版发布：`v1.0.0`。

- 面向普通用户的项目报告：[docs/REPORT.md](docs/REPORT.md)
- 第一版更新记录：[docs/RELEASE_NOTES.md](docs/RELEASE_NOTES.md)
- 产品需求文档：[docs/PRD.md](docs/PRD.md)
- 设计说明：[docs/DESIGN.md](docs/DESIGN.md)

## 开发者

本项目是原生 macOS 应用，主要使用 SwiftUI + AppKit。

```bash
swift test
./scripts/package_app.sh
./scripts/package_dmg.sh
open build/Hunter.app
```

本地开发密钥放在 `.env.local` 或 Hunter 的 Application Support 目录，不要提交到仓库。
