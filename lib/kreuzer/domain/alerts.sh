# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# domain/alerts.sh - warnings and celebrations after a change
#
# Depends on : load_wb load_cs month_totals budget_for quota_sum fm
# Provides   : alert_state qb_alert
# Globals    : ALERTS
#
# ALERTS entries are "W:text" (warning) or "G:text" (good news). Alerts only
# inform: data entry is never blocked. Showing them is the UI's job
# (ui/widgets.sh show_alerts).

# Checks wallet bounds, the category quota and the monthly budget as they stand
# after a write. Pass an empty wallet or category to skip that check; KIND other
# than E skips the expense checks.
alert_state() { # month category wallet1 wallet2 kind
  local m=$1 c=$2 l id kd nm sp q w b lo up
  ALERTS=(); load_wb
  for w in "$3" "$4"; do
    [[ -n $w ]] || continue
    for l in "${WB[@]}"; do
      IFS=$'\t' read -r id nm b lo up <<<"$l"
      [[ $id == "$w" ]] || continue
      fm "$b"
      if [[ $lo != - ]] && ((b <= lo)); then ALERTS+=("W:Warning: $nm is at or below its lower bound (balance $M).")
      elif [[ $up != - ]] && ((b >= up)); then ALERTS+=("G:Congratulations! $nm reached its upper bound (balance $M).")
      fi
    done
  done
  [[ $5 == E ]] || return 0
  load_cs "$m"
  for l in "${CS[@]}"; do
    IFS=$'\t' read -r id kd nm sp q <<<"$l"
    if [[ $id == "$c" ]] && ((q > 0 && sp > q)); then fm $((sp - q)); ALERTS+=("W:$nm is over its quota by $M."); fi
  done
  month_totals "$m"; budget_for "$m"
  if ((BUD > 0 && EXP > BUD)); then fm $((EXP - BUD)); ALERTS+=("W:The monthly budget is exceeded by $M."); fi
}

# The quota sum may legitimately exceed the budget, but the user is told.
qb_alert() { # month
  local a
  load_cs "$1"; quota_sum CS; budget_for "$1"
  if ((BUD > 0 && QS > BUD)); then
    fm "$QS"; a=$M; fm "$BUD"
    ALERTS+=("W:Quotas total $a, above the monthly budget of $M.")
  fi
}
