# Hunter Implementation Status

日期：2026-05-27  
状态：MVP 开发中

## 已完成

- Swift Package 原生 macOS 工程骨架。
- 可打包 `.app`：`./scripts/package_app.sh` -> `build/Hunter.app`。
- 菜单栏状态入口。
- SwiftUI 设置窗口：General、Watchlist、AI、Voice、History。
- AppKit 浮动监督窗：悬浮球、抓包卡片、时长任务 toast。
- 前台 App 检测：`NSWorkspace.shared.frontmostApplication`。
- Chrome/Safari URL 读取：AppleScript/ScriptingBridge 起步。
- 黑名单命中、冷却、事件日志。
- 语音时长任务解析：中文/英文样例已加测试。
- Option+Space 全局事件监听入口，未授权时提示需要辅助功能权限。
- 麦克风 4 秒短录音入口。
- 阿里 Paraformer WebSocket ASR 代码路径。
- 阿里 Qwen Turbo LLM 抓包吐槽和语音回击代码路径。
- 阿里 CosyVoice HTTP TTS 代码路径，默认 `cosyvoice-v3-flash + longanyang`。
- 本机密钥读取：`.env.local` / Keychain，仓库忽略 `.env.local`。

## 已验证

- `swift build` 通过。
- `swift test` 通过，覆盖时长任务解析。
- `./scripts/package_app.sh` 可产出 `build/Hunter.app`。
- 阿里 `qwen-turbo` 极短文本冒烟测试通过。
- 阿里 `cosyvoice-v3-flash + longanyang` 极短文本冒烟测试通过，TTS 用量 4 字符。

## 未完成 / 下一步

- 在已解锁桌面环境中完整验收 UI 截图、浮窗交互和状态栏菜单。
- 验证 Option+Space 辅助功能授权流程。
- 验证麦克风权限弹窗、录音、Paraformer ASR 返回文本。
- 端到端验证：语音说“监督我接下来的 40 分钟” -> 生成 Focus Session。
- 端到端验证：进入 YouTube/Bilibili 黑名单 -> LLM 生成吐槽 -> CosyVoice 播放。
- 设置页 Provider 字段目前是模板展示，后续需要变成可编辑表单并写入 Keychain 引用。
- TTS 音色复刻/声音设计暂未实现，需授权样本或用户明确选择声音设计。

## 注意

- HTML 原型中的桌面壁纸、Dock、系统菜单栏不是开发范围。
- 测试音频保持低音量，避免打扰。
- 云端测试只用极短文本，避免消耗过多免费额度。
