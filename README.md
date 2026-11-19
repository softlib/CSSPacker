# CssPacker — 通用 CSS 压缩 / 解压工具

基于工作空间提供的 `Source/cssunpack.pas`，使用 **Delphi 12.2（Studio 23.0，编译器 36.0）** 编写的通用 CSS 内容压缩与解压工具。同一套核心引擎可用于命令行批处理、图形界面交互，以及作为单元被其他 Delphi 程序直接调用。

---

## 1. 功能特性

- **三种处理模式**
  - `pack-safe`：保守压缩。删除注释、折叠空白、收紧分隔符；不改变任何语义（保留 `calc()` 运算符空格、`url()` 数据、字符串、负值与后代选择器空格）。
  - `pack-fast`：Bootstrap 风格压缩，在安全压缩之上提供可选优化：十六进制颜色缩短（`#aabbcc`→`#abc`）、`0px`→`0`、`0.5`→`.5`、删除末尾分号、删除 `@charset`。
  - `unpack`：稳定、可读的美化输出，支持嵌套 `@media` / `@keyframes` 缩进、伪类冒号正确识别（`a:hover` 不会变成 `a: hover`）。
  - `auto`：根据输入行长、换行数自动判断是压缩还是解压。
- **编码安全**：自动识别 UTF-8 / UTF-16 BOM，读写时保留原始编码与 BOM。
- **语义安全**：字符串、`/*! 许可注释 */`、`url(data:...)` 等敏感内容不会被破坏。
- **统计信息**：输入/输出字节与行数、规则数、声明数、注释数、压缩率、耗时。
- **多语言 GUI**：内置英语、简体中文、繁體中文、日本語、한국어、Deutsch、Français、Español、Русский 九种界面语言，运行时即时切换并记忆偏好；支持通过外部 UTF-8 INI 语言包无限扩展或覆盖任意文本。
- **向后兼容**：保留原始 `cssunpack.pas`（`TCSSTools.FormatCSS2`），并提供 `LegacyFormat` 桥接。

---

## 2. 目录结构

```
CssPacker-main/
├── Source/
│   └── cssunpack.pas          # 原始提供的单元（保留，作为 legacy 引擎）
├── Lib/
│   ├── CssPacker.Core.pas     # 通用核心库（新引擎、文件 IO、统计、选项）
│   └── CssPacker.Lang.pas     # 多语言引擎（内置 9 种语言 + 外部语言包）
├── CLI/
│   └── CssPackerCli.dpr       # 命令行工具
├── GUI/
│   ├── CssPackerGui.dpr       # 图形界面程序
│   ├── CssPackerGuiMain.pas   # VCL 窗体单元（{$R *.dfm}）
│   ├── CssPackerGuiMain.dfm   # 窗体设计文件（IDE 可视化编辑）
│   ├── version.rc             # 版本信息资源源文件
│   └── CssPackerGui.res       # 编译后的版本信息资源
├── Tests/
│   ├── CssPackerTests.dpr     # 自动化测试（48 项）
│   └── GuiLangSmoke.dpr       # GUI 运行时语言切换冒烟测试
├── TestData/
│   ├── Example.css            # 未压缩示例
│   └── Example.css.bak        # 已压缩示例
├── bin/                       # 编译输出（exe + dcu）
│   └── lang/                  # 外部语言包目录
│       ├── it.ini             # 示例：意大利语包（UTF-8）
│       └── README.md          # 语言包编写说明
├── build.bat                  # 构建脚本
└── README.md
```

---

## 3. 构建

已安装 Delphi 12.2（路径 `C:\Program Files (x86)\Embarcadero\Studio\23.0`）。在项目根目录执行：

```bat
build.bat          :: 同时构建 Win32 与 Win64
build.bat 32       :: 仅 Win32
build.bat 64       :: 仅 Win64
```

