#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Smoke test for the data writers behind the forms, against a throwaway
# directory. Needs no terminal.

export NO_COLOR=1
root=$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)
KREUZER_LIBDIR=$root/lib/kreuzer
# shellcheck source=/dev/null
source "$KREUZER_LIBDIR/main.sh" || exit 1

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
CFG[data_dir]=$tmp; CFG[currency]='$'; config_apply; store_set_paths
mkdir -p "$DATA/meta"; touch "$CATS" "$WALS" "$QUOTAS" "$BUDG" "$TRASH"

fail=0
check() { if [[ $2 == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: got [$2] want [$3]"; fail=1; fi; }
yn() { if "$@"; then echo yes; else echo no; fi; }

category_create E Food;  check "category id" "$NID" 1
category_create E Rent;  check "second category id" "$NID" 2
check "category row" "$(sed -n 1p "$CATS")" $'1\tE\tFood\t1'
category_list E
check "category list order" "${CATL[1]}" $'2\tRent'
check "name exists, case-insensitive" "$(yn category_name_exists E food)" yes
check "name exists, own id excluded" "$(yn category_name_exists E food 1)" no
check "name exists, other kind" "$(yn category_name_exists I food)" no
category_rename 1 Groceries
check "rename" "$(sed -n 1p "$CATS")" $'1\tE\tGroceries\t1'

wallet_create Cash 10000 2026-01-01 - -; check "wallet id" "$NID" 3
check "wallet row" "$(<"$WALS")" $'3\tCash\t10000\t2026-01-01\t-\t-\t1'
wallet_get 3; check "wallet_get" "$WG_NAME $WG_OPEN $WG_DATE $WG_LO" "Cash 10000 2026-01-01 -"
wallet_update 3 Bank 500 2026-02-01 100 900
check "wallet update" "$(<"$WALS")" $'3\tBank\t500\t2026-02-01\t100\t900\t1'
check "wallet name exists" "$(yn wallet_name_exists bank)" yes
check "wallet name, own id excluded" "$(yn wallet_name_exists bank 3)" no

M11=$DATA/2026-11.tsv
tx_save "" "" 2026-11-03 - E 1250 1 3 lunch
check "tx created" "$(<"$M11")" $'4\t2026-11-03\t-\tE\t1250\t1\t3\t-\tlunch'
tx_save 4 2026-11-03 2026-12-01 - E 1300 1 3 lunch
check "edit leaves old month" "$(grep -c '^4' "$M11")" 0
check "edit lands in new month" "$(<"$DATA/2026-12.tsv")" $'4\t2026-12-01\t-\tE\t1300\t1\t3\t-\tlunch'

tx_save_transfer "" "" 2026-11-05 - 1000 3 9 50 moved
check "fee category id" "$FEEC" 8
check "transfer writes three rows" "$(awk -F'\t' '$8==5' "$M11" | wc -l)" 3
check "fee category created once" "$(grep -c 'Transfer fees' "$CATS")" 1
tx_transfer_parts 5 2026-11-05
check "transfer parts" "$TP_FROM $TP_TO $TP_AMT $TP_FEE $TP_NOTE" "3 9 1000 50 moved"
tx_save_transfer 5 2026-11-05 2026-11-05 - 2000 3 9 0 moved
check "edit drops the fee row" "$(awk -F'\t' '$8==5' "$M11" | wc -l)" 2
check "no fee, FEEC empty" "[$FEEC]" "[]"
tx_transfer_parts 5 2026-11-05
check "edited parts" "$TP_AMT $TP_FEE" "2000 0"

budget_set_month 2026-01 10000
budget_set_month 2026-11 50000
budget_set_month 2026-11 60000
check "one record per month" "$(wc -l <"$BUDG")" 2
budget_for_month 2026-12; check "latest at or before" "$BUD" 60000
budget_for_month 2026-02; check "earlier month keeps its value" "$BUD" 10000

((fail)) && { echo "FAILED"; exit 1; }
echo "all passed"
