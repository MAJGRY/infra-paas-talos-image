#!/usr/bin/env bash
# No em dash (U+2014) in the tracked text files (WS14-T299, RULES.md section 4). Prints every match
# with its file and line and exits 1 when one exists. `git grep -I` reads tracked files only, so
# binary files and anything untracked are never scanned.
#
#   hack/check-em-dash.sh            check this repository
#   hack/check-em-dash.sh --root DIR check DIR instead, a git repository (the CI self-test uses it)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
if [[ "${1:-}" == "--root" ]]; then
  ROOT="${2:?--root needs a directory}"
elif [[ $# -ne 0 ]]; then
  echo "usage: hack/check-em-dash.sh [--root DIR]" >&2
  exit 2
fi

# git grep: 0 a match, 1 none, 2 an error (not a git repository).
set +e
matches="$(git -C "${ROOT}" grep -n -I $'\xe2\x80\x94' -- .)"
status=$?
set -e
if ((status == 2)); then
  echo "FAIL [em-dash] git grep failed in ${ROOT}" >&2
  exit 1
fi
if ((status == 0)); then
  printf '%s\n' "${matches}" >&2
  echo "FAIL [em-dash] tracked files contain U+2014 (em dash): listed above" >&2
  exit 1
fi
echo "em-dash: no U+2014 in the tracked files"
