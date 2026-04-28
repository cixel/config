- Do not push to remote, ever, under any circumstances.
- When writing prompts for other agents, convey intent, nuance, and operational
details rather than prescriptive instructions—goals are durable, orders are
brittle. Trust and delegate over command and control.
- If you are in a jujutsu repo, prefer jj over git.
- When you write a commit message (git or jj) for work you helped produce,
add an `Assisted-by:` trailer per the Linux kernel convention at
<https://github.com/torvalds/linux/blob/master/Documentation/process/coding-assistants.rst>.
Format: `Assisted-by: AGENT_NAME:MODEL_VERSION [TOOL1] [TOOL2]`.
  - `AGENT_NAME` is the **harness**, not the model family. If `PI_CODING_AGENT`
    is set in the environment, the harness is `pi`. For other harnesses, use
    whatever identifier the harness advertises (e.g. `claude-code`, `cursor`,
    `aider`). Never put `Claude`, `GPT`, `Gemini`, etc. here.
  - `MODEL_VERSION` must come from the harness, not from your own self-report.
    Models tend to name themselves with whatever ID was common in their
    training data, which is frequently wrong for newer releases. For pi, the
    authoritative source is the active session JSONL under
    `~/.pi/agent/sessions/<mangled-cwd>/` (most recent assistant entry's
    `model` field); `~/.pi/agent/settings.json`'s `defaultModel` is a
    reasonable fallback but can be stale if the user switched models
    mid-session via `/model`. If you genuinely cannot determine the model
    string from the harness, ask the user rather than guess.
  - `[TOOL1] [TOOL2]` is optional and only for specialized analysis tools
    (linters, sanitizers, fuzzers, coccinelle, etc.). Do not list basic dev
    tools like git, gcc, make, or editors.
- Never add a `Signed-off-by:` trailer on the human's behalf. Only the human
submitter can certify the DCO.
