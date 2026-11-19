# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# viz/entry.sh - live charts shown beside the entry forms
#
# Depends on : viz/blocks.sh, viz/pie.sh, domain/*, data/transactions.sh, balances_get
# Provides   : preview_load preview_highlight_category preview_project viz_entry_income viz_entry_expense
#              viz_entry_transfer
# Globals    : ENT_*
#
# Contract with forms/: the form's preview function sets ENT_MONTH (month of the
# date field), ENT_AMT (pending change in cents, 0 when empty or invalid),
# ENT_CAT (selected category id) and, for transfers, ENT_WAL and ENT_WAL2. The
# charts below read those and show the state as it would be after saving.

ENT_MONTH=""; ENT_CAT=""; ENT_WAL=""; ENT_WAL2=""; ENT_AMT=0
ENT_KEY=""; ENT_TX=(); ENT_CS=(); ENT_INC=0; ENT_EXP=0; ENT_BUD=0

# Loads the month shown by the form into ENT_* without touching the arrays of the
# screen underneath, which must be unchanged when the form closes. Reloads only
# when the month or the data version changes, so typing is cheap.
preview_load() {
  local m=${ENT_MONTH:-$MONTH} key f
  key="$m|$DVER"
  [[ $key == "$ENT_KEY" ]] && return 0
  local -a kTX=("${TX[@]}") kCS=("${CS[@]}")
  local kI=$INC kE=$EXP kB=$BUD
  f="$DATA/$m.tsv"; tx_filter_clear
  if [[ -f $f ]]; then tx_load "$f"; else TX=(); fi
  ENT_TX=("${TX[@]}")
  totals_load_categories "$m"; ENT_CS=("${CS[@]}")
  totals_month "$m"; ENT_INC=$INC; ENT_EXP=$EXP
  budget_for_month "$m"; ENT_BUD=$BUD
  TX=("${kTX[@]}"); CS=("${kCS[@]}"); INC=$kI; EXP=$kE; BUD=$kB
  ENT_KEY=$key
}

# Highlights the selected category in the pie legend.
preview_highlight_category() {
  local l id kd nm sp q
  LEG_HL=""; [[ -n $ENT_CAT ]] || return 0
  for l in "${ENT_CS[@]}"; do
    IFS=$'\t' read -r id kd nm sp q <<<"$l"
    [[ $id == "$ENT_CAT" ]] && { LEG_HL=$nm; return 0; }
  done
}

viz_entry_income() {
  local r=$VY each=$((VH - 5)) ttl="This month"
  preview_load; preview_highlight_category
  ((each > 14)) && each=14
  pie_aggregate tx I ENT_TX; pie_slices
  if pie_panel "$r" "$VX" "$VW" "$each" "Income, ${ENT_MONTH:-$MONTH}" "+" "$C_INC"; then r=$((r + USED)); fi
  ((ENT_AMT > 0)) && ttl="This month with this entry"
  block_month "$r" $((ENT_INC + ENT_AMT)) "$ENT_EXP" "$ttl"
}

viz_entry_expense() {
  local r=$VY each bh=4 qs ex ttl="Monthly budget"
  preview_load; preview_highlight_category
  ex=$((ENT_EXP + ENT_AMT)); totals_quota_sum ENT_CS; qs=$QS
  ((ENT_BUD > 0 && qs > ENT_BUD)) && bh=5
  each=$(((VH - bh - 4) * 45 / 100)); ((each < 7)) && each=7; ((each > 14)) && each=14
  pie_aggregate tx E ENT_TX; pie_slices
  if pie_panel "$r" "$VX" "$VW" "$each" "Expenses, ${ENT_MONTH:-$MONTH}" "-" "$C_EXP"; then r=$((r + USED)); fi
  ((ENT_AMT > 0)) && ttl="Budget after this entry"
  block_budget "$r" "$ex" "$ENT_BUD" "$qs" "$ttl"; r=$((r + USED + 1))
  block_quotas "$r" $((VY + VH - r)) ENT_CS "$ENT_CAT" "$ENT_AMT" "Quota cli_usage"
}

# preview_project ROW WALLET_ID DELTA : one line with a wallet's balance before and after.
preview_project() {
  local nb a b col msg=""
  USED=0; [[ -n $2 ]] && balances_get "$2" || return 0
  nb=$((WBB + $3)); money_format "$WBB"; a=$M; money_format "$nb"; b=$M; col=$C_TXT
  if [[ $WBL != - ]] && ((nb <= WBL)); then col=$C_WARN; msg="  below lower bound"; fi
  if [[ $WBU != - ]] && ((nb >= WBU)); then col=$C_OK; msg="  upper bound reached"; fi
  viz_line "$1" "${C_DIM}$WBN${RST}  $a → ${col}$b${RST}${C_DIM}$msg${RST}"
  USED=1
}

viz_entry_transfer() {
  local r=$VY cap=$((VH - 9))
  ((cap < 2)) && cap=2
  viz_section "$r" "Wallet balances"
  block_wallets $((r + 1)) "$cap" "$ENT_WAL" "$ENT_WAL2" WB "-" "+"; r=$((r + USED + 2))
  viz_section "$r" "After this transfer"; r=$((r + 1))
  preview_project "$r" "$ENT_WAL" $((-ENT_AMT)); r=$((r + USED))
  preview_project "$r" "$ENT_WAL2" "$ENT_AMT"
}
