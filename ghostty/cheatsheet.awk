# Builds the markdown keybind tables of the cheatsheet.
# Input lines:  "<c|s> keybind = <trigger>=<action>"   (c = your preset, s = stock Ghostty)
# Usage: awk -v haveCustom=1 -f cheatsheet.awk < lines
# POSIX awk only (macOS awk too): no gensub, no length(array).

function arrow(t) {
  if (t == "up") return "↑"; if (t == "down") return "↓"
  if (t == "left") return "←"; if (t == "right") return "→"
  return ""
}

# one raw key token -> canonical lowercase name used for comparisons
function nkey(t,   a) {
  sub(/^physical:/, "", t); sub(/^digit_/, "", t); sub(/^key_/, "", t); sub(/^arrow_/, "", t)
  if (t == "bracket_left") return "["
  if (t == "bracket_right") return "]"
  if (t == "page_up") return "pgup"
  if (t == "page_down") return "pgdn"
  if (t == "equal") return "="
  if (t == "minus") return "-"
  if (t == "comma") return ","
  if (t == "plus") return "+"
  return t
}

# strip action prefixes like performable:/global:/all:/unconsumed:
function unprefix(s) {
  while (match(s, /^(performable|global|all|unconsumed):/)) s = substr(s, RLENGTH + 1)
  return s
}

# canonical form of a whole trigger, e.g. "alt+key_r>arrow_up" -> "alt+r>up"
function canon(trig,   s, n, parts, i, m, toks, j, out, seg) {
  s = unprefix(trig)
  if (sub(/\+\+$/, "+plus", s)) { }
  n = split(s, parts, ">")
  out = ""
  for (i = 1; i <= n; i++) {
    m = split(parts[i], toks, "+")
    seg = ""
    for (j = 1; j <= m; j++) seg = seg (j > 1 ? "+" : "") nkey(toks[j])
    out = out (i > 1 ? ">" : "") seg
  }
  return out
}

function capkey(t,   a) {
  a = arrow(t); if (a != "") return a
  if (t == "pgup") return "PgUp"
  if (t == "pgdn") return "PgDn"
  if (length(t) == 1) return toupper(t)
  return toupper(substr(t, 1, 1)) substr(t, 2)
}

# canonical trigger -> human text, e.g. "alt+r>up" -> "Alt+R, then ↑"
function disp(c,   n, parts, i, m, toks, j, out, seg) {
  n = split(c, parts, ">")
  out = ""
  for (i = 1; i <= n; i++) {
    m = split(parts[i], toks, "+")
    seg = ""
    for (j = 1; j <= m; j++) seg = seg (j > 1 ? "+" : "") capkey(toks[j])
    out = out (i > 1 ? ", then " : "") seg
  }
  return out
}

function lastkey(c,   n, parts, m, toks) {
  n = split(c, parts, ">")
  m = split(parts[n], toks, "+")
  return toks[m]
}

function normact(a) {
  if (a ~ /^copy_to_clipboard:/) return "copy_to_clipboard"
  if (a ~ /^close_tab:/) return "close_tab"
  if (a ~ /^(increase|decrease)_font_size:/) { sub(/:.*/, "", a); return a }
  if (a ~ /^inspector:/) return "inspector"
  if (a ~ /^resize_split:/) { sub(/,[0-9]+$/, "", a); return a }
  return a
}

function def(key, cat, text) {
  nrows++; RK[nrows] = key; CAT[key] = cat; TXT[key] = text
}

function addkey(key, src, text,   id) {
  id = key SUBSEP src SUBSEP text
  if (id in SEEN) return
  SEEN[id] = 1
  if (src == "c") CUS[key] = CUS[key] (CUS[key] == "" ? "" : ", ") "`" text "`"
  else            STK[key] = STK[key] (STK[key] == "" ? "" : ", ") "`" text "`"
}

