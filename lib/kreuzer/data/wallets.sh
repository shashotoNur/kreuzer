# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# data/wallets.sh - wallet records (balances are computed in domain/balances.sh)
#
# Depends on : data/store.sh
# Provides   : wallet_name_exists wallet_get wallet_create wallet_update
# Out-vars   : WG_NAME WG_OPEN WG_DATE WG_LO WG_UP NID
#
# meta/wallets.tsv columns: id, name, opening_cents, opening_date, lower, upper,
# sort_order. "-" stands for "no bound".

# wallet_name_exists NAME [EXCLUDE_ID] : status 0 if another wallet has the name.
wallet_name_exists() {
  awk -F'\t' -v n="${1,,}" -v i="${2:-}" 'tolower($2)==n && $1!=i{f=1} END{exit !f}' "$WALS"
}

# The list rows carry no opening data, so editing reads the full record here.
wallet_get() { # id
  local line
  line=$(awk -F'\t' -v i="$1" '$1==i' "$WALS"); [[ -n $line ]] || return 1
  IFS=$'\t' read -r _ WG_NAME WG_OPEN WG_DATE WG_LO WG_UP _ <<<"$line"
}

wallet_create() { # name opening_cents opening_date lower upper -> NID
  store_next_id; store_max_sort "$WALS" 7
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$NID" "$1" "$2" "$3" "$4" "$5" $((MS + 1)) >>"$WALS"
}

wallet_update() { # id name opening_cents opening_date lower upper
  awk -F'\t' -v OFS='\t' -v i="$1" -v n="$2" -v o="$3" -v d="$4" -v lo="$5" -v up="$6" \
    '$1==i{$2=n; $3=o; $4=d; $5=lo; $6=up} 1' "$WALS" | store_atomic "$WALS"
}
