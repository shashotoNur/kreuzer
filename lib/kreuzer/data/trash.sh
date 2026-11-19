# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# data/trash.sh - move records to trash, restore, purge
#
# Depends on : data/store.sh, store_max_sort, store_row_remove, store_atomic, store_next_id
# Provides   : trash_meta trash_tx trash_restore trash_purge
# Globals    : NOW
#
# meta/trash.tsv columns: trash_id, deleted_at (epoch), kind (T C W), source_file,
# then the original record verbatim. Keeping the raw record means restoring is a
# copy back with the original id, so nothing that references it breaks.
# Transfers span several rows; all rows with the same transfer id travel together.

trash_meta() { # file kind(C|W) id
  local line
  line=$(awk -F'\t' -v i="$3" '$1==i' "$1"); [[ -n $line ]] || return 1
  printf -v NOW '%(%s)T' -1; store_next_id
  printf '%s\t%s\t%s\t-\t%s\n' "$NID" "$NOW" "$2" "$line" >>"$TRASH"
  store_row_remove "$1" "$3"
}

trash_tx() { # id iso_date transfer_id
  local f="$DATA/${2:0:7}.tsv" src="${2:0:7}.tsv" line
  printf -v NOW '%(%s)T' -1
  if [[ $3 != - ]]; then
    while IFS= read -r line; do
      store_next_id; printf '%s\t%s\tT\t%s\t%s\n' "$NID" "$NOW" "$src" "$line" >>"$TRASH"
    done < <(awk -F'\t' -v t="$3" '$8==t' "$f")
    awk -F'\t' -v t="$3" '$8!=t' "$f" | store_atomic "$f"
  else
    line=$(awk -F'\t' -v i="$1" '$1==i' "$f"); [[ -n $line ]] || return 1
    store_next_id; printf '%s\t%s\tT\t%s\t%s\n' "$NID" "$NOW" "$src" "$line" >>"$TRASH"
    store_row_remove "$f" "$1"
  fi
}

# A restored category or wallet goes to the end of its list: reusing the old sort
# position could collide with a sort_order that was handed out since.
trash_restore() { # one trash row
  local tid ts kind src r1 r2 r3 r4 r5 r6 r7 r8 r9 l so
  local -a sib
  IFS=$'\t' read -r tid ts kind src r1 r2 r3 r4 r5 r6 r7 r8 r9 <<<"$1"
  case $kind in
    T)
      if [[ $r8 != - ]]; then mapfile -t sib < <(awk -F'\t' -v t="$r8" '$3=="T" && $12==t' "$TRASH")
      else sib=("$1"); fi
      for l in "${sib[@]}"; do
        printf '%s\n' "$(cut -f5- <<<"$l")" >>"$DATA/$(cut -f4 <<<"$l")"
        store_row_remove "$TRASH" "$(cut -f1 <<<"$l")"
      done ;;
    C)
      store_max_sort "$CATS" 4; so=$((MS + 1))
      printf '%s\t%s\t%s\t%s\n' "$r1" "$r2" "$r3" "$so" >>"$CATS"
      store_row_remove "$TRASH" "$tid" ;;
    W)
      store_max_sort "$WALS" 7; so=$((MS + 1))
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$r1" "$r2" "$r3" "$r4" "$r5" "$r6" "$so" >>"$WALS"
      store_row_remove "$TRASH" "$tid" ;;
  esac
}

trash_purge() { # one trash row
  local tid ts kind src r1 r2 r3 r4 r5 r6 r7 r8 r9
  IFS=$'\t' read -r tid ts kind src r1 r2 r3 r4 r5 r6 r7 r8 r9 <<<"$1"
  case $kind in
    T) if [[ $r8 != - ]]; then awk -F'\t' -v t="$r8" '!($3=="T" && $12==t)' "$TRASH" | store_atomic "$TRASH"
       else store_row_remove "$TRASH" "$tid"; fi ;;
    C) store_row_remove "$TRASH" "$tid"; awk -F'\t' -v c="$r1" '$2!=c' "$QUOTAS" | store_atomic "$QUOTAS" ;;
    *) store_row_remove "$TRASH" "$tid" ;;
  esac
}
