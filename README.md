# branchnew

🌐 [English version ↓](#branchnew-english)

> 🤖 **最省事的装法**:把这个仓库、或它的 URL `https://github.com/limin112/branchnew` 丢给 Claude Code,说一句「**帮我装 branchnew**」,它就会照着本 README 的 [安装](#安装) 步骤帮你装好(并会问你要不要 iTerm2 ⌘F 热键)。

在**当前终端**向右劈一个窗格,并在那里把当前的 Claude Code 会话 **fork 一份继续**——于是你立刻得到一个上下文相同的「分身」,就贴在你正在工作的地方。你原来的窗格不动。

一句话:`branchnew` = 「把这个 Claude 会话再 fork 一个分身,放右边」。

```
┌───────────────┬───────────────┐
│  你正在工作的   │  branchnew 开的 │
│  Claude 会话    │  fork 分身      │
│  (原样不动)     │  newBranch[N]   │
└───────────────┴───────────────┘
```

## 用法

只有三种形式:

```bash
branchnew            # 向右劈窗格 + fork 当前会话,自动命名 newBranch1 / newBranch2 / …
branchnew <name>     # 同上,但把新会话命名为 <name>(原样,不带编号)
branchnew --help     # 查看帮助
```

例:

```bash
branchnew                 # → newBranch3(自动编号)
branchnew login-fix       # → 会话名 "login-fix"
branchnew 试一下别的方案    # 名字可带空格/中文,不用加引号
```

> **在 Claude Code 会话里**:直接打 **`/branchnew`**(或 `/branchnew <名字>`)即可触发同样的 fork——斜杠命令内部就是调 `branchnew`。`install.sh` 会一并把它装到 `~/.claude/commands/`。

## 它做什么

- **同上下文 + 分叉**:新窗格里跑 `claude --continue --fork-session`,接上 `$PWD` 里最近的那个会话,并 **fork** 成独立的一支——两边各走各的,互不影响。
- **自动命名**:不传名字时,新会话自动叫 `newBranch1`、`newBranch2`……(全局自增编号);传了名字就用你的名字。名字通过 `claude --name` 设置,显示在新会话的**输入框、`/resume` 选择器、终端标题**里,方便区分一堆分支。
- **不改动任何文件或配置**:它只是开一个新的终端视图去跑 `claude`,纯粹的「开窗器」。

## 支持的终端(自动识别)

按优先级自动选择,**无需手动指定**;动作始终是「向右劈一个窗格」,不能劈的退而求其次:

| 终端环境 | 行为 |
|---|---|
| **tmux**(在任意终端里) | `tmux split-window -h`,真·向右分屏 |
| **iTerm2** | 原生 `split vertically`,向右分屏 |
| **Apple Terminal**(系统自带) | 不支持分屏 → **新开一个窗口**(想真分屏请用 tmux 或 iTerm2) |
| 其它终端(Ghostty/Kitty/Warp/VS Code…) | 无法脚本控制 → 新开一个 Apple Terminal 窗口,并给出提示 |

## 进阶:iTerm2 热键 fork(⌘F)

除了命令行,还有一个 iTerm2 集成:**按快捷键 fork 当前窗格里那条确切的会话**(精确到 session id,所以 fork-of-a-fork 也对)。它靠一个 iTerm2 后台守护 + Claude 钩子(钩子调用 `branchnew --record` 记录「窗格 ↔ 会话」映射)。安装:`./install.sh --hotkey`。完整原理与复现步骤见 **[HOTKEY-FORK.md](HOTKEY-FORK.md)**。

## 安装

**一行装好**(`branchnew` 命令 + `/branchnew` 斜杠命令,无需 clone):

```bash
curl -fsSL https://raw.githubusercontent.com/limin112/branchnew/main/install.sh | bash
```

想**连 iTerm2 ⌘F 热键 fork 一起装**(会自动帮你写好 Claude 钩子):

```bash
curl -fsSL https://raw.githubusercontent.com/limin112/branchnew/main/install.sh | bash -s -- --hotkey
```

> 热键还需两步一次性手动:iTerm2 设置里开启 Python API、重启 iTerm2 并允许脚本——见 [HOTKEY-FORK.md](HOTKEY-FORK.md)。

装完后:在 Claude Code 里打 **`/branchnew`**,或终端里 `branchnew --help`。`~/.local/bin` 不在 PATH 时安装脚本会自动加上(新开终端生效)。

<details>
<summary>从 clone 安装 / 只装命令本体</summary>

```bash
git clone https://github.com/limin112/branchnew.git && cd branchnew
./install.sh            # 基础:branchnew + /branchnew
./install.sh --hotkey   # 再加 iTerm2 热键守护 + 自动写钩子
```

只要 `branchnew` 命令本体(手动):

```bash
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/limin112/branchnew/main/branchnew -o ~/.local/bin/branchnew
chmod +x ~/.local/bin/branchnew
grep -q '.local/bin' ~/.zshrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
```
</details>

## 会话命名与编号

- **不传名字** → `newBranch<N>`。**N 是全局自增计数器**,持久化在 `~/.local/state/branchnew/counter`(遵循 `$XDG_STATE_HOME`),每次自动命名 +1,永不重复。想重新从头计数就删掉该文件,或写入起始值:
  ```bash
  echo 0 > ~/.local/state/branchnew/counter   # 下一个就是 newBranch1
  ```
- **传名字** → 直接用你给的名字,**不带编号、不消耗计数器**。名字可带空格/中文(脚本用 `$*`,不必加引号)。
- **预览不开窗**:`BRANCHNEW_DRYRUN=1 branchnew [name]` 只打印将要执行的命令(含最终名字)然后退出,不开任何窗口。

## 环境要求

- **macOS**(基于 AppleScript / tmux)。
- 已安装 **Claude Code** CLI,且 `claude` 在 PATH 中。
- 终端被允许运行 AppleScript:首次会弹「自动化(Automation)」授权 → 允许即可
  (系统设置 › 隐私与安全性 › 自动化)。

## 工作原理

`branchnew` 检测 `$TMUX` / `$TERM_PROGRAM` 选择后端,在新窗格/窗口里实际运行:

```bash
cd <你当前的目录> && claude --continue --fork-session --name <名字>
```

脚本本身**不写死任何个人路径**(只用 `$PWD`、`$@`),可以原样分享。

## 排错

| 现象 | 原因 / 解决 |
|---|---|
| 报错 `could not open the new view` + AppleScript 错误 | 没给终端「自动化」授权。系统设置 › 隐私与安全性 › 自动化,勾选你的终端控制 iTerm/Terminal。 |
| Apple Terminal 里开成了新窗口而不是分屏 | 正常行为——Terminal 不支持分屏。想真分屏请用 tmux 或 iTerm2。 |
| 新视图里 `claude: command not found` | 新开的 shell 里 `claude` 不在 PATH。先确保 Claude Code 已正确安装。 |

## License

MIT — 见 [LICENSE](LICENSE)。

---

# branchnew (English)

🌐 [中文版 ↑](#branchnew)

> 🤖 **Easiest install**: hand this repo — or just its URL `https://github.com/limin112/branchnew` — to Claude Code and say *"install branchnew for me."* Claude follows the [Install](#install) steps below (and asks whether you want the iTerm2 ⌘F hotkey).

Split the **current terminal** pane to the right and **fork-continue the current Claude Code session** there — instantly giving you a second view with the same context, right next to where you're working. Your original pane is untouched.

In one line: `branchnew` = "fork this Claude session into a clone on the right."

```
┌────────────────┬────────────────┐
│  the session   │  branchnew's   │
│  you're in     │  fork clone    │
│  (untouched)   │  newBranch[N]  │
└────────────────┴────────────────┘
```

## Usage

Just three forms:

```bash
branchnew            # split right + fork the current session, auto-named newBranch1 / newBranch2 / …
branchnew <name>     # same, but name the new session <name> (verbatim, no number)
branchnew --help     # show help
```

Examples:

```bash
branchnew                 # → newBranch3 (auto-numbered)
branchnew login-fix       # → session named "login-fix"
branchnew try other ideas # names may contain spaces — no quotes needed
```

> **Inside a Claude Code session**: just type **`/branchnew`** (or `/branchnew <name>`) to trigger the same fork — the slash command runs `branchnew` under the hood. `install.sh` installs it to `~/.claude/commands/`.

## What it does

- **Same context + branch off**: the new pane runs `claude --continue --fork-session`, resuming the most recent session in `$PWD` and **forking** it into an independent line — the two go their own ways, no interference.
- **Auto-naming**: with no name, the new session is `newBranch1`, `newBranch2`, … (a global incrementing counter); pass a name and it uses yours. The name is set via `claude --name` and shows in the new session's **prompt box, `/resume` picker, and terminal title**.
- **Changes no files or config**: it only opens a new terminal view running `claude` — purely a "window opener."

## Supported terminals (auto-detected)

Chosen automatically by priority, **no flags needed**; the action is always "split a pane to the right," falling back when a terminal can't:

| Terminal | Behavior |
|---|---|
| **tmux** (inside any terminal) | `tmux split-window -h` — a real split to the right |
| **iTerm2** | native `split vertically` to the right |
| **Apple Terminal** (built-in) | no split panes → **opens a new window** (use tmux or iTerm2 for a real split) |
| Others (Ghostty/Kitty/Warp/VS Code…) | can't be scripted → opens a new Apple Terminal window, with a notice |

## Advanced: iTerm2 hotkey fork (⌘F)

Besides the command line, there's an iTerm2 integration: **press a hotkey to fork the exact session live in the current pane** (precise to the session id, so fork-of-a-fork works too). It uses an iTerm2 background daemon + Claude hooks (the hooks call `branchnew --record` to record the pane ↔ session mapping). Install: `./install.sh --hotkey`. Full design & reproduce steps: **[HOTKEY-FORK.md](HOTKEY-FORK.md)**.

## Install

**One line** (`branchnew` command + `/branchnew` slash command, no clone needed):

```bash
curl -fsSL https://raw.githubusercontent.com/limin112/branchnew/main/install.sh | bash
```

To **also install the iTerm2 ⌘F hotkey fork** (auto-wires the Claude hooks for you):

```bash
curl -fsSL https://raw.githubusercontent.com/limin112/branchnew/main/install.sh | bash -s -- --hotkey
```

> The hotkey still needs two one-time manual steps: enable the Python API in iTerm2 settings, then restart iTerm2 and allow the script — see [HOTKEY-FORK.md](HOTKEY-FORK.md).

After installing: type **`/branchnew`** in Claude Code, or run `branchnew --help` in a terminal. If `~/.local/bin` isn't on PATH, the installer adds it (takes effect in a new terminal).

<details>
<summary>Install from a clone / just the command itself</summary>

```bash
git clone https://github.com/limin112/branchnew.git && cd branchnew
./install.sh            # base: branchnew + /branchnew
./install.sh --hotkey   # also the iTerm2 hotkey daemon + auto-wired hooks
```

Just the `branchnew` command (manual):

```bash
mkdir -p ~/.local/bin
curl -fsSL https://raw.githubusercontent.com/limin112/branchnew/main/branchnew -o ~/.local/bin/branchnew
chmod +x ~/.local/bin/branchnew
grep -q '.local/bin' ~/.zshrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
```
</details>

## Naming & numbering

- **No name** → `newBranch<N>`. **N is a global incrementing counter** persisted in `~/.local/state/branchnew/counter` (respects `$XDG_STATE_HOME`), +1 on each auto-name, never reused. To start over, delete that file or write a starting value:
  ```bash
  echo 0 > ~/.local/state/branchnew/counter   # next will be newBranch1
  ```
- **With a name** → used verbatim, **no number, counter untouched**. Names may contain spaces/CJK (the script uses `$*`, no quotes needed).
- **Preview without opening anything**: `BRANCHNEW_DRYRUN=1 branchnew [name]` just prints the command it would run (with the final name) and exits.

## Requirements

- **macOS** (built on AppleScript / tmux).
- The **Claude Code** CLI installed, with `claude` on PATH.
- Your terminal allowed to run AppleScript: the first run prompts for **Automation** permission → allow it (System Settings › Privacy & Security › Automation).

## How it works

`branchnew` detects `$TMUX` / `$TERM_PROGRAM` to pick a backend, and in the new pane/window runs:

```bash
cd <your current dir> && claude --continue --fork-session --name <name>
```

The script hardcodes no personal paths (only `$PWD`, `$@`), so it's safe to share as-is.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `could not open the new view` + an AppleScript error | Terminal lacks Automation permission. System Settings › Privacy & Security › Automation → allow your terminal to control iTerm/Terminal. |
| Apple Terminal opens a new window instead of splitting | Expected — Terminal has no split panes. Use tmux or iTerm2 for a real split. |
| `claude: command not found` in the new view | `claude` isn't on PATH in the new shell. Make sure Claude Code is installed. |

## License

MIT — see [LICENSE](LICENSE).
