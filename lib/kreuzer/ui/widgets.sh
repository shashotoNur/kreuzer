# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# ui/widgets.sh - interactive building blocks: confirm, help, picker, line editor,
#                 widget_prompt line, alerts popup
#
# Depends on : ui/input.sh, ui/canvas.sh, draw (ui/draw.sh), text_pad, KEYMAP, ACTIONS
# Provides   : widget_confirm widget_help widget_pick widget_edit_view widget_edit widget_prompt widget_alerts
# Globals    : OVERLAY PROMPT PROMPT_RES EDIT EBUF EPOS EDIT_CHECK EV
#              PTITLE PSEL PTOP PICK_ID PICK_LABEL
#
# Popups work through OVERLAY: the name of a function that draw() calls last, so
# the popup is repainted on top of the screen after every key or resize.

OVERLAY=""
PROMPT=""; PROMPT_RES=""
EDIT=-1; EBUF=""; EPOS=0; EDIT_CHECK=""; EV=""
PTITLE=""; PSEL=0; PTOP=0; PICK_ID=""; PICK_LABEL=""

# widget_confirm TEXT -> status 0 only on an explicit y, so a stray key never confirms.
widget_confirm() {
  MSG="${C_WARN}${1:0:COLS-14}${RST} ${C_DIM}[y/N]${RST}"; draw
  input_read_key; MSG=""
  [[ $KEY == y || $KEY == Y ]]
}

