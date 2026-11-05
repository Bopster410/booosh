# State shared by install.sh and pack: the stable "core", its generations, and the manifest of what boosh installed.
#
#   $BOOSH_HOME/core            symlink to the current generation: everything the shell and Ghostty read lives behind it
#   $BOOSH_HOME/generations/ID  one complete snapshot per install (so a rollback is just "point core at the previous one")
#   $BOOSH_HOME/packs/NAME      snapshot of an installed pack (independent of generations)
#   $BOOSH_HOME/manifest        what boosh put where: owner <TAB> kind <TAB> live path <TAB> target <TAB> extra
#
# The repository is only the SOURCE: switching branches, moving or deleting it cannot break an installed setup.
# bash 3.2 compatible.

BOOSH_HOME="${BOOSH_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/booosh}"
BH_CORE="$BOOSH_HOME/core"
BH_GENS="$BOOSH_HOME/generations"
BH_PACKS="$BOOSH_HOME/packs"
BH_MANIFEST="$BOOSH_HOME/manifest"
BH_KEEP="${BOOSH_KEEP_GENERATIONS:-5}"

# ─── checksums ───────────────────────────────────────────
sum_of() { # sum_of FILE -> "crc-size" (cksum exists everywhere)
  cksum < "$1" 2>/dev/null | awk '{ print $1 "-" $2 }'
}

# ─── manifest ────────────────────────────────────────────
# kinds: link (live symlink -> target; extra: core|repo|packs), file (generated file; target = checksum),
#        user (a file that is yours once created; target = checksum at creation), backup (live = original, target = backup)
MF_NEW=()   # entries collected during a run, written by mf_commit

mf_add() { # mf_add KIND LIVE TARGET [EXTRA]
  MF_NEW[${#MF_NEW[@]}]="$1"$'\t'"$2"$'\t'"$3"$'\t'"${4:-}"
}

mf_commit() { # mf_commit OWNER : replace this owner's lines with the collected entries
  local owner="$1" e tmp
  mkdir -p "$BOOSH_HOME"
  tmp="$BH_MANIFEST.tmp.$$"
  # replace this owner's link/file lines; keep its backup and user lines (they must survive: they are how an uninstall
  # finds your original files and tells a file you edited from one boosh created), then drop exact duplicates
  { [ -f "$BH_MANIFEST" ] && awk -F'\t' -v o="$owner" '$1 != o || $2 == "backup" || $2 == "user"' "$BH_MANIFEST"
    if [ ${#MF_NEW[@]} -gt 0 ]; then for e in "${MF_NEW[@]}"; do printf '%s\t%s\n' "$owner" "$e"; done; fi
  } | awk '!seen[$0]++' > "$tmp" || true
  mv -f "$tmp" "$BH_MANIFEST"
  MF_NEW=()
}

mf_set_sum() { # mf_set_sum LIVE SUM : a generated file was rewritten (rollback), remember its new checksum
  [ -f "$BH_MANIFEST" ] || return 0
  awk -F'\t' -v OFS='\t' -v l="$1" -v s="$2" '$2 == "file" && $3 == l { $4 = s } { print }' "$BH_MANIFEST" > "$BH_MANIFEST.tmp.$$" \
    && mv -f "$BH_MANIFEST.tmp.$$" "$BH_MANIFEST"
}

mf_drop_live() { # mf_drop_live LIVE : forget the link/file entries of this path
  [ -f "$BH_MANIFEST" ] || return 0
  awk -F'\t' -v l="$1" '!(($2 == "link" || $2 == "file") && $3 == l)' "$BH_MANIFEST" > "$BH_MANIFEST.tmp.$$" \
    && mv -f "$BH_MANIFEST.tmp.$$" "$BH_MANIFEST"
}

mf_forget() { # mf_forget OWNER
  MF_NEW=(); mf_commit "$1"
}

mf_owner_of() { # mf_owner_of LIVE -> the owner that has a link/file entry for this path (nothing if none)
  [ -f "$BH_MANIFEST" ] && awk -F'\t' -v l="$1" '($2 == "link" || $2 == "file") && $3 == l { print $1; exit }' "$BH_MANIFEST"
  return 0
}

mf_owners_like() { # mf_owners_like PREFIX -> owners that start with PREFIX
  [ -f "$BH_MANIFEST" ] && awk -F'\t' -v p="$1" 'index($1, p) == 1 { print $1 }' "$BH_MANIFEST" | sort -u
}

# ─── generations ─────────────────────────────────────────
gen_current() { # basename of the current generation, or nothing
  [ -L "$BH_CORE" ] && basename "$(readlink "$BH_CORE")"
}

gen_list() { # ids, oldest first (the number in front is a sequence, so the order never depends on the clock)
  [ -d "$BH_GENS" ] && ls -1 "$BH_GENS" 2>/dev/null | LC_ALL=C sort
}

gen_new_id() { # NNNN-date-time-commit: one more than the newest existing number
  local last n c="nogit" dirty=""
  last="$(gen_list | tail -n 1 | sed -n 's/^\([0-9][0-9]*\)-.*/\1/p')"
  n=$((10#${last:-0} + 1))
  if c="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null)"; then
    [ -z "$(git -C "$SRC" status --porcelain 2>/dev/null)" ] || dirty="+dirty"
  else
    c="nogit"
  fi
  printf '%04d-%s-%s%s\n' "$n" "$(date +%Y%m%d-%H%M%S)" "$c" "$dirty"
}

gen_commit() { # gen_commit STAGE ID : move the finished stage in and point core at it
  mv "$1" "$BH_GENS/$2"
  ln -sfn "generations/$2" "$BH_CORE"
}

gen_prune() { # keep the newest BH_KEEP generations (never the current one)
  local cur n total i=0 id
  cur="$(gen_current)"
  total="$(gen_list | wc -l | tr -d ' ')"
  [ "$total" -gt "$BH_KEEP" ] || return 0
  for id in $(gen_list); do
    i=$((i + 1))
    [ $((total - i)) -ge "$BH_KEEP" ] || break
    [ "$id" = "$cur" ] || rm -rf "$BH_GENS/$id"
  done
}
