# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# core/deps.sh - startup dependency check
#
# Depends on : die
# Provides   : check_deps

# Checks every external tool up front so a missing one produces one clear message
# instead of a failure in the middle of a redraw.
check_deps() {
  local t missing=()
  for t in awk sort date flock mktemp find stty fold tar cut grep tac; do
    command -v "$t" >/dev/null 2>&1 || missing+=("$t")
  done
  if ((${#missing[@]})); then
    echo "$APP: missing tools: ${missing[*]}" >&2
    echo "Arch/CachyOS: sudo pacman -S gawk coreutils util-linux findutils tar grep" >&2
    exit 1
  fi
  # mawk (Debian's default) lacks mktime/strftime/atan2 behavior the pies rely on.
  awk --version 2>&1 | grep -q 'GNU Awk' || die "GNU awk is required: sudo pacman -S gawk"
}
