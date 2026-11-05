# Where packs come from, and how they are downloaded. Used by `pack`. bash 3.2 compatible.
#
# A SOURCE (what you give to `./pack add`) is one of
#   NAME                      a pack of the catalog (packs.conf: CATALOG=...), or one shipped in this repository
#   OWNER/REPO[@REF]          a GitHub repository, fisher style (REF = tag, branch or commit)
#   github:OWNER/REPO[@REF]   the same, spelled out
#   https://host/file.tar.gz  an archive
#   /path, ./path, ~/path     a folder on this machine (development, offline)
# A downloaded archive is unpacked into a fresh folder, checked (no symlinks), and only then installed.
# Nothing is ever downloaded over plain http, and nothing is executed while downloading.

BH_CACHE="$BOOSH_HOME/cache"

sha256_of() { # sha256_of FILE -> hex digest, or "unverified" when no tool exists
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else echo unverified; fi
}

src_kind() { # src_kind ARG -> none (a plain pack name) | github | url | local | bad
  case "$1" in
    github:*) echo github ;;
    http://*) echo bad ;;
    https://*) echo url ;;
    /*|./*|../*|~*|.|..) echo local ;;
    */*) if [ -d "$1" ]; then echo local; else echo github; fi ;;   # OWNER/REPO, unless such a folder exists
    *) echo none ;;
  esac
}

src_path() { # a local source with ~ expanded
  case "$1" in "~"*) echo "$HOME${1#\~}" ;; *) echo "$1" ;; esac
}

src_github_parse() { # src_github_parse SPEC -> sets SRC_REPO, SRC_REF ; fails on a malformed spec
  local s="${1#github:}"
  SRC_REPO="${s%%@*}"; SRC_REF=""
  case "$s" in *@*) SRC_REF="${s#*@}" ;; esac
  case "$SRC_REPO" in */*/*|''|/*|*/) return 1 ;; esac
  case "$SRC_REPO" in *[!A-Za-z0-9._/-]*) return 1 ;; esac
  case "$SRC_REF" in *[!A-Za-z0-9._/-]*) return 1 ;; esac
  case "$SRC_REPO" in */*) ;; *) return 1 ;; esac
  return 0
}

src_slug() { # a pack name made of [a-z0-9_-] from a repository / folder / archive name
  echo "$1" | tr 'A-Z' 'a-z' | sed 's/\.tar\.gz$//; s/\.tgz$//; s/[^a-z0-9_-]/-/g; s/^-*//; s/-*$//'
}

src_plugin_name() { # the name fisher uses for events: the last path part without .fish
  local b; b="$(basename "$1")"
  echo "${b%.tar.gz}" | sed 's/\.fish$//'
}

src_pinned() { # is this spec fixed to one commit (40 hex digits) or a local folder?
  local ref=""
  case "$1" in *@*) ref="${1##*@}" ;; esac
  case "$(src_kind "$1")" in local) return 0 ;; esac
  [ "${#ref}" -eq 40 ] && case "$ref" in *[!0-9a-f]*) return 1 ;; *) return 0 ;; esac
  return 1
}

