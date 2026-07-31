#!/usr/bin/env bash
# Push a branch to GitHub (origin) and Gitea iykyka (gitea) remotes.
# Master policy: land work on main, then run: ./scripts/push-both.sh main
# See AGENTS.md "Git remotes & branch policy".
set -euo pipefail
BRANCH="${1:-main}"
cd "$(dirname "$0")/.."
git push -u origin "$BRANCH"
git push -u gitea "$BRANCH"
echo "Pushed $BRANCH → origin (GitHub) + gitea (gitea.iykyka.com/oh/iykyka)"
