#!/bin/sh
# Prepares a sim release: the source tarball, Formula/sim.rb, the AUR package sim-editor
# (PKGBUILD and .SRCINFO), and the `gh release create` command. It changes local files only: it never
# pushes, tags, commits or publishes, and it never runs gh; it prints the command for you to run.
# Needs git, tar, gzip, awk, sha256sum (or shasum) and, for .SRCINFO, makepkg (so run it on Arch).
set -eu

REPO=efg-technologies/sim

usage() {
  cat <<EOF
Usage: tools/release.sh [--dry-run] [--keep] [--aur DIR] [--out DIR] VERSION SIM_REPO

  VERSION    X.Y.Z, without the v. The tarball is made from the tag vVERSION of SIM_REPO.
  SIM_REPO   a git checkout of $REPO.

  -n, --dry-run   Work on main instead of the tag, and change no file of the tap or the AUR
                  package: show what would change as a diff. The tarball is not a release.
  -k, --keep      Keep the work directory (the tarball and the filled files) and print its path.
  --aur DIR       The AUR package (PKGBUILD, .SRCINFO). Default: \$SIM_AUR_DIR, else
                  \$HOME/ghq/aur.archlinux.org/sim-editor.
  --out DIR       Where a real run puts sim-VERSION.tar.gz. Default: dist/ in this repository.
EOF
}

die() {
  printf 'release.sh: %s\n' "$*" >&2
  exit 1
}

# Quotes an argument for the shell only when it needs it, so the printed command can be pasted.
q() {
  case $1 in
    '' | *[!A-Za-z0-9_./:@%+=,-]*) printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")" ;;
    *) printf '%s' "$1" ;;
  esac
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

DRY=0
KEEP=0
AUR_DIR=${SIM_AUR_DIR:-${HOME:-}/ghq/aur.archlinux.org/sim-editor}
OUT_DIR=

while [ $# -gt 0 ]; do
  case $1 in
    -n | --dry-run) DRY=1 ;;
    -k | --keep) KEEP=1 ;;
    --aur | --out)
      [ $# -ge 2 ] || die "$1 needs a directory"
      if [ "$1" = --aur ]; then AUR_DIR=$2; else OUT_DIR=$2; fi
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*) die "unknown option: $1 (see --help)" ;;
    *) break ;;
  esac
  shift
done
if [ $# -ne 2 ]; then
  usage >&2
  exit 2
fi
VERSION=$1
SIM_REPO=$2

printf '%s\n' "$VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' ||
  die "version must be X.Y.Z, without a v or a suffix (the AUR's pkgver cannot hold a hyphen): $VERSION"

TAP=$(cd "$(dirname "$0")/.." && pwd)
[ -n "$OUT_DIR" ] || OUT_DIR=$TAP/dist
TAG=v$VERSION
TARBALL_NAME=sim-$VERSION.tar.gz
URL=https://github.com/$REPO/releases/download/$TAG/$TARBALL_NAME
NOTES=$TAP/drafts/release-notes-$TAG.md

[ -f "$TAP/Formula/sim.rb" ] || die "no Formula/sim.rb in $TAP"
[ -f "$AUR_DIR/PKGBUILD" ] || die "no PKGBUILD in $AUR_DIR (use --aur DIR)"
command -v makepkg >/dev/null 2>&1 || die "makepkg not found: .SRCINFO is made with makepkg --printsrcinfo, run this on Arch"
git -C "$SIM_REPO" rev-parse --git-dir >/dev/null 2>&1 || die "not a git repository: $SIM_REPO"

if [ "$DRY" -eq 1 ]; then
  REF=refs/heads/main
  git -C "$SIM_REPO" rev-parse --verify -q "$REF^{commit}" >/dev/null || die "no branch main in $SIM_REPO"
else
  REF=refs/tags/$TAG
  git -C "$SIM_REPO" rev-parse --verify -q "$REF^{commit}" >/dev/null ||
    die "no tag $TAG in $SIM_REPO: tag the release first (--dry-run works on main without a tag)"
fi
COMMIT=$(git -C "$SIM_REPO" rev-parse "$REF^{commit}")

# Both crates must say the version being released.
crate_version() {
  git -C "$SIM_REPO" show "$REF:$1" 2>/dev/null | sed -n 's/^version = "\(.*\)"$/\1/p' | head -n 1
}
for manifest in core/Cargo.toml sim/Cargo.toml; do
  found=$(crate_version "$manifest")
  if [ "$found" != "$VERSION" ]; then
    if [ "$DRY" -eq 1 ]; then
      printf 'release.sh: warning: %s at main says version "%s", not %s\n' "$manifest" "$found" "$VERSION" >&2
    else
      die "$manifest at $TAG says version \"$found\", not $VERSION"
    fi
  fi
done

WORK=$(mktemp -d "${TMPDIR:-/tmp}/sim-release.XXXXXX")
cleanup() {
  if [ "$KEEP" -eq 1 ]; then
    printf 'work directory kept: %s\n' "$WORK"
  else
    rm -rf "$WORK"
  fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# The tarball: git archive, then gzip -n (no name, no time), so the same commit gives the same bytes.
# The sha256 that matters is that of the file uploaded as the release asset.
git -C "$SIM_REPO" archive --format=tar --prefix="sim-$VERSION/" -o "$WORK/sim-$VERSION.tar" "$REF" ||
  die "git archive failed"
gzip -n -9 -c "$WORK/sim-$VERSION.tar" >"$WORK/$TARBALL_NAME"
rm -f "$WORK/sim-$VERSION.tar"
tar -tzf "$WORK/$TARBALL_NAME" >"$WORK/list"
for f in Cargo.lock LICENSE-MIT LICENSE-APACHE sim/Cargo.toml; do
  grep -qx "sim-$VERSION/$f" "$WORK/list" || die "the tarball has no sim-$VERSION/$f"
done
SHA=$(sha256_of "$WORK/$TARBALL_NAME")

# Fill copies first; the real files are written only when all three are made.
mkdir -p "$WORK/Formula" "$WORK/aur"
awk -v url="$URL" -v sha="$SHA" '
  /^  url "/    { print "  url \"" url "\""; u++; next }
  /^  sha256 "/ { print "  sha256 \"" sha "\""; s++; next }
  { print }
  END { if (u != 1 || s != 1) exit 1 }
