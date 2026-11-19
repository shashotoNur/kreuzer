# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# forms/budget.sh - set the monthly budget
#
# Depends on : ui/form.sh, data/budget.sh, viz/blocks.sh, domain/alerts.sh
# Provides   : budget_form budget_preview
#
# The value applies from the chosen month on; earlier months keep theirs, so
# their unused/overused figures stay accurate.

budget_preview() {
  local m b=0
  printf -v m '%(%Y-%m)T' -1; PVL=()
  block_quota_sum "$m"; money_format "$QS"
  PVL+=("${C_DIM}Category quotas total $M for $m.${RST}")
  if [[ -n ${FV[0]} ]] && money_parse "${FV[0]}"; then b=$PM; fi
  ((b > 0 && QS > b)) && PVL+=("${C_WARN}The quotas exceed this budget.${RST}")
  return 0
}

budget_form() {
  local m cur vb="" newb bm
  printf -v m '%(%Y-%m)T' -1; budget_for_month "$m"; cur=$BUD
  if ((cur > 0)); then money_plain "$cur"; vb=${PL/./$DEC}; fi
  form_begin "Monthly budget" budget_preview "" ""
  form_field Budget omoney "$vb" "Total mandatory expense budget. Empty removes it."
  form_field "From" date "01/${m:5:2}/${m:0:4}" "Applies from this month on. Earlier months keep their value."
  if form_run; then
    newb=0; if [[ -n ${FV[0]} ]]; then money_parse "${FV[0]}"; newb=$PM; fi
    date_parse "${FV[1]}"; bm=${PD:0:7}
    if ((cur > 0 && newb != cur)) && ! widget_confirm "Changing the budget is discouraged: it blurs month comparisons. Change anyway?"; then
      canvas_flash "$C_WARN" "Budget left unchanged."; refresh; return 0
    fi
    budget_set_month "$bm" "$newb"
    ALERTS=(); alerts_quota_budget "$bm"
    canvas_flash "$C_OK" "Saved."; refresh; widget_alerts
  else draw; fi
}
