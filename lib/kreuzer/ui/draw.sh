# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# ui/draw.sh - frame renderer: header, sidebar, list, form, footer
#
# Depends on : ui/canvas.sh, ui/term.sh, ui/widgets.sh (widget_edit_view), input_key_label, screen_title
#              and screen_<name>_row / screen_<name>_viz (screens/, viz/), KEYDEF
# Provides   : draw draw_update_labels draw_clamp_selection draw_move_selection
# Globals    : MONTH_LABEL DAY_LABEL LBL_M LBL_D
#
# draw() only renders cached data (ROWS_DATA, TX, WB, ...). Reloading is the job of
# refresh (app/actions.sh), so moving the cursor never starts awk.

MONTH_LABEL=""; DAY_LABEL=""; LBL_M=""; LBL_D=""

# Month and day names come from date(1), which forks, so they are recomputed only
# when the value changed.
draw_update_labels() {
  if [[ $LBL_M != "$MONTH" ]]; then MONTH_LABEL=$(date -d "$MONTH-01" '+%B %Y'); LBL_M=$MONTH; fi
  if [[ $LBL_D != "$DAY" ]]; then DAY_LABEL=$(date -d "$DAY" '+%a %d/%m/%Y'); LBL_D=$DAY; fi
}

draw_header() {
  local nav="" right=$NW_TXT
  case $SCREEN in
    daily) nav="‹ $DAY_LABEL ›" ;;
    dashboard | transactions | categories | budget) nav="‹ $MONTH_LABEL ›" ;;
  esac
  canvas_put 1 2 "${BOLD}${C_ACC}$APP${RST} ${C_DIM}$VERSION${RST}"
  [[ -n $nav ]] && canvas_put 1 $(((COLS - ${#nav}) / 2)) "${C_TXT}$nav${RST}"
  canvas_put 1 $((COLS - ${#right} - 12)) "${C_DIM}Net worth:${RST} ${C_ACC}$right${RST}"
  canvas_put 2 1 "${C_DIM}$HR${RST}"
}

# Sidebar shortcuts come from KEYDEF, so rebinding a screen key updates the label.
draw_sidebar() {
  local i r s
  for i in "${!SCREENS[@]}"; do
    s=${SCREENS[i]}; r=$((BY0 + i)); input_key_label "${KEYDEF[goto_$s]%%,*}"
    if [[ $s == "$SCREEN" ]]; then
      text_pad "$KN ${SCR_LABEL[i]}" $((SW - 1)); canvas_highlight "$r" 1 "$SW" " ${BOLD}${C_ACC}$PAD${RST}"
    else
      canvas_put "$r" 2 "${C_DIM}$KN${RST} ${C_TXT}${SCR_LABEL[i]}${RST}"
    fi
  done
  for ((r = BY0; r <= BY1; r++)); do canvas_put "$r" $((SW + 1)) "${C_DIM}│${RST}"; done
  canvas_put 2 $((SW + 1)) "${C_DIM}┬${RST}"
}

# Only the visible slice of ROWS_DATA is formatted, so large months stay fast.
draw_list() {
  local n=${#ROWS_DATA[@]} i r=$((BY0 + 2)) pos=""
  screen_title
  ((SELECTABLE && n)) && pos="$((SEL + 1))/$n"
  canvas_put "$BY0" "$LX" "${BOLD}${C_ACC}${TL:0:LW-${#pos}-1}${RST}"
  [[ -n $pos ]] && canvas_put "$BY0" $((LX + LW - ${#pos})) "${C_DIM}$pos${RST}"
  [[ -n $CH ]] && canvas_put $((BY0 + 1)) "$LX" "${C_DIM}${CH:0:LW}${RST}"
  if ((n == 0)); then canvas_put "$r" "$LX" "${C_DIM}Nothing here yet.${RST}"; return 0; fi
  for ((i = TOPROW; i < n && i < TOPROW + LH; i++)); do
    "screen_${SCREEN}_row" "${ROWS_DATA[i]}"
    if ((SELECTABLE && i == SEL)); then canvas_highlight "$r" "$LX" "$LW" "$RR"; else canvas_put "$r" "$LX" "$RR"; fi
    r=$((r + 1))
  done
}

draw_form() {
  local n=${#FL[@]} i r=$BY0 lab val vw=$((LW - 16)) t line
  # The preview (charts, projected balances) is rebuilt only after a value change.
  if ((FDIRTY)); then FDIRTY=0; PVL=(); [[ -n $FPREVFN ]] && "$FPREVFN"; fi
  canvas_put "$r" "$LX" "${BOLD}${C_ACC}${FTITLE:0:LW}${RST}"; r=$((r + 2))
  for ((i = 0; i < n && r <= BY1; i++)); do
    text_pad "${FL[i]}" 13; lab=$PAD; t=${FA[i]%%:*}
    if ((i == EDIT)); then widget_edit_view "$vw"; val=$EV
    else
      val=${FV[i]}
      [[ $t == choice ]] && val="‹ $val ›"
      [[ -z $val ]] && { [[ $t == pick ]] && val="(choose)" || val="-"; }
      val=${val:0:vw}
    fi
    line="${C_DIM}$lab${RST} ${C_TXT}$val${RST}"
    if ((i == FCUR)); then canvas_highlight "$r" "$LX" "$LW" "$line"; else canvas_put "$r" "$LX" "$line"; fi
    r=$((r + 1))
  done
  if ((r <= BY1)); then
    line="${C_ACC}[ Save ]${RST}"
    if ((FCUR == n)); then canvas_highlight "$r" "$LX" "$LW" "$line"; else canvas_put "$r" "$LX" "$line"; fi
  fi
  r=$((r + 2))
  ((FCUR < n && r <= BY1)) && [[ -n ${FH[FCUR]} ]] && canvas_put "$r" "$LX" "${C_DIM}${FH[FCUR]:0:LW}${RST}"
  r=$((r + 2))
  for line in "${PVL[@]}"; do ((r <= BY1)) && canvas_put "$r" "$LX" "$line"; r=$((r + 1)); done
}

# While a form is open and names a chart function, that one is drawn instead of
# the screen's own chart. This is how entry forms show live previews.
draw_viz() {
  local vf=screen_${SCREEN}_viz
  [[ $MODE == form && -n $FVIZ ]] && vf=$FVIZ
  declare -F "$vf" >/dev/null || return 0
  "$vf"
}

draw_msgline() {
  local r=$((ROWS - 1))
  if [[ -n $PROMPT ]]; then
    widget_edit_view $((COLS - ${#PROMPT} - 4))
    canvas_put "$r" 2 "${C_ACC}$PROMPT${RST}${C_TXT}$EV${RST}"
  elif [[ -n $MSG ]]; then canvas_put "$r" 2 "$MSG"; fi
}

# Hints are given as action:label pairs; the key shown is whatever is bound now.
# Hints that do not fit are dropped from the right, so Help and Quit always show.
draw_footer() {
  local specs=() s a lab k left="" used=0 w item hk qk
  if [[ $MODE == form ]]; then specs=(up:Move select:Edit back:Cancel)
  else
    case $SCREEN in
      dashboard) specs=(add_income:Income add_expense:Expense add_transfer:Transfer prev_month:Prev next_month:Next toggle_viz:Charts settings:Settings) ;;
      transactions | search) specs=(add:Add edit:Edit delete:Delete sort:Sort sort_reverse:Reverse search:Search prev_month:Prev next_month:Next toggle_viz:Charts) ;;
      daily) specs=(add:Add edit:Edit delete:Delete prev_day:Prev next_day:Next sort:Sort toggle_viz:Charts) ;;
      categories | wallets) specs=(add:Add edit:Edit delete:Delete move_up:Up move_down:Down sort:Sort sort_reverse:Reverse toggle_viz:Charts) ;;
      budget) specs=(edit:Set prev_month:Prev next_month:Next toggle_viz:Charts) ;;
      trash) specs=(restore:Restore purge:Delete empty_trash:Empty) ;;
    esac
  fi
  input_key_label "${KEYDEF[help]%%,*}"; hk=$KN; input_key_label "${KEYDEF[quit]%%,*}"; qk=$KN
  w=$((COLS - ${#hk} - ${#qk} - 16))
  for s in "${specs[@]}"; do
    a=${s%%:*}; lab=${s#*:}; k=${KEYDEF[$a]%%,*}
    [[ -n $k ]] || continue
    input_key_label "$k"; item="$KN $lab"
    ((used + ${#item} + 2 > w)) && break
    left+="${C_ACC}$KN${RST} ${C_DIM}$lab${RST}  "; used=$((used + ${#item} + 2))
  done
  canvas_put "$ROWS" 2 "$left"
  canvas_put "$ROWS" $((COLS - ${#hk} - ${#qk} - 12)) "${C_ACC}$hk${RST} ${C_DIM}Help${RST}  ${C_ACC}$qk${RST} ${C_DIM}Quit${RST}"
}

# The whole frame is built in BUF and written once, wrapped in synchronized-output
# markers (mode 2026) so terminals that support it show the frame atomically.
draw() {
  local r
  ((RESIZED)) && { RESIZED=0; term_layout; }
  draw_update_labels; term_panes
  BUF=$'\e[?2026h\e[H\e[2J'
  draw_header
  if ((TOOSMALL)); then
    canvas_put 4 2 "${C_WARN}Terminal too small: need 70x20, have ${COLS}x${ROWS}${RST}"
  else
    draw_sidebar
    if ((VIZFULL)); then draw_viz
    else
      if [[ $MODE == form ]]; then draw_form; else draw_list; fi
      if ((VIZON)); then
        for ((r = BY0; r <= BY1; r++)); do
          canvas_put "$r" $((VX - 2)) $'\e['$((COLS - VX + 3))'X'
          canvas_put "$r" $((VX - 2)) "${C_DIM}│${RST}"
        done
        canvas_put 2 $((VX - 2)) "${C_DIM}┬${RST}"
        draw_viz
      fi
    fi
  fi
  draw_msgline; draw_footer
  [[ -n $OVERLAY ]] && "$OVERLAY"
  BUF+=$'\e[?2026l'
  printf '%s' "$BUF"
}

# Keeps the selection inside the list and scrolls the visible window with it.
draw_clamp_selection() {
  local n=${#ROWS_DATA[@]}
  ((SEL >= n)) && SEL=$((n - 1))
  ((SEL < 0)) && SEL=0
  ((SEL < TOPROW)) && TOPROW=$SEL
  ((LH > 0 && SEL >= TOPROW + LH)) && TOPROW=$((SEL - LH + 1))
  ((TOPROW < 0)) && TOPROW=0
  return 0
}

draw_move_selection() { SEL=$((SEL + $1)); local n=${#ROWS_DATA[@]}; ((SEL >= n)) && SEL=$((n - 1)); ((SEL < 0)) && SEL=0; draw_clamp_selection; }
