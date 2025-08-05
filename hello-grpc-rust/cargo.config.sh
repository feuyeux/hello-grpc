#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
cp cargo.config.toml "$HOME"/.cargo/config.toml
