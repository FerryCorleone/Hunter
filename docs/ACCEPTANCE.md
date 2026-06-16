# v1.0.0 验收清单

日期：2026-06-16
目标：作为公开第一版发布，只提供 macOS DMG 下载。

## 结论

v1.0.0 的验收重点是让普通用户可以完成“下载 -> 安装 -> 配置黑名单 -> 配置模型 -> 开始监督 -> 被抓包吐槽”的主链路。旧的历史测试报告、过时失败项和中间更新记录已清理，后续只从这一版开始记录正式 release。

## 用户侧验收

| 项目 | 状态 | 说明 |
| --- | --- | --- |
| macOS DMG 安装包 | Pass | `./scripts/package_dmg.sh` 产出 `build/Hunter.dmg` |
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
codesign --verify --deep --strict build/Hunter.app
hdiutil verify build/Hunter.dmg
```

## 发布边界

- 只发布 macOS DMG。
- 不包含 API Key，用户需要填写自己的模型服务 Key。
- 不支持 Windows、iOS、Android 或浏览器插件。
- 不做老板监控员工、隐身采集、远程上报或不可关闭监督。
- 云端模型调用只发送当前抓包或语音交互所需的最小上下文。
