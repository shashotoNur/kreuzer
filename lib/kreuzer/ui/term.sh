# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# ui/term.sh - terminal lifecycle and screen geometry
#
# Depends on : log_die, text_repeat, stty
# Provides   : term_start term_cleanup term_layout term_panes
# Globals    : ROWS COLS SW LX LW LH BY0 BY1 BH VWD VX VY VW VH WIDE VIZON VIZFULL
#              TOOSMALL TXWAL HR LWW LWN OLD_STTY
#
# Screen map: row 1 header, row 2 rule, rows BY0..BY1 body, then a message line
# and the footer. Columns: sidebar (SW), list (LX..), optional chart pane (VX..).

ROWS=24; COLS=80; SW=16; LX=19; LW=60; LH=10; BY0=3; BY1=22; BH=20
VWD=42; VX=1; VY=3; VW=42; VH=20
WIDE=0; VIZON=0; VIZFULL=0; TOOSMALL=0; TXWAL=0; HR=""; LWW=58; LWN=60
OLD_STTY=""

# Idempotent: it runs from the EXIT trap and may be reached twice (INT, then EXIT).
term_cleanup() {
  if ((TUI)); then
    printf '\e[?7h\e[?25h\e[?1049l'
    stty "$OLD_STTY" 2>/dev/null
    TUI=0
  fi
}

# Alternate screen keeps the user's scrollback intact. Autowrap is switched off
# so writing in the last column never scrolls the frame.
term_start() {
  [[ -t 0 && -t 1 ]] || log_die "needs an interactive terminal"
  OLD_STTY=$(stty -g) || log_die "cannot read terminal settings"
  stty -echo
  printf '\e[?1049h\e[?25l\e[?7l'
  TUI=1
  trap 'RESIZED=1' WINCH
  trap 'exit 130' INT TERM HUP
  trap term_cleanup EXIT
  term_layout
}

# Recomputes every geometry variable. Called at start and after a resize.
term_layout() {
  local sz
  if sz=$(stty size 2>/dev/null </dev/tty) && [[ -n $sz ]]; then read -r ROWS COLS <<<"$sz"; fi
  ((ROWS > 0)) || ROWS=24
  ((COLS > 0)) || COLS=80
  BY0=3; BY1=$((ROWS - 2)); BH=$((BY1 - BY0 + 1)); LH=$((BH - 2)); VY=$BY0; VH=$BH
  TOOSMALL=0; ((ROWS < 20 || COLS < 70)) && TOOSMALL=1
  WIDE=0; ((COLS >= 120)) && WIDE=1
  LWW=$((COLS - VWD + 1 - LX - 2)); LWN=$((COLS - LX))
  text_repeat "─" "$COLS"; HR=$REP
}

# Decides where the charts go. Wide terminals show them beside the list (SHOWVIZ=1
# hides them); narrower ones show them instead of the list when SHOWVIZ=1.
# Forms never lose the chart pane, so charts stay visible during data entry.
term_panes() {
  VIZON=0; VIZFULL=0; LW=$LWN
  if ((WIDE && SHOWVIZ == 0)); then
    VIZON=1; LW=$LWW; VW=$VWD; VX=$((COLS - VWD + 1))
  elif ((!WIDE && SHOWVIZ == 1)) && [[ $MODE == list ]]; then
    VIZFULL=1; VX=$LX; VW=$((COLS - LX))
  fi
  TXWAL=0; ((LW >= 72)) && TXWAL=1
}
