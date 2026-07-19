#!/usr/bin/env sh
set -eu

git config core.hooksPath scripts/hooks
echo "Git hooks installed from scripts/hooks."
