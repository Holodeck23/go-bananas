---
identity:
  name: go-bananas
  description:
    full: >
      End-of-session closer and next-session starter. Use when the user says
      "go bananas", "wrap up", "finish what's owed", asks for a handover, or
      wants to resume from a handover. With room left in the session it
      finishes every outstanding task it can, writes exact prompts for
      anything a browser agent should do, and walks the user through anything
      only they can do. When the session is running low it updates the docs,
      pushes what is safe, saves a complete handover to HANDOVER.md, and gives
      a one-line command that opens a fresh session already picking up where
      this one left off, plus one-click handoff buttons for the Claude Code
      and Codex apps. Accepts "finish", "handover" or "resume".
    short: Finish what's owed, or hand over with one click
activation:
  triggers:
    - go bananas
    - wrap up
    - handover
    - resume from handover
    - finish outstanding tasks
  auto_invoke: false
  user_invoke: true
dependencies:
  mcp: []
  bash:
    - pattern: Bash(git:*)
      reason: check working tree state, commit and push safe work
  env: []
resources:
  scripts:
    - scripts/handoff-links.sh
  references: []
  assets: []
behavior:
  dynamic_injections: []
constraints:
  max_body_lines: 500
  recommended_body_tokens: 5000
---

# go-bananas

Excellent work so far. This skill closes out a session properly: finish what's owed, or hand over so cleanly that the next session starts working without a single question.

## Step 0. Read the mode

Look at what the user typed after the skill name.

| They typed | Do this |
|---|---|
| nothing | Steps 1 and 2 below; you choose the mode. |
| `finish` | Step 1, then Mode A. |
| `handover` | Step 1, then Mode B. |
| `resume` | Skip everything else and go straight to **Mode C**. |

If there is no argument but a `HANDOVER.md` exists in the project root and this session has done no work yet, ask one question: "There's a handover from a previous session. Resume it?" If yes, Mode C.

## Step 1. Take stock

List what is still open. Look back through this session for:

- Tasks the user asked for that are not done, or only partly done.
- Things you said you would do ("I'll also...", "next I'll...") and haven't.
- Failing tests, lint errors, TODOs you introduced, unpushed commits.
- Decisions you deferred to the user.

If you are in a git repository, run `git status --short --branch` and `git log --oneline -5` so the list reflects what is actually committed and pushed.

Show the list as a short checklist before acting on it. If nothing is outstanding, say so plainly and stop. Don't invent work.

## Step 2. Pick a mode

Judge how much room is left in this session. Signs it is running low: the conversation is very long, earlier context has already been summarized or compacted, or the remaining work is large (many files, a long debugging loop).

- **Room left → Mode A (Finish).**
- **Running low, or unsure → Mode B (Hand over).** A clean handover is cheap; a session that dies mid-task is expensive.

Say which mode you picked and why, in one line.

## Mode A. Finish what's owed

Sort every checklist item into exactly one bucket:

1. **You can do it yourself → do it.** Don't ask permission for work already requested. Verify each item (run the tests, re-read the output) before ticking it off.
2. **A browser agent can do it inside an app → write the prompt.** One copy box per task with a detailed, exact prompt for the browser agent: the URL or app to open, every click, field and value, what "done" looks like, and what to do if something doesn't match.
3. **Only the user can do it → walk them through it.** Numbered steps, one action per step, saying exactly where to click and what they should see after. Typical cases: logging in, paying, approving access, anything needing their judgment or credentials.

If you start running low partway through, stop and switch to Mode B rather than leaving work half done and undocumented.

Finish with the checklist again, each item marked ✅ done, 🤖 handed to a browser agent, or 🙋 waiting on the user.

## Mode B. Hand over