# ------------------------------------------------------------------ help overlay
widget_help_overlay() {
  local cols=3 n=${#ACTIONS[@]} per i a col row colw ks k s
  local -a ka
  ((COLS < 90)) && cols=2
  per=$(((n + cols - 1) / cols)); colw=$(((COLS - 6) / cols))
  canvas_box 3 3 $((per + 4)) $((COLS - 4)) "Keys - edit $CONF_FILE or run: $APP --dump-keys"
  for ((i = 0; i < n; i++)); do
    a=${ACTIONS[i]}; col=$((i / per)); row=$((i % per))
    IFS=, read -ra ka <<<"${KEYDEF[$a]}"; s=""
    for k in "${ka[@]}"; do input_key_label "$k"; s+="${s:+/}$KN"; done
    text_pad "$s" 11; ks=$PAD
    canvas_put $((5 + row)) $((5 + col * colw)) "${C_ACC}$ks${RST}${C_TXT}${ADESC[$a]:0:colw-13}${RST}"
  done
  canvas_put $((per + 6)) 5 "${C_DIM}Press any key to close${RST}"
}
widget_help() { OVERLAY=widget_help_overlay; draw; input_read_key; OVERLAY=""; }

# ------------------------------------------------------------------ picker
widget_pick_overlay() {
  local n=${#PICK[@]} i w=0 h vis r c lab line
  for line in "${PICK[@]}"; do lab=${line#*$'\t'}; ((${#lab} > w)) && w=${#lab}; done
  w=$((w + 6)); ((w < 30)) && w=30; ((w > COLS - 6)) && w=$((COLS - 6))
  h=$((n + 4)); ((h > ROWS - 6)) && h=$((ROWS - 6)); vis=$((h - 4))
  r=$(((ROWS - h) / 2 + 1)); c=$(((COLS - w) / 2 + 1))
  ((PSEL >= n)) && PSEL=$((n - 1)); ((PSEL < 0)) && PSEL=0
  ((PSEL < PTOP)) && PTOP=$PSEL
  ((PSEL >= PTOP + vis)) && PTOP=$((PSEL - vis + 1))
  canvas_box "$r" "$c" "$h" "$w" "$PTITLE"
  for ((i = PTOP; i < n && i < PTOP + vis; i++)); do
    lab=${PICK[i]#*$'\t'}; text_pad "$lab" $((w - 4))
    if ((i == PSEL)); then canvas_highlight $((r + 2 + i - PTOP)) $((c + 2)) $((w - 4)) "${C_TXT}$PAD${RST}"
    else canvas_put $((r + 2 + i - PTOP)) $((c + 2)) "${C_TXT}$PAD${RST}"; fi
  done
}

# widget_pick TITLE [INDEX] : choose from PICK ("id<TAB>label" items).
# Sets PICK_ID and PICK_LABEL; status 1 if cancelled or the list is empty.
# Typing a letter jumps to the first label starting with it.
widget_pick() {
  local n=${#PICK[@]} act i lab
  ((n)) || { canvas_flash "$C_WARN" "nothing to choose from yet"; return 1; }
  PTITLE=$1; PSEL=${2:-0}; PTOP=0; OVERLAY=widget_pick_overlay
  while :; do
    draw; input_read_key; MSG=""
    case $KEY in RESIZE) continue ;; EOF) OVERLAY=""; return 1 ;; esac
    act=${KEYMAP[$KEY]:-}
    case $act in
      up) ((PSEL > 0)) && PSEL=$((PSEL - 1)) ;;
      down) ((PSEL < n - 1)) && PSEL=$((PSEL + 1)) ;;
      top) PSEL=0 ;;
      bottom) PSEL=$((n - 1)) ;;
      select) PICK_ID=${PICK[PSEL]%%$'\t'*}; PICK_LABEL=${PICK[PSEL]#*$'\t'}; OVERLAY=""; return 0 ;;
      back) OVERLAY=""; return 1 ;;
      *) if ((${#KEY} == 1)); then
           for ((i = 0; i < n; i++)); do
             lab=${PICK[i]#*$'\t'}
             if [[ ${lab,,} == "${KEY,,}"* ]]; then PSEL=$i; break; fi
           done
         fi ;;
    esac
  done
}

# ------------------------------------------------------------------ line editor
# widget_edit_view WIDTH -> EV : the buffer with a reverse-video block at the cursor,
# scrolled so the cursor is always inside the field. The terminal's own cursor is
# hidden for the whole session, so the cursor is drawn by hand.
widget_edit_view() {
  local w=$1 s=0 rel vis cur
  ((w < 1)) && w=1
  ((EPOS >= w)) && s=$((EPOS - w + 1))
  vis=${EBUF:s:w}; rel=$((EPOS - s))
  cur=${vis:rel:1}; [[ -z $cur ]] && cur=" "
  EV="${vis:0:rel}"$'\e[7m'"$cur"$'\e[27m'"${vis:rel+1}"
}

widget_edit_insert() { ((${#EBUF} < 200)) || return 0; EBUF=${EBUF:0:EPOS}$1${EBUF:EPOS}; EPOS=$((EPOS + 1)); }

# Edits EBUF in place. Status 0 on Enter (after EDIT_CHECK passes, if set),
# 1 on Esc. A failing EDIT_CHECK keeps the editor open so the user can correct it.
widget_edit() {
  while :; do
    draw; input_read_key; MSG=""
    case $KEY in
      RESIZE) ;;
      EOF | ESC) return 1 ;;
      ENTER) if [[ -n $EDIT_CHECK ]]; then "$EDIT_CHECK" || continue; fi; return 0 ;;
      LEFT) ((EPOS > 0)) && EPOS=$((EPOS - 1)) ;;
      RIGHT) ((EPOS < ${#EBUF})) && EPOS=$((EPOS + 1)) ;;
      HOME | CTRL_A) EPOS=0 ;;
      END | CTRL_E) EPOS=${#EBUF} ;;
      BACKSPACE) if ((EPOS > 0)); then EBUF=${EBUF:0:EPOS-1}${EBUF:EPOS}; EPOS=$((EPOS - 1)); fi ;;
      DELETE) EBUF=${EBUF:0:EPOS}${EBUF:EPOS+1} ;;
      CTRL_U) EBUF=${EBUF:EPOS}; EPOS=0 ;;
      CTRL_K) EBUF=${EBUF:0:EPOS} ;;
      SPACE) widget_edit_insert " " ;;
      COMMA) widget_edit_insert "," ;;
      *) ((${#KEY} == 1)) && widget_edit_insert "$KEY" ;;
    esac
  done
}

# widget_prompt LABEL INITIAL -> PROMPT_RES : one-line input on the message line.
widget_prompt() {
  local rc=1
  PROMPT=$1; EBUF=$2; EPOS=${#2}; EDIT=-1; EDIT_CHECK=""
  if widget_edit; then PROMPT_RES=$EBUF; rc=0; fi
  PROMPT=""; return $rc
}

# ------------------------------------------------------------------ alerts popup
# ALERTS entries start with "W:" (warning) or "G:" (good news).
widget_alerts_overlay() {
  local n=${#ALERTS[@]} w=34 a i h r c col
  for a in "${ALERTS[@]}"; do ((${#a} + 2 > w)) && w=$((${#a} + 2)); done
  ((w > COLS - 6)) && w=$((COLS - 6))
  h=$((n + 5)); r=$(((ROWS - h) / 2 + 1)); c=$(((COLS - w) / 2 + 1))
  canvas_box "$r" "$c" "$h" "$w" "Heads up"
  for ((i = 0; i < n; i++)); do
    a=${ALERTS[i]}; col=$C_WARN; [[ ${a:0:1} == G ]] && col=$C_OK
    text_pad "${a:2}" $((w - 4)); canvas_put $((r + 2 + i)) $((c + 2)) "$col$PAD${RST}"
  done
  canvas_put $((r + h - 2)) $((c + 2)) "${C_DIM}Press any key${RST}"
}

widget_alerts() {
  ((${#ALERTS[@]})) || return 0
  OVERLAY=widget_alerts_overlay; draw; input_read_key; OVERLAY=""; ALERTS=()
}
