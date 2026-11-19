# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# screens/wallets.sh - wallets with balances, bounds and history sparklines
#
# Depends on : domain/balances.sh (WB), domain/series.sh, viz/*
# Provides   : load_wallets row_wallets title_wallets viz_wallets
#
# WB rows: id, name, balance, lower, upper

load_wallets() {
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

row_wallets() {
  local id nm b lo up bc np b1 l1 u1
  IFS=$'\t' read -r id nm b lo up <<<"$1"
  pad "$nm" 18; np=$PAD
  fm "$b"; rpad "$M" 14; b1=$RP
  bc=$C_TXT
  [[ $lo != - ]] && ((b <= lo)) && bc=$C_BAD
  [[ $up != - ]] && ((b >= up)) && bc=$C_OK
  if [[ $lo == - ]]; then l1="-"; else fm "$lo"; l1=$M; fi; rpad "$l1" 12; l1=$RP
  if [[ $up == - ]]; then u1="-"; else fm "$up"; u1=$M; fi; rpad "$u1" 12; u1=$RP
  RR="${C_TXT}$np${RST}${bc}$b1${RST} ${C_DIM}$l1 $u1${RST}"
}

title_wallets() {
  local dir="↑"; ((WALREV)) && dir="↓"
  TL="Wallets - sort: $WALSORT $dir"
  printf -v CH '%-18s%14s %12s %12s' Name Balance Lower Upper
}

viz_wallets() {
  local n=${#ROWS_DATA[@]} r=$VY cap off id nm b lo up d t a
  local -a part
  if ((n == 0)); then sec "$r" "Wallets"; vp $((r + 1)) "${C_DIM}No wallets yet.${RST}"; return 0; fi
  IFS=$'\t' read -r id nm b lo up <<<"${ROWS_DATA[SEL]}"
  # Bars take what is left after the detail block; scroll so the selection shows.
  cap=$((VH - 14)); ((cap < 3)) && cap=3; ((cap > n)) && cap=$n
  off=0; ((SEL >= cap)) && off=$((SEL - cap + 1))
  part=("${ROWS_DATA[@]:off:cap}")
  sec "$r" "Balances"
  wallet_bars $((r + 1)) "$cap" "$id" "" part; r=$((r + USED + 2))
  sec "$r" "$nm"; r=$((r + 1))
  fm "$b"; vp "$r" "${C_DIM}Balance     ${RST}${C_ACC}$M${RST}"; r=$((r + 1))
  if [[ $lo != - ]]; then
    fm "$lo"; t=$M; d=$((b - lo)); fm "${d#-}"
    if ((d > 0)); then vp "$r" "${C_DIM}Lower bound ${RST}${C_TXT}$t${RST} ${C_DIM}($M above)${RST}"
    else vp "$r" "${C_DIM}Lower bound ${RST}${C_WARN}$t${RST} ${C_DIM}(reached)${RST}"; fi
    r=$((r + 1))
  fi
  if [[ $up != - ]]; then
    fm "$up"; t=$M; d=$((up - b)); fm "${d#-}"
    if ((d > 0)); then vp "$r" "${C_DIM}Upper bound ${RST}${C_TXT}$t${RST} ${C_DIM}($M to go)${RST}"
    else vp "$r" "${C_DIM}Upper bound ${RST}${C_OK}$t${RST} ${C_DIM}(reached)${RST}"; fi
    r=$((r + 1))
  fi
  [[ $lo != - ]] && ((b <= lo)) && { vp "$r" "${C_WARN}Warning: at or below the lower bound.${RST}"; r=$((r + 1)); }
  [[ $up != - ]] && ((b >= up)) && { vp "$r" "${C_OK}Upper bound reached. Nicely done!${RST}"; r=$((r + 1)); }
  r=$((r + 1))
  if ((r + 3 <= VY + VH)); then
    spark_w y "$id" "$MONTH"; sec "$r" "Last 12 months (month end)"
    vp $((r + 1)) "${C_ACC}$SPK${RST}"
    fm "$SMIN"; a=$M; fm "$SMAX"; vp $((r + 2)) "${C_DIM}min $a   max $M${RST}"; r=$((r + 4))
  fi
  if ((r + 3 <= VY + VH)); then
    spark_w m "$id" "$MONTH"; sec "$r" "Daily - $MONTH_LABEL"
    vp $((r + 1)) "${C_ACC}$SPK${RST}"
    fm "$SMIN"; a=$M; fm "$SMAX"; vp $((r + 2)) "${C_DIM}min $a   max $M${RST}"
  fi
}
