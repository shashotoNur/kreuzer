# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# forms/transfer.sh - move money between wallets
#
# Depends on : forms/entry.sh (helpers), data/categories.sh (category_ensure_fee), viz/entry.sh
# Provides   : transfer_form transfer_preview transfer_validate
# Globals    : OLD_WAL2
#
# A transfer is stored as a TO row (source) and a TI row (destination) sharing a
# transfer id, plus an optional fee row (an expense on the source wallet). All
# rows carry the same id so deleting, editing or restoring acts on the whole set.

OLD_WAL2=""

transfer_preview() {
  local na=0
  ENT_MONTH=$MONTH; ENT_WAL=${FID[1]}; ENT_WAL2=${FID[2]}; ENT_CAT=""
  money_parse "${FV[0]}" && na=$PM
  ENT_AMT=$na
  [[ -n $OLD_WAL && $ENT_WAL == "$OLD_WAL" && $ENT_WAL2 == "$OLD_WAL2" ]] && ENT_AMT=$((na - OLD_AMT))
  PVL=()
  if [[ -n ${FV[3]} ]] && money_parse "${FV[3]}" && ((PM > 0)); then
    money_format "$PM"; PVL+=("${C_DIM}Fee $M is recorded as an expense (Transfer fees).${RST}")
  fi
}

# Form-level check: each field is valid alone, but source and destination must differ.
transfer_validate() {
  [[ ${FID[1]} != "${FID[2]}" ]] || { FERR="choose two different wallets"; return 1; }
}

transfer_form() { # [row]
  local row=${1:-} id dt k cents cat wal note tr cid wid d t nt="" fw="" tw="" amt=0 fee=0 tid="" od="" ttl="Add transfer"
  local r1 r2 r3 r4 r5 r6 r7 r8 r9 va="" vfee="" vd vtm="" vf vfid vt vtid f
  ((${#WB[@]} >= 2)) || { canvas_flash "$C_WARN" "Transfers need at least two wallets"; draw; return 0; }
  FKIND=T; OLD_M=""; OLD_AMT=0; OLD_WAL=""; OLD_WAL2=""
  entry_default_date; vd=$DMY
  IFS=$'\t' read -r vfid vf _ <<<"${WB[0]}"
  IFS=$'\t' read -r vtid vt _ <<<"${WB[1]}"
  if [[ -n $row ]]; then
    IFS=$'\t' read -r id dt k cents cat wal note tr cid wid <<<"$row"
    ttl="Edit transfer"
    od=${dt%% *}; vtm=${dt#* }; [[ $vtm == - ]] && vtm=""; tid=$tr
    # Rebuild the form from all rows of the set, whichever row was selected.
    while IFS=$'\t' read -r r1 r2 r3 r4 r5 r6 r7 r8 r9; do
      case $r4 in TO) fw=$r7; amt=$r5; nt=$r9 ;; TI) tw=$r7 ;; E) fee=$r5 ;; esac
    done < <(awk -F'\t' -v t="$tid" '$8==t' "$DATA/${od:0:7}.tsv")
    [[ $nt == - ]] && nt=""
    date_display "$od"; vd=$DMY; money_plain "$amt"; va=${PL/./$DEC}
    if ((fee > 0)); then money_plain "$fee"; vfee=${PL/./$DEC}; fi
    if balances_name "$fw"; then vf=$WNM; vfid=$fw; else vf=""; vfid=""; fi
    if balances_name "$tw"; then vt=$WNM; vtid=$tw; else vt=""; vtid=""; fi
    OLD_M=${od:0:7}; OLD_AMT=$amt; OLD_WAL=$fw; OLD_WAL2=$tw
  fi
  form_begin "$ttl" transfer_preview transfer_validate viz_entry_transfer
  form_field Amount money "$va" "Amount moved out of the source wallet"
  form_field From "pick:entry_pick_wallet" "$vf" "Source wallet" "$vfid"
  form_field To "pick:entry_pick_wallet" "$vt" "Destination wallet" "$vtid"
  form_field Fee omoney "$vfee" "Optional, recorded as an expense on the source wallet"
  form_field Date date "$vd" "DD/MM/YYYY, or DD/MM for this year"
  form_field Time time "$vtm" "HH:MM, optional"
  form_field Note otext "$nt" "Optional"
  if form_run; then
    money_parse "${FV[0]}"; amt=$PM
    date_parse "${FV[4]}"; d=$PD
    t=${FV[5]}; [[ -n $t ]] || t=-
    nt=${FV[6]//$'\t'/ }; [[ -n $nt ]] || nt=-
    fee=0; if [[ -n ${FV[3]} ]]; then money_parse "${FV[3]}"; fee=$PM; fi
    # Edit = remove the whole old set, then write a new one under the same id.
    if [[ -n $tid ]]; then
      f="$DATA/${od:0:7}.tsv"; awk -F'\t' -v t="$tid" '$8!=t' "$f" | store_atomic "$f"
    else store_next_id; tid=$NID; fi
    f="$DATA/${d:0:7}.tsv"
    store_next_id; printf '%s\t%s\t%s\tTO\t%s\t-\t%s\t%s\t%s\n' "$NID" "$d" "$t" "$amt" "${FID[1]}" "$tid" "$nt" >>"$f"
    store_next_id; printf '%s\t%s\t%s\tTI\t%s\t-\t%s\t%s\t%s\n' "$NID" "$d" "$t" "$amt" "${FID[2]}" "$tid" "$nt" >>"$f"
    FEEC=""
    if ((fee > 0)); then
      category_ensure_fee; store_next_id
      printf '%s\t%s\t%s\tE\t%s\t%s\t%s\t%s\t-\n' "$NID" "$d" "$t" "$fee" "$FEEC" "${FID[1]}" "$tid" >>"$f"
    fi
    LASTW=${FID[1]}
    if ((fee > 0)); then alerts_check "${d:0:7}" "$FEEC" "${FID[1]}" "${FID[2]}" E
    else alerts_check "${d:0:7}" "" "${FID[1]}" "${FID[2]}" T; fi
    entry_save_done "$d"
  else draw; fi
}
