#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

git add -A && git commit -m "up"
git pull
git submodule update --remote
git push
