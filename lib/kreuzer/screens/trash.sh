# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# screens/trash.sh - deleted items: restore, delete forever, empty
#
# Depends on : data/trash.sh, ui/widgets.sh (confirm), refresh (app/actions.sh)
# Provides   : load_trash row_trash title_trash viz_trash trash_act
#
# Raw rows are meta/trash.tsv rows (see data/trash.sh), newest first.

load_trash() {
  TX=(); SELECTABLE=1
  mapfile -t ROWS_DATA < <(sort -t$'\t' -k2,2nr "$TRASH")
}

row_trash() {
  local tid ts kind src f1 f2 f3 f4 f5 f6 f7 f8 f9 d lab desc sg=0 nt=""
  IFS=$'\t' read -r tid ts kind src f1 f2 f3 f4 f5 f6 f7 f8 f9 <<<"$1"
  printf -v d '%(%d/%m/%Y %H:%M)T' "$ts"
  case $kind in
    T) lab=Transaction; sg=$f5; [[ $f4 == E || $f4 == TO ]] && sg=$((-f5))
       fm "$sg"; [[ $f9 != - ]] && nt=$f9
       desc="${f2:8:2}/${f2:5:2}/${f2:0:4}  $M  $nt"; [[ $f8 != - ]] && desc+=" (transfer)" ;;
    C) lab=Category; desc=$f3 ;;
    W) lab=Wallet; desc=$f2 ;;
    *) lab=$kind; desc="" ;;
  esac
  pad "$lab" 12
  RR="${C_DIM}$d${RST} ${C_ACC}$PAD${RST} ${C_TXT}$desc${RST}"
}

title_trash() {
  TL="Trash - ${#ROWS_DATA[@]} items"
  printf -v CH '%-17s %-12s %s' Deleted Type Item
}

viz_trash() {
  local r=$VY n=${#ROWS_DATA[@]} t cc w tid ts kind src f1 f2 f3 f4 f5 f6 f7 f8 f9 d rk pk ek
  sec "$r" "Trash"; r=$((r + 1))
  if ((n == 0)); then vp "$r" "${C_DIM}Trash is empty.${RST}"; return 0; fi
  read -r t cc w < <(printf '%s\n' "${ROWS_DATA[@]}" | awk -F'\t' '{c[$3]++} END{print c["T"]+0, c["C"]+0, c["W"]+0}')
  vp "$r" "${C_DIM}Transactions ${RST}${C_TXT}$t${RST}"
  vp $((r + 1)) "${C_DIM}Categories   ${RST}${C_TXT}$cc${RST}"
  vp $((r + 2)) "${C_DIM}Wallets      ${RST}${C_TXT}$w${RST}"
  if [[ ${CFG[auto_purge_days]} =~ ^[0-9]+$ ]] && ((CFG[auto_purge_days] > 0)); then
    vp $((r + 3)) "${C_DIM}Auto-purge after ${CFG[auto_purge_days]} days${RST}"
  else vp $((r + 3)) "${C_DIM}Auto-purge is off${RST}"; fi
  r=$((r + 5))
  IFS=$'\t' read -r tid ts kind src f1 f2 f3 f4 f5 f6 f7 f8 f9 <<<"${ROWS_DATA[SEL]}"
  printf -v d '%(%d/%m/%Y %H:%M)T' "$ts"
  sec "$r" "Selected"; r=$((r + 1))
  vp "$r" "${C_DIM}Deleted ${RST}${C_TXT}$d${RST}"; r=$((r + 1))
  case $kind in
    T) fm "$f5"; vp "$r" "${C_DIM}Amount  ${RST}${C_TXT}$M${RST}"
       vp $((r + 1)) "${C_DIM}Returns to ${src##*/}${RST}"; r=$((r + 2)) ;;
    C | W) vp "$r" "${C_DIM}Its transactions show DELETED${RST}"
       vp $((r + 1)) "${C_DIM}until you restore it.${RST}"; r=$((r + 2)) ;;
  esac
  kn "${KEYDEF[restore]%%,*}"; rk=$KN; kn "${KEYDEF[purge]%%,*}"; pk=$KN; kn "${KEYDEF[empty_trash]%%,*}"; ek=$KN
  vp $((r + 1)) "${C_ACC}$rk${RST}${C_DIM} restore  ${RST}${C_ACC}$pk${RST}${C_DIM} delete forever  ${RST}${C_ACC}$ek${RST}${C_DIM} empty${RST}"
}

# trash_act restore|purge|empty : acts on the selected row (or all, for empty).
# Destructive actions ask first; restore does not, because it is harmless.
trash_act() {
  local row=${ROWS_DATA[SEL]:-}
  [[ $SCREEN == trash ]] || { flash "$C_WARN" "Open the Trash screen first"; draw; return 0; }
  case $1 in
    restore) [[ -n $row ]] || return 0; trash_restore "$row"; flash "$C_OK" "Restored." ;;
    purge) [[ -n $row ]] || return 0
      confirm "Delete this item forever?" || { draw; return 0; }
      trash_purge "$row"; flash "$C_OK" "Deleted forever." ;;
    empty) ((${#ROWS_DATA[@]})) || return 0
      confirm "Empty the whole trash? This cannot be undone." || { draw; return 0; }
      : >"$TRASH"; prune_quotas; flash "$C_OK" "Trash emptied." ;;
  esac
  refresh
}
