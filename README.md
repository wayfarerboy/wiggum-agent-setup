# wiggum-agent-setup

A skill that installs **Ralph Wiggum** — an autonomous AI agent loop that works through your GitHub Issues unattended.

## What it does

Ralph fetches open GitHub Issues, has an AI prioritise them, then delegates each one to Claude (or Gemini as a fallback) which implements the fix, runs your test suite, and commits the result — all without human intervention.

## Installation

```bash
npx skills add wayfarerboy/wiggum-agent-setup
```

## Usage

Invoke Ralph with `/wiggum`:

| Command            | What it does                                                             |
| ------------------ | ------------------------------------------------------------------------ |
| `/wiggum init`     | One-time setup — copies `ralph.sh` and `AGENT.md` into your project root |
| `/wiggum update`   | Refreshes those files from the latest skill templates                    |
| `/wiggum add-task` | Creates a labelled GitHub Issue for Ralph to pick up                     |
| `/wiggum help`     | Full documentation                                                       |

## Quickstart

```bash
# 1. Install the skill into your project
/wiggum init

# 2. Customise AGENT.md with your test/lint/build commands

# 3. Queue some work
# Tell your agent: "Add a task for Ralph: the login button is broken on mobile"

# 4. Check out a feature branch (Ralph refuses to run on main/master)
git checkout -b ralph/batch-fixes

# 5. Run Ralph
./ralph.sh
```

## How it works

1. **Fetch** — Ralph lists open issues labelled `ralph: pending` (or all bugs with `--bugs`)
2. **Prioritise** — an AI ranks them by priority label, type, dependencies, and complexity
3. **Claim** — the issue is relabelled `ralph: in-progress` so parallel instances don't collide
4. **Implement** — the AI agent reads the issue, writes code, runs tests, and commits
5. **Close** — on success the label becomes `ralph: completed`; on failure, `ralph: failed`

```
ralph: pending  →  ralph: in-progress  →  ralph: completed
                                       →  ralph: failed
```

## Issue labels

Labels are bootstrapped automatically on the first run.

| Label                                 | Purpose                              |
| ------------------------------------- | ------------------------------------ |
| `ralph: pending`                      | Queued for Ralph to pick up          |
| `ralph: in-progress`                  | Currently being worked on            |
| `ralph: completed`                    | Done                                 |
| `ralph: failed`                       | Something went wrong — check the log |
| `type: bug` / `type: feature`         | Issue type                           |
| `priority: now / high / medium / low` | Determines ordering                  |

## Flags

```bash
./ralph.sh           # Process all issues labelled ralph: pending (default)
./ralph.sh --bugs    # Work on all open bug issues regardless of label
./ralph.sh --help    # Show usage
```

## Prerequisites

| Tool                 | Install                                                                                           | Notes                                             |
| -------------------- | ------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| `gh`                 | `brew install gh`                                                                                 | Run `gh auth login` once                          |
| `jq`                 | `brew install jq`                                                                                 | JSON processor                                    |
| `claude` or `gemini` | [Claude Code](https://claude.ai/code) / [Gemini CLI](https://github.com/google-gemini/gemini-cli) | AI engine (Claude is primary, Gemini is fallback) |
| `pnpm`               | `npm i -g pnpm`                                                                                   | Used for Gemini CLI                               |

## Tips

- **Run multiple instances in parallel** on different branches — the `ralph: in-progress` label prevents conflicts
- **Requeue a failed issue** by removing `ralph: failed` and adding `ralph: pending`
- **Claude quota hit?** Ralph falls back to Gemini automatically — and vice versa
- **Check the log** — the path is printed at startup, e.g. `/tmp/ralph_20260320_143000.log`
- **Never run on `main`** — Ralph enforces this and will exit with an error

## Skill files

```
wiggum-agent-setup/
├── SKILL.md          # Skill definition and command logic
├── AGENT.md          # Guardrails copied into target projects
└── scripts/
    └── ralph.sh      # The autonomous agent runner
```
