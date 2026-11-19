# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# screens/common.sh - screen contract and code shared by the transaction screens
#
# Depends on : ui/state.sh, core/money, core/text, theme colours
# Provides   : screen_title screen_title_tx screen_row_tx
# Out-vars   : TL CH RR
#
# A screen NAME provides screen_NAME_load, screen_NAME_row, screen_NAME_title and screen_NAME_viz:
#   screen_NAME_load   fills ROWS_DATA (raw rows), TX (rows behind the charts), SELECTABLE
#   screen_NAME_row    formats one raw row into RR for the list
#   screen_NAME_title  sets TL (heading) and CH (column header, may be empty)
#   screen_NAME_viz    draws the chart pane
# Screens are looked up by name at call time, so a new screen is one new file
# plus an entry in SCREENS (ui/state.sh).

screen_title() { CH=""; "screen_${SCREEN}_title"; }

# Heading and column header of every list that shows transactions.
screen_title_tx() { # heading
  local n=${#ROWS_DATA[@]} dir="↓"
  ((TXREV)) || dir="↑"
  TL="$1 - $n items - sort: $TXSORT $dir"
  # The wallet column is dropped on narrow terminals instead of squeezing notes.
  if ((TXWAL)); then printf -v CH '%-10s %-5s %12s %-12s %-10s %s' Date Time Amount Category Wallet Note
  else printf -v CH '%-10s %-5s %12s %-12s %s' Date Time Amount Category Note; fi
}

# One transaction row. Input is a tx_load row:
# id, "date time", kind, cents, category, wallet, note, transfer_id, category_id, wallet_id
screen_row_tx() {
  local id dt kind cents cat wal note tr cid wid d t sg col cc wc c1 c2 c3 c4 c5 c6 nw
  IFS=$'\t' read -r id dt kind cents cat wal note tr cid wid <<<"$1"
  d=${dt%% *}; t=${dt#* }
  [[ $t == - ]] && t=""
  [[ $note == - ]] && note=""
  sg=$cents; col=$C_INC
  case $kind in E) sg=$((-cents)); col=$C_EXP ;; TO) sg=$((-cents)); col=$C_XFR ;; TI) col=$C_XFR ;; esac
  money_format "$sg"; ((sg >= 0)) && M="+$M"
  text_pad "${d:8:2}/${d:5:2}/${d:0:4}" 10; c1=$PAD
  text_pad "$t" 5; c2=$PAD
  text_rpad "$M" 12; c3=$RP
  text_pad "$cat" 12; c4=$PAD
  # Warning colour on DELETED makes orphaned rows easy to spot.
  cc=$C_TXT; [[ $cat == DELETED ]] && cc=$C_WARN; [[ $cat == Transfer ]] && cc=$C_XFR
  if ((TXWAL)); then
    wc=$C_DIM; [[ $wal == DELETED ]] && wc=$C_WARN
    text_pad "$wal" 10; c5=$PAD; nw=$((LW - 54)); text_pad "$note" "$nw"; c6=$PAD
    RR="${C_DIM}$c1 $c2${RST} ${col}$c3${RST} ${cc}$c4${RST} ${wc}$c5${RST} ${C_TXT}$c6${RST}"
  else
    nw=$((LW - 43)); text_pad "$note" "$nw"; c6=$PAD
    RR="${C_DIM}$c1 $c2${RST} ${col}$c3${RST} ${cc}$c4${RST} ${C_TXT}$c6${RST}"
  fi
}
