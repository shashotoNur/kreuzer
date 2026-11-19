# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# forms/settings.sh - currency, separators, pie ratio, trash auto-purge
#
# Depends on : ui/form.sh, config/config.sh
# Provides   : settings_form settings_validate
#
# Key bindings are not edited here; they live in the config file (see --dump-keys).

settings_validate() {
  [[ ${FV[4]} =~ ^[0-9](\.[0-9]+)?$ ]] && awk -v a="${FV[4]}" 'BEGIN{exit !(a>=1 && a<=4)}' ||
    { FERR="cell ratio must be between 1.0 and 4.0"; return 1; }
  [[ ${FV[5]} =~ ^[0-9]+$ ]] || { FERR="auto-purge days must be a whole number (0 = off)"; return 1; }
}

settings_form() {
  form_begin "Settings" "" settings_validate ""
  form_field Currency text "${CFG[currency]}" "Symbol or name, for example \$ or EUR"
  form_field Position "choice:prefix|suffix" "${CFG[currency_pos]}" "Enter toggles"
  form_field Thousands "choice:,|.|space|none" "${CFG[thousands]}" "Enter cycles"
  form_field Decimal "choice:.|," "${CFG[decimal]}" "Enter toggles"
  form_field "Cell ratio" text "${CFG[pie_aspect]}" "Cell height / width of your font, usually 2.0. Adjust if pies look oval."
  form_field "Purge days" text "${CFG[auto_purge_days]}" "Delete trash older than N days at start. 0 = never."
  if form_run; then
    CFG[currency]=${FV[0]}; CFG[currency_pos]=${FV[1]}; CFG[thousands]=${FV[2]}
    CFG[decimal]=${FV[3]}; CFG[pie_aspect]=${FV[4]}; CFG[auto_purge_days]=${FV[5]}
    config_write; config_apply
    canvas_flash "$C_OK" "Settings saved to $CONF_FILE"; refresh
  else draw; fi
}
