# 当前状态

日期：2026-06-30
版本：v1.1.0 Mac + Windows 桌面版
状态：Mac Universal DMG 和 Windows x64 zip 公开版整理完成

## 面向用户的可用能力

- 原生 macOS App，可通过 `Hunter.dmg` 安装。
- 原生 Windows App，可通过 `Hunter-Windows-win-x64.zip` 解压运行。
- App 内显示中文名称“监管者”，保留英文项目名 Hunter 作为仓库和安装包识别名。
- 桌面悬浮球、快捷菜单、抓包弹窗和时长任务 toast。
- 网站黑名单和本机 App 黑名单。
- 本机 App 搜索支持已添加状态：已加入黑名单的 App 仍可被搜到，但按钮显示为“已添加”。
- 开始监督前如果用户已经在前台打开黑名单 App 或网站，启动监督后会重新检查当前前台上下文，避免漏抓。
- ASR / LLM / TTS 三段模型配置。
- API Key 独立保存/更新，不再保留跨卡片的“更新配置”按钮。
- AI 页面已移除对普通用户没有帮助的自动配置说明文案。
- 语音时长任务、语音反驳、TTS 播报和本地历史记录。
- 中文/英文界面与监督语言。

## 下载与分发

- Mac：`build/Hunter.dmg` 是 Universal 安装包，支持 macOS 14 Sonoma 及以上、Apple Silicon 和 Intel 芯片 Mac。
- Windows：`artifacts/Hunter-Windows-win-x64.zip` 是 win-x64 自包含包，支持 Windows 10 / 11 x64。
- 暂不提供 iOS、Android 或浏览器插件版本。

## 模型配置口径

普通用户只需要理解三件事：

- ASR 是“耳朵”，负责把语音转成文字。
- LLM 是“大脑”，负责生成吐槽和回击。
- TTS 是“嘴巴”，负责把文字念出来。

内置厂商会自动处理 Base URL、鉴权头、region 和语言提示等细节。用户选择厂商和模型后，只需要粘贴自己的 API Key，点击输入框后的保存/更新按钮，再运行对应测试即可。

## 验收口径

公开版验收关注三层：

1. Mac 工程质量：`swift test`。
2. Mac 可分发包：`./scripts/package_dmg.sh`、`lipo -info build/Hunter.app/Contents/MacOS/Hunter`、`codesign --verify --deep --strict build/Hunter.app`、`hdiutil verify build/Hunter.dmg`。
3. Windows 自动化验收：GitHub Actions `windows-latest` 跑 `windows/build-windows.ps1`、core tests、package smoke、foreground smoke、UI render smoke。
4. 用户主链路：安装、授权、添加黑名单、保存模型 Key、开始监督、命中黑名单、播放吐槽。

真实云端 ASR / LLM / TTS 测试依赖用户自己的 API Key；仓库不提交任何密钥。
