# Claude 会话「热键 fork」——iTerm2 集成

按一个快捷键(默认 **⌘F**),就把**当前 iTerm 窗格里正在跑的那条 Claude Code 会话**,在右边劈一个窗格 fork 出来。

和 `branchnew` 命令的关键区别:它 fork 的是**这个窗格里这一条确切的会话**(精确到 session id,`claude --resume <id>`),而不是「`$PWD` 里最近的那个」——所以 **fork-of-a-fork(对分支再分支)也能对**。

> 整套东西和 `branchnew` 命令共用一个脚本和 `~/.local/state/branchnew/` 状态目录:记录映射的活儿已经**并进 `branchnew --record`**(不再有单独的 `branchnew-record`)。

---

## 与 `branchnew` 命令的区别

| | `branchnew`(命令) | 热键 fork(本文档) |
|---|---|---|
| 触发方式 | 终端里敲 `branchnew` | 按 **⌘F** |
| fork 哪条会话 | `$PWD` 里**最近**的会话(`--continue`) | 当前窗格里**那一条确切**的会话(`--resume <id>`) |
| 新会话命名 | `--name newBranch<N>`(自增编号) | `-n fork`(固定叫 `fork`) |
| 依赖 | 无(纯 shell + AppleScript) | iTerm2 Python API + 后台守护脚本 + 会话映射表 |
| 适用 | 任意终端(tmux/iTerm2/Terminal) | 仅 iTerm2 |

---

## 快捷键在哪里定义、怎么改

快捷键**不在 iTerm2 的偏好设置里**,而是写在守护脚本里(`iterm2/claude_fork.py` 第 24–26 行):

```python
HOTKEY_KEYCODE = iterm2.Keycode.ANSI_F
HOTKEY_MODS = {iterm2.Modifier.COMMAND}
```

脚本用 iTerm2 的 `KeystrokeFilter` 把这个组合键「吞掉」(不让它到达 shell),再用 `KeystrokeMonitor` 监听它被按下。**想改键就改这两行**(例如换成 `ANSI_J`,或增删某个 Modifier),保存后重启 iTerm2。

> ⚠️ 默认 **⌘F** 会被守护**全局拦截**,所以 iTerm2 自带的 **Find(⌘F 搜索)在所有面板都会失效**。不想丢 Find,就给 `HOTKEY_MODS` 加修饰键,例如 `{iterm2.Modifier.OPTION, iterm2.Modifier.COMMAND}`(⌥⌘F),重启 iTerm2。

---

## 整体架构与数据流

```
  记录阶段(持续,每条 Claude 会话都在做)
  ┌────────────────────────────────────────────────────────────────┐
  │  Claude 钩子:SessionStart / UserPromptSubmit                    │
  │     │  stdin = 钩子 JSON(session_id, cwd, transcript_path …)    │
  │     ▼                                                            │
  │  branchnew --record                                             │
  │     │  • 从 $ITERM_SESSION_ID 取 iTerm 窗格 GUID                 │
  │     │  • 从 transcript 文件名取「真实」session id                │
  │     ▼                                                            │
  │  写映射文件:~/.local/state/branchnew/iterm/<GUID>             │
  │        第 1 行 = claude session id                              │
  │        第 2 行 = cwd                                            │
  └────────────────────────────────────────────────────────────────┘

  触发阶段(按下热键时)
  ┌────────────────────────────────────────────────────────────────┐
  │  iTerm2 AutoLaunch 守护:claude_fork.py                         │
  │     按 ⌘F                                                     │
  │     │  • 当前窗格 → session.session_id(= GUID)                 │
  │     │  • 读 ~/.local/state/branchnew/iterm/<GUID> → sid, cwd    │
  │     ▼                                                            │
  │  向右劈窗格,在新窗格里运行:                                    │
  │     cd <cwd> && claude --resume <sid> --fork-session -n fork    │
  └────────────────────────────────────────────────────────────────┘
```

