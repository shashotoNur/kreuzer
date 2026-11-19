# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# viz/blocks.sh - reusable chart blocks shared by several screens
#
# Depends on : viz/bars.sh, viz/pie.sh, domain/*, core/money, core/text
# Provides   : qsum_month bud_c budget_block month_block wallet_bars quota_lines viz_pair
# Out-vars   : USED (rows consumed by the last block), QS BUD
# Globals    : QSC BDC
#
# Each block takes its first row and returns the rows it used in USED, so the
# caller can stack blocks vertically without knowing their heights in advance.

declare -gA QSC=() BDC=()

# Quota total for any month without disturbing the CS array the screen is
# showing, which is why it saves and restores it.
qsum_month() { # month -> QS
  local key="$1|$DVER"
  if [[ -z ${QSC["$key"]+x} ]]; then
    local -a keep=("${CS[@]}")
    load_cs "$1"; quota_sum CS; CS=("${keep[@]}")
    QSC["$key"]=$QS
  fi
  QS=${QSC["$key"]}
}

bud_c() { # month -> BUD (cached budget_for)
  local key="$1|$DVER"
  if [[ -z ${BDC["$key"]+x} ]]; then budget_for "$1"; BDC["$key"]=$BUD; fi
  BUD=${BDC["$key"]}
}

# budget_block ROW SPENT BUDGET QUOTASUM [TITLE]
budget_block() {
  local r=$1 ex=$2 bu=$3 qs=${4:-0} ttl=${5:-Monthly budget} bw pc pcs col sp bd
  sec "$r" "$ttl"; USED=1
  if ((bu <= 0)); then vp $((r + 1)) "${C_DIM}Not set. Use the Budget screen.${RST}"; USED=2; return 0; fi
  bw=$((VW - 6)); ((bw < 8)) && bw=8
  mkbar "$ex" "$bu" "$bw"
  pc=$((ex * 100 / bu)); printf -v pcs '%3d%%' "$pc"
  col=$C_OK; ((pc >= 80)) && col=$C_WARN; ((pc > 100)) && col=$C_BAD
  vp $((r + 1)) "$BAR ${col}$pcs${RST}"
  fm "$ex"; sp=$M; fm "$bu"; bd=$M
  vp $((r + 2)) "${C_DIM}Spent${RST} ${C_TXT}$sp${RST} ${C_DIM}of${RST} ${C_TXT}$bd${RST}"
  if ((ex <= bu)); then fm $((bu - ex)); vp $((r + 3)) "${C_DIM}Unused${RST} ${C_OK}$M${RST}"
  else fm $((ex - bu)); vp $((r + 3)) "${C_DIM}Over by${RST} ${C_BAD}$M${RST}"; fi
  USED=4
  if ((qs > bu)); then fm "$qs"; vp $((r + 4)) "${C_WARN}Quotas total $M, above the budget${RST}"; USED=5; fi
}

# month_block ROW INCOME EXPENSES [TITLE]
month_block() {
  local r=$1 i=$2 e=$3 ttl=${4:-This month} nc=$C_INC sg=""
  sec "$r" "$ttl"
  fm "$i"; vp $((r + 1)) "${C_DIM}Income   ${RST}${C_INC}+$M${RST}"
  fm "$e"; vp $((r + 2)) "${C_DIM}Expenses ${RST}${C_EXP}-$M${RST}"
  ((i < e)) && nc=$C_EXP
  ((i >= e)) && sg=+
  fm $((i - e)); vp $((r + 3)) "${C_DIM}Net      ${RST}${nc}$sg$M${RST}"
  USED=4
}