脚本会编译 CLI、GUI、Tests 三个程序到 `bin/`，中间 `.dcu` 放到 `bin/dcu/<32|64>/`。GUI 的 `CssPackerGui.res`（版本信息资源）已随项目提供。

---

## 4. 命令行工具用法

```
CssPackerCli [options] [input] [output]
```

- 未指定 `input` 时从 **stdin** 读取；未指定 `output` 时写到 **stdout**（便于管道）。
- `input` 可以是单个文件、目录（配合 `-p` / `-r` 批量处理）或 `-`（stdin）。

### 主要参数

| 参数 | 说明 |
|------|------|
| `-m, --mode <name>` | `pack-safe` / `pack-fast` / `unpack` / `auto`（默认 auto） |
| `-i, --indent <n>` | 解压缩进空格数（0–16，默认 2） |
| `-t, --tabs` | 使用 Tab 缩进 |
| `--eol <type>` | `auto` / `lf` / `crlf` / `cr` |
| `--keep-comments` | 压缩时保留普通注释 |
| `--no-license` | 不保留 `/*! ... */` 许可注释 |
| `--hex` / `--zero` / `--leading-zero` | 启用对应激进优化 |
| `--no-final-semi` | 删除 `}` 前最后一个分号 |
| `--charset` | 删除 `@charset` 声明 |
| `--blank-lines` | 解压时规则之间加空行 |
| `-r, --recursive` | 递归处理子目录 |
| `-p, --pattern <pat>` | 目录匹配掩码（默认 `*.css`） |
| `-b, --backup` | 覆盖前创建 `.bak` 备份 |
| `-f, --force` | 直接覆盖已存在的输出 |
| `--dry-run` | 只显示将执行的操作 |
| `--legacy` | 使用原始 `Source/cssunpack.pas` 引擎 |
| `-s, --stats` | 输出统计信息 |
| `-v, -q, -h, --version` | 详细 / 静默 / 帮助 / 版本 |

### 示例

```bat
:: 解压压缩后的 CSS 到新文件
CssPackerCli -m unpack site.min.css site.css

:: 激进压缩并备份原文件（原地覆盖）
CssPackerCli -m pack-fast --hex --zero --no-final-semi -b site.css

:: 管道：压缩后输出到文件
type site.css | CssPackerCli -m pack-safe > site.min.css

:: 批量递归压缩目录内所有 CSS，并生成统计
CssPackerCli -r -p *.css -m pack-safe -b -s .\css
```

> 注意：原地覆盖（input == output）时建议加 `-b` 备份；批量模式默认原地写回，也建议加 `-b`。

---

## 5. 图形界面

运行 `bin/CssPackerGui.exe`：

- 左侧 **INPUT CSS** 粘贴或直接 `Open...` 打开 `.css` 文件；
- 顶部选择模式、缩进、换行符与优化选项；
- 点击 **Process** 生成结果到右侧 **OUTPUT CSS**；
- **Save...** 保存结果（保留源文件编码）、**Copy Output** 复制到剪贴板、**Swap** 交换输入输出；
- 底部状态栏显示压缩率、行数、规则数、声明数、注释数、耗时；
- 顶部右侧的 **Language:** 下拉框可随时切换界面语言，所有按钮、标签、选项、模式列表、状态栏消息和文件对话框过滤器会立即刷新；选择会保存到本机 `LOCALAPPDATA\CssPacker\settings.ini`，下次启动自动生效（首次启动按系统语言自动匹配）。

---

## 6. 多语言与自定义语言包

### 内置语言

`en`（English）、`zh-CN`（简体中文）、`zh-TW`（繁體中文）、`ja`（日本語）、`ko`（한국어）、`de`（Deutsch）、`fr`（Français）、`es`（Español）、`ru`（Русский）。

下拉框中每种语言都以自己的语言名称显示，便于识别；切换无需重启、无需重新编译。

### 新增 / 覆盖语言

