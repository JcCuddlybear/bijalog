# Bijalog — start here

## Why

You work something out with an AI. Next week it's forgotten. And when it tells
you what you decided, you can't check.

## What this does

It writes your decisions into a text file. One decision, one line, with the date.

Lines are never changed. Change your mind and a new line goes underneath. The
old one stays.

- The AI reads the file, so it knows where you got to
- You can open the file and see it yourself
- Nothing vanishes
- The AI can only suggest. Nothing counts until you say yes

**Not for** lists or notes. Just decisions you'll want to remember.

## What you need

There are two ways to run this. Start with the first.

**The quick way** — a Claude account with Google Drive connected. That's it.
Works in a browser, on any computer. Nothing to install.

**The computer version** — Python, and Google Drive for desktop if you want
your log synced. Windows has a setup window that does the work; on macOS and
Linux there are wrappers in the `mac/` folder.

- Claude — <https://claude.ai>
- Google Drive for desktop (computer version only) —
  <https://support.google.com/drive/answer/10838124>

## Setting it up (the quick way — no install)

1. In Claude, start a new **Project**
2. Connect **Google Drive** in its settings
3. Open **[setup_block.txt](setup_block.txt)**, click the copy button at the top
   right of it, and paste the lot into the project's instructions
4. Say hello

Claude does the rest. It may ask you to approve things as it goes. That's fine.

**One thing to know before you start.** This works by Claude rewriting your
whole file every time. Fine at first. Once the file gets big, it starts making
mistakes you won't spot. Then you need the computer version — see below. It's
not optional forever.

## Every time after that

Nothing to paste again. Just say what you're working on: *"Where are we on
my-story?"*

Claude should tell you which file it read. **If it doesn't, ask.** An AI will
guess and sound certain. That's the whole reason this exists.

## Keep a copy

Copy the bijalog folder somewhere else now and then. It's just text files.

## The computer version

When the file gets too big for the quick setup — or you want lots of projects
at once — the same log can live on your own computer instead, where it never
gets re-sent.

**1. Download it.** Green **Code** button above → **Download ZIP**.

**2. Unblock it before you unzip.** Right-click the downloaded file →
**Properties** → tick **Unblock** at the bottom → OK. Windows flags anything
that came from the internet, and this clears the whole set in one go.

![The Unblock tick box in the zip file's Properties](docs/unblock.png)

**3. Extract it.** Right-click → **Extract All**. Don't run things from inside
the zip preview window — Windows copies them off somewhere on their own and it
fails confusingly. GitHub nests the folder, so go one level in afterwards.

**4. Run `bijalog_setup.bat`.** A window opens. It finds Python, or offers to
install it for you; asks where your files should live; and asks what name
should go on the decisions you approve.

![The Bijalog Setup window](docs/setup-window.png)

If Windows warns about an unknown publisher, click **Run**. Bijalog does not
need administrator rights and should not be given them.

**5. Click Set up Bijalog.** It creates your folders, saves your settings, and
runs eight checks to prove the install works.

![All eight checks passed](docs/checks-passed.png)

If a check fails, copy that box and send it to me — it says exactly where it
broke.

Once it's set up, these are the four things it does:

```text
python bijalog.py add <project> "<decision>" --topic <topic> [--approved]
python bijalog.py approve <project> <id>
python bijalog.py verify
python bijalog.py state <project>
```

- `add` writes a line. Without `--approved` it's PROPOSED; with it, ACTIVE
- `approve` turns a PROPOSED line into ACTIVE
- `verify` checks nothing is missing or damaged
- `state` shows what's true right now

Same file format as the quick setup. Move across whenever you like — nothing
is lost.

## Rough edges, so you're not surprised

- There's an MCP server (`bijalog_mcp.py`) for AI tools that support that kind
  of connector. It's built and passes its own tests, but hasn't been run
  against a live AI client yet. Treat it as experimental.
- Tested on Windows and Linux. On a Mac, use the wrappers in the `mac/` folder
  (see `mac/README_MAC.md`) - the Python is identical, only the double-click
  scripts differ. The full cycle passes on Linux; a real Mac hasn't been tried
  yet, so treat that as expected-to-work rather than proven.
- This is early. Expect a few things to be unclear or slightly broken.

## Last thing

Use it on something real and tell me what annoyed you. Especially worth
reporting: if Claude forgets to read the log, picks the wrong project, or calls
something current that you'd already changed. And if you ran `test_bijalog.bat`,
send the verdict block either way.

Email me, or better, Discord: <https://discord.gg/nDxxXW5u5>
