# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# app/actions.sh - application controller: reload, navigation, actions, main loop
#
# Depends on : ui/*, screens/*, forms/*, data/*, config/keys.sh (KEYMAP)
# Provides   : refresh nav_goto_screen nav_shift_month nav_shift_day action_add action_edit action_delete
#              action_move action_sort action_sort_reverse action_search dispatch main_loop
#
# The only layer that connects input to behaviour. Screens and forms never call
# each other directly; they are reached from dispatch by action name.

# The one place that reloads data. Bumping DVER first invalidates every chart
# cache (their keys include it), so callers only need to call refresh after a
# write and the charts are correct.
refresh() { DVER=$((DVER + 1)); balances_load; "screen_${SCREEN}_load"; draw_clamp_selection; draw; }

nav_goto_screen() { SCREEN=$1; SEL=0; TOPROW=0; MODE=list; refresh; }

# Month arithmetic goes through date(1) so year rollover and month lengths are
# not reimplemented. The 1st is used so "-1 month" can never skip a short month.
nav_shift_month() { MONTH=$(date -d "$MONTH-01 $1 month" +%Y-%m); SEL=0; TOPROW=0; }
nav_shift_day() { DAY=$(date -d "$DAY $1 day" +%F); SEL=0; TOPROW=0; }

action_add() {
  case $SCREEN in
    categories) category_form ;;
    wallets) wallet_form ;;
    budget) budget_form ;;
    trash) canvas_flash "$C_DIM" "Nothing to add here"; draw ;;
    *)
      PICK=("I"$'\t'"Income" "E"$'\t'"Expense" "T"$'\t'"Transfer")
      # Starts on Expense, the most common entry.
      if widget_pick "Add" 1; then
        case $PICK_ID in I | E) entry_form "$PICK_ID" ;; T) transfer_form ;; esac
      else draw; fi ;;
  esac
}

action_edit() {
  local row=${ROWS_DATA[SEL]:-} id dt kind cents cat wal note tr cid wid
  case $SCREEN in
    transactions | search | daily)
      [[ -n $row ]] || return 0
      IFS=$'\t' read -r id dt kind cents cat wal note tr cid wid <<<"$row"
      # A transfer is edited as a whole, whichever of its rows is selected.
      if [[ $tr != - ]]; then transfer_form "$row"; else entry_form "$kind" "$row"; fi ;;
    categories) [[ -n $row ]] && category_form "$row" ;;
    wallets) [[ -n $row ]] && wallet_form "$row" ;;
    budget) budget_form ;;
  esac
}

action_delete() {
  local row=${ROWS_DATA[SEL]:-} id dt kind cents cat wal note tr cid wid kd nm sp q msg
  [[ -n $row ]] || return 0
  case $SCREEN in
    transactions | search | daily)
      IFS=$'\t' read -r id dt kind cents cat wal note tr cid wid <<<"$row"
      msg="Move this transaction to the trash?"
      [[ $tr != - ]] && msg="Move this transfer, with its linked entries, to the trash?"
      widget_confirm "$msg" || { draw; return 0; }
      trash_tx "$id" "${dt%% *}" "$tr"; canvas_flash "$C_OK" "Moved to trash."; refresh ;;
    categories)
      IFS=$'\t' read -r id kd nm sp q <<<"$row"
      widget_confirm "Move category '$nm' to trash? Its transactions will show DELETED." || { draw; return 0; }
      trash_meta "$CATS" C "$id"; canvas_flash "$C_OK" "Moved to trash."; refresh ;;
    wallets)
      IFS=$'\t' read -r id nm sp q cid <<<"$row"
      widget_confirm "Move wallet '$nm' to trash? Its transactions will show DELETED." || { draw; return 0; }
      trash_meta "$WALS" W "$id"; canvas_flash "$C_OK" "Moved to trash."; refresh ;;
  esac
}