1. **Update the docs.** Bring README, CHANGELOG, setup notes or other project docs in line with what changed this session. Only edit docs that are actually stale.
2. **Write `HANDOVER.md`** in the project root (format below). If the project has no clear root, use the current working directory.
3. **Push what is safe.** Commit and push work that is complete and passes its checks, plus `HANDOVER.md`, so the next session finds it on any machine. Never push secrets or broken builds to a shared or default branch. Say what you pushed and what you held back. If this isn't a git repository, just save the file.

   **Uncommitted work doesn't travel.** A new session on another machine or in the cloud only sees what was pushed. If there are half-finished changes, create a branch named `wip/handover-<YYYYMMDD>`, commit them there with `HANDOVER.md`, push it, and stay on it, so the handoff buttons open that branch. If the user told you not to commit something, leave it, and warn them plainly that it exists only on this computer and a cloud session won't see it.
4. **Give the user the handoff buttons.** Run the script that ships with this skill, from the project root:

   ```bash
   bash <this skill's folder>/scripts/handoff-links.sh --for claude   # in Claude Code
   bash <this skill's folder>/scripts/handoff-links.sh --for codex    # in Codex
   ```

   It prints Markdown links that open a new session with the resume prompt already filled in: a claude.ai link (web, desktop and phone apps, with the repo and branch pre-selected), a Claude desktop link, a Claude Code terminal link and a Codex app link, depending on where you are running. **Paste its output into your reply exactly as printed**, so the apps render the links as buttons. Don't build these links by hand.

   If the script can't run, give the user these instead:
   - Claude Code terminal: `claude "/go-bananas resume"`
   - Codex terminal: `codex '$go-bananas resume'`
   - Any app: open a new session in this project and send "Resume from HANDOVER.md in this project: read all of it and follow its resume rules."

5. **Also show the full handover** in one copy box, for pasting anywhere the skill isn't installed. Use a **four-backtick fence** (` ```` `) or a tilde fence (`~~~`) for the outer block so any code inside, fenced with normal three backticks, can't break it. The outer fence must open once at the top and close once at the bottom.

### HANDOVER.md format

The file must stand on its own: a fresh session with no memory of this one, and possibly without this skill, must be able to act on it.

```markdown
# Handover: <project or task name>

> Written <date> by a previous session.
>
> **Resume rules for the next session:** read this whole file. Run
> `git status --short --branch` and `git log --oneline -5` and say if anything
> differs from "Where things stand". Ask the user every question under
> "Decisions for the user" at once, with the options and recommendation as
> written. Then start "First move" and work down "Outstanding tasks", verifying
> each one. When every task is done, delete this file and commit the deletion.

## Goal
What we are building and why, in two or three sentences.

## Where things stand
- Repo and branch, last commit (hash + message)
- What is done and verified
- What was pushed, and what was held back and why

## Outstanding tasks
1. Most important first, each with enough detail to start without asking.

## Known issues
Errors, flaky tests, gotchas and dead ends discovered this session.

## Decisions for the user
### <Question, in plain non-technical language>
- **Option A**: what it means in practice, with a concrete example.
  - Pros / cons
- **Option B**: ...
- **Recommendation:** which one and why it's the most useful choice.

## First move
The exact first thing the next session should do.
```

Leave out sections that would be empty, except **Outstanding tasks** and **First move**.

## Mode C. Resume

1. Read `HANDOVER.md` from the project root. If there isn't one, say so and ask the user what to pick up instead. If they pasted a handover into the chat, use that.
2. **Check it against reality.** Run `git status --short --branch` and `git log --oneline -5`. If the branch or last commit differs from the handover, or files it mentions are missing, say what changed before doing anything.
3. **Ask the open decisions first**, all at once, exactly as written (options, pros and cons, recommendation). They usually block the tasks. If the user says "go with your recommendations", do that.
4. **Start the first move**, then work down the outstanding tasks the same way as Mode A.
5. When every task in the handover is done, delete `HANDOVER.md` and commit the deletion with the finished work, so a stale handover never confuses a later session.

## Rules

- Never claim something is done that you didn't verify. "Pushed" means the push succeeded.
- Never put secrets, tokens or passwords in `HANDOVER.md`. Name where they live instead ("the API key is in `.env`").
- Don't put the handoff links or any local file paths in `HANDOVER.md`; they belong in your reply only.
- When everything is wrapped up, end with: "Bob's your uncle. 🍌"
