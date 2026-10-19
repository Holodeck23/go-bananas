# 🍌 Go Bananas

Finish what's owed. Preserve what isn't. Resume in Claude Code or Codex.

Inspired by the “go bananas” end-of-session voice-snippet workflow shared in Early AI-dopters. This packages that habit as a [Polyskill](https://github.com/earlyaidopters/polyskill) skill: one portable source, generated variants for both runtimes.

## Use it

| Action | Claude Code | Codex |
|---|---|---|
| Choose finish or handover | `/gb` | `$gb` |
| Finish authorized work | `/gb finish` | `$gb finish` |
| Save progress, keep working here | `/gb checkpoint` | `$gb checkpoint` |
| Transfer remaining work | `/gb handover` | `$gb handover` |
| Continue from a handover | `/gb resume` | `$gb resume` |

The full name `go-bananas` also works. Plain `GB`, `gb` or `go bananas` is a convenience trigger that depends on the model selecting the skill; explicit invocation is more reliable. A voice snippet can insert either form.

## What happens

The skill inventories unfinished requests and promises, checks them against actual artifacts and Git state, and works within the user's existing authorization. Review-only remains read-only; prepared instructions, verified work, successful pushes, deployment and human acceptance remain separate states.

If tools can finish an authorized task, it uses them. Otherwise it prepares a browser-agent prompt or gives the user practical steps. A prepared prompt stays marked **prepared** until execution is confirmed.

For continuation, it saves one active `HANDOVER.md` (or the project's preferred artifact path), including boundaries, evidence, unresolved tasks and the first move. It preserves concurrent writers' work and archives completed handovers instead of erasing history. Read-only sessions return the handover in chat.

The small closeout check adapts the useful part of Vulcan's Mirror: reconcile requests against observed results, identify unresolved owners, and retain only lessons that affect the next action. No Vulcan installation, ritual logs or hooks are required.

### Before sharing

The skill reviews the exact staged diff and runs the packaged scanner before committing or pushing:

```bash
python3 <installed-skill>/scripts/preshare-scan.py
# Optional private names/identifiers, one literal per line; keep this file private:
python3 <installed-skill>/scripts/preshare-scan.py --deny-file <private-local-file>
```

It scans full staged blobs for common credential patterns, personal paths, emails, contact fields, pasted chat/export markers and sensitive filenames. Findings show file, line and category, without echoing matched contents. Binary, linked or unreadable content requires review. Re-scan after changing the staged content.

**A clean scan is not proof of privacy.** Personal names, client details and private narrative context still require a content review. This is a model-followed workflow with a deterministic helper, not an enforced Git hook. Python 3 is required for the scanner; a missing scanner does not clear anything for sharing.

### Opening the next session

The link helper verifies that the handover is committed and unchanged, the working tree is clean, and the **live origin branch** matches the local commit. It uses a read-only remote query, not a stale or unrelated tracking branch. Only then does it offer a cloud link. Offline/access failures, symlinks, missing files and local changes produce a warning and local/copyable alternatives. It never commits or pushes to make a link work.

```bash
bash <installed-skill>/scripts/handoff-links.sh --for codex
bash <installed-skill>/scripts/handoff-links.sh --for claude --handover handovers/task.md
```

Local links and terminal commands include the intended project location; cloud links identify the GitHub repository and branch. You still need destination access and any local services or ignored files. App links are conveniences: generated URL tests do not prove that an app opened or successfully resumed. The full copyable handover remains the fallback.

While loaded, the skill aims to hand over by **50% context use**. It checks real usage when available, prepares early and stops starting substantial work at the target, allowing safe closeout. This applies to finish, checkpoint and resume unless the user explicitly asks to continue. When usage is unavailable, it discloses that limit and uses bounded units with early handoffs; it never invents a percentage or treats compaction as a fresh session. This is guidance for the agent, not an automatic monitor of sessions where the skill is not loaded.

## Install

Review a checkout first, then preview and install its built variants:

```bash
git clone https://github.com/Holodeck23/go-bananas
cd go-bananas
bash install.sh --dry-run --target all
bash install.sh --target all
```

`--target claude` or `--target codex` installs only that runtime. With no target, the installer detects existing runtimes. Destinations are `~/.claude/skills/{go-bananas,gb}` and `~/.agents/skills/{go-bananas,gb}`. Refresh skill discovery if the new skill does not appear; you can also explicitly ask the agent to read the installed `SKILL.md` by path.

Existing destinations are refused by default. After reviewing the preview, `--replace` stages all new files before replacing anything, retains previous copies outside the skill catalog, and prints a receipt plus an undo command. A normal failure or handled interruption rolls the transaction back. A hard interruption may require the recorded recovery script; inspect the retained files first. No unrelated runtime configuration or hooks are modified.

Remote installation requires an explicit reviewed commit or tag:

```bash
# Download install.sh from the same reviewed revision, then:
bash install.sh --ref <reviewed-commit-or-tag> --dry-run --target all
bash install.sh --ref <reviewed-commit-or-tag> --target all
```

There is no unpinned remote-install fallback. The installer needs Bash and Git; using the scanner also needs Python 3.

## Build and test

Edit `src/definition.md` and `src/scripts/`, or `src-gb/definition.md` for the shortcut. Runtime directories are generated artifacts, not separate sources.

```bash
(cd src && polyskill build && polyskill validate)
(cd src-gb && polyskill build && polyskill validate)
python3 -m unittest discover -s tests -p '*_test.py' -v
```

The regression suites use throwaway Git repositories and isolated home directories. They cover cloud-readiness failures, encoding/quoting, custom handovers, staged privacy checks and installer recovery. The helper's remote transport is redirected to a real local bare repository for repeatable tests. These tests do not establish model behavior or app-link compatibility.

For a live trial, start with a harmless task and ask for a checkpoint. Inspect its goal, boundaries, evidence and remaining work. Resume it in a fresh session, then try the other runtime with the same handover. Also try a read-only request: it should produce a chat handover without changing files.

## License

[MIT](LICENSE).
