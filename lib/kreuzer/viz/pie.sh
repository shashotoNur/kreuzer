# shellcheck shell=bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# viz/pie.sh - aggregation, slices and the half-block pie renderer
#
# Depends on : viz/bars.sh (vp, DVER), core/text, core/money, ui/canvas.sh,
#              ui/theme.sh (PAL GRAYC NOCOL), ASP100 (config/config.sh)
# Provides   : agg make_slices pie_render swatch pie_panel sel_cat
# Out-vars   : AGG PSL LEG PTOT PIE SWT USED LEG_HL
# Globals    : AGC PIEC RINGC OTHERC GLY
#
# Pipeline: agg (group by name) -> make_slices (colours, "Other" bucket) ->
# pie_render (one awk call) -> pie_panel (title, pie and legend).

RINGC="122;128;146"    # empty-month ring
OTHERC="112;118;134"   # the "Other (n)" slice
# Glyphs used instead of colours under NO_COLOR, one per slice.
GLY=("█" "▓" "▒" "░" "#" "%" "+" "=" "~" "*" ":" "-")
USED=0; LEG_HL=""; PTOT=0; SWT=""
PIE=(); PSL=(); LEG=(); AGG=()
declare -gA AGC=() PIEC=()

# sel_cat : name of the category of the selected transaction row, so its legend
# entry can be highlighted while browsing.
sel_cat() {
  local -a f; LEG_HL=""
  ((${#ROWS_DATA[@]})) || return 0
  IFS=$'\t' read -ra f <<<"${ROWS_DATA[SEL]}"; LEG_HL=${f[4]:-}
}

# agg tx|cs KIND ARRAYNAME -> AGG ("name<TAB>cents", largest first)
# tx sums transaction rows by category name; cs reads (name, spent) from category
# rows. The result is cached because the sums run through awk and sort.
agg() {
  local -n _s=$3
  local key="$1|$2|$3|$DVER|${#_s[@]}|${#_s[0]}" out prog
  if [[ -z ${AGC["$key"]+x} ]]; then
    if [[ $1 == tx ]]; then prog='$3==k && $4>0 {s[$5]+=$4} END{for(n in s) print n "\t" s[n]}'
    else prog='$2==k && $4>0 {print $3 "\t" $4}'; fi
    out=$(printf '%s\n' "${_s[@]}" | awk -F'\t' -v k="$2" "$prog" | sort -t$'\t' -k2,2nr -k1,1)
    ((${#AGC[@]} > 60)) && AGC=()
    AGC["$key"]=$out
  fi
  if [[ -n ${AGC["$key"]} ]]; then mapfile -t AGG <<<"${AGC["$key"]}"; else AGG=(); fi
}

# AGG -> PSL (rgb<TAB>cents) for the renderer and LEG (name, cents, rgb, glyph)
# for the legend. The palette has 12 colours; beyond that the smallest
# categories are merged into one "Other" slice rather than reusing colours.
make_slices() {
  local n=${#AGG[@]} i nm cents rgb lim=12 other=0 cnt=0
  PSL=(); LEG=(); PTOT=0
  ((n > 12)) && lim=11
  for ((i = 0; i < n; i++)); do
    IFS=$'\t' read -r nm cents <<<"${AGG[i]}"
    PTOT=$((PTOT + cents))
    if ((i < lim)); then
      rgb=${PAL[i]}; [[ $nm == DELETED ]] && rgb=$GRAYC
      PSL+=("$rgb"$'\t'"$cents"); LEG+=("$nm"$'\t'"$cents"$'\t'"$rgb"$'\t'"${GLY[i]}")
    else other=$((other + cents)); cnt=$((cnt + 1)); fi
  done
  if ((other > 0)); then
    PSL+=("$OTHERC"$'\t'"$other"); LEG+=("Other ($cnt)"$'\t'"$other"$'\t'"$OTHERC"$'\t'"${GLY[11]}")
  fi
}

# swatch RGB GLYPH -> SWT : legend marker, a colour block or doubled glyph.
swatch() { if ((NOCOL)); then SWT="$2$2"; else SWT=$'\e[38;2;'"$1"'m██'"$RST"; fi; }

# pie_render WIDTH HEIGHT -> PIE (one string per terminal row), from PSL.
# Each cell holds two vertical "pixels" (an upper-half block with foreground =
# top pixel and background = bottom pixel). A cell is about twice as tall as it
# is wide, so the pixels come out square; ASP100 (cell ratio x 100) corrects
# for fonts that differ. Pixel centres are sampled at +0.5 to avoid a lopsided
# edge. atan2(dx, -dy) puts 0 at 12 o'clock and runs clockwise, the usual pie
# convention. The geometry is done in awk because the bash equivalent would
# cost thousands of arithmetic evaluations per frame. Results are cached.
pie_render() {
  local w=$1 h=$2 key out
  key="$w|$h|$ASP100|$NOCOL|${PSL[*]}"
  if [[ -z ${PIEC["$key"]+x} ]]; then
    out=$(printf '%s\n' "${PSL[@]}" | awk -F'\t' -v W="$w" -v H="$h" -v asp="$ASP100" \
      -v nc="$NOCOL" -v gl="${GLY[*]}" -v ringc="$RINGC" '
      function rc(x) { return (x == -1) ? ringc : col[x] }
      NF >= 2 { n++; col[n] = $1; v[n] = $2 + 0; tot += $2 }
      END {
        pi = atan2(0, -1); a = asp / 100; R = W / 2
        split(gl, g, " ")
        for (i = 1; i <= n; i++) { acc += v[i]; cum[i] = (tot > 0) ? acc / tot : 0 }
        for (cy = 0; cy < H; cy++) {
          line = ""; last = ""
          for (cx = 0; cx < W; cx++) {
            for (q = 0; q < 2; q++) {
              py = cy * 2 + q
              dx = cx + 0.5 - W / 2
              dy = (py + 0.5 - H) * a / 2
              d2 = dx * dx + dy * dy
              c[q] = ""
              if (d2 <= R * R) {
                if (tot > 0) {
                  t = atan2(dx, -dy); if (t < 0) t += 2 * pi
                  f = t / (2 * pi); s = 1
                  while (s < n && f >= cum[s]) s++
                  c[q] = s
                } else if (d2 >= (R - 1.4) * (R - 1.4)) c[q] = -1
              }
            }
            A = c[0]; B = c[1]
            if (nc) {
              s = (A != "") ? A : B
              ch = (s == "") ? " " : ((s == -1) ? "·" : g[s])
              line = line ch
            } else {
              if (A == "" && B == "") { sg = "\033[0m"; ch = " " }
              else if (B == "") { sg = "\033[0;38;2;" rc(A) "m"; ch = "▀" }
              else if (A == "") { sg = "\033[0;38;2;" rc(B) "m"; ch = "▄" }
              else { sg = "\033[0;38;2;" rc(A) ";48;2;" rc(B) "m"; ch = "▀" }
              if (sg != last) { line = line sg; last = sg }
              line = line ch
            }
          }
          if (!nc) line = line "\033[0m"
          print line
        }
      }')
    ((${#PIEC[@]} > 40)) && PIEC=()
    PIEC["$key"]=$out
  fi
  mapfile -t PIE <<<"${PIEC["$key"]}"
}

# pie_panel ROW COL WIDTH MAXROWS TITLE SIGN COLOUR : title, pie and legend.
# Needs PSL, LEG and PTOT from make_slices. Sets USED to the rows consumed;
# returns 1 when there is too little room, so callers can skip or stack panels.
pie_panel() {
  local row=$1 col=$2 wd=$3 rows=$4 title=$5 sgn=$6 tc=$7
  local ph pw lim lc lw n show lines top amt=0 nwid i nm cents rgb gl pc pcs nc line
  USED=0
  ph=$((rows - 2)); ((ph >= 3)) || return 1
  pw=$((ph * ASP100 / 100)); lim=$((wd * 45 / 100))
  ((pw > lim)) && pw=$lim
  ((pw < 6)) && pw=6
  # Recompute the height from the (possibly clamped) width to keep it round.
  ph=$(((pw * 100 + ASP100 - 1) / ASP100))
  if ((ph > rows - 2)); then ph=$((rows - 2)); pw=$((ph * ASP100 / 100)); fi
  ((pw >= 4)) || return 1
  pie_render "$pw" "$ph"
  fm "$PTOT"
  vp "$row" "${BOLD}${C_ACC}$title${RST}  ${tc}$sgn$M${RST}"
  for ((i = 0; i < ${#PIE[@]}; i++)); do put $((row + 1 + i)) "$col" "${PIE[i]}"; done
  USED=$((ph + 2))
  if ((PTOT == 0)); then
    put $((row + 1 + ph / 2)) $((col + (pw - 7) / 2)) "${C_DIM}no data${RST}"
    return 0
  fi
  lc=$((col + pw + 2)); lw=$((wd - pw - 2)); ((lw >= 10)) || return 0
  n=${#LEG[@]}; show=$n; ((n > ph)) && show=$((ph - 1))
  lines=$show; ((n > show)) && lines=$((show + 1))
  top=$((row + 1 + (ph - lines) / 2))
  # Amounts only fit beside the names when the legend is wide enough.
  ((lw >= 32)) && amt=12
  nwid=$((lw - 8)); ((amt)) && nwid=$((lw - 21))
  for ((i = 0; i < show; i++)); do
    IFS=$'\t' read -r nm cents rgb gl <<<"${LEG[i]}"
    swatch "$rgb" "$gl"
    pc=$((cents * 100 / PTOT)); pcs="$pc%"; ((pc == 0)) && pcs="<1%"
    rpad "$pcs" 4; pcs=$RP
    pad "$nm" "$nwid"
    nc=$C_TXT; [[ $nm == "$LEG_HL" ]] && nc=$BOLD$C_ACC
    line="$SWT ${nc}$PAD${RST} ${C_DIM}$pcs${RST}"
    if ((amt)); then fm "$cents"; rpad "$M" 12; line+=" ${C_DIM}$RP${RST}"; fi
    put $((top + i)) "$lc" "$line"
  done
  ((n > show)) && put $((top + show)) "$lc" "${C_DIM}+$((n - show)) more${RST}"
  return 0
}
