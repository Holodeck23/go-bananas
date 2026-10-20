---
name: gb
description: |
  Use when the user types /gb or $gb. Two-letter shortcut for the go-bananas skill: finish authorized work, checkpoint or hand over verified progress.
disable-model-invocation: true
---

# gb

Shortcut for **go-bananas**. Run the go-bananas skill now, exactly as if the user had typed it, and pass along anything they typed after `gb` (`finish`, `handover`, `checkpoint` or `resume`).

- Claude Code: invoke the `go-bananas` skill.
- Codex: use `$go-bananas`.

If go-bananas isn't installed, say so and point the user to https://github.com/Holodeck23/go-bananas to install it.
