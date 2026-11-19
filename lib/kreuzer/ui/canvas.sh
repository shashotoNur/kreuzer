# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# ui/canvas.sh - frame buffer primitives
#
# Depends on : text_repeat, theme colours, ROWS (ui/term.sh)
# Provides   : canvas_put canvas_highlight canvas_box canvas_flash
#
# Nothing is written to the terminal here. Everything appends to BUF, which
# ui/draw.sh flushes with a single printf per frame, so a redraw never flickers.

# canvas_put ROW COL TEXT : move the cursor and write. Off-screen rows are ignored so
# callers do not have to clip.
canvas_put() { (($1 >= 1 && $1 <= ROWS)) || return 0; BUF+=$'\e['"$1;$2"'H'"$3"; }

# One-line status message, truncated to fit.
canvas_flash() { MSG="$1${2:0:COLS-4}${RST}"; }

# Selected-row highlight. ECH (CSI n X) paints the background across the whole
# width in one go, and the background is re-applied after every colour reset in
# the text, otherwise the first reset would end the highlight mid-row.
canvas_highlight() { # row col width text
  (($1 >= 1 && $1 <= ROWS)) || return 0
  local t=${4//"$RST"/"$RST$BG_SEL"}
  BUF+=$'\e['"$1;$2"'H'"$BG_SEL"$'\e['"$3"'X'"$t$RST"
}

canvas_box() { # row col height width title
  local r=$1 c=$2 h=$3 w=$4 t=$5 i
  text_repeat "─" $((w - 2))
  canvas_put "$r" "$c" "${C_DIM}╭$REP╮${RST}"
  [[ -n $t ]] && canvas_put "$r" $((c + 2)) "${C_DIM} ${RST}${BOLD}${C_ACC}${t:0:w-6}${RST}${C_DIM} ${RST}"
  for ((i = 1; i < h - 1; i++)); do
    # Clear the interior first so a popup hides what is underneath it.
    canvas_put $((r + i)) $((c + 1)) $'\e['$((w - 2))'X'
    canvas_put $((r + i)) "$c" "${C_DIM}│${RST}"
    canvas_put $((r + i)) $((c + w - 1)) "${C_DIM}│${RST}"
  done
  text_repeat "─" $((w - 2))
  canvas_put $((r + h - 1)) "$c" "${C_DIM}╰$REP╯${RST}"
}
