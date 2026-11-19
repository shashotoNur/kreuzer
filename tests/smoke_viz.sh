#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Smoke test for lib/kreuzer/viz: renders a pie and aggregates sample rows.
# Needs no terminal and touches no user data.

set -f
# Glyph mode makes the pie output comparable as plain text.
export NO_COLOR=1

APP=kreuzer
root=$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)
lib=$root/lib/kreuzer

for m in core/log core/text core/list core/money core/dates config/config config/keys \
  ui/theme ui/state data/store domain/balances domain/totals domain/series \
  ui/canvas viz/bars viz/pie viz/blocks viz/entry; do
  # shellcheck source=/dev/null
  source "$lib/$m.sh" || exit 1
done

CFG[currency]='$'; config_apply

fail=0
check() { # name got want
  if [[ $2 == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: got [$2] want [$3]"; fail=1; fi
}

# Rows have the shape tx_load produces: id, "date time", kind, cents,
# category, wallet, note, transfer_id, category_id, wallet_id.
TX=($'1\t2026-11-01 -\tE\t1000\tFood\tCash\t-\t-\t3\t1'
  $'2\t2026-11-02 -\tE\t500\tRent\tCash\t-\t-\t4\t1'
  $'3\t2026-11-03 -\tI\t9000\tSalary\tCash\t-\t-\t1\t1')

pie_aggregate tx E TX
check "pie_aggregate largest first" "${AGG[0]}" $'Food\t1000'
check "pie_aggregate second" "${AGG[1]}" $'Rent\t500'
pie_aggregate tx I TX
check "pie_aggregate income" "${AGG[0]}" $'Salary\t9000'

pie_aggregate tx E TX; pie_slices
check "slice total" "$PTOT" 1500
check "legend entry" "${LEG[0]}" $'Food\t1000\t240;160;160\t█'

# 50/30/20 split: slice 1 fills the right half from 12 o'clock clockwise, so
# the top row must contain the first glyph (right) and the third (left).
PSL=($'240;160;160\t50' $'150;190;232\t30' $'182;220;165\t20')
pie_render 20 10
check "pie rows" "${#PIE[@]}" 10
[[ ${PIE[0]} == *█* && ${PIE[0]} == *▒* ]] && r=yes || r=no
check "pie top row has slices 1 and 3" "$r" yes

# pie_panel draws into BUF; 18 columns of pie at this width gives 9 rows + 2.
ROWS=24; COLS=80; VX=1; VY=1; VW=42; VH=20; BUF=""
pie_aggregate tx E TX; pie_slices
pie_panel 1 1 42 12 Expenses - "$C_EXP"
check "pie_panel rows used" "$USED" 11
[[ $BUF == *Expenses* ]] && r=yes || r=no
check "pie_panel wrote title" "$r" yes

((fail)) && { echo "FAILED"; exit 1; }
echo "all passed"
