# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# core/list.sh - small list helpers
#
# Depends on : nothing
# Provides   : cycle

# cycle VARNAME item...   advance VARNAME to the next item, wrapping around.
# Uses a nameref so the caller's variable is updated in place; the underscore
# names avoid colliding with a caller variable that happens to be called "v".
# If the current value is not in the list, the loop ends past the last index and
# the modulo wraps to the first item.
cycle() {
  local -n _v=$1; shift
  local -a _a=("$@"); local _i
  for _i in "${!_a[@]}"; do [[ ${_a[_i]} == "$_v" ]] && break; done
  _v=${_a[(_i + 1) % ${#_a[@]}]}
}