BEGIN {
  def("new_split",            "Splits", "Split pane (arrow = direction)")
  def("new_split:right",      "Splits", "Split right")
  def("new_split:down",       "Splits", "Split down")
  def("new_split:left",       "Splits", "Split left")
  def("new_split:up",         "Splits", "Split up")
  def("goto_split",           "Splits", "Focus pane (arrow = direction)")
  def("goto_split:next",      "Splits", "Focus next pane")
  def("goto_split:previous",  "Splits", "Focus previous pane")
  def("goto_split:up",        "Splits", "Focus pane above")
  def("goto_split:down",      "Splits", "Focus pane below")
  def("goto_split:left",      "Splits", "Focus pane left")
  def("goto_split:right",     "Splits", "Focus pane right")
  def("resize_split",         "Splits", "Resize pane (arrow = direction)")
  def("resize_split:up",      "Splits", "Resize pane up")
  def("resize_split:down",    "Splits", "Resize pane down")
  def("resize_split:left",    "Splits", "Resize pane left")
  def("resize_split:right",   "Splits", "Resize pane right")
  def("toggle_split_zoom",    "Splits", "Zoom / unzoom pane")
  def("equalize_splits",      "Splits", "Equalize pane sizes")
  def("close_surface",        "Splits", "Close pane (the last pane closes the tab)")

  def("new_tab",              "Tabs", "New tab")
  def("close_tab",            "Tabs", "Close tab with all its panes")
  def("previous_tab",         "Tabs", "Previous tab")
  def("next_tab",             "Tabs", "Next tab")
  def("goto_tab",             "Tabs", "Tab by number")
  def("last_tab",             "Tabs", "Last tab")
  def("move_tab:-1",          "Tabs", "Move tab left")
  def("move_tab:1",           "Tabs", "Move tab right")
  def("new_window",           "Tabs", "New window")

  def("jump_to_prompt:-1",    "Scrollback and prompts", "Jump to previous prompt")
  def("jump_to_prompt:1",     "Scrollback and prompts", "Jump to next prompt")
  def("scroll_page_up",       "Scrollback and prompts", "Scroll page up")
  def("scroll_page_down",     "Scrollback and prompts", "Scroll page down")
  def("scroll_to_top",        "Scrollback and prompts", "Scroll to top")
  def("scroll_to_bottom",     "Scrollback and prompts", "Scroll to bottom")
  def("start_search",         "Scrollback and prompts", "Search the scrollback")

  def("copy_to_clipboard",    "Clipboard", "Copy")
  def("paste_from_clipboard", "Clipboard", "Paste")
  def("paste_from_selection", "Clipboard", "Paste selection")
  def("select_all",           "Clipboard", "Select all")

  def("toggle_command_palette", "Misc", "Command palette (search every action)")
  def("reload_config",        "Misc", "Reload config")
  def("open_config",          "Misc", "Open config file")
  def("increase_font_size",   "Misc", "Bigger font")
  def("decrease_font_size",   "Misc", "Smaller font")
  def("reset_font_size",      "Misc", "Reset font size")
  def("toggle_fullscreen",    "Misc", "Fullscreen")
  def("inspector",            "Misc", "Inspector (shows key events)")
  def("quit",                 "Misc", "Quit Ghostty")

  FAM["new_split"] = 1; FAM["goto_split"] = 1; FAM["resize_split"] = 1
  split("up down left right", DIRS, " ")
  ng = 0
}

{
  src = substr($0, 1, 1)
  line = substr($0, 3)
  sub(/^keybind = /, "", line)
  p = 0
  for (i = length(line); i > 0; i--) if (substr(line, i, 1) == "=") { p = i; break }
  if (p < 2) next
  trig = substr(line, 1, p - 1)
  act = normact(substr(line, p + 1))
  c = canon(trig)

  if (src == "c") CT[c] = 1
  else if (c in CT) next            # stock bind shadowed by one of yours

  if (act ~ /^goto_tab:/) {         # collapse 1..8 into one row
    if (act != "goto_tab:1") next
    d = disp(c); sub(/1$/, "1–8", d)
    addkey("goto_tab", src, d)
    next
  }

  # arrow-key family: new_split / goto_split / resize_split with the matching arrow
  fam = act; sub(/:.*/, "", fam)
  dir = act; sub(/^[^:]*:/, "", dir)
  lk = lastkey(c)
  if ((fam in FAM) && (lk == dir) && arrow(dir) != "") {
    prefix = substr(c, 1, length(c) - length(dir))
    g = src SUBSEP fam SUBSEP prefix
    if (!(g in GSEEN)) { GSEEN[g] = 1; ng++; GORD[ng] = g }
    GDIR[g, dir] = 1
    GFULL[g, dir] = disp(c)
    next
  }

  if (act in CAT) addkey(act, src, disp(c))
}

END {
  for (k = 1; k <= ng; k++) {
    g = GORD[k]
    split(g, gp, SUBSEP)
    gsrc = gp[1]; gfam = gp[2]; gpre = gp[3]
    all = 1
    for (i = 1; i <= 4; i++) if (!((g, DIRS[i]) in GDIR)) all = 0
    if (all) {
      if (gpre == "") t = "↑↓←→"
      else if (substr(gpre, length(gpre)) == ">") t = disp(substr(gpre, 1, length(gpre) - 1)) ", then ↑↓←→"
      else t = disp(substr(gpre, 1, length(gpre) - 1)) "+↑↓←→"
      addkey(gfam, gsrc, t)
    } else {
      for (i = 1; i <= 4; i++) if ((g, DIRS[i]) in GDIR) addkey(gfam ":" DIRS[i], gsrc, GFULL[g, DIRS[i]])
    }
  }

  lastcat = ""
  for (r = 1; r <= nrows; r++) {
    key = RK[r]
    if (CUS[key] == "" && STK[key] == "") continue
    if (CAT[key] != lastcat) {
      if (lastcat != "") print ""
      print "### " CAT[key]
      print ""
      if (haveCustom + 0) { print "| Action | Your keys | Stock keys |"; print "|---|---|---|" }
      else                { print "| Action | Keys |"; print "|---|---|" }
      lastcat = CAT[key]
    }
    if (haveCustom + 0) print "| " TXT[key] " | " (CUS[key] == "" ? "—" : CUS[key]) " | " (STK[key] == "" ? "—" : STK[key]) " |"
    else                print "| " TXT[key] " | " (STK[key] == "" ? CUS[key] : STK[key]) " |"
  }
}