一句话:**钩子持续把「iTerm 窗格 ↔ Claude 会话」的对应关系记下来;按键时守护脚本查这张表,fork 出当前窗格那条会话。**

---

## 改动清单(你「都改了哪些地方」)

| 文件 / 位置 | 类型 | 作用 |
|---|---|---|
| `~/Library/Application Support/iTerm2/Scripts/AutoLaunch/claude_fork.py` | **新增** | 热键守护:监听 ⌘F,劈窗格 + fork 当前窗格的会话(仓库内副本:`iterm2/claude_fork.py`) |
| `~/.local/bin/branchnew` 的 `--record` 分支 | **新增(合并)** | 钩子调用,写「窗格 GUID → 会话 id + cwd」映射;原 `branchnew-record` 已并入此处 |
| `~/.claude/settings.json` 的 `hooks` | **修改** | `SessionStart` + `UserPromptSubmit` 各加一条 → `branchnew --record` |
| iTerm2 设置 → Enable Python API | **手动开启** | AutoLaunch 脚本能运行的前提(`EnableAPIServer=1`) |
| `~/.local/state/branchnew/iterm/<GUID>` | 运行时数据 | 映射文件,每个 iTerm 窗格一份 |
| `~/.local/state/branchnew/iterm-fork.log` | 运行时日志 | 守护脚本(fork 动作)日志 |
| `~/.local/state/branchnew/record.log` | 运行时日志 | `branchnew --record` 每次写映射的日志 |

> **历史备注**:`UserPromptSubmit` 曾指向一个不存在的 `bash ~/.claude/hooks/branchnew.sh`,每次提交都报 `No such file or directory`。那条先被独立的 `branchnew-record` 取代,现在又进一步**并入 `branchnew --record`**,只剩一个脚本。

---

## 各组件详解

### 1. `iterm2/claude_fork.py` — 热键守护(iTerm2 AutoLaunch)

- 放在 iTerm2 的 `Scripts/AutoLaunch/` 目录里,**iTerm2 启动时自动运行**,常驻后台。
- `KeystrokeFilter([pattern])` 拦截 ⌘F(避免这串键打进 shell);`KeystrokeMonitor` 收到按键后,匹配 keycode + 修饰键,调用 `do_fork()`。
- `do_fork()`:取**当前窗口/标签/窗格**的 `session.session_id`(即 GUID)→ 读映射 → `async_split_pane(vertical=True)` 向右劈 → 在新窗格里 `async_send_text` 发:
  ```
  cd <cwd> && claude --resume <sid> --fork-session -n fork
  ```
  (`<sid>`/`<cwd>` 都做了 `shlex.quote`;发送前 `sleep(0.35)` 等新窗格 shell 起来。)
- 找不到映射时,日志写 `no mapping for pane guid=…` 并放弃(说明该窗格还没记录过 Claude 会话)。

### 2. `branchnew --record` — 映射记录器(已并入 branchnew)

- 由钩子调用(stdin 是钩子 JSON);也可在会话内手动调用(stdin 接 tty 时回退到 `$CLAUDE_CODE_SESSION_ID` / `$PWD`)。**不是给人日常用的子命令,不出现在 `branchnew --help` 里。**
- **窗格 GUID**:取 `$ITERM_SESSION_ID`(形如 `w0t0p0:GUID`)冒号后那段——它正好等于 iTerm2 Python API 里的 `session.session_id`。
- **会话 id**:优先用 **transcript 文件名**(`transcript_path` 去目录去扩展名)——这是当前**真正在用**的 `.jsonl`,因此一条 fork 会解析到 **fork 自己的 id**;其次 `$CLAUDE_CODE_SESSION_ID`,再次 JSON 里的 `session_id`。
- 把 `sid` 和 `cwd` 两行写进 `~/.local/state/branchnew/iterm/<GUID>`,并往 `record.log` 追加一行(排错用)。

