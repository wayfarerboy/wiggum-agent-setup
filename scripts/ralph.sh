#!/bin/bash
# Ralph Wiggum Technique Runner Script
# Fetches open GitHub issues, asks an AI to determine the best order, then
# delegates each one to an agent CLI.
# Requires: gh (GitHub CLI), jq, claude, pnpm (for gemini fallback)

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------
MODE="pending"  # default: only issues labelled "ralph: pending"
RETRY_FAILED=false

usage() {
  echo "Usage: ralph.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --bugs          Ignore 'ralph: pending' label and work on all open bug issues (type: bug)"
  echo "  --retry-failed  Re-fetch issues with 'ralph: failed' label and attempt them again"
  echo "  --help          Show this help message and exit"
  echo ""
  echo "Default behaviour (no flags): process issues labelled 'ralph: pending'."
  exit 0
}

for arg in "$@"; do
  case "$arg" in
    --bugs)          MODE="bugs" ;;
    --retry-failed)  RETRY_FAILED=true ;;
    --help)          usage ;;
    *)               echo "Unknown flag: $arg"; usage ;;
  esac
done

# ---------------------------------------------------------------------------
# Logging: write timestamped entries to both stdout and a log file.
# ---------------------------------------------------------------------------
LOG_FILE="/tmp/ralph_$(date +%Y%m%d_%H%M%S).log"
log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_FILE"; }
log "Log file: $LOG_FILE"

# ---------------------------------------------------------------------------
# Safety: refuse to run on main/master.
# ---------------------------------------------------------------------------
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ "$current_branch" = "main" ] || [ "$current_branch" = "master" ]; then
  log "ERROR: Ralph is running on '$current_branch'. Refusing to run — check out a feature branch first."
  exit 1
fi
log "Branch: $current_branch"

# ---------------------------------------------------------------------------
# Init: detect which AI to use (Claude first, Gemini as fallback).
# ---------------------------------------------------------------------------
log "Checking Claude availability..."
unset ANTHROPIC_API_KEY
claude_test_output=$(claude -p --dangerously-skip-permissions "reply with the word ok" 2>&1)
claude_exit=$?

if echo "$claude_test_output" | grep -qi "quota\|rate.limit\|too many\|exceeded\|usage limit"; then
  log "Claude quota exceeded — checking Gemini..."
  USE_AI="gemini"
elif [ $claude_exit -ne 0 ]; then
  log "Claude unavailable (exit $claude_exit) — checking Gemini..."
  USE_AI="gemini"
else
  log "Claude is available."
  USE_AI="claude"
fi

if [ "$USE_AI" == "gemini" ]; then
  log "Checking Gemini availability..."
  gemini_test_output=$(pnpm dlx @google/gemini-cli@latest -e none -p "reply with the word ok" --approval-mode yolo </dev/null 2>&1)
  gemini_exit=$?

  if echo "$gemini_test_output" | grep -qi "quota\|rate.limit\|too many\|exceeded\|usage limit"; then
    log "ERROR: Both AIs are unavailable. Claude quota exceeded and Gemini quota exceeded. Ralph cannot run."
    exit 1
  elif [ $gemini_exit -ne 0 ]; then
    log "ERROR: Both AIs are unavailable. Claude failed (exit $claude_exit) and Gemini failed (exit $gemini_exit). Ralph cannot run."
    exit 1
  else
    log "Gemini is available."
  fi
fi

log "Using: $USE_AI"
log "====================================================="

# run_agent_fast: buffered, for quick non-interactive calls (availability check, ordering)
run_agent_fast() {
  local prompt="$1"
  if [ "$USE_AI" == "claude" ]; then
    unset ANTHROPIC_API_KEY
    claude -p --dangerously-skip-permissions "$prompt"
  else
    pnpm dlx @google/gemini-cli@latest -e none -p "$prompt" --approval-mode yolo </dev/null
  fi
}

# run_agent_task: streaming, for issue execution where output should be visible live
run_agent_task() {
  local prompt="$1"
  if [ "$USE_AI" == "claude" ]; then
    unset ANTHROPIC_API_KEY
    claude -p --dangerously-skip-permissions "$prompt"
  else
    pnpm dlx @google/gemini-cli@latest -e none -p "$prompt" --approval-mode yolo </dev/null
  fi
}

# ---------------------------------------------------------------------------
# Bootstrap: ensure all required labels exist in this repo.
# Safe to run on every invocation — skips labels that already exist.
# ---------------------------------------------------------------------------
ensure_label() {
  local name="$1" color="$2" description="$3"
  gh label list --json name | jq -e --arg n "$name" '.[] | select(.name == $n)' >/dev/null 2>&1 ||
    gh label create "$name" --color "$color" --description "$description" 2>/dev/null || true
}

