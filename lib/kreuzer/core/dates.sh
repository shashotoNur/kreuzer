# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# core/dates.sh - date input and display
#
# Depends on : date(1) from GNU coreutils
# Provides   : parse_date dmy
# Out-vars   : PD DMY
#
# Dates are shown and typed as DD/MM/YYYY but stored as YYYY-MM-DD, so plain
# string comparison and sort(1) order them chronologically.

# Accepts DD/MM or DD/MM/YYYY (year defaults to the current one). The round trip
# through `date -d` is the calendar check: it rejects 31/02 and handles leap years
# without reimplementing them here.
parse_date() {
  local s=$1 d m y
  [[ $s =~ ^([0-9]{1,2})/([0-9]{1,2})(/([0-9]{4}))?$ ]] || return 1
  d=$((10#${BASH_REMATCH[1]})); m=$((10#${BASH_REMATCH[2]})); y=${BASH_REMATCH[4]:-$(date +%Y)}
  printf -v PD '%04d-%02d-%02d' $((10#$y)) "$m" "$d"
  [[ $(date -d "$PD" +%F 2>/dev/null) == "$PD" ]]
}

# ISO date to display form, by slicing only (no fork).
dmy() { DMY="${1:8:2}/${1:5:2}/${1:0:4}"; }