> 这就是为什么要**两个钩子**:`SessionStart` 在会话一开始建立映射;`UserPromptSubmit` 每次发消息时刷新——保证 fork-of-a-fork 时映射指向最新那条会话 id。

### 3. `~/.claude/settings.json` 钩子

```json
{
  "hooks": {
    "SessionStart": [
      { "hooks": [
          { "type": "command",
            "command": "pgrep -f claude-net-bubble.py > /dev/null || python3 .../claude-net-bubble.py &",
            "async": true },
          { "type": "command",
            "command": "/Users/limin/.local/bin/branchnew --record" }
      ] }
    ],
    "UserPromptSubmit": [
      { "hooks": [
          { "type": "command",
            "command": "/Users/limin/.local/bin/branchnew --record" }
      ] }
    ]
  }
}
```

(`SessionStart` 里第一条 `claude-net-bubble.py` 是无关的既有钩子,保留即可;关键是两处 `branchnew --record`。)

### 4. 状态目录与日志

```
~/.local/state/branchnew/
├── counter            # branchnew CLI 的 newBranch<N> 自增计数器
├── iterm/             # 映射:每个 iTerm 窗格 GUID 一个文件(第1行 sid,第2行 cwd)
│   └── <ITERM-GUID>
├── iterm-fork.log     # claude_fork.py 的动作日志
└── record.log         # branchnew --record 的写映射日志
```

### 5. 前提:iTerm2 Python API

- iTerm2 → **Settings → General → Magic → Enable Python API**(对应 `EnableAPIServer = 1`)。首次开启会下载一个 Python 运行时。
- `AutoLaunch/` 里的脚本会在 iTerm2 启动时自动运行;首次运行 iTerm2 会弹窗让你**允许**它访问 API。

---

## 从零复现 / 装到另一台机器

一行(无需 clone):

```bash
curl -fsSL https://raw.githubusercontent.com/limin112/branchnew/main/install.sh | bash -s -- --hotkey
```

`--hotkey` 会:装好 `branchnew` + `/branchnew`、把 `claude_fork.py` 放进 iTerm2 AutoLaunch、**并自动把两条 `branchnew --record` 钩子写进 `~/.claude/settings.json`**(已存在则跳过,原文件备份为 `.bak`)。剩下两步一次性手动:

1. **开启 iTerm2 Python API**:Settings → General → Magic → Enable Python API。
2. **重启 iTerm2**(首次弹窗点「允许」),开一个 Claude 会话触发 `SessionStart` 写映射,然后在该窗格按 **⌘F**。

> 从 clone 装也行:`git clone … && cd branchnew && ./install.sh --hotkey`。

---

## 排错

| 现象 | 排查 |
|---|---|
| 按键没反应 | 看 `~/.local/state/branchnew/iterm-fork.log` 有没有 `daemon started`;没有 → Python API 没开 / 脚本没在 AutoLaunch / iTerm2 没重启 / 首次授权弹窗没点允许。 |
| 日志里 `no mapping for pane guid=…` | 该窗格还没记录过会话。确认两个钩子生效:`grep event= ~/.local/state/branchnew/record.log` 应看到 `SessionStart` / `UserPromptSubmit`。 |
| fork 出来没接上原会话 | 映射里的 `sid` 可能过期;在原窗格发一条消息(触发 `UserPromptSubmit` 刷新)再按键。 |
| 想换快捷键 | 改 `iterm2/claude_fork.py` 第 24–26 行,重启 iTerm2。 |
| 想看守护脚本报错 | `tail -f ~/.local/state/branchnew/iterm-fork.log`。 |

---

## 可改进(可选)

- **命名不一致**:热键 fork 固定 `-n fork`(都叫 "fork");`branchnew` 命令用 `--name newBranch<N>`(带自增编号)。可以把 `claude_fork.py` 里 `-n fork` 也改成读同一个 `counter` 文件、生成 `newBranch<N>` 或 `fork<N>`,与命令行统一。
