# 🍌 Go Bananas

> The laziest way to end an AI coding session. Type one command, and Bob's your uncle.

You know that long "finish everything, and if you're running out of room write me a handover" prompt you paste at the end of every session? This is that, as a skill, plus a **handoff button** that opens the next session already picking up where this one stopped.

```
/go-bananas      # Claude Code
$go-bananas      # OpenAI Codex
```

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Holodeck23/go-bananas/main/install.sh | bash
```

It finds Claude Code and/or Codex on your machine and installs the skill for each one. Prefer to do it by hand? See [Manual install](#manual-install).

## What it does

It lists everything still owed (unfinished asks, things it promised, failing tests, unpushed commits), checks git so the list matches reality, then picks a mode and tells you why.

### 🏁 Finish (room left in the session)

Every open item goes into exactly one bucket:

| Who can do it | What you get |
|---|---|
| The agent itself | It just does it, and verifies it. |
| A browser agent, inside an app | A detailed, exact prompt in a copy box. |
| Only you | A step-by-step walkthrough, one action per step. |

### 🤝 Hand over (running low, or unsure)

1. Updates any docs that went stale this session.
2. Saves a full handover to `HANDOVER.md`: goal, where things stand, outstanding tasks, known issues, and the first move. Every open decision gets plain-language options with examples, pros and cons, and a recommendation.
3. Pushes what's safe, including the handover, so the next session finds it on any machine. Half-finished work goes to its own `wip/handover-<date>` branch instead of being left behind on your computer. It never pushes secrets or broken builds to your main branch.
4. Gives you the **handoff buttons**:

> ### ▶️ Start the next session
> - **▶ Open in Claude Code** (web, desktop or phone): opens a new session on the same repo and branch, with the resume prompt filled in
> - **Open in the Claude desktop app** or **a Claude Code terminal** on your own computer
> - **▶ Open in the Codex app** when you're in Codex
> - Terminal: `claude "/go-bananas resume"` or `codex '$go-bananas resume'`

Click one, check the prompt, press Enter. The apps never send a link's prompt for you, so you stay in control.

| Where you are | Button it gives you |
|---|---|
| Claude Code on the web, phone or desktop | `https://claude.ai/code/new?…` with the repo and branch pre-selected |
| Claude desktop app, local folder | `claude://code/new?…` (you pick the folder) |
| Claude Code in a terminal | `claude-cli://open?…` in the same folder, plus the `claude` command |
| Codex app | `codex://threads/new?…` in the same folder, plus the `codex` command |

It also warns you if anything hasn't been pushed or committed, because a new session somewhere else can't see it.

### ▶️ Resume (the new session)

Reads `HANDOVER.md`, checks it against the repo and flags anything that changed, asks you the open decisions all at once, then starts on the first move. When everything's done it deletes the handover so it can't confuse a later session.

## Commands

| Type | What happens |
|---|---|
| `/go-bananas` | It decides: finish or hand over. |
| `/go-bananas finish` | Finish what's owed now. |
| `/go-bananas handover` | Hand over now, even with room left. |
| `/go-bananas resume` | Pick up from `HANDOVER.md` in a new session. |

(Use `$go-bananas` instead of `/go-bananas` in Codex.)

## Good to know

- **It only runs when you ask.** It's set to manual-only, so saying "wrap up" mid-task won't set it off by accident.
- **It can't see a fuel gauge.** Agents can't measure exactly how much room is left in a session, so it judges from signs like a very long chat or earlier messages already being summarized. When in doubt it hands over: a clean handover is cheap, a session that dies mid-task isn't. Force it either way with `finish` or `handover`.
- **No skill on the other end? No problem.** `HANDOVER.md` carries its own resume rules, so the buttons work even where the skill isn't installed. The full handover is also shown in one copy box you can paste anywhere.
- **Extra lazy:** map a voice or text-expander snippet to `/go-bananas` and just say "go bananas".

## Manual install

```bash
git clone https://github.com/Holodeck23/go-bananas
cp -r go-bananas/claude/go-bananas ~/.claude/skills/    # Claude Code
cp -r go-bananas/codex/go-bananas ~/.agents/skills/     # Codex
```

Claude Code picks it up right away. In Codex, refresh skills.

## How it's built

Go Bananas is a [polyskill](https://github.com/earlyaidopters/polyskill) workspace: one portable source, compiled into a version tuned for each runtime.

```
src/                      ← the source (edit here)
  definition.md           ← the skill, written once
  polyskill.yaml          ← build targets
  scripts/handoff-links.sh
claude/go-bananas/        ← built for Claude Code
codex/go-bananas/         ← built for Codex (+ agents/openai.yaml)
tests/                    ← checks for the button script
```

To change it, edit `src/`, then rebuild and test:

```bash
cd src && polyskill build --force && polyskill validate && cd ..
bash tests/handoff-links.test.sh
```

## License

[MIT](LICENSE). Share it, fork it, go bananas.
