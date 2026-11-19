# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# core/dates.sh - date input and display
#
# Depends on : date(1) from GNU coreutils
# Provides   : date_parse date_display
# Out-vars   : PD DMY
#
# Dates are typed and shown as DD/MM/YYYY but stored as YYYY-MM-DD, so plain
# string comparison and sort(1) order them chronologically.

# Accepts DD/MM or DD/MM/YYYY (the year defaults to the current one). The round
# trip through `date -d` is the calendar check: it rejects 31/02 and knows leap
# years without reimplementing them.
date_parse() {
  local s=$1 d m y
  [[ $s =~ ^([0-9]{1,2})/([0-9]{1,2})(/([0-9]{4}))?$ ]] || return 1
  d=$((10#${BASH_REMATCH[1]})); m=$((10#${BASH_REMATCH[2]})); y=${BASH_REMATCH[4]:-$(date +%Y)}
  printf -v PD '%04d-%02d-%02d' $((10#$y)) "$m" "$d"
  [[ $(date -d "$PD" +%F 2>/dev/null) == "$PD" ]]
}

# ISO date to display form, by slicing only (no fork).
date_display() { DMY="${1:8:2}/${1:5:2}/${1:0:4}"; }
