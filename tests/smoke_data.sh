#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Smoke test for the data layer behind the forms: pickers, alerts, quotas and the
# trash round trip, against a throwaway directory. Needs no terminal.

export NO_COLOR=1
root=$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)
KREUZER_LIBDIR=$root/lib/kreuzer
# Sourcing main.sh loads every module (and exits if one is missing); main is not called.
# shellcheck source=/dev/null
source "$KREUZER_LIBDIR/main.sh" || exit 1
draw() { :; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
CFG[data_dir]=$tmp; CFG[currency]='$'; config_apply; store_set_paths
mkdir -p "$DATA/meta"; touch "$QUOTAS" "$BUDG" "$TRASH"
printf '1\tCash\t10000\t2026-01-01\t400000\t-\t1\n' >"$WALS"
printf '2\tE\tFood\t1\n3\tI\tSalary\t2\n' >"$CATS"
M1=$DATA/2026-11.tsv
printf '4\t2026-11-03\t-\tE\t1250\t2\t1\t-\tlunch\n5\t2026-11-01\t-\tI\t300000\t3\t1\t-\t-\n' >"$M1"
printf '6\t2026-11-05\t-\tTO\t1000\t-\t1\t9\t-\n7\t2026-11-05\t-\tTI\t1000\t-\t1\t9\t-\n' >>"$M1"
echo 7 >"$SEQ"
MONTH=2026-10; SCREEN=dashboard

fail=0
check() { if [[ $2 == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: got [$2] want [$3]"; fail=1; fi; }

balances_load
entry_pick_expense; check "expense picker" "${PICK[*]}" "2	Food"
entry_pick_wallet; check "wallet picker" "${PICK[0]}" "1	Cash"
entry_default_date; check "default date outside current month" "$DMY" 01/10/2026

alerts_check 2026-11 2 1 "" E
check "lower bound warning" "${ALERTS[0]:0:15}" "W:Warning: Cash"

budget_set_quota 2 5000
totals_load_categories "$(date +%Y-%m)"
IFS=$'\t' read -r _ _ _ _ q <<<"${CS[0]}"
check "quota stored" "$q" 5000

trash_tx 4 2026-11-03 -
check "trashed row left month file" "$(grep -c '^4' "$M1")" 0
check "trash has one row" "$(wc -l <"$TRASH")" 1
trash_restore "$(<"$TRASH")"
check "restored row is back" "$(grep -c '^4' "$M1")" 1
check "trash empty again" "$(wc -l <"$TRASH")" 0

trash_tx 6 2026-11-05 9
check "transfer trashes both legs" "$(wc -l <"$TRASH")" 2
mapfile -t t <"$TRASH"
trash_restore "${t[0]}"
check "transfer restores both legs" "$(grep -c $'\t9\t' "$M1")" 2

trash_meta "$CATS" C 3
check "category trashed" "$(wc -l <"$CATS")" 1
trash_restore "$(<"$TRASH")"
check "category restored at the end" "$(tail -1 "$CATS")" $'3\tI\tSalary\t3'

((fail)) && { echo "FAILED"; exit 1; }
echo "all passed"
