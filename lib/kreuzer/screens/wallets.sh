# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# screens/wallets.sh - wallets with balances, bounds and history sparklines
#
# Depends on : domain/balances.sh (WB), domain/series.sh, viz/*
# Provides   : screen_wallets_load screen_wallets_row screen_wallets_title screen_wallets_viz
#
# WB rows: id, name, balance, lower, upper

screen_wallets_load() {
  TX=(); SELECTABLE=1
  local sk=""
  case $WALSORT in name) sk="2,2f" ;; balance) sk="3,3n" ;; esac
  ROWS_DATA=("${WB[@]}")
  ((${#WB[@]})) || return 0
  if [[ -n $sk ]]; then
    ((WALREV)) && sk+="r"
    mapfile -t ROWS_DATA < <(printf '%s\n' "${WB[@]}" | sort -t$'\t' -k"$sk" -k1,1n)
  elif ((WALREV)); then
    mapfile -t ROWS_DATA < <(printf '%s\n' "${WB[@]}" | tac)
  fi
}

screen_wallets_row() {
  local id nm b lo up bc np b1 l1 u1
  IFS=$'\t' read -r id nm b lo up <<<"$1"
  text_pad "$nm" 18; np=$PAD
  money_format "$b"; text_rpad "$M" 14; b1=$RP
  bc=$C_TXT
  [[ $lo != - ]] && ((b <= lo)) && bc=$C_BAD
  [[ $up != - ]] && ((b >= up)) && bc=$C_OK
  if [[ $lo == - ]]; then l1="-"; else money_format "$lo"; l1=$M; fi; text_rpad "$l1" 12; l1=$RP
  if [[ $up == - ]]; then u1="-"; else money_format "$up"; u1=$M; fi; text_rpad "$u1" 12; u1=$RP
  RR="${C_TXT}$np${RST}${bc}$b1${RST} ${C_DIM}$l1 $u1${RST}"
}

screen_wallets_title() {
  local dir="↑"; ((WALREV)) && dir="↓"
  TL="Wallets - sort: $WALSORT $dir"
  printf -v CH '%-18s%14s %12s %12s' Name Balance Lower Upper
}

screen_wallets_viz() {
  local n=${#ROWS_DATA[@]} r=$VY cap off id nm b lo up d t a
  local -a part
  if ((n == 0)); then viz_section "$r" "Wallets"; viz_line $((r + 1)) "${C_DIM}No wallets yet.${RST}"; return 0; fi
  IFS=$'\t' read -r id nm b lo up <<<"${ROWS_DATA[SEL]}"
  # Bars take what is left after the detail block; scroll so the selection shows.
  cap=$((VH - 14)); ((cap < 3)) && cap=3; ((cap > n)) && cap=$n
  off=0; ((SEL >= cap)) && off=$((SEL - cap + 1))
  part=("${ROWS_DATA[@]:off:cap}")
  viz_section "$r" "Balances"
  block_wallets $((r + 1)) "$cap" "$id" "" part; r=$((r + USED + 2))
  viz_section "$r" "$nm"; r=$((r + 1))
  money_format "$b"; viz_line "$r" "${C_DIM}Balance     ${RST}${C_ACC}$M${RST}"; r=$((r + 1))
  if [[ $lo != - ]]; then
    money_format "$lo"; t=$M; d=$((b - lo)); money_format "${d#-}"
    if ((d > 0)); then viz_line "$r" "${C_DIM}Lower bound ${RST}${C_TXT}$t${RST} ${C_DIM}($M above)${RST}"
    else viz_line "$r" "${C_DIM}Lower bound ${RST}${C_WARN}$t${RST} ${C_DIM}(reached)${RST}"; fi
    r=$((r + 1))
  fi
  if [[ $up != - ]]; then
    money_format "$up"; t=$M; d=$((up - b)); money_format "${d#-}"
    if ((d > 0)); then viz_line "$r" "${C_DIM}Upper bound ${RST}${C_TXT}$t${RST} ${C_DIM}($M to go)${RST}"
    else viz_line "$r" "${C_DIM}Upper bound ${RST}${C_OK}$t${RST} ${C_DIM}(reached)${RST}"; fi
    r=$((r + 1))
  fi
  [[ $lo != - ]] && ((b <= lo)) && { viz_line "$r" "${C_WARN}Warning: at or below the lower bound.${RST}"; r=$((r + 1)); }
  [[ $up != - ]] && ((b >= up)) && { viz_line "$r" "${C_OK}Upper bound reached. Nicely done!${RST}"; r=$((r + 1)); }
  r=$((r + 1))
  if ((r + 3 <= VY + VH)); then
    viz_spark_wallet y "$id" "$MONTH"; viz_section "$r" "Last 12 months (month end)"
    viz_line $((r + 1)) "${C_ACC}$SPK${RST}"
    money_format "$SMIN"; a=$M; money_format "$SMAX"; viz_line $((r + 2)) "${C_DIM}min $a   max $M${RST}"; r=$((r + 4))
  fi
  if ((r + 3 <= VY + VH)); then
    viz_spark_wallet m "$id" "$MONTH"; viz_section "$r" "Daily - $MONTH_LABEL"
    viz_line $((r + 1)) "${C_ACC}$SPK${RST}"
    money_format "$SMIN"; a=$M; money_format "$SMAX"; viz_line $((r + 2)) "${C_DIM}min $a   max $M${RST}"
  fi
}
