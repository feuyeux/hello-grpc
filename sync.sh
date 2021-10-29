#!/usr/bin/env bash
git pull
git submodule update --remote
git add -A && git commit -m "up" && git push
