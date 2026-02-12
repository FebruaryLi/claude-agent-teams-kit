# Claude Code aliases
# cc  — single session (default)
# cct — Agent Teams session with tmux split panes
alias cc="claude --dangerously-skip-permissions"
alias cct="CLAUDE_TEAM_MODE=1 claude --dangerously-skip-permissions --teammate-mode tmux"
