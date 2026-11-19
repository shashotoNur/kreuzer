# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# forms/category.sh - add or edit a category and its quota
#
# Depends on : ui/form.sh, data/categories.sh, data/budget.sh, domain/alerts.sh
# Provides   : category_form category_validate
# Globals    : CF_ID CF_KIND

CF_ID=""; CF_KIND=""

# Names must be unique within a type. The type is fixed once a category exists,
# because changing it would silently reclassify old transactions.
category_validate() {
  local k=$CF_KIND
  if [[ -z $CF_ID ]]; then k=I; [[ ${FV[1]} == Expense ]] && k=E; fi
  if category_name_exists "$k" "${FV[0]}" "$CF_ID"; then
    FERR="a category with that name and type already exists"; return 1
  fi
}

category_form() { # [row]
  local row=${1:-} id="" kd=I nm="" sp=0 q=0 vq="" ttl="Add category" qi=-1 newq
  if [[ -n $row ]]; then IFS=$'\t' read -r id kd nm sp q <<<"$row"; ttl="Edit category"; fi
  CF_ID=$id; CF_KIND=$kd
  if ((q > 0)); then money_plain "$q"; vq=${PL/./$DEC}; fi
  form_begin "$ttl" "" category_validate ""
  form_field Name text "$nm" "Unique within its type"
  [[ -z $id ]] && form_field Type "choice:Income|Expense" Expense "Enter toggles Income and Expense"
  # Only expense categories have quotas; qi remembers which field holds it.
  if [[ -z $id || $kd == E ]]; then
    form_field Quota omoney "$vq" "Optional monthly limit. Applies from this month on."
    qi=$((${#FL[@]} - 1))
  fi
  if form_run; then
    nm=${FV[0]}
    if [[ -z $id ]]; then
      kd=I; [[ ${FV[1]} == Expense ]] && kd=E
      category_create "$kd" "$nm"; id=$NID
    else
      category_rename "$id" "$nm"
    fi
    ALERTS=()
    if [[ $kd == E ]] && ((qi >= 0)); then
      newq=0; if [[ -n ${FV[qi]} ]]; then money_parse "${FV[qi]}"; newq=$PM; fi
      if ((newq != q)); then
        # Only changing an existing quota is discouraged; setting a first one is not.
        if ((q > 0)) && ! widget_confirm "Changing a quota is discouraged: it blurs month comparisons. Change anyway?"; then
          canvas_flash "$C_WARN" "Quota left unchanged."
        else
          budget_set_quota "$id" "$newq"; alerts_quota_budget "$(date +%Y-%m)"
        fi
      fi
    fi
    canvas_flash "$C_OK" "Saved."; refresh; widget_alerts
  else draw; fi
}
