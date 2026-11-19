# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# data/categories.sh - category lookups
#
# Depends on : data/store.sh
# Provides   : has_cat fee_cat
# Globals    : FEEC
#
# meta/categories.tsv columns: id, kind (I or E), name, sort_order

has_cat() { awk -F'\t' -v k="$1" '$2==k{f=1} END{exit !f}' "$CATS"; }

# Returns the id of the "Transfer fees" expense category in FEEC, creating it on
# first use so transfer fees show up in expense totals like any other cost.
fee_cat() {
  FEEC=$(awk -F'\t' '$2=="E" && $3=="Transfer fees"{print $1; exit}' "$CATS")
  if [[ -z $FEEC ]]; then
    next_id; FEEC=$NID; max_sort "$CATS" 4
    printf '%s\tE\tTransfer fees\t%s\n' "$FEEC" $((MS + 1)) >>"$CATS"
  fi
}
