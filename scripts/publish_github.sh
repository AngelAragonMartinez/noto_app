#!/usr/bin/env bash
# Prereq: gh auth login
set -euo pipefail
cd "$(dirname "$0")/.."

chmod +x scripts/install.sh

git init -b main 2>/dev/null || true
git add -A
git commit -m "Initial release: Noto for Linux" || true
gh repo create noto --public --source=. --remote=origin --push \
  --description "Local encrypted notes for Linux"
