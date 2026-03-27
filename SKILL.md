---
name: wiggum
description: Ralph Wiggum autonomous agent loop. Use for setup, updates, or queuing tasks. Triggered by /wiggum or when the user mentions "Ralph", "the agent loop", or "wiggum".
argument-hint: init | update | add-task | help
---

# Ralph Wiggum

Read the argument and run the matching feature. If no argument is given, ask the user which they need.

---

## `init` — One-time repo setup

Read `scripts/ralph.sh` from this skill directory, then use the **Write tool** (not Edit) to write it to the project root and make it executable (`chmod +x ralph.sh`).
Read `AGENT.md` from this skill directory, then use the **Write tool** (not Edit) to write it to the project root.

After scaffolding, tell the user to:
- Customise the test/lint/build commands in `AGENT.md` to match their project.
- Create GitHub Issues labelled `ralph: pending` + a `type:` and `priority:` label — these are the tasks Ralph will work through.
- Run `ralph.sh` from inside their git repo (it uses the local git remote automatically).
- Ensure dependencies are installed: `gh` (authenticated), `jq`, `claude` CLI. Gemini (`pnpm dlx @google/gemini-cli@latest`) is used as a fallback if Claude is unavailable.
- **Never run `ralph.sh` on `main` or `master`** — the script refuses, but they should branch first.
- Labels are bootstrapped automatically on first run.

---

## `update` — Refresh project files from latest skill templates

Read `scripts/ralph.sh` from this skill directory, then use the **Write tool** (not Edit) to overwrite the project root `ralph.sh` entirely with that content. Re-apply `chmod +x`.
Read `AGENT.md` from this skill directory, then use the **Write tool** (not Edit) to overwrite the project root `AGENT.md` entirely with that content.

Do not diff or apply partial changes — always replace the full file contents.

Confirm what was updated when done.

---

## `add-task` — Queue a task for Ralph

Create a GitHub Issue in the current repo that the Ralph runner will pick up.

Ask for anything missing: title, description, and type (`bug` or `feature`). Write a body with enough context for the agent to complete the task without further input.

Infer priority from anything the user has said. If no priority is stated, default to `priority: now`.

Create the issue with:
- `--label "ralph: pending"`
- `--label "type: bug"` or `--label "type: feature"`
- `--label "priority: now"`, `"priority: high"`, `"priority: medium"`, or `"priority: low"`

Confirm the issue URL to the user when done.

---

## `help` — Show Ralph documentation

Output the following documentation directly to the user:

---

### Ralph Wiggum — Autonomous Agent Loop

Ralph is an AI-powered script (`ralph.sh`) that autonomously works through GitHub Issues, one at a time, using Claude (or Gemini as a fallback). Run it unattended on a feature branch while you get on with other things.

#### Prerequisites

| Tool | Install | Notes |
|---|---|---|
| `gh` | `brew install gh` | Run `gh auth login` once |
| `jq` | `brew install jq` | JSON processor used internally |
| `claude` | [Claude Code CLI](https://claude.ai/code) | Primary AI engine |
| `pnpm` | `npm i -g pnpm` | Used for Gemini fallback |

#### Quickstart

```bash
# 1. Check out a feature branch (Ralph refuses to run on main/master)
git checkout -b ralph/batch-fixes

# 2. Install dependencies
pnpm install

# 3. Run Ralph
./ralph.sh
```

#### Queuing Tasks

Ask Claude Code:
> "Add a task for Ralph: the login button is broken on mobile"

Or create a GitHub Issue manually with these labels:

| Label | Required? | Values |
|---|---|---|
| `ralph: pending` | Yes | Tells Ralph to pick it up |
| `ralph: retry` | No | Automatically added on quota failure; Ralph will retry these |
| `type: bug` or `type: feature` | Yes | Categorises the work |
| `priority: now / high / medium / low` | Yes | Determines ordering |

#### Issue Lifecycle

```
ralph: pending  →  ralph: in-progress  →  ralph: completed
ralph: retry    ↗                      →  ralph: failed
```

- **`ralph: pending`** — waiting in the queue
- **`ralph: retry`** — waiting for quota reset; Ralph picks these up automatically
- **`ralph: in-progress`** — actively being worked on (prevents two Ralph instances claiming the same task)
- **`ralph: completed`** — done; GitHub closes the issue automatically if the commit contains `Fixes #N`
- **`ralph: failed`** — something went wrong; check the log file printed at startup or the issue comment

#### Flags

```bash
./ralph.sh           # Process all issues labelled ralph: pending or ralph: retry (default)
./ralph.sh --bugs    # Process all open bug issues regardless of label
./ralph.sh --retry-failed  # Attempt to process all issues currently marked as ralph: failed
./ralph.sh --help    # Show usage
```

#### Tips

- **Run multiple instances in parallel** on different branches — the `ralph: in-progress` label prevents conflicts.
- **Check the log file** printed at startup (e.g. `/tmp/ralph_20260320_143000.log`) if something goes wrong.
- **Requeue a failed issue** by removing `ralph: failed` and adding `ralph: pending` — Ralph will retry it.
- **Claude quota hit?** Ralph automatically falls back to Gemini with no intervention needed.

#### Slash commands

| Command | What it does |
|---|---|
| `/wiggum init` | One-time setup: copies `ralph.sh` and `AGENT.md` into the project |
| `/wiggum update` | Refreshes `ralph.sh` and `AGENT.md` from the latest skill templates |
| `/wiggum add-task` | Creates a labelled GitHub Issue for Ralph to pick up |
| `/wiggum help` | Shows this documentation |
