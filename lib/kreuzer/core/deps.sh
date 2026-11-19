# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# core/deps.sh - startup dependency check
#
# Depends on : log_die
# Provides   : deps_check

# Checks every external tool up front, so a missing one gives one clear message
# instead of a failure in the middle of a redraw.
deps_check() {
  local t missing=()
  for t in awk sort date flock mktemp find stty fold tar cut grep tac; do
    command -v "$t" >/dev/null 2>&1 || missing+=("$t")
  done
  if ((${#missing[@]})); then
    echo "$APP: missing tools: ${missing[*]}" >&2
    echo "Arch/CachyOS: sudo pacman -S gawk coreutils util-linux findutils tar grep" >&2
    exit 1
  fi
  # mawk lacks the mktime and atan2 behaviour the pies rely on.
  awk --version 2>&1 | grep -q 'GNU Awk' || log_die "GNU awk is required: sudo pacman -S gawk"
}
