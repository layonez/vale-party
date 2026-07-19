#!/usr/bin/env sh
set -eu

./scripts/format.sh

if ! git diff --quiet -- . ':!dist' ':!node_modules'; then
  echo "Formatting changed tracked files. Review and stage the formatting changes, then rerun checks." >&2
  git diff --stat -- . ':!dist' ':!node_modules' >&2
  exit 1
fi

./scripts/test.sh
./scripts/lint.sh
./scripts/build-love.sh
./scripts/build-web.sh
./scripts/build-stock.sh
