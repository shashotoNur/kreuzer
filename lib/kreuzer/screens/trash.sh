# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# screens/trash.sh - deleted items: restore, delete forever, empty
#
# Depends on : data/trash.sh, ui/widgets.sh (widget_confirm), refresh (app/actions.sh)
# Provides   : screen_trash_load screen_trash_row screen_trash_title screen_trash_viz screen_trash_act
#
# Raw rows are meta/trash.tsv rows (see data/trash.sh), newest first.

screen_trash_load() {
  TX=(); SELECTABLE=1
  mapfile -t ROWS_DATA < <(sort -t$'\t' -k2,2nr "$TRASH")
}

screen_trash_row() {
  local tid ts kind src f1 f2 f3 f4 f5 f6 f7 f8 f9 d lab desc sg=0 nt=""
  IFS=$'\t' read -r tid ts kind src f1 f2 f3 f4 f5 f6 f7 f8 f9 <<<"$1"
  printf -v d '%(%d/%m/%Y %H:%M)T' "$ts"
  case $kind in
    T) lab=Transaction; sg=$f5; [[ $f4 == E || $f4 == TO ]] && sg=$((-f5))
       money_format "$sg"; [[ $f9 != - ]] && nt=$f9
       desc="${f2:8:2}/${f2:5:2}/${f2:0:4}  $M  $nt"; [[ $f8 != - ]] && desc+=" (transfer)" ;;
    C) lab=Category; desc=$f3 ;;
    W) lab=Wallet; desc=$f2 ;;
    *) lab=$kind; desc="" ;;
  esac
  text_pad "$lab" 12
  RR="${C_DIM}$d${RST} ${C_ACC}$PAD${RST} ${C_TXT}$desc${RST}"
}

screen_trash_title() {
  TL="Trash - ${#ROWS_DATA[@]} items"
  printf -v CH '%-17s %-12s %s' Deleted Type Item
}

screen_trash_viz() {
  local r=$VY n=${#ROWS_DATA[@]} t cc w tid ts kind src f1 f2 f3 f4 f5 f6 f7 f8 f9 d rk pk ek
  viz_section "$r" "Trash"; r=$((r + 1))
  if ((n == 0)); then viz_line "$r" "${C_DIM}Trash is empty.${RST}"; return 0; fi
  read -r t cc w < <(printf '%s\n' "${ROWS_DATA[@]}" | awk -F'\t' '{c[$3]++} END{print c["T"]+0, c["C"]+0, c["W"]+0}')
  viz_line "$r" "${C_DIM}Transactions ${RST}${C_TXT}$t${RST}"
  viz_line $((r + 1)) "${C_DIM}Categories   ${RST}${C_TXT}$cc${RST}"
  viz_line $((r + 2)) "${C_DIM}Wallets      ${RST}${C_TXT}$w${RST}"
  if [[ ${CFG[auto_purge_days]} =~ ^[0-9]+$ ]] && ((CFG[auto_purge_days] > 0)); then
    viz_line $((r + 3)) "${C_DIM}Auto-purge after ${CFG[auto_purge_days]} days${RST}"
  else viz_line $((r + 3)) "${C_DIM}Auto-purge is off${RST}"; fi
  r=$((r + 5))
  IFS=$'\t' read -r tid ts kind src f1 f2 f3 f4 f5 f6 f7 f8 f9 <<<"${ROWS_DATA[SEL]}"
  printf -v d '%(%d/%m/%Y %H:%M)T' "$ts"
  viz_section "$r" "Selected"; r=$((r + 1))
  viz_line "$r" "${C_DIM}Deleted ${RST}${C_TXT}$d${RST}"; r=$((r + 1))
  case $kind in
    T) money_format "$f5"; viz_line "$r" "${C_DIM}Amount  ${RST}${C_TXT}$M${RST}"
       viz_line $((r + 1)) "${C_DIM}Returns to ${src##*/}${RST}"; r=$((r + 2)) ;;
    C | W) viz_line "$r" "${C_DIM}Its transactions show DELETED${RST}"
       viz_line $((r + 1)) "${C_DIM}until you restore it.${RST}"; r=$((r + 2)) ;;
  esac
  input_key_label "${KEYDEF[restore]%%,*}"; rk=$KN; input_key_label "${KEYDEF[purge]%%,*}"; pk=$KN; input_key_label "${KEYDEF[empty_trash]%%,*}"; ek=$KN
  viz_line $((r + 1)) "${C_ACC}$rk${RST}${C_DIM} restore  ${RST}${C_ACC}$pk${RST}${C_DIM} delete forever  ${RST}${C_ACC}$ek${RST}${C_DIM} empty${RST}"
}

# screen_trash_act restore|purge|empty : acts on the selected row (or all, for empty).
# Destructive actions ask first; restore does not, because it is harmless.
screen_trash_act() {
  local row=${ROWS_DATA[SEL]:-}
  [[ $SCREEN == trash ]] || { canvas_flash "$C_WARN" "Open the Trash screen first"; draw; return 0; }
  case $1 in
    restore) [[ -n $row ]] || return 0; trash_restore "$row"; canvas_flash "$C_OK" "Restored." ;;
    purge) [[ -n $row ]] || return 0
      widget_confirm "Delete this item forever?" || { draw; return 0; }
      trash_purge "$row"; canvas_flash "$C_OK" "Deleted forever." ;;
    empty) ((${#ROWS_DATA[@]})) || return 0
      widget_confirm "Empty the whole trash? This cannot be undone." || { draw; return 0; }
      : >"$TRASH"; budget_prune_quotas; canvas_flash "$C_OK" "Trash emptied." ;;
  esac
  refresh
}
