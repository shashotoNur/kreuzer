# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# viz/bars.sh - bars, sparklines and chart-pane drawing primitives
#
# Depends on : ui/canvas.sh (canvas_put), ui/theme.sh, domain/series.sh, WMAX, text_repeat
# Provides   : viz_line viz_section viz_bar viz_bar_plain viz_bar_wallet viz_spark_daily viz_spark_wallet
# Out-vars   : BAR SPK SMIN SMAX
# Globals    : DVER SPKC WSC
#
# Every viz function draws inside the chart pane rectangle VX VY VW VH.

# Chart data version, bumped by refresh() after every reload. Cache keys include
# it, so stale entries are never hit and nothing has to be invalidated by hand.
DVER=0
declare -gA SPKC=() WSC=()

# viz_line ROW TEXT : write one line at the pane's left edge, clipped to the pane.
viz_line() { (($1 >= VY && $1 < VY + VH)) && canvas_put "$1" "$VX" "$2"; return 0; }

# viz_section ROW TITLE : section rule with a title, spanning the pane width.
viz_section() { local t=$2; text_repeat "─" $((VW - ${#t} - 4)); viz_line "$1" "${C_DIM}── ${RST}${BOLD}${C_ACC}$t${RST}${C_DIM} $REP${RST}"; }

# Progress bar that turns yellow at 80% and red above 100%, for spending
# against a limit. Integer math only: bash has no floats.
viz_bar() { # current max width -> BAR
  local cur=$1 max=$2 w=$3 f=0 col=$C_OK a b
  ((max > 0)) && f=$((cur * w / max))
  ((f > w)) && f=$w; ((f < 0)) && f=0
  if ((max > 0)); then ((cur * 100 >= max * 80)) && col=$C_WARN; ((cur > max)) && col=$C_BAD; fi
  printf -v a '%*s' "$f" ''; printf -v b '%*s' "$((w - f))" ''
  BAR="$col${a// /█}$C_DIM${b// /░}$RST"
}

# Same shape without the traffic-light colours, for values with no limit.
viz_bar_plain() { # current max width -> BAR
  local cur=$1 max=$2 w=$3 f=0 a b
  ((max > 0)) && f=$((cur * w / max))
  ((f > w)) && f=$w; ((f < 0)) && f=0
  printf -v a '%*s' "$f" ''; printf -v b '%*s' "$((w - f))" ''
  BAR="$C_ACC${a// /█}$C_DIM${b// /░}$RST"
}

# Wallet bar with its bounds drawn as markers. The scale is the upper bound when
# one exists (so a full bar means "goal reached"), otherwise the largest wallet.
# "-" means "no bound", the same placeholder the data files use.
viz_bar_wallet() { # balance lower upper width -> BAR
  local bal=$1 lo=$2 up=$3 w=$4 scale f=0 col=$C_ACC i s="" mlo=-1 mup=-1
  scale=$WMAX; [[ $up != - ]] && ((up > 0)) && scale=$up
  ((scale < 1)) && scale=1
  ((bal > 0)) && f=$((bal * w / scale)); ((f > w)) && f=$w
  [[ $lo != - ]] && { mlo=$((lo * w / scale)); ((mlo >= w)) && mlo=$((w - 1)); }
  [[ $up != - ]] && mup=$((w - 1))
  [[ $lo != - ]] && ((bal <= lo)) && col=$C_BAD
  [[ $up != - ]] && ((bal >= up)) && col=$C_OK
  for ((i = 0; i < w; i++)); do
    if ((i == mlo)); then s+="${C_WARN}┃"
    elif ((i == mup)); then s+="${C_OK}┃"
    elif ((i < f)); then s+="${col}█"
    else s+="${C_DIM}░"; fi
  done
  BAR="$s$RST"
}

# Cached sparklines: the awk passes behind them read every month file, which is
# too slow to repeat on each keypress.
viz_spark_daily() { # month kind(I|E) -> SPK
  local key="$1|$2|$DVER"
  if [[ -z ${SPKC["$key"]+x} ]]; then
    series_daily "$1" "$2"
    ((${#SPKC[@]} > 60)) && SPKC=()
    SPKC["$key"]=$SPK
  fi
  SPK=${SPKC["$key"]}
}

viz_spark_wallet() { # m|y wallet_id month -> SPK SMIN SMAX   (m = daily, y = 12 months)
  local key="$1|$2|$3|$DVER"
  if [[ -z ${WSC["$key"]+x} ]]; then
    if [[ $1 == m ]]; then series_wallet_month "$2" "$3"; else series_wallet_year "$2" "$3"; fi
    ((${#WSC[@]} > 80)) && WSC=()
    WSC["$key"]="$SPK $SMIN $SMAX"
  fi
  read -r SPK SMIN SMAX <<<"${WSC["$key"]}"
}