' "$TAP/Formula/sim.rb" >"$WORK/Formula/sim.rb" ||
  die "Formula/sim.rb must have exactly one url and one sha256 line"

awk -v ver="$VERSION" -v sha="$SHA" -v sq="'" '
  /^pkgver=/       { print "pkgver=" ver; v++; next }
  /^pkgrel=/       { print "pkgrel=1"; r++; next }
  /^sha256sums=\(/ { print "sha256sums=(" sq sha sq ")"; s++; next }
  { print }
  END { if (v != 1 || r != 1 || s != 1) exit 1 }
' "$AUR_DIR/PKGBUILD" >"$WORK/aur/PKGBUILD" ||
  die "PKGBUILD must have exactly one pkgver=, pkgrel= and sha256sums=( line"

(cd "$WORK/aur" && makepkg --printsrcinfo >.SRCINFO) || die "makepkg --printsrcinfo failed"

show_diff() { # old new label
  if [ -f "$1" ]; then old=$1; else old=/dev/null; fi
  diff -u -L "a/$3" -L "b/$3" "$old" "$2" || true
}

if [ "$DRY" -eq 1 ]; then
  printf '== DRY RUN: no file of the tap or the AUR package is changed ==\n\n'
  show_diff "$TAP/Formula/sim.rb" "$WORK/Formula/sim.rb" Formula/sim.rb
  show_diff "$AUR_DIR/PKGBUILD" "$WORK/aur/PKGBUILD" PKGBUILD
  show_diff "$AUR_DIR/.SRCINFO" "$WORK/aur/.SRCINFO" .SRCINFO
  printf '\n'
else
  mkdir -p "$OUT_DIR"
  cp "$WORK/$TARBALL_NAME" "$OUT_DIR/$TARBALL_NAME"
  cp "$WORK/Formula/sim.rb" "$TAP/Formula/sim.rb"
  cp "$WORK/aur/PKGBUILD" "$AUR_DIR/PKGBUILD"
  cp "$WORK/aur/.SRCINFO" "$AUR_DIR/.SRCINFO"
  printf 'written: %s\n         %s\n         %s\n         %s\n\n' \
    "$OUT_DIR/$TARBALL_NAME" "$TAP/Formula/sim.rb" "$AUR_DIR/PKGBUILD" "$AUR_DIR/.SRCINFO"
fi

if [ "$DRY" -eq 1 ]; then
  printf 'ref:     main (%s)\n' "$COMMIT"
else
  printf 'ref:     tag %s (%s)\n' "$TAG" "$COMMIT"
fi
printf 'tarball: %s\n' "$OUT_DIR/$TARBALL_NAME"
printf 'sha256:  %s\n' "$SHA"
printf 'url:     %s\n' "$URL"

if [ -f "$NOTES" ]; then
  if grep -q 'PENDING' "$NOTES"; then
    printf 'release.sh: warning: %s still has PENDING markers\n' "$NOTES" >&2
  fi
  NOTES_ARGS="--notes-file $(q "$NOTES")"
else
  printf 'release.sh: warning: no %s; the command asks GitHub to generate notes\n' "$NOTES" >&2
  NOTES_ARGS="--generate-notes"
fi

if [ "$DRY" -eq 1 ]; then
  printf '\nA real run would print this command (the tarball above is main, not a release):\n'
else
  printf '\nNot run. A draft release with the tarball as its asset (publish it after you have looked at it):\n'
fi
printf '\n  gh release create %s \\\n' "$(q "$TAG")"
printf '    %s \\\n' "$(q "$OUT_DIR/$TARBALL_NAME")"
printf '    --repo %s \\\n' "$REPO"
printf '    --title %s \\\n' "$(q "sim $VERSION")"
printf '    %s \\\n' "$NOTES_ARGS"
printf '    --verify-tag \\\n'
printf '    --draft\n'

if [ "$DRY" -eq 0 ]; then
  cat <<EOF

Then, by hand (nothing here has been run):
  - --verify-tag needs the tag on GitHub:  git -C $(q "$SIM_REPO") push origin $TAG
  - once the release is public, the asset must be the file hashed above:
      curl -fsSL $URL | sha256sum    # expect $SHA
  - commit the filled files in the tap and in the AUR package, and push them when you decide to
EOF
fi
