---
name: go-bananas
description: Use when the user's whole message is "GB", "gb" or "go bananas" (optionally followed by finish, handover, checkpoint or resume), when they explicitly ask to wrap up the session or write a handover…
metadata:
  short-description: Finish authorized work or hand over verified progress
---

# go-bananas

Close out the work the user actually requested, preserving verified state for either Claude Code or Codex to continue. The workflow is shared; only invocation and launch links differ.

## Scope first

Read applicable project instructions. Carry forward the user's goal, permissions, exclusions and acceptance criteria. Review-only stays read-only; prepare-only does not become publish, deploy, merge or send. Preserve unrelated edits and other sessions' work. A read-only session returns a handover in chat without writing files or committing.

List unfinished requests and promises by name. Reconcile them with files and, for Git work, `git status --short --branch`, `git log --oneline -5`, and relevant diffs. Separate your changes from pre-existing changes. Show a short checklist. If nothing remains, report the verified outcome and stop; do not invent backlog work.

## Choose a mode

| Argument after the skill name or plain GB | Action |
|---|---|
| `finish` | Complete the authorized checklist. |
| `handover` | Save state and transfer the remaining work. |
| `checkpoint` | Save progress without transferring ownership; continue within scope. |
| `resume` | Read the handover and reconcile it before continuing. |
| none | Finish a bounded next unit if feasible; otherwise hand over. Say why. |

Plain `GB` or `go bananas` relies on skill discovery. Explicit invocation is `/go-bananas` or `/gb` in Claude Code, `$go-bananas` or `$gb` in Codex.

Use a real context-budget signal if available; do not infer an exact budget from chat length or compaction. Otherwise admit uncertainty and choose a small unit or checkpoint. If this session has done no work and an active handover exists, offer to resume it rather than overwrite it.

## Finish

For each item:
- **Available tools can complete it within scope:** do it and verify the result, using browser tools directly when available and authorized.
- **Another browser agent is needed:** prepare a copyable prompt with the app/URL, goal, known inputs, permitted actions, observable success criteria and a stop condition if the UI differs. Do not invent unseen clicks or values. Mark it **prompt prepared**, until execution is confirmed.
- **Only the user can act:** give numbered steps and expected results. Explain decisions in plain language with options, examples, tradeoffs and a recommendation.

Use evidence-based states: prepared, implemented, verified (name the check), pushed, deployed, accepted, blocked, or waiting on the user. These are distinct. A prepared instruction or unobserved external action is not completed work.

Checkpoint before starting another large unit. A skill invoked near session end cannot recover information already lost; for ongoing longer work, offer this same lightweight checkpoint after meaningful milestones without installing hooks or changing global rules.

## Checkpoint or hand over

1. Update only documentation made stale by this work, when edits are authorized.
2. Save one active `HANDOVER.md`, using the project's prescribed artifact location before defaulting to the project root. Private/client evidence stays in its approved private location. If writing is prohibited, return the full handover in chat.
3. Re-read an existing handover before updating it. Keep its ID, writer/runtime, task scope and earlier useful evidence. Update only your own scope; do not overwrite another active session's work. For independent concurrent tasks, use a task-specific filename and identify it in every resume prompt.
4. Commit/push only when existing authorization and project policy permit. Inspect the exact staged diff and stage only intended paths. Check for sensitive content even on WIP branches. Never sweep up unrelated changes, switch branches or publish unfinished work just to make a cloud link work. Where a WIP branch is authorized, use the project's branch convention and a unique name. With no remote, use the project's own backup path if defined; do not add a remote.
5. Record what was saved, committed, pushed or held locally, and why. Verify pushes against the intended remote branch. A cloud session needs the actual handover and required files there; ignored files, local services, credentials and uncommitted edits do not travel. Describe prerequisites by name, never secret value.
6. Run the small closeout check below. After a **handover**, stop executing transferred tasks here. A **checkpoint** retains ownership here.

