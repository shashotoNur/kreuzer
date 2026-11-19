# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# config/keys.sh - actions, default key bindings, key lookup table
#
# Depends on : log_die
# Provides   : keys_build keys_dump
# Globals    : ACTIONS KEYDEF ADESC KEYMAP
#
# Key names (ENTER, UP, ...) are produced by ui/input.sh input_read_key. Plain
# characters stand for themselves.

# The order here is the order shown in the help overlay and the config file.
ACTIONS=(up down top bottom select back next_screen goto_dashboard goto_transactions goto_daily
  goto_categories goto_wallets goto_budget goto_search goto_trash prev_month next_month prev_day
  next_day add add_income add_expense add_transfer edit delete move_up move_down sort sort_reverse
  search restore purge empty_trash toggle_viz settings help quit)

declare -gA KEYDEF=([up]="k,UP" [down]="j,DOWN" [top]="g" [bottom]="G" [select]="ENTER" [back]="ESC"
  [next_screen]="TAB" [goto_dashboard]="1" [goto_transactions]="2" [goto_daily]="3"
  [goto_categories]="4" [goto_wallets]="5" [goto_budget]="6" [goto_search]="7" [goto_trash]="8"
  [prev_month]="[" [next_month]="]" [prev_day]="h,LEFT" [next_day]="l,RIGHT" [add]="a"
  [add_income]="i" [add_expense]="x" [add_transfer]="t" [edit]="e" [delete]="d" [move_up]="K"
  [move_down]="J" [sort]="s" [sort_reverse]="S" [search]="/" [restore]="r" [purge]="D"
  [empty_trash]="E" [toggle_viz]="v" [settings]="C" [help]="?" [quit]="q")

declare -gA ADESC=([up]="move up" [down]="move down" [top]="first item" [bottom]="last item"
  [select]="open / details" [back]="to dashboard" [next_screen]="next screen"
  [goto_dashboard]="Dashboard" [goto_transactions]="Transactions" [goto_daily]="Daily"
  [goto_categories]="Categories" [goto_wallets]="Wallets" [goto_budget]="Budget"
  [goto_search]="Search" [goto_trash]="Trash" [prev_month]="previous month" [next_month]="next month"
  [prev_day]="previous day" [next_day]="next day" [add]="add item" [add_income]="quick income"
  [add_expense]="quick expense" [add_transfer]="quick transfer" [edit]="edit item"
  [delete]="to trash" [move_up]="move item up" [move_down]="move item down" [sort]="next sort key"
  [sort_reverse]="reverse sort" [search]="search all months" [restore]="restore (Trash)"
  [purge]="delete forever" [empty_trash]="empty trash" [toggle_viz]="show/hide charts"
  [settings]="settings" [help]="this help" [quit]="quit")

declare -gA KEYMAP=()

# Inverts KEYDEF (action -> keys) into KEYMAP (key -> action) for O(1) dispatch.
# Rejecting duplicates here, at startup, is cheaper than debugging a key that
# silently does the wrong thing. Relies on `set -f` from main.sh: unquoted
# expansion of keys like "[" or "?" would otherwise glob against file names.
keys_build() {
  local a k IFS=,
  KEYMAP=()
  for a in "${ACTIONS[@]}"; do
    for k in ${KEYDEF[$a]}; do
      [[ -z $k ]] && continue
      [[ -n ${KEYMAP[$k]+x} ]] && log_die "key '$k' is bound to both '${KEYMAP[$k]}' and '$a'"
      KEYMAP[$k]=$a
    done
  done
}

keys_dump() { local a; echo "[keys]"; for a in "${ACTIONS[@]}"; do echo "$a=${KEYDEF[$a]}"; done; }
