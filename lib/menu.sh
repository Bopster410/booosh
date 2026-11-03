# Arrow-key menu in plain bash (3.2+, no dependencies). Source this file.
#
#   menu_ok                              true when stdin/stdout are a real terminal
#   select_menu VAR "label" DEFAULT opt...
#       Up/Down or k/j move, 1-9 jump, Enter (or Space) selects, Ctrl+C aborts.
#       Sets VAR. DEFAULT is the preselected option (first option if it is not in the list).
#       If a function  menu_desc VAR OPTION  exists, its output is shown next to each option.
#       Live preview: if  menu_preview_lines VAR  prints a number P > 0, then  menu_preview VAR OPTION
#       is called for the highlighted option and its first P lines are drawn under the list
#       (padded with blank lines, so the layout never jumps). Skipped on terminals too short for it.
#       Live cursor: if  menu_cursor_info VAR  prints "UP COL" (the sample line is UP lines above the
#       bottom of the preview, the cursor goes to column COL), then  menu_cursor_shape VAR OPTION  prints
#       a DECSCUSR code 1-6 (1/3/5 blink, 2/4/6 steady: block/underline/bar) or nothing to hide the
#       cursor. The real terminal cursor is moved there and reshaped; it is reset (CSI 0 SP q) afterwards.
#
# The menu redraws itself in place and collapses to one "✔ label: value" line when done.
# Previews are drawn in a dim frame ("┌─ preview ──"); define  menu_preview_frame VAR  printing "no"
# to skip the frame (the theme preview has its own boxes). Line wrapping is switched off while a menu
# is open, so a line wider than the terminal is clipped instead of breaking the redraw.

menu_ok() { [ -t 0 ] && [ -t 1 ] && [ "${TERM:-dumb}" != dumb ]; }

_menu_utf8() {
  case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in *UTF-8*|*utf-8*|*UTF8*|*utf8*) return 0 ;; esac
  return 1
}

_menu_size() { # prints "ROWS COLS" of the terminal ("24 80" when unknown)
  local r c
  if read -r r c < <(stty size 2>/dev/null) && [ "${r:-0}" -gt 0 ] && [ "${c:-0}" -gt 0 ]; then echo "$r $c"; else echo "24 80"; fi
}

_menu_abort() {
  printf '\033[0 q\033[?7h\033[?25h\n'
  stty echo 2>/dev/null || true
  exit 130
}

# frame pieces: "  ┌─ preview ───", "  │<content>", "  └───" (open on the right, so no width maths)
_frame_init() { # sets _FR_TL _FR_V _FR_BL _FR_C _FR_R
  if [ -z "${NO_COLOR:-}" ]; then _FR_C=$'\033[90m'; _FR_R=$'\033[0m'; else _FR_C=""; _FR_R=""; fi
  if _menu_utf8; then
    _FR_TL="┌─ preview ──────────────────────────────────"; _FR_V="│"; _FR_BL="└────────────────────────────────────────────"
  else
    _FR_TL="+- preview ----------------------------------"; _FR_V="|"; _FR_BL="+--------------------------------------------"
  fi
}

_frame_wanted() { # _frame_wanted VAR -> true when the preview of VAR gets a frame
  if type menu_preview_frame >/dev/null 2>&1 && [ "$(menu_preview_frame "$1")" = no ]; then return 1; fi
  return 0
}

_frame_print() { # _frame_print FRAMED CONTENT_ARRAY_NAME COUNT : the preview lines, framed or bare
  local fr="$1" arr="$2" n="$3" i line
  if [ "$fr" = 1 ]; then printf '\033[2K  %s%s%s\n' "$_FR_C" "$_FR_TL" "$_FR_R"; fi
  for ((i = 0; i < n; i++)); do
    eval "line=\"\${$arr[$i]:-}\""
    if [ "$fr" = 1 ]; then printf '\033[2K  %s%s%s%s\n' "$_FR_C" "$_FR_V" "$_FR_R" "$line"; else printf '\033[2K%s\n' "$line"; fi
  done
  if [ "$fr" = 1 ]; then printf '\033[2K  %s%s%s\n' "$_FR_C" "$_FR_BL" "$_FR_R"; fi
}

