# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# domain/alerts.sh - warnings and celebrations after a change
#
# Depends on : balances_load totals_load_categories totals_month budget_for_month totals_quota_sum money_format
# Provides   : alerts_check alerts_quota_budget
# Globals    : ALERTS
#
# ALERTS entries are "W:text" (warning) or "G:text" (good news). Alerts only
# inform: data entry is never blocked. Showing them is the UI's job
# (ui/widgets.sh widget_alerts).

# Checks wallet bounds, the category quota and the monthly budget as they stand
# after a write. Pass an empty wallet or category to skip that check; KIND other
# than E skips the expense checks.
alerts_check() { # month category wallet1 wallet2 kind
  local m=$1 c=$2 l id kd nm sp q w b lo up
  ALERTS=(); balances_load
  for w in "$3" "$4"; do
    [[ -n $w ]] || continue
    for l in "${WB[@]}"; do
      IFS=$'\t' read -r id nm b lo up <<<"$l"
      [[ $id == "$w" ]] || continue
      money_format "$b"
      if [[ $lo != - ]] && ((b <= lo)); then ALERTS+=("W:Warning: $nm is at or below its lower bound (balance $M).")
      elif [[ $up != - ]] && ((b >= up)); then ALERTS+=("G:Congratulations! $nm reached its upper bound (balance $M).")
      fi
    done
  done
  [[ $5 == E ]] || return 0
  totals_load_categories "$m"
  for l in "${CS[@]}"; do
    IFS=$'\t' read -r id kd nm sp q <<<"$l"
    if [[ $id == "$c" ]] && ((q > 0 && sp > q)); then money_format $((sp - q)); ALERTS+=("W:$nm is over its quota by $M."); fi
  done
  totals_month "$m"; budget_for_month "$m"
  if ((BUD > 0 && EXP > BUD)); then money_format $((EXP - BUD)); ALERTS+=("W:The monthly budget is exceeded by $M."); fi
}

# The quota sum may legitimately exceed the budget, but the user is told.
alerts_quota_budget() { # month
  local a
  totals_load_categories "$1"; totals_quota_sum CS; budget_for_month "$1"
  if ((BUD > 0 && QS > BUD)); then
    money_format "$QS"; a=$M; money_format "$BUD"
    ALERTS+=("W:Quotas total $a, above the monthly budget of $M.")
  fi
}
