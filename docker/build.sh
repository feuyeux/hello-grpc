#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

langs=(cpp rust java go csharp python nodejs dart kotlin swift php ts)
langs=(cpp php)
for lang in "${langs[@]}"; do
  sh "build_$lang.sh"
done
