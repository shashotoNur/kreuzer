# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# ui/canvas.sh - frame buffer primitives
#
# Depends on : rep, theme colours, ROWS (ui/term.sh)
# Provides   : put hl box flash
#
# Nothing is written to the terminal here. Everything appends to BUF, which
# ui/draw.sh flushes with a single printf per frame, so a redraw never flickers.

# put ROW COL TEXT : move the cursor and write. Off-screen rows are ignored so
# callers do not have to clip.
put() { (($1 >= 1 && $1 <= ROWS)) || return 0; BUF+=$'\e['"$1;$2"'H'"$3"; }

# One-line status message, truncated to fit.
flash() { MSG="$1${2:0:COLS-4}${RST}"; }

# Selected-row highlight. ECH (CSI n X) paints the background across the whole
# width in one go, and the background is re-applied after every colour reset in
# the text, otherwise the first reset would end the highlight mid-row.
hl() { # row col width text
  (($1 >= 1 && $1 <= ROWS)) || return 0
  local t=${4//"$RST"/"$RST$BG_SEL"}
  BUF+=$'\e['"$1;$2"'H'"$BG_SEL"$'\e['"$3"'X'"$t$RST"
}

box() { # row col height width title
  local r=$1 c=$2 h=$3 w=$4 t=$5 i
  rep "─" $((w - 2))
  put "$r" "$c" "${C_DIM}╭$REP╮${RST}"
  [[ -n $t ]] && put "$r" $((c + 2)) "${C_DIM} ${RST}${BOLD}${C_ACC}${t:0:w-6}${RST}${C_DIM} ${RST}"
  for ((i = 1; i < h - 1; i++)); do
    # Clear the interior first so a popup hides what is underneath it.
    put $((r + i)) $((c + 1)) $'\e['$((w - 2))'X'
    put $((r + i)) "$c" "${C_DIM}│${RST}"
    put $((r + i)) $((c + w - 1)) "${C_DIM}│${RST}"
  done
  rep "─" $((w - 2))
  put $((r + h - 1)) "$c" "${C_DIM}╰$REP╯${RST}"
}
