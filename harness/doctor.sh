#!/usr/bin/env bash
# Checks the tools the demo needs, in a few seconds.
ok=1
check() { if command -v "$1" >/dev/null; then echo "ok    $1 $({ $1 --version || $1 -V; } 2>/dev/null | head -n 1)"; else echo "MISS  $1: $2"; [ "$3" = need ] && ok=0; fi; }
check git    "install git" need
check bun    "curl -fsSL https://bun.sh/install | bash" need
check claude "npm install -g @anthropic-ai/claude-code" need
check tmux   "optional, only for 'bash harness/tmux.sh' (brew install tmux)" optional
git rev-parse --verify -q main >/dev/null || { echo "MISS  a local main branch: run git checkout main"; ok=0; }
[ $ok = 1 ] && echo "Ready. Try: bash harness/try.sh 01" || exit 1