在 `bin/CssPackerGui.exe` 同级的 `lang\` 目录放入 UTF-8 编码的 `.ini` 文件即可。示例 `bin/lang/it.ini` 提供了一个完整的意大利语包：

```ini
[Lang]
Name=Italiano
Code=it

[Strings]
btn.open=Apri...
btn.save=Salva...
status.ready=Pronto - apri un file CSS o incolla il CSS nell'area di input.
```

- 只需列出要翻译或覆盖的键，其余自动回退英文；
- `Code` 可省略，默认使用文件名；
- 含 `%s` 的条目是格式化模板，必须保留占位符；
- 完整键名见 `Lib/CssPacker.Lang.pas` 顶部的 `TXT_*` 常量；
- 格式错误的语言包会被安全忽略，不影响程序启动。

重新打开界面语言下拉框即可看到新增语言。详细说明见 `bin/lang/README.md`。

### 在代码中使用

```pascal
uses CssPacker.Lang;

TCssLang.SetLanguage('zh-CN');
ShowMessage(TCssLang.T(TXT_BtnOpen));                        // 打开...
ShowMessage(TCssLang.TFormat(TXT_StatusLoaded, ['a.css', '128']));
```

---

## 7. 作为库使用（Delphi API）

在您的项目中引用 `Lib/CssPacker.Core.pas`：

```pascal
uses CssPacker.Core;

var
  Opts: TCssOptions;
  Stats: TCssStats;
  Output: string;
begin
  Opts := TCssOptions.Default;
  Opts.Operation := coPackSafe;        // 或 coPackAggressive / coUnpackPretty / coAuto
  Output := TCssPacker.Format(CssText, Opts, Stats);
  WriteLn(Stats.ToString);

  // 文件到文件（自动保留编码/BOM）
  Stats := TCssPacker.ProcessFile('in.css', 'out.min.css', Opts);

  // 兼容旧引擎
  Output := TCssPacker.LegacyFormat(CssText, coUnpackPretty);
end;
```

主要类型：

- `TCssOperation` = (`coPackSafe`, `coPackAggressive`, `coUnpackPretty`, `coAuto`)
- `TCssOptions`：缩进、换行符、注释、各项优化开关
- `TCssStats`：统计信息（`CompressionPercent`、`ToString`）
- `TCssPacker`：`Format` / `Pack` / `Unpack` / `DetectOperation` / `ProcessFile` / `ReadTextFile` / `WriteTextFile` / `LegacyFormat`

---

## 8. 测试

```bat
bin\CssPackerTests.exe
bin\GuiLangSmoke.exe
```

当前 **48 项测试全部通过**，覆盖：空白与分隔符压缩、语义保持（`calc` / `url` 数据 URI / 字符串 / 负值）、注释处理、激进优化、美化输出（含嵌套 at-rule 与伪类）、幂等性与往返一致性、自动检测、文件 IO、legacy 桥接，以及多语言翻译完整性、格式化、系统语言检测与外部 UTF-8 语言包加载。`GuiLangSmoke.exe` 会实际创建 VCL 窗体并切换语言，将结果写入 `bin\GuiLangSmoke.txt`。

---

## 9. 与原 `cssunpack.pas` 的关系

原始 `Source/cssunpack.pas` 的 `TCSSTools.FormatCSS2` 提供三种模式，但其 `UnpackPretty` 存在空白处理缺陷（字符被跳过）、且对嵌套规则 / 数据 URI / 伪类冒号的鲁棒性有限。本项目：

1. **保留**该文件不作破坏性修改，确保既有调用方可继续编译；
2. 在 `CssPacker.Core.pas` 中实现更健壮的新引擎作为默认；
3. 通过 `TCssPacker.LegacyFormat` 与 CLI 的 `--legacy` 参数保留对原始引擎的可用性。

---

*版本 1.0.0 — 使用 Delphi 12.2 构建。*