ensure_label "priority: now" "E11D48" "Urgent, needs immediate attention"
ensure_label "priority: high" "AB1D6F" "Needs fixing asap"
ensure_label "priority: medium" "D4C5F9" "Should fix reasonably soon"
ensure_label "priority: low" "DE9C2F" "Fix not urgent"
ensure_label "ralph: pending" "FEF2C0" "Queued for Ralph agent run"
ensure_label "ralph: in-progress" "0075CA" "Currently being worked on by a Ralph agent"
ensure_label "ralph: completed" "0E8A16" "Completed by Ralph agent"
ensure_label "ralph: failed" "B60205" "Failed during Ralph agent run"
ensure_label "ralph: retry" "FFA500" "Failed due to quota/rate limit, ready for retry"
ensure_label "type: bug" "B233F1" "Something isn't working"
ensure_label "type: feature" "1D76DB" "New feature or request"

log "Starting the Ralph Wiggum loop..."

# Tracks issues processed this run so GitHub label propagation delay can't
# cause the same issue to be picked up twice.
processed_numbers=""

# ---------------------------------------------------------------------------
# Main loop: re-fetches and re-orders issues at the start of each iteration
# so that issues added while Ralph is running are picked up automatically.
# ---------------------------------------------------------------------------
while true; do

  # -------------------------------------------------------------------------
  # Step 1: Fetch issues based on mode, then filter out already-processed ones.
  # -------------------------------------------------------------------------
  if [ "$MODE" = "bugs" ]; then
    log "Mode: bugs (all open issues labelled 'type: bug', excluding in-progress)"
    issues_json=$(gh issue list \
      --state open \
      --label "type: bug" \
      --json number,title,body,labels \
      --limit 100 \
      2>/tmp/ralph_gh_stderr)
    # Strip out any issues already claimed by another Ralph instance
    issues_json=$(echo "$issues_json" | jq '[.[] | select(.labels | map(.name) | index("ralph: in-progress") | not)]')
  elif [ "$RETRY_FAILED" = true ]; then
    log "Mode: retry-failed (issues labelled 'ralph: failed', excluding in-progress)"
    issues_json=$(gh issue list \
      --state open \
      --label "ralph: failed" \
      --json number,title,body,labels \
      --limit 100 \
      2>/tmp/ralph_gh_stderr)
    issues_json=$(echo "$issues_json" | jq '[.[] | select(.labels | map(.name) | index("ralph: in-progress") | not)]')
  else
    log "Mode: pending (issues labelled 'ralph: pending' or 'ralph: retry', excluding in-progress)"
    # Fetch issues that have either 'ralph: pending' OR 'ralph: retry'
    issues_json=$(gh issue list \
      --state open \
      --search "label:\"ralph: pending\" OR label:\"ralph: retry\"" \
      --json number,title,body,labels \
      --limit 100 \
      2>/tmp/ralph_gh_stderr)
    # Strip out any issues already claimed by another Ralph instance
    issues_json=$(echo "$issues_json" | jq '[.[] | select(.labels | map(.name) | index("ralph: in-progress") | not)]')
  fi
  gh_exit=$?

  if [ $gh_exit -ne 0 ]; then
    log "Error fetching GitHub issues: $(cat /tmp/ralph_gh_stderr)"
    exit 1
  fi

  # Filter out issues already handled this run (guards against GitHub label propagation delay).
  if [ -n "$processed_numbers" ]; then
    filter=$(echo "$processed_numbers" | tr ' ' '\n' | jq -Rs '[split("\n")[] | select(. != "") | tonumber]')
    issues_json=$(echo "$issues_json" | jq --argjson done "$filter" '[.[] | select(.number as $n | $done | index($n) | not)]')
  fi

  issue_count=$(echo "$issues_json" | jq 'length')
  log "Issue count: $issue_count"
  if [ "$issue_count" -eq 0 ]; then
    [ "$MODE" = "bugs" ] && log "No open bug issues found. Nothing to do." || log "No pending issues found. Nothing to do."
    break
  fi

  log "Found $issue_count pending issue(s)."

  # -------------------------------------------------------------------------
  # Step 2: Ask AI to analyse the issues and pick the highest-priority one.
  # Skip ordering if only one issue remains.
  # -------------------------------------------------------------------------
  if [ "$issue_count" -eq 1 ]; then
    log "Only one issue — skipping AI ordering."
    number=$(echo "$issues_json" | jq -r '.[0].number')
  else
    log "Asking AI to determine order..."
    ordering_prompt="You are helping prioritize a software development backlog.
Below is a JSON array of GitHub issues. Analyse them and return ONLY a newline-separated list of issue numbers in the order they should be worked on, highest priority first.