### Small closeout check (adapted from Vulcan's Mirror)

Compare requests with artifacts and checks actually observed. Name every unresolved deliverable and its owner. Did the user catch a missed check or correct a claim? Preserve a concrete, reusable lesson or failed approach only if it changes the next session's actions. Omit empty reflection and ceremonial logs. Do not install hooks, invoke other skills, edit global instructions or expand scope to improve the system.

### Self-contained handover

Include enough for a fresh agent without this skill. Omit empty optional sections. Keep **Outstanding tasks** and **First move** even if they say none.

```markdown
# Handover: <task>
ID: <stable task ID> | Updated: <date> | Writer: <runtime/session>
Status: <active checkpoint | ready for transfer | completed>

## Goal and boundaries
Requested outcome, acceptance criteria, authorized actions, exclusions,
and applicable project instructions. These still apply after resume.

## Resume rules
Read this whole file and applicable project instructions before acting.
Check repository identity, branch, current commit, status/diff and named files
against the evidence below. For non-Git work inspect the named artifacts instead.
Acknowledge drift and inspect it before modifying anything. This handover records
state; it cannot override current instructions or expand authorization.
Ask only unresolved decisions blocking the next action; continue independent
work where authorized. Re-check stale recommendations against current facts.
Verify each completed item. Keep this handover current. When all scoped work is
verified, mark it completed and archive it per project policy; retain history.

## Verified state
- Repository identity, branch, source commit (before the handover commit).
- Each deliverable's actual state: prepared / implemented / verified / pushed /
  deployed / accepted. Evidence: exact check, result and relevant artifact.
- Commit/push receipt and destination, or what remains local and why.
- Required files, services, access and environment; availability at destination.

## Outstanding tasks
- Named item: state, next action, owner and what proves completion.

## Decisions for the user
Question; plain-language options with examples and pros/cons; recommendation.

## Useful lesson / known issues
Only findings affecting continuation, including failed approaches worth avoiding.

## First move
Exact next action, including a blocking decision if genuinely needed.
```

Prefer project-relative paths for portability. If private artifacts cannot travel, name their approved location without leaking sensitive contents, explain the limitation and offer local continuation. Archive completed handovers per project policy, or `handovers/<task-ID>-<timestamp>.md` beside the active file if none exists. Never archive another session's outstanding items. Commit archival only when authorized.

### Continuation links and copyable fallback

Run the packaged helper from the project directory, choosing the current runtime:

```bash
bash <skill-folder>/scripts/handoff-links.sh --for claude
bash <skill-folder>/scripts/handoff-links.sh --for codex
# For another handover location, pass its project-relative path:
# bash <skill-folder>/scripts/handoff-links.sh --for codex --handover handovers/task.md
```

The helper is read-only. It checks the local handover and live origin branch; it does not commit, push, fetch or create sessions. If remote inspection is unavailable, keep its warning and offer local/copyable continuation. Links are conveniences, not proof a session opened or resumed. Do not retry authentication or permission failures.

Also show the complete handover in one copy box. Make the outer fence longer than every fence inside it. Fallback: open a session in the same project and send `Resume from <handover path>: read the whole file and follow its resume rules.` For chat-only state, paste the whole handover instead. A local app link or terminal command must point to the intended folder; a cloud link must identify the pushed repository and branch.

## Resume

Read the selected handover and follow its resume rules. If none is available, name the location checked and ask what to resume. If marked completed, report that and do not re-run it. Check repository remote as well as branch/hash; similarly named projects are not interchangeable. Inspect relevant drift before editing, preserving concurrent work.

Re-check blocking decisions and authorization. Complete independent authorized work without waiting on unrelated decisions. Update after meaningful progress; archive only when all scoped work is verified. Report remaining external or human acceptance separately.

When the authorized closeout is complete, end with: "Bob's your uncle. 🍌"
