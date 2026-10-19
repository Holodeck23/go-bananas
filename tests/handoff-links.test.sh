#!/usr/bin/env bash
# Compatibility entrypoint for the real-Git regression suite.
set -euo pipefail
exec python3 "$(cd "$(dirname "$0")" && pwd)/handoff_links_test.py"
