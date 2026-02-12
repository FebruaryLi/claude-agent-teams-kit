# claude-agent-teams-kit

Orchestration guide and deterministic activation for Claude Code Agent Teams.

## Problem

Claude Code Agent Teams is powerful, but out of the box it has two issues:

1. **Orchestration quality is inconsistent.** When to create a team, how many teammates, how to partition tasks, how to avoid file conflicts — these decisions rely entirely on the model's implicit knowledge, with unpredictable results.
2. **Skill activation is probabilistic.** Even with an orchestration guide skill installed, Claude may or may not reference it in a given session — skill matching depends on the model's interpretation of the task, with no guarantee of activation.

This project lifts Agent Teams orchestration from "probabilistically available" to "deterministically available" through a three-layer mechanism:

| Layer | Mechanism | What it solves |
|-------|-----------|----------------|
| **Environment variable** | `cct` alias injects `CLAUDE_TEAM_MODE=1` | Separates team sessions from normal sessions with zero cross-contamination |
| **SessionStart Hook** | Injects `additionalContext` at session start | Ensures Claude knows it's in team mode before the first turn, proactively loading the skill |
| **CLAUDE.md** | Persistent background instruction | Survives context compaction, preventing long sessions from forgetting team mode |

## What the Skill Provides

The `agent-teams` skill contains:

- **Decision matrix** — when to use team / subagent / single session (prevents over-orchestrating simple tasks)
- **4 orchestration patterns** — Parallel Specialists, Pipeline with Dependencies, Research-then-Implement, Coordinated Multi-File
- **Team sizing and task granularity** — 3-4 teammates sweet spot, 5-6 tasks per teammate, task description standards
- **Common failure modes and recovery** — lead doing implementation work, teammates not marking completion, file conflicts, orphan sessions
- **Reusable prompt templates** — ready-to-use prompts for team creation and task assignment

## How It Works

```
cc  → claude (normal session)
      └─ CLAUDE_TEAM_MODE not set → hook outputs nothing → no interference

cct → CLAUDE_TEAM_MODE=1 claude --teammate-mode tmux
      └─ hook outputs additionalContext → Claude is aware of team mode
      └─ CLAUDE.md provides persistent background → survives compaction
      └─ agent-teams skill loaded on demand → provides orchestration guide
```

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed
- tmux installed
  - macOS: `brew install tmux`
  - Ubuntu/Debian/WSL: `sudo apt install tmux`
  - Fedora: `sudo dnf install tmux`
  - Arch: `sudo pacman -S tmux`
- A terminal that supports tmux

## Install

```bash
chmod +x install.sh
./install.sh
# restart your shell, or:
source ~/.bashrc   # Linux / WSL
source ~/.zshrc    # macOS
```

The installer is idempotent — safe to run multiple times. It merges into existing `settings.json` and `CLAUDE.md` without overwriting.

## File Structure

```
claude-agent-teams-kit/
├── install.sh                      # Idempotent installer
├── shell/
│   └── aliases.sh                  # cc / cct alias definitions
├── claude/
│   ├── settings.json               # Agent Teams feature flag + hook registration
│   ├── CLAUDE.md                   # Agent Teams persistent instruction (appended to existing)
│   ├── hooks/
│   │   └── team-mode-init.sh       # SessionStart hook (conditional activation)
│   └── skills/
│       └── agent-teams/
│           └── SKILL.md            # Orchestration guide (decision matrix, patterns, templates)
└── README.md
```

## Verify

1. **`cc` session**: give a complex task — should NOT propose creating a team unprompted
2. **`cct` session**: give a multi-module task — should proactively suggest Agent Teams and reference the orchestration guide
3. **Skill discovery**: ask "what skills are available" — should list `agent-teams`

## Uninstall

```bash
# Remove aliases (manually delete cc/cct lines from ~/.bashrc or ~/.zshrc)

# Remove Claude config additions
rm ~/.claude/hooks/team-mode-init.sh
rm -rf ~/.claude/skills/agent-teams

# Remove hooks and Agent Teams section from settings.json and CLAUDE.md
# (manually edit these files)
```
