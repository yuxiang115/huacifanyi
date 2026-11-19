# 划词 Huaci

macOS 菜单栏划词翻译：在任何应用里选中文字，按 **⌥D**，译文就出现在鼠标旁边。

## 现在能做什么（v0.1）

- **触发**：⌥D 翻译选中文字（快捷键可在设置里改）；也可以从菜单栏触发，或直接在弹窗里输入文字后回车。
- **取词**：先用辅助功能接口读选中文字；读不到时（Electron 应用等）模拟一次 ⌘C 从剪贴板取，取完把原来的剪贴板恢复。
- **弹窗**：不抢焦点，跟随鼠标出现，内容变长会自动长高；Esc 或点外面关闭，可以固定，译文一键复制。
- **单词卡片**：选中的是英文单词或短语时，显示音标、英式和美式发音、词性和中文释义、词形变化、原形、考试标签和柯林斯星级。完全离线，数据来自 ECDICT。
- **发音**：原文和译文旁边都有朗读按钮，使用系统语音。
- **引擎**
  - Apple 翻译（默认）：系统自带，免费，可离线。
  - 自定义 LLM：支持 OpenAI 兼容格式和 Anthropic 格式，流式输出。API Key 存在钥匙串。
- **方向**：自动识别原文语言。原文是「我的语言」（默认简体中文）就翻译成「第二语言」（默认英文），其他语言都翻译成「我的语言」。

## 环境要求

- macOS 15 及以上
- Xcode 16 及以上
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`

## 在 Mac 上开发

```bash
xcodegen generate        # 由 project.yml 生成 Huaci.xcodeproj（这个文件不提交）
open Huaci.xcodeproj
```

改了 `project.yml` 或者增删了源文件，都要重新跑一次 `xcodegen generate`。

第一次运行会弹出权限引导：到「系统设置 → 隐私与安全性 → 辅助功能」里勾选「划词」。

### 让辅助功能权限在重新编译后保留

默认用 ad-hoc 签名（Sign to Run Locally）。这种签名每次编译都会变，所以 macOS 会忘掉之前的辅助功能授权，钥匙串也可能弹窗询问。用开发者证书签名就不会这样，免费 Apple ID 也可以：

```bash
cp Configs/Local.xcconfig.example Configs/Local.xcconfig
# 把里面的 HUACI_DEVELOPMENT_TEAM 改成你的 Team ID
xcodegen generate
```

`Configs/Local.xcconfig` 已被 git 忽略。

## 在 Windows 上写代码、到 Mac 上编译

```bash
HUACI_MAC=user@mac-host scripts/mac-build.sh test   # 同步并跑单元测试
HUACI_MAC=user@mac-host scripts/mac-build.sh build  # 同步并编译 Debug 版
HUACI_MAC=user@mac-host scripts/mac-build.sh run    # 编译并在 Mac 上启动
```

这个脚本通过 SSH 把代码同步到 Mac 的 `~/workspace/huaci`，再在 Mac 上执行 xcodegen 和 xcodebuild。Mac 上的那份副本每次同步都会被覆盖，所以请在 Windows 这边改代码。

## 词典数据

`Huaci/Resources/Dictionary.sqlite`（约 17.5 MB）由 [ECDICT](https://github.com/skywind3000/ECDICT)（MIT 协议，许可证随 App 一起分发）生成：

- 只保留常用词：考试词表、柯林斯、牛津 3000、词频排名前 5 万的词，以及它们的变形。总共约 9 万条，原始数据有 77 万条。
- ECDICT 的旧式音标（比如 `'fainәli`）会转换成现代 IPA（`ˈfaɪnəli`）。
- 英文释义每条最多保留 3 行。

重新生成：

```bash
curl -LO https://raw.githubusercontent.com/skywind3000/ECDICT/master/ecdict.csv
python3 scripts/build_dictionary.py ecdict.csv Huaci/Resources/Dictionary.sqlite
```

## LLM 配置示例

| 服务 | 接口格式 | 地址 | 模型 |
|---|---|---|---|
| Ollama（本地） | OpenAI 兼容 | `http://localhost:11434/v1` | `qwen2.5:7b` |
| DeepSeek | OpenAI 兼容 | `https://api.deepseek.com/v1` | `deepseek-chat` |
| Claude | Anthropic | `https://api.anthropic.com` | `claude-opus-5-5`，Effort 选 `low` |

地址可以只填到 `/v1`，也可以填完整路径，程序会自动补上 `/chat/completions` 或 `/v1/messages`。

## 目录结构

```
Huaci/
├── App/           入口、菜单栏、启动流程、权限引导
├── Selection/     取词（辅助功能接口 + ⌘C 兜底）
├── Trigger/       全局快捷键
├── Panel/         悬浮面板、SwiftUI 界面、视图模型
├── Translation/   语言识别、LLM 请求构造、SSE 解析、流式客户端
├── Settings/      设置项与设置界面
└── Support/       钥匙串、权限、剪贴板等小工具
HuaciTests/        纯逻辑单元测试（不需要启动 App）
Configs/           签名配置（xcconfig）
scripts/           Windows → Mac 同步编译脚本
```

## 路线图

- **M2 体验**：划词后鼠标旁出现小图标、交换翻译方向、单词卡片显示例句、真人发音（可选，需联网）
- **M3 扩展**：截图识字翻译（Vision）、独立的输入翻译窗口、历史记录
- **M4 发布**：Developer ID 签名和公证、Sparkle 自动更新、DMG 安装包

## 已知限制

- 走 ⌘C 兜底时，有些应用在没有选中文字时也会复制内容（比如 VS Code 会复制当前整行）。
- Apple 翻译第一次遇到某个语言对时，需要先在「系统设置 → 通用 → 语言与地区 → 翻译语言」里下载语言包，弹窗会提示。
- 单词卡片只支持英译中。ECDICT 每个词只有一个音标（大多是英式），英式和美式的区别只体现在发音按钮上。
- 需要辅助功能权限，所以应用不能开沙盒，也就上不了 Mac App Store。
