---
identity:
  name: gb
  description:
    full: >
      Use when the user types /gb or $gb. Two-letter shortcut for the
      go-bananas skill: finish authorized work, checkpoint or hand over verified progress.
    short: Shortcut for go-bananas
activation:
  triggers:
    - gb
  auto_invoke: false
  user_invoke: true
dependencies:
  mcp: []
  bash: []
  env: []
resources:
  scripts: []
  references: []
  assets: []
behavior:
  dynamic_injections: []
constraints:
  max_body_lines: 50
  recommended_body_tokens: 300
---

# gb

Shortcut for **go-bananas**. Run the go-bananas skill now, exactly as if the user had typed it, and pass along anything they typed after `gb` (`finish`, `handover`, `checkpoint` or `resume`).

- Claude Code: invoke the `go-bananas` skill.
- Codex: use `$go-bananas`.

If go-bananas isn't installed, say so and point the user to https://github.com/Holodeck23/go-bananas to install it.