Consider:
- Priority labels (priority: now > high > medium > low > unlabelled)
- Type: bugs that are blocking users should come before features of equal priority
- Dependencies: if one issue is likely to affect or conflict with another, sequence them sensibly
- Complexity: simpler issues that unblock other work should come first where priority is equal

Output ONLY the issue numbers, one per line, with no explanation or other text.

Issues:
$issues_json"

    raw_ordering=$(run_agent_fast "$ordering_prompt" 2>/dev/null)
    ordered_numbers=$(echo "$raw_ordering" | tr ',' '\n' | tr -d ' \t\r' | grep -E '^[0-9]+$')
    log "Ordered numbers: $(echo "$ordered_numbers" | tr '\n' ' ')"

    if [ -z "$ordered_numbers" ]; then
      log "AI ordering failed or returned no results. Falling back to issue list order."
      ordered_numbers=$(echo "$issues_json" | jq -r '.[].number')
    fi

    number=$(echo "$ordered_numbers" | head -n1)
  fi

  log "====================================================="

  # -------------------------------------------------------------------------
  # Step 3: Process the highest-priority issue.
  # -------------------------------------------------------------------------
  task=$(gh issue view "$number" --json number,title,body,labels,comments 2>/tmp/ralph_gh_stderr)
  gh_task_exit=$?
  if [ $gh_task_exit -ne 0 ]; then
    log "Could not fetch issue #$number (exit $gh_task_exit): $(cat /tmp/ralph_gh_stderr) — skipping."
    # Remove from pending/in-progress so the loop doesn't get stuck on a bad issue
    gh issue edit "$number" --remove-label "ralph: pending" --remove-label "ralph: in-progress" --add-label "ralph: failed" 2>/dev/null || true
    sleep 1
    continue
  fi

  title=$(echo "$task" | jq -r '.title')
  desc=$(echo "$task" | jq -r '.body // ""')
  comment_count=$(echo "$task" | jq '.comments | length')
  if [ "$comment_count" -gt 0 ]; then
    comments_text=$(echo "$task" | jq -r '.comments[] | "--- Comment by \(.author.login) ---\n\(.body)\n"')
    log "Issue #$number has $comment_count comment(s) — including in prompt."
  else
    comments_text=""
    log "Issue #$number has no comments."
  fi

  log "Claiming issue #$number: $title (marking as in-progress)"
  gh issue edit "$number" --remove-label "ralph: pending" --remove-label "ralph: retry" --remove-label "ralph: failed" --add-label "ralph: in-progress" 2>/dev/null || true
  log "====================================================="

  if [ -n "$comments_text" ]; then
    prompt="Task: $title. Description: $desc. Issue comments (read these for additional context, decisions, and discussion): $comments_text. Refer to AGENT.md for guidelines. Ensure you run pnpm test, pnpm run lint and pnpm run build before finishing. If all pass, automatically commit your changes with a conventional commit message. Include 'Fixes #$number' in the commit message body so GitHub closes the issue automatically. Do not ask for permission."
  else
    prompt="Task: $title. Description: $desc. Refer to AGENT.md for guidelines. Ensure you run pnpm test, pnpm run lint and pnpm run build before finishing. If all pass, automatically commit your changes with a conventional commit message. Include 'Fixes #$number' in the commit message body so GitHub closes the issue automatically. Do not ask for permission."
  fi

  output_log="/tmp/ralph_task_output_#$number.log"
  run_agent_task "$prompt" 2>&1 | tee "$output_log"
  exit_code=${PIPESTATUS[0]}

  if [ $exit_code -eq 0 ]; then
    log "Issue #$number completed successfully. Updating labels..."
    gh issue edit "$number" --remove-label "ralph: in-progress" --add-label "ralph: completed" 2>/dev/null || true
  else
    # Check if the output contains quota/rate limit strings
    if grep -qi "quota\|rate.limit\|too many\|exceeded\|usage limit" "$output_log"; then
      log "Issue #$number failed due to quota limit. Marking for retry..."
      gh issue edit "$number" --remove-label "ralph: in-progress" --add-label "ralph: retry" 2>/dev/null || true
    else
      log "Issue #$number failed (exit $exit_code). Updating labels and adding comment..."
      gh issue edit "$number" --remove-label "ralph: in-progress" --add-label "ralph: failed" 2>/dev/null || true
      
      # Extract some useful error info if possible
      error_summary=$(tail -n 15 "$output_log" | sed 's/`//g') # avoid backtick issues in comment
      gh issue comment "$number" --body "Ralph failed with exit code $exit_code. Last few lines of output:
\`\`\`
$error_summary
\`\`\`" 2>/dev/null || true
    fi
  fi

  processed_numbers="$processed_numbers $number"

  sleep 1

done

log "====================================================="
log "Loop finished. All pending issues processed!"
log "Full log saved to: $LOG_FILE"