# wallet_bars ROW MAXROWS [HL1] [HL2] [ARRAY=WB] [MARK1] [MARK2]
# HL1 and HL2 are wallet ids to mark (for example source and destination of a
# transfer). The array is taken by name so a screen can pass a scrolled slice.
wallet_bars() {
  local r=$1 mx=$2 h1=${3:-} h2=${4:-} m1=${6:-›} m2=${7:-+} i n bw id nm b lo up mk nc
  local -n _w=${5:-WB}
  n=${#_w[@]}; USED=0; ((n > 0)) || return 0
  bw=$((VW - 25)); ((bw < 6)) && bw=6
  for ((i = 0; i < n && i < mx; i++)); do
    IFS=$'\t' read -r id nm b lo up <<<"${_w[i]}"
    mk=" "; nc=$C_TXT
    if [[ -n $h1 && $id == "$h1" ]]; then mk="${C_ACC}$m1${RST}"; nc=$BOLD$C_TXT
    elif [[ -n $h2 && $id == "$h2" ]]; then mk="${C_ACC}$m2${RST}"; nc=$BOLD$C_TXT; fi
    pad "$nm" 10; wbar "$b" "$lo" "$up" "$bw"; fm "$b"; rpad "$M" 12
    vp $((r + i)) "$mk${nc}$PAD${RST} $BAR ${C_DIM}$RP${RST}"
  done
  USED=$i
}

# quota_lines ROW MAXROWS ARRAY SELECTED_ID EXTRA [TITLE]
# One bar per expense category that has a quota. EXTRA is added to the selected
# category's spending, which is how entry forms preview the effect of the
# amount being typed.
quota_lines() {
  local -n _c=$3
  local r=$1 mx=$2 sel=$4 extra=${5:-0} ttl=${6:-} l id kd nm sp q i n start=0 spos=-1 bw pc pcs mk nc pcc sp2
  local -a ql=()
  USED=0
  for l in "${_c[@]}"; do
    IFS=$'\t' read -r id kd nm sp q <<<"$l"
    if [[ $kd == E ]] && ((q > 0)); then [[ $id == "$sel" ]] && spos=${#ql[@]}; ql+=("$l"); fi
  done
  n=${#ql[@]}; ((n > 0)) || return 0
  if [[ -n $ttl ]]; then sec "$r" "$ttl"; r=$((r + 1)); mx=$((mx - 1)); fi
  ((mx >= 1)) || return 0
  ((n > mx)) && n=$mx
  # Scroll so the selected category stays visible when the list is clipped.
  ((spos >= n)) && start=$((spos - n + 1))
  bw=$((VW - 20)); ((bw < 6)) && bw=6
  for ((i = start; i < start + n; i++)); do
    IFS=$'\t' read -r id kd nm sp q <<<"${ql[i]}"
    sp2=$sp; mk=" "; nc=$C_TXT
    if [[ $id == "$sel" ]]; then sp2=$((sp + extra)); mk="${C_ACC}›${RST}"; nc=$BOLD$C_TXT; fi
    mkbar "$sp2" "$q" "$bw"; pc=$((sp2 * 100 / q)); printf -v pcs '%4d%%' "$pc"
    pcc=$C_DIM; ((sp2 > q)) && pcc=$C_BAD
    pad "$nm" 12
    vp $((r + i - start)) "$mk${nc}$PAD${RST} $BAR ${pcc}$pcs${RST}"
  done
  USED=$((n + (${#ttl} > 0 ? 1 : 0)))
}

# viz_pair ROW ROWS ARRAYNAME [SUFFIX] : income pie, expense pie and net total,
# stacked, each getting half of the rows. Used by every transaction-list screen.
viz_pair() {
  local r=$1 rows=$2 each=$(($2 / 2 - 1)) sfx=${4:-} ti te n sg nc=$C_INC drew=0
  agg tx I "$3"; make_slices; ti=$PTOT
  if pie_panel "$r" "$VX" "$VW" "$each" "Income$sfx" "+" "$C_INC"; then r=$((r + USED)); drew=1; fi
  agg tx E "$3"; make_slices; te=$PTOT
  if pie_panel "$r" "$VX" "$VW" "$each" "Expenses$sfx" "-" "$C_EXP"; then r=$((r + USED)); drew=1; fi
  ((drew)) || { vp "$r" "${C_DIM}Enlarge the terminal to see charts${RST}"; return 0; }
  n=$((ti - te)); sg=""; ((n >= 0)) && sg=+; ((n < 0)) && nc=$C_EXP
  fm "$n"; vp "$r" "${C_DIM}Net${RST} ${nc}$sg$M${RST}"
}
