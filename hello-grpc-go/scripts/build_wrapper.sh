#!/usr/bin/env bash
# DEPRECATED: This script is deprecated and will be removed in a future version.
# Please use the consolidated build script instead:
#   scripts/build/build-language.sh --language go
#
# This wrapper is provided for backward compatibility.

echo "⚠️  WARNING: This script is deprecated!"
echo "Please use: scripts/build/build-language.sh --language go"
echo ""
echo "Redirecting to consolidated script..."
echo ""

# Get the repository root
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Execute the consolidated script
exec "${REPO_ROOT}/scripts/build/build-language.sh" --language go "$@"
