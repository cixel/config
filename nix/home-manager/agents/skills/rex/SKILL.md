---
name: rex
description: Use the rex CLI to manage Rex sessions, open tabs, arrange panes, run commands, inspect terminal output, and control connected Rex apps.
metadata:
  rex-stub: "2"
---
<!-- Copied from the stub that "rex skill setup --session-naming" writes. Kept declaratively instead of running setup; see nix/home-manager/rex/default.nix (hms warns if Rex's stub drifts). -->

Run `rex __internal skill` and follow the guide it prints. The guide comes from
the installed Rex CLI, so it describes the commands available in that version.

If the command fails, the installed Rex version predates the guide. Start with
`rex whoami --json`, then use `rex --help` and `rex COMMAND --help`.