# action_move -1|1 : swap the selected item with its neighbour in the stored order.
# Only meaningful in the manual, non-reversed order: any other order is a view
# of the data, not the stored sequence, so a swap there would look arbitrary.
action_move() {
  local n=${#ROWS_DATA[@]} t=$((SEL + $1)) file sc a b
  case $SCREEN in
    categories) [[ $CATSORT == manual ]] && ((!CATREV)) || { canvas_flash "$C_WARN" "Set sort to manual to reorder"; draw; return 0; }
      file=$CATS; sc=4 ;;
    wallets) [[ $WALSORT == manual ]] && ((!WALREV)) || { canvas_flash "$C_WARN" "Set sort to manual to reorder"; draw; return 0; }
      file=$WALS; sc=7 ;;
    *) return 0 ;;
  esac
  ((t >= 0 && t < n)) || return 0
  a=${ROWS_DATA[SEL]%%$'\t'*}; b=${ROWS_DATA[t]%%$'\t'*}
  store_swap_sort "$file" "$sc" "$a" "$b"; SEL=$t; refresh
}

action_sort() {
  case $SCREEN in
    transactions | search | daily) list_cycle TXSORT date amount category wallet type ;;
    categories) list_cycle CATSORT manual name total kind ;;
    wallets) list_cycle WALSORT manual name balance ;;
    *) return 0 ;;
  esac
  SEL=0; TOPROW=0; refresh
}

action_sort_reverse() {
  case $SCREEN in
    transactions | search | daily) TXREV=$((1 - TXREV)) ;;
    categories) CATREV=$((1 - CATREV)) ;;
    wallets) WALREV=$((1 - WALREV)) ;;
    *) return 0 ;;
  esac
  SEL=0; TOPROW=0; refresh
}

action_search() {
  widget_prompt "Search (from: to: min: max: /regex/): " "$QUERY" || { draw; return 0; }
  text_trim "$PROMPT_RES"; QUERY=$TRIM
  SCREEN=search; SEL=0; TOPROW=0; MODE=list; refresh
}

# Maps an action name (from KEYMAP) to its handler. Plain navigation redraws
# only; anything that changes data or the viewed period goes through refresh.
dispatch() {
  local a=$1 i
  case $a in
    up) draw_move_selection -1; draw ;;
    down) draw_move_selection 1; draw ;;
    top) SEL=0; draw_clamp_selection; draw ;;
    bottom) SEL=$((${#ROWS_DATA[@]} - 1)); draw_clamp_selection; draw ;;
    select | edit) action_edit ;;
    back) [[ $SCREEN == dashboard ]] || nav_goto_screen dashboard ;;
    next_screen)
      for i in "${!SCREENS[@]}"; do [[ ${SCREENS[i]} == "$SCREEN" ]] && break; done
      nav_goto_screen "${SCREENS[(i + 1) % ${#SCREENS[@]}]}" ;;
    goto_*) nav_goto_screen "${a#goto_}" ;;
    prev_month) nav_shift_month -1; refresh ;;
    next_month) nav_shift_month +1; refresh ;;
    # Left and right step days on the Daily screen and months everywhere else.
    prev_day) if [[ $SCREEN == daily ]]; then nav_shift_day -1; else nav_shift_month -1; fi; refresh ;;
    next_day) if [[ $SCREEN == daily ]]; then nav_shift_day +1; else nav_shift_month +1; fi; refresh ;;
    add) action_add ;;
    add_income) entry_form I ;;
    add_expense) entry_form E ;;
    add_transfer) transfer_form ;;
    delete) action_delete ;;
    move_up) action_move -1 ;;
    move_down) action_move 1 ;;
    sort) action_sort ;;
    sort_reverse) action_sort_reverse ;;
    search) action_search ;;
    restore) screen_trash_act restore ;;
    purge) screen_trash_act purge ;;
    empty_trash) screen_trash_act empty ;;
    toggle_viz) SHOWVIZ=$((1 - SHOWVIZ)); draw ;;
    settings) settings_form ;;
    help) widget_help; draw ;;
    quit) QUIT=1 ;;
  esac
}

main_loop() {
  local act
  refresh
  while ((!QUIT)); do
    input_read_key; MSG=""
    # Paging and Home/End are fixed keys, not actions: they have no letter
    # equivalent worth reserving, so they are not rebindable.
    case $KEY in
      RESIZE) RESIZED=0; term_layout; draw_clamp_selection; draw; continue ;;
      EOF) break ;;
      PGUP) draw_move_selection $((-LH)); draw; continue ;;
      PGDN) draw_move_selection "$LH"; draw; continue ;;
      HOME) dispatch top; continue ;;
      END) dispatch bottom; continue ;;
    esac
    act=${KEYMAP[$KEY]:-}
    if [[ -n $act ]]; then dispatch "$act"; else draw; fi
  done
}
