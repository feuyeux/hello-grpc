#!/bin/bash
# ──────────────────────────────────────────────────────────────────────
# Shared pre-flight check: ensure the PHP gRPC C-extension is loaded.
#
# Usage (source from other scripts):
#   source "$(dirname "$0")/check_grpc_ext.sh"
#   check_grpc_extension || exit 1
#
# After check_grpc_extension succeeds, the variable GRPC_EXT_FLAG is set.
# Pass it to the php command:
#   php $GRPC_EXT_FLAG hello_server.php
# ──────────────────────────────────────────────────────────────────────

_info()  { echo "[INFO]  $*"; }
_warn()  { echo "[WARN]  $*" >&2; }
_error() { echo "[ERROR] $*" >&2; }

_detect_os() {
  case "$(uname -s)" in
    Darwin*) echo "darwin"  ;;
    Linux*)  echo "linux"   ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *)       echo "unknown" ;;
  esac
}

_is_grpc_loaded() {
  php -m 2>/dev/null | grep -qi '^grpc$'
}

# Locate a grpc shared-object compatible with the running PHP API version.
_find_compatible_grpc_so() {
  local api_version ext_name
  api_version="$(php -r 'echo PHP_API_VERSION;' 2>/dev/null)"
  ext_name="$(php -r 'echo PHP_SHLIB_SUFFIX;' 2>/dev/null)"
  [ -z "$ext_name" ] && ext_name="so"
  [ "$ext_name" = "dll" ] && ext_name="dll"

  local os
  os="$(_detect_os)"
  local -a search_roots
  case "$os" in
    darwin)
      search_roots=(
        "/opt/homebrew/lib/php/pecl"
        "/usr/local/lib/php/pecl"
      )
      ;;
    linux)
      search_roots=(
        "/usr/lib/php"
        "/usr/local/lib/php/pecl"
        "/usr/lib64/php"
      )
      ;;
    windows)
      search_roots=("$(php -r 'echo PHP_EXTENSION_DIR;' 2>/dev/null)")
      ;;
    *)
      search_roots=("$(php -r 'echo PHP_EXTENSION_DIR;' 2>/dev/null)")
      ;;
  esac

  # Always check the runtime extension dir first
  local rt_dir
  rt_dir="$(php -r 'echo PHP_EXTENSION_DIR;' 2>/dev/null)"
  search_roots=("$rt_dir" "${search_roots[@]}")

  for root in "${search_roots[@]}"; do
    [ -z "$root" ] && continue
    if [ -f "$root/grpc.$ext_name" ]; then
      echo "$root/grpc.$ext_name"; return 0
    fi
    if [ -f "$root/$api_version/grpc.$ext_name" ]; then
      echo "$root/$api_version/grpc.$ext_name"; return 0
    fi
  done
  return 1
}

# Pre-flight: ensure the gRPC C-extension is available.
# Strategy:
#   1. Already loaded              → proceed.
#   2. Compatible .so found on disk → inject via -d extension=…
#   3. pecl available (non-Windows) → try pecl install grpc
#   4. Otherwise                   → print OS-specific hint and return 1.
GRPC_EXT_FLAG=""
check_grpc_extension() {
  if _is_grpc_loaded; then
    return 0
  fi

  _warn "gRPC C-extension is NOT loaded in the current PHP runtime."

  # 2. Look for a compatible binary already on disk
  local found_so
  if found_so="$(_find_compatible_grpc_so)"; then
    _info "Found compatible gRPC extension: $found_so"
    GRPC_EXT_FLAG="-d extension=$found_so"
    return 0
  fi

  # 3. Try pecl install (skip on Windows)
  if command -v pecl >/dev/null 2>&1; then
    local os
    os="$(_detect_os)"
    if [ "$os" = "windows" ]; then
      _warn "pecl install is not supported on Windows."
      _warn "Download the pre-built grpc.dll from https://pecl.php.net/package/grpc"
      _warn "and place it in: $(php -r 'echo PHP_EXTENSION_DIR;' 2>/dev/null)"
      return 1
    fi
    _info "Attempting to install gRPC extension via pecl …"
    if pecl install grpc; then
      _info "pecl install grpc succeeded."
      if _is_grpc_loaded; then
        return 0
      fi
      if found_so="$(_find_compatible_grpc_so)"; then
        GRPC_EXT_FLAG="-d extension=$found_so"
        return 0
      fi
    else
      _warn "pecl install grpc failed or timed out."
    fi
  fi

  # 4. Give OS-specific guidance
  local os
  os="$(_detect_os)"
  _error "The PHP gRPC C-extension is required but not available."
  echo ""
  case "$os" in
    darwin)
      echo "  macOS — install or rebuild via Homebrew PECL:"
      echo "    pecl install grpc"
      echo "  Then add 'extension=grpc.so' to:"
      echo "    $(php --ini 2>/dev/null | grep 'Loaded Configuration' | awk '{print $NF}')"
      ;;
    linux)
      echo "  Debian / Ubuntu:"
      echo "    sudo apt-get install -y php-grpc"
      echo "    # or: sudo pecl install grpc && echo 'extension=grpc.so' | sudo tee /etc/php/*/mods-available/grpc.ini"
      echo ""
      echo "  Alpine (Docker):"
      echo "    apk add --no-cache php-grpc"
      ;;
    windows)
      echo "  Windows:"
      echo "    1. Download grpc.dll from https://pecl.php.net/package/grpc"
      echo "    2. Place it in: $(php -r 'echo PHP_EXTENSION_DIR;' 2>/dev/null)"
      echo "    3. Add 'extension=grpc.dll' to php.ini"
      ;;
    *)
      echo "  Install the gRPC extension for your platform:"
      echo "    pecl install grpc"
      ;;
  esac
  echo ""
  return 1
}