_menu_draw() { # uses the _M_* globals set by select_menu
  local i line
  for ((i = 0; i < _M_N; i++)); do
    if [ "$i" -eq "$_M_CUR" ]; then
      printf '\033[2K  %s%s %-*s%s' "$_M_ON" "$_M_PTR" "$_M_W" "${_M_OPTS[$i]}" "$_M_OFF"
    else
      printf '\033[2K    %-*s' "$_M_W" "${_M_OPTS[$i]}"
    fi
    if [ -n "${_M_DESC[$i]}" ]; then printf '  %s%s%s' "$_M_DIM" "${_M_DESC[$i]}" "$_M_OFF"; fi
    printf '\n'
  done
  if [ "$_M_P" -gt 0 ]; then
    if [ "$_M_PCUR" -ne "$_M_CUR" ]; then _menu_preview_load; fi
    _frame_print "$_M_FR" _M_PREV "$_M_P"
  fi
}

_menu_cursor_place() { # park the real cursor on the preview's sample line, in the shape of the highlighted option
  local code
  code="$(menu_cursor_shape "$_M_VAR" "${_M_OPTS[$_M_CUR]}")"
  if [ -n "$code" ]; then
    printf '\033[%dA\033[%dG\033[%s q\033[?25h' "$_M_LUP" "$_M_LCOL" "$code"
    _M_MOVED=1
  fi
}

_menu_preview_load() { # fills _M_PREV with exactly the preview lines of the highlighted option
  local line i=0
  _M_PREV=()
  while IFS= read -r line; do
    if [ "$i" -lt "$_M_P" ]; then _M_PREV[$i]="$line"; fi
    i=$((i + 1))
  done <<< "$(menu_preview "$_M_VAR" "${_M_OPTS[$_M_CUR]}")"
  _M_PCUR=$_M_CUR
}

select_menu() {
  local var="$1" label="$2" def="$3"; shift 3
  _M_VAR="$var"; _M_OPTS=("$@"); _M_N=$#; _M_CUR=0; _M_W=0
  _M_DESC=()
  local i key rest
  for ((i = 0; i < _M_N; i++)); do
    [ "${_M_OPTS[$i]}" = "$def" ] && _M_CUR=$i
    [ ${#_M_OPTS[$i]} -gt "$_M_W" ] && _M_W=${#_M_OPTS[$i]}
    if type menu_desc >/dev/null 2>&1; then _M_DESC[$i]="$(menu_desc "$var" "${_M_OPTS[$i]}")"; else _M_DESC[$i]=""; fi
  done

  _M_P=0; _M_PREV=(); _M_PCUR=-1; _M_FR=0; _M_PT=0
  if type menu_preview_lines >/dev/null 2>&1 && type menu_preview >/dev/null 2>&1; then
    _M_P="$(menu_preview_lines "$var")"
    if [ "$_M_P" -gt 0 ] && _frame_wanted "$var"; then _M_FR=1; _frame_init; fi
    local rows _c; read -r rows _c <<< "$(_menu_size)"
    # keep the whole menu on screen: no preview on a terminal that is too short
    [ $((_M_N + _M_P + 2 * _M_FR + 3)) -le "$rows" ] || { _M_P=0; _M_FR=0; }
    _M_PT=$((_M_P + 2 * _M_FR))
  fi

  _M_LIVE=0; _M_LUP=0; _M_LCOL=0; _M_MOVED=0
  if [ "$_M_P" -gt 0 ] && type menu_cursor_info >/dev/null 2>&1 && type menu_cursor_shape >/dev/null 2>&1; then
    local info; info="$(menu_cursor_info "$var")"
    if [ -n "$info" ]; then
      read -r _M_LUP _M_LCOL <<< "$info"; _M_LIVE=1
      if [ "$_M_FR" = 1 ]; then _M_LUP=$((_M_LUP + 1)); _M_LCOL=$((_M_LCOL + 3)); fi   # bottom rule and the "  │" prefix
    fi
  fi

  if [ -z "${NO_COLOR:-}" ]; then
    _M_ON=$'\033[36;1m'; _M_DIM=$'\033[2m'; _M_OFF=$'\033[0m'; local bold=$'\033[1m' green=$'\033[32m'
  else
    _M_ON=""; _M_DIM=""; _M_OFF=""; local bold="" green=""
  fi
  local tick="*"; _M_PTR=">"
  if _menu_utf8; then tick="✔"; _M_PTR="❯"; fi

  printf '\033[?7l'   # no line wrapping while the menu is open
  printf '%s%s%s %s(↑/↓ move, Enter select)%s\n' "$bold" "$label" "$_M_OFF" "$_M_DIM" "$_M_OFF"
  printf '\033[?25l'
  trap '_menu_abort' INT TERM
  while :; do
    _menu_draw
    _M_MOVED=0
    if [ "$_M_LIVE" = 1 ]; then _menu_cursor_place; fi
    IFS= read -rsn1 key || key=""
    if [ "$_M_MOVED" = 1 ]; then printf '\033[?25l\r\033[%dB' "$_M_LUP"; fi   # back to the bottom of the menu
    case "$key" in
      $'\033')
        IFS= read -rsn2 -t 1 rest || rest=""
        case "$rest" in
          '[A'|'OA') _M_CUR=$(( (_M_CUR + _M_N - 1) % _M_N )) ;;
          '[B'|'OB') _M_CUR=$(( (_M_CUR + 1) % _M_N )) ;;
        esac ;;
      k) _M_CUR=$(( (_M_CUR + _M_N - 1) % _M_N )) ;;
      j) _M_CUR=$(( (_M_CUR + 1) % _M_N )) ;;
      [1-9]) if [ $((key - 1)) -lt "$_M_N" ]; then _M_CUR=$((key - 1)); fi ;;
      ''|' ') break ;;
    esac
    printf '\033[%dA' $((_M_N + _M_PT))
  done
  trap - INT TERM

  printf '\033[%dA\033[J' $((_M_N + _M_PT + 1))
  if [ "$_M_LIVE" = 1 ]; then printf '\033[0 q'; fi
  printf '\033[?7h\033[?25h'
  printf '%s%s%s %s: %s\n' "$green" "$tick" "$_M_OFF" "${label%:}" "${_M_OPTS[$_M_CUR]}"
  printf -v "$var" '%s' "${_M_OPTS[$_M_CUR]}"
}

