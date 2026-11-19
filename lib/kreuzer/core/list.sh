# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# core/list.sh - small list helpers
#
# Provides : list_cycle

# list_cycle VARNAME item... : advance VARNAME to the next item, wrapping around.
# A value that is not in the list wraps to the first item. The underscore names
# keep the nameref from clashing with the caller's variable name.
list_cycle() {
  local -n _v=$1; shift
  local -a _a=("$@"); local _i
  for _i in "${!_a[@]}"; do [[ ${_a[_i]} == "$_v" ]] && break; done
  _v=${_a[(_i + 1) % ${#_a[@]}]}
}