# fetch_into SPEC DEST : fill the empty folder DEST with the contents of SPEC. Sets FETCH_SHA (digest of the archive,
# or "local"). Prints the reason on stderr and returns 1 on any problem.
fetch_into() {
  local spec="$1" dest="$2" kind url tmp p
  FETCH_SHA=""
  kind="$(src_kind "$spec")"
  mkdir -p "$dest"
  case "$kind" in
    local)
      p="$(src_path "$spec")"
      [ -d "$p" ] || { echo "no such folder: $p" >&2; return 1; }
      cp -R "$p/." "$dest/" && rm -rf "$dest/.git"
      FETCH_SHA=local ;;
    github|url)
      if [ "$kind" = github ]; then
        src_github_parse "$spec" || { echo "not a GitHub source: '$spec' (expected OWNER/REPO or OWNER/REPO@REF)" >&2; return 1; }
        url="https://codeload.github.com/$SRC_REPO/tar.gz/${SRC_REF:-HEAD}"
      else
        url="$spec"
      fi
      tmp="$(mktemp "${TMPDIR:-/tmp}/boosh-dl.XXXXXX")"
      if command -v curl >/dev/null 2>&1; then
        curl -fsSL --proto '=https' --max-time 90 --max-filesize 20000000 -o "$tmp" "$url" || { rm -f "$tmp"; echo "download failed: $url" >&2; return 1; }
      elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$tmp" "$url" || { rm -f "$tmp"; echo "download failed: $url" >&2; return 1; }
      else
        rm -f "$tmp"; echo "need curl or wget to download packs" >&2; return 1
      fi
      FETCH_SHA="$(sha256_of "$tmp")"
      # tar refuses absolute names and ".." members by default
      tar -xzf "$tmp" -C "$dest" --strip-components=1 2>/dev/null || { rm -f "$tmp"; echo "not a valid archive: $url" >&2; return 1; }
      rm -f "$tmp" ;;
    bad) echo "plain http:// is not allowed, use https://" >&2; return 1 ;;
    *) echo "not a source: $spec" >&2; return 1 ;;
  esac
  # a pack is plain text files; a symlink could point anywhere on this machine
  if [ -n "$(find "$dest" -type l 2>/dev/null | head -n 1)" ]; then
    echo "refusing: the download contains symbolic links ($(find "$dest" -type l | head -n 1 | sed "s|^$dest/||"))" >&2
    return 1
  fi
  return 0
}

# ─── the catalog: where `./pack add NAME` finds packs that are not in this repository ───
catalog_spec() { # BOOSH_CATALOG, else CATALOG= from packs.conf next to the scripts
  if [ -n "${BOOSH_CATALOG:-}" ]; then echo "$BOOSH_CATALOG"
  else sed -n 's/^CATALOG=//p' "$SRC/packs.conf" 2>/dev/null | head -n 1; fi
}

CATALOG_DIR=""
catalog_load() { # catalog_load [refresh] : sets CATALOG_DIR (downloaded once per run; a fixed commit is cached for good)
  local spec key dir tmp
  [ -z "$CATALOG_DIR" ] || return 0
  spec="$(catalog_spec)"
  [ -n "$spec" ] || { echo "no catalog configured (packs.conf has no CATALOG= line, BOOSH_CATALOG is empty)" >&2; return 1; }
  if [ "$(src_kind "$spec")" = local ]; then CATALOG_DIR="$(src_path "$spec")"; [ -d "$CATALOG_DIR" ] || { echo "catalog folder missing: $CATALOG_DIR" >&2; CATALOG_DIR=""; return 1; }; return 0; fi
  key="$(printf '%s' "$spec" | cksum | cut -d' ' -f1)"
  dir="$BH_CACHE/catalog-$key"
  if [ -d "$dir" ] && src_pinned "$spec" && [ "${1:-}" != refresh ]; then
    CATALOG_DIR="$dir"; FETCH_SHA="$(cat "$dir/.archive_sha256" 2>/dev/null || true)"; return 0   # reused: remember what it was when downloaded
  fi
  mkdir -p "$BH_CACHE"
  tmp="$(mktemp -d "$BH_CACHE/.dl.XXXXXX")"
  if fetch_into "$spec" "$tmp"; then
    printf '%s\n' "$FETCH_SHA" > "$tmp/.archive_sha256"
    rm -rf "$dir"; mv "$tmp" "$dir"; CATALOG_DIR="$dir"; return 0
  fi
  rm -rf "$tmp"
  if [ -d "$dir" ]; then
    echo "warn    could not reach the catalog $spec; using the copy downloaded earlier" >&2
    CATALOG_DIR="$dir"; FETCH_SHA="$(cat "$dir/.archive_sha256" 2>/dev/null || true)"; return 0
  fi
  return 1
}
