#!/usr/bin/env bash
# Push main to GitHub (origin) and Gitea (gitea) remotes.
set -euo pipefail
BRANCH="${1:-main}"
cd "$(dirname "$0")/.."
git push -u origin "$BRANCH"
git push -u gitea "$BRANCH"
echo "Pushed $BRANCH → origin (GitHub) + gitea (gitea.iykyka.com/oh/iykyka)"
