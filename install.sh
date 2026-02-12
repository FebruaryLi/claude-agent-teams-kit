#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "=== claude-agent-teams-kit installer ==="
echo ""

# --- 1. Shell aliases ---
SHELL_RC=""
if [ -n "${ZSH_VERSION:-}" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
  SHELL_RC="$HOME/.zshrc"
elif [ -n "${BASH_VERSION:-}" ] || [ "$(basename "$SHELL")" = "bash" ]; then
  SHELL_RC="$HOME/.bashrc"
fi

if [ -n "$SHELL_RC" ]; then
  if grep -q 'alias cct=' "$SHELL_RC" 2>/dev/null; then
    echo "[skip] aliases already exist in $SHELL_RC"
  else
    echo "" >> "$SHELL_RC"
    echo "# Claude Code aliases (added by claude-agent-teams-kit)" >> "$SHELL_RC"
    cat "$SCRIPT_DIR/shell/aliases.sh" >> "$SHELL_RC"
    echo "[done] aliases appended to $SHELL_RC"
  fi
else
  echo "[warn] unknown shell, please manually source shell/aliases.sh"
fi

# --- 2. hooks directory + script ---
mkdir -p "$CLAUDE_DIR/hooks"
cp "$SCRIPT_DIR/claude/hooks/team-mode-init.sh" "$CLAUDE_DIR/hooks/team-mode-init.sh"
chmod +x "$CLAUDE_DIR/hooks/team-mode-init.sh"
echo "[done] hooks/team-mode-init.sh installed"

# --- 3. skills directory ---
mkdir -p "$CLAUDE_DIR/skills/agent-teams"
cp "$SCRIPT_DIR/claude/skills/agent-teams/SKILL.md" "$CLAUDE_DIR/skills/agent-teams/SKILL.md"
echo "[done] skills/agent-teams/SKILL.md installed"

# --- 4. settings.json (merge, not overwrite) ---
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
  HAS_HOOKS="no"
  HAS_TEAMS_ENV="no"
  if command -v jq >/dev/null 2>&1; then
    HAS_HOOKS=$(jq -r 'if .hooks.SessionStart then "yes" else "no" end' "$SETTINGS_FILE" 2>/dev/null || echo "no")
    HAS_TEAMS_ENV=$(jq -r 'if .env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS == "1" then "yes" else "no" end' "$SETTINGS_FILE" 2>/dev/null || echo "no")
  else
    grep -q '"SessionStart"' "$SETTINGS_FILE" 2>/dev/null && HAS_HOOKS="yes"
    grep -q '"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"' "$SETTINGS_FILE" 2>/dev/null && HAS_TEAMS_ENV="yes"
  fi

  if [ "$HAS_HOOKS" = "yes" ] && [ "$HAS_TEAMS_ENV" = "yes" ]; then
    echo "[skip] settings.json already has Agent Teams config"
  else
    if command -v jq >/dev/null 2>&1; then
      INCOMING=$(cat "$SCRIPT_DIR/claude/settings.json")
      jq --argjson incoming "$INCOMING" '
        .env = (.env // {} | . + $incoming.env) |
        .hooks = (.hooks // {} | if .SessionStart then . else . + {SessionStart: $incoming.hooks.SessionStart} end)
      ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    elif command -v python3 >/dev/null 2>&1; then
      python3 -c "
import json
with open('$SETTINGS_FILE') as f:
    existing = json.load(f)
with open('$SCRIPT_DIR/claude/settings.json') as f:
    incoming = json.load(f)
existing.setdefault('env', {})
existing['env'].update(incoming['env'])
if 'hooks' not in existing:
    existing['hooks'] = incoming['hooks']
elif 'SessionStart' not in existing['hooks']:
    existing['hooks']['SessionStart'] = incoming['hooks']['SessionStart']
with open('$SETTINGS_FILE', 'w') as f:
    json.dump(existing, f, indent=2)
    f.write('\n')
"
    else
      echo "[error] jq or python3 is required to merge settings.json"
      echo "        Install jq: sudo apt install jq  OR  brew install jq"
      exit 1
    fi
    echo "[done] settings.json merged (existing config preserved)"
  fi
else
  cp "$SCRIPT_DIR/claude/settings.json" "$SETTINGS_FILE"
  echo "[done] settings.json created"
fi

# --- 5. CLAUDE.md (append Agent Teams section if missing) ---
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
  if grep -q 'Agent Teams' "$CLAUDE_MD" 2>/dev/null; then
    echo "[skip] CLAUDE.md already has Agent Teams section"
  else
    echo "" >> "$CLAUDE_MD"
    cat "$SCRIPT_DIR/claude/CLAUDE.md" >> "$CLAUDE_MD"
    echo "[done] Agent Teams section appended to CLAUDE.md"
  fi
else
  cp "$SCRIPT_DIR/claude/CLAUDE.md" "$CLAUDE_MD"
  echo "[done] CLAUDE.md created"
fi

echo ""
echo "=== Installation complete ==="
echo ""
if [ -n "$SHELL_RC" ]; then
  echo "Restart your shell or run: source $SHELL_RC"
else
  echo "Restart your shell to apply changes."
fi
echo ""
echo "Usage:"
echo "  cc   — single Claude session (no team mode)"
echo "  cct  — Agent Teams session (tmux split panes)"
echo ""
echo "Verify:"
echo "  1. Run 'cc', ask a complex task — should NOT propose teams"
echo "  2. Run 'cct', ask a multi-module task — should suggest Agent Teams"
echo "  3. Ask 'what skills are available' — should list 'agent-teams'"
