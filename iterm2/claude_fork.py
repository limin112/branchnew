#!/usr/bin/env python3
"""
claude_fork.py — iTerm2 AutoLaunch daemon.

Press the hotkey (default: Command+F) in any iTerm pane that is
running a Claude Code session, and it splits the pane to the right and forks
*that exact* session there:  claude --resume <id> --fork-session

The pane -> session mapping is written by `branchnew --record` (run from the
Claude SessionStart / UserPromptSubmit hooks) under
~/.local/state/branchnew/iterm/<iterm-session-guid>, where the guid equals the
iTerm2 API's session.session_id.
"""
import asyncio
import os
import shlex
import time

import iterm2

STATE_DIR = os.path.expanduser("~/.local/state/branchnew/iterm")
LOG = os.path.expanduser("~/.local/state/branchnew/iterm-fork.log")

# ---- Hotkey: edit these two lines to rebind ---------------------------------
HOTKEY_KEYCODE = iterm2.Keycode.ANSI_F
HOTKEY_MODS = {iterm2.Modifier.COMMAND}
# -----------------------------------------------------------------------------


def _v(x):
    """Enum member or plain int -> int."""
    return getattr(x, "value", x)


_HK = _v(HOTKEY_KEYCODE)
_HM = {_v(m) for m in HOTKEY_MODS}


def log(msg):
    try:
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, "a") as f:
            f.write("%s %s\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), msg))
    except Exception:
        pass


def lookup(guid):
    try:
        with open(os.path.join(STATE_DIR, guid)) as f:
            lines = f.read().splitlines()
    except OSError:
        return None, None
    sid = lines[0].strip() if len(lines) > 0 else ""
    cwd = lines[1].strip() if len(lines) > 1 else ""
    return (sid or None), (cwd or None)


async def do_fork(app):
    window = app.current_terminal_window
    tab = window.current_tab if window else None
    session = tab.current_session if tab else None
    if session is None:
        log("no current session")
        return
    guid = session.session_id
    sid, cwd = lookup(guid)
    if not sid:
        log("no mapping for pane guid=%s — open/record a Claude session there first" % guid)
        return
    # Fork the session that's actually live in this pane. The pane->id map is kept
    # current by the UserPromptSubmit hook, so a forked pane resolves to the FORK's
    # own id (which only comes into existence once the fork first branches) — that's
    # what lets a fork-of-a-fork fork the fork instead of the original.
    log("fork: pane=%s -> session=%s cwd=%s" % (guid, sid, cwd))
    new_session = await session.async_split_pane(vertical=True)
    cmd = "claude --resume %s --fork-session -n fork" % shlex.quote(sid)
    if cwd:
        cmd = "cd %s && %s" % (shlex.quote(cwd), cmd)
    await asyncio.sleep(0.35)  # let the new pane's shell come up
    await new_session.async_send_text(cmd + "\n")


async def main(connection):
    app = await iterm2.async_get_app(connection)

    pattern = iterm2.KeystrokePattern()
    pattern.keycodes = [HOTKEY_KEYCODE]
    pattern.required_modifiers = list(HOTKEY_MODS)

    log("daemon started (hotkey keycode=%s mods=%s)" % (_HK, sorted(_HM)))

    # KeystrokeFilter swallows our chord so it never reaches the shell;
    # KeystrokeMonitor notifies us when it (and everything else) is pressed.
    async with iterm2.KeystrokeFilter(connection, [pattern]):
        async with iterm2.KeystrokeMonitor(connection) as mon:
            while True:
                ks = await mon.async_get()
                if _v(ks.keycode) != _HK:
                    continue
                if not _HM.issubset({_v(m) for m in ks.modifiers}):
                    continue
                try:
                    await do_fork(app)
                except Exception as e:
                    log("fork error: %r" % e)


iterm2.run_forever(main)
