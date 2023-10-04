#!/bin/bash
cd "$(
  cd "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)/" || exit
set -e

# update or resolve package dependencies
swift package update
rm -rf .build
rm -rf .swiftpm
# generate a .xcodeproj to edit on Xcode
swift package generate-xcodeproj
# open generated .xcodeproj automatically
xed .