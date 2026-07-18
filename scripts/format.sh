#!/usr/bin/env sh
set -eu
if command -v stylua >/dev/null 2>&1; then stylua .; else echo "stylua not installed; format check skipped"; fi