# ─── slider ──────────────────────────────────────────────
#   select_slider VAR "label" MIN MAX STEP DEFAULT
#       Left/Right (h/l, -/+, Down/Up) change the value by STEP, Enter or Space selects.
#       Numbers may have up to 2 decimals (for example 8 32 0.5 13). Sets VAR to e.g. "13.5".
#       The default is snapped to the nearest step and clamped into MIN..MAX.
#       Live preview: if  slider_preview_lines VAR  prints P > 0, then  slider_preview VAR VALUE  is
#       called after every change and its first P lines are drawn under the slider.

_sl_h() { # "13.5" -> 1350 (hundredths); non-numbers -> 0
  local s="$1" i f=""
  case "$s" in ''|*[!0-9.]*|*.*.*) echo 0; return ;; esac
  i="${s%%.*}"
  case "$s" in *.*) f="${s#*.}" ;; esac
  f="${f}00"; f="${f:0:2}"
  echo $(( 10#${i:-0} * 100 + 10#$f ))
}

_sl_fmt() { # 1350 -> 13.5, 1300 -> 13, 105 -> 1.05
  local v="$1" i f
  i=$((v / 100)); f=$((v % 100))
  if [ "$f" -eq 0 ]; then echo "$i"
  elif [ $((f % 10)) -eq 0 ]; then echo "$i.$((f / 10))"
  else printf '%d.%02d\n' "$i" "$f"; fi
}

_sl_draw() { # uses _S_* globals
  local pos=$(( (_S_VAL - _S_MIN) * (_S_W - 1) / (_S_MAX - _S_MIN) )) i bar=""
  for ((i = 0; i < _S_W; i++)); do
    if [ "$i" -lt "$pos" ]; then bar="$bar$_S_FILL"
    elif [ "$i" -eq "$pos" ]; then bar="$bar$_S_ON$_S_KNOB$_S_OFF$_S_DIM"
    else bar="$bar$_S_EMPTY"; fi
  done
  printf '\r\033[2K  %s%s%s %s%s%s%s %s%s%s  %s%s%s' \
    "$_S_DIM" "$(_sl_fmt "$_S_MIN")" "$_S_OFF" "$_S_ON" "$bar" "$_S_OFF" "" \
    "$_S_DIM" "$(_sl_fmt "$_S_MAX")" "$_S_OFF" "$_S_ON" "$(_sl_fmt "$_S_VAL")" "$_S_OFF"
  printf '\n'
  if [ "$_S_P" -gt 0 ]; then
    _slider_preview_load
    _frame_print "$_S_FR" _S_PREV "$_S_P"
  fi
}

_slider_preview_load() { # fills _S_PREV with exactly the preview lines for the current value
  local line i=0
  _S_PREV=()
  while IFS= read -r line; do
    if [ "$i" -lt "$_S_P" ]; then _S_PREV[$i]="$line"; fi
    i=$((i + 1))
  done <<< "$(slider_preview "$_S_VAR" "$(_sl_fmt "$_S_VAL")")"
}

select_slider() {
  local var="$1" label="$2" min step def key rest
  _S_MIN="$(_sl_h "$3")"; _S_MAX="$(_sl_h "$4")"; step="$(_sl_h "$5")"; def="$(_sl_h "$6")"
  [ "$step" -gt 0 ] && [ "$_S_MAX" -gt "$_S_MIN" ] || { printf -v "$var" '%s' "$6"; return 0; }
  # snap the default to the grid and clamp it
  [ "$def" -lt "$_S_MIN" ] && def="$_S_MIN"
  [ "$def" -gt "$_S_MAX" ] && def="$_S_MAX"
  _S_VAL=$(( _S_MIN + ( (def - _S_MIN + step / 2) / step ) * step ))
  [ "$_S_VAL" -gt "$_S_MAX" ] && _S_VAL=$(( _S_MIN + ( (_S_MAX - _S_MIN) / step ) * step ))
  _S_W=40
  _S_VAR="$var"; _S_P=0; _S_PREV=(); _S_FR=0; _S_PT=0
  if type slider_preview_lines >/dev/null 2>&1 && type slider_preview >/dev/null 2>&1; then
    _S_P="$(slider_preview_lines "$var")"
    if [ "$_S_P" -gt 0 ] && _frame_wanted "$var"; then _S_FR=1; _frame_init; fi
    local rows _c; read -r rows _c <<< "$(_menu_size)"
    [ $((_S_P + 2 * _S_FR + 4)) -le "$rows" ] || { _S_P=0; _S_FR=0; }     # keep the whole control on screen
    _S_PT=$((_S_P + 2 * _S_FR))
  fi

  if [ -z "${NO_COLOR:-}" ]; then
    _S_ON=$'\033[36;1m'; _S_DIM=$'\033[2m'; _S_OFF=$'\033[0m'; local bold=$'\033[1m' green=$'\033[32m'
  else
    _S_ON=""; _S_DIM=""; _S_OFF=""; local bold="" green=""
  fi
  local tick="*"; _S_FILL="="; _S_KNOB="O"; _S_EMPTY="-"
  if _menu_utf8; then tick="✔"; _S_FILL="━"; _S_KNOB="●"; _S_EMPTY="─"; fi
  _S_FILL="$_S_ON$_S_FILL$_S_OFF$_S_ON"   # filled part in colour, knob/empty handled in _sl_draw
  _S_EMPTY="$_S_OFF$_S_DIM$_S_EMPTY$_S_OFF$_S_DIM"

  printf '\033[?7l'   # no line wrapping while the control is open
  printf '%s%s%s %s(←/→ adjust, Enter select)%s\n' "$bold" "$label" "$_S_OFF" "$_S_DIM" "$_S_OFF"
  printf '\033[?25l'
  trap '_menu_abort' INT TERM
  while :; do
    _sl_draw
    IFS= read -rsn1 key || key=""
    case "$key" in
      $'\033')
        IFS= read -rsn2 -t 1 rest || rest=""
        case "$rest" in
          '[D'|'OD'|'[B'|'OB') _S_VAL=$(( _S_VAL - step )) ;;
          '[C'|'OC'|'[A'|'OA') _S_VAL=$(( _S_VAL + step )) ;;
        esac ;;
      h|-|j) _S_VAL=$(( _S_VAL - step )) ;;
      l|+|=|k) _S_VAL=$(( _S_VAL + step )) ;;
      ''|' ') break ;;
    esac
    [ "$_S_VAL" -lt "$_S_MIN" ] && _S_VAL="$_S_MIN"
    [ "$_S_VAL" -gt "$_S_MAX" ] && _S_VAL="$_S_MAX"
    printf '\033[%dA' $((_S_PT + 1))
  done
  trap - INT TERM

  printf '\033[%dA\033[J\033[?7h\033[?25h' $((_S_PT + 2))
  printf '%s%s%s %s: %s\n' "$green" "$tick" "$_S_OFF" "${label%:}" "$(_sl_fmt "$_S_VAL")"
  printf -v "$var" '%s' "$(_sl_fmt "$_S_VAL")"
}
