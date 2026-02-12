#!/bin/bash
if [ "${CLAUDE_TEAM_MODE:-}" = "1" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"AGENT TEAMS MODE: This session runs with --teammate-mode tmux. For complex tasks involving parallel work, multi-file changes, or competing investigations, proactively use the agent-teams skill to orchestrate teammates. For simple single-file or sequential tasks, a single session is still appropriate."}}'
fi
exit 0
