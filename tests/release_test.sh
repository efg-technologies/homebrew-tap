#!/bin/sh
# Tests of tools/release.sh. They run it on a fixture of the sim repository and on temporary copies of
# this tap and of the AUR package: the real repositories are only read. git push/tag/commit and gh are
# replaced by shims that fail, to show the script never calls them.
#
#   sh tests/release_test.sh        (needs makepkg, so run it on Arch)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
TAP=$(dirname "$HERE")
AUR=${SIM_AUR_DIR:-${HOME:-}/ghq/aur.archlinux.org/sim-editor}

if ! command -v makepkg >/dev/null 2>&1; then
  echo "release_test: SKIPPED: makepkg not found (the script needs it for .SRCINFO)"
  exit 0
fi
[ -f "$AUR/PKGBUILD" ] || {
  echo "release_test: no PKGBUILD in $AUR (set SIM_AUR_DIR)" >&2
  exit 1
}

REAL_GIT=$(command -v git)
T=$(mktemp -d "${TMPDIR:-/tmp}/release-test.XXXXXX")
trap 'rm -rf "$T"' EXIT
# The fixture never reads the user's git configuration.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
GIT="$REAL_GIT -c user.name=test -c user.email=test@example.invalid"

FAILED=0
pass() { printf 'ok   %s\n' "$1"; }
fail() {
  printf 'FAIL %s\n' "$1"
  FAILED=$((FAILED + 1))
}
# check NAME CMD...: passes when CMD succeeds
check() {
  name=$1
  shift
  if "$@" >/dev/null 2>&1; then pass "$name"; else fail "$name"; fi
}
has() { grep -q -F -e "$2" "$1"; }

# ---- fixtures -------------------------------------------------------------------------------------

mkdir -p "$T/sim/core" "$T/sim/sim"
(
  cd "$T/sim"
  printf '[workspace]\nmembers = ["core", "sim"]\n' >Cargo.toml
  printf '# lock\n' >Cargo.lock
  printf 'mit\n' >LICENSE-MIT
  printf 'apache\n' >LICENSE-APACHE
  printf '# sim\n' >README.md
  printf '[package]\nname = "sim-editor-core"\nversion = "0.1.0"\n' >core/Cargo.toml
  # a dependency line with a version must not be taken for the package's
  printf '[package]\nname = "sim-editor"\nversion = "0.1.0"\n\n[dependencies]\nsim-core = { package = "sim-editor-core", version = "0.7.7" }\n' >sim/Cargo.toml
  $GIT init -q -b main
  $GIT add .
  $GIT commit -q -m 'init'
)

mkdir -p "$T/tap" "$T/aur" "$T/shim"
cp -R "$TAP/Formula" "$TAP/tools" "$T/tap/"
[ -d "$TAP/drafts" ] && cp -R "$TAP/drafts" "$T/tap/"
cp "$AUR/PKGBUILD" "$T/aur/PKGBUILD"
cp "$T/tap/Formula/sim.rb" "$T/formula.orig"
cp "$T/aur/PKGBUILD" "$T/pkgbuild.orig"

cat >"$T/shim/git" <<EOF
#!/bin/sh
for a in "\$@"; do
  case \$a in
    push | commit | tag | remote | fetch | pull | clone | config)
      echo "git \$a" >>"$T/shim.log"
      exit 97
      ;;
  esac
done
exec "$REAL_GIT" "\$@"
EOF
cat >"$T/shim/gh" <<EOF
#!/bin/sh
echo "gh \$*" >>"$T/shim.log"
exit 98
EOF
chmod +x "$T/shim/git" "$T/shim/gh"
: >"$T/shim.log"

RELEASE="$T/tap/tools/release.sh"
# run NAME... : runs the script under the shims; the output is in $T/out and $T/err, the status in $T/rc
run() {
  set +e
  PATH="$T/shim:$PATH" sh "$RELEASE" "$@" >"$T/out" 2>"$T/err"
  echo $? >"$T/rc"
  set -e
}
rc() { cat "$T/rc"; }
unchanged() { cmp -s "$T/formula.orig" "$T/tap/Formula/sim.rb" && cmp -s "$T/pkgbuild.orig" "$T/aur/PKGBUILD"; }

# The tarball the script must make, made here the same way: git archive | gzip -n -9.
$REAL_GIT -C "$T/sim" archive --format=tar --prefix=sim-0.1.0/ main | gzip -n -9 >"$T/expected.tar.gz"
EXPECTED_SHA=$(sha256sum "$T/expected.tar.gz" | cut -d' ' -f1)

# ---- tests ----------------------------------------------------------------------------------------

run
[ "$(rc)" = 2 ] && pass "no arguments: usage, status 2" || fail "no arguments: usage, status 2 (got $(rc))"
has "$T/err" "Usage:" && pass "usage is printed" || fail "usage is printed"

for v in v0.1.0 0.1 0.1.0-rc1 1.2.x; do
  run --aur "$T/aur" "$v" "$T/sim"
  [ "$(rc)" != 0 ] && has "$T/err" "version" && pass "refuses version '$v'" || fail "refuses version '$v'"
done

run --aur "$T/aur" 0.1.0 "$T/sim"
if [ "$(rc)" != 0 ] && has "$T/err" "v0.1.0" && unchanged; then
  pass "without the tag v0.1.0 a real run stops and changes nothing"
else fail "without the tag v0.1.0 a real run stops and changes nothing"; fi

run --dry-run --aur "$T/aur" 0.1.0 "$T/sim"
[ "$(rc)" = 0 ] && pass "dry run on main works without a tag" || { fail "dry run on main works without a tag"; cat "$T/err"; }
check "dry run changes no file of the tap or the AUR package" unchanged
[ ! -e "$T/tap/dist" ] && pass "dry run makes no dist/" || fail "dry run makes no dist/"
has "$T/out" "DRY RUN" && pass "dry run says so" || fail "dry run says so"
has "$T/out" "$EXPECTED_SHA" && pass "dry run prints the sha256 of git archive | gzip -n -9" || fail "dry run prints the sha256 of git archive | gzip -n -9"
has "$T/out" "gh release create v0.1.0" && pass "dry run prints the gh release create command" || fail "dry run prints the gh release create command"
has "$T/out" "sim-0.1.0.tar.gz" && pass "the command names the tarball" || fail "the command names the tarball"
has "$T/out" "--repo efg-technologies/sim" && pass "the command names the repository" || fail "the command names the repository"
has "$T/out" "--verify-tag" && pass "the command verifies the tag" || fail "the command verifies the tag"
has "$T/out" "+  sha256 \"$EXPECTED_SHA\"" && pass "dry run shows the formula's new sha256 line" || fail "dry run shows the formula's new sha256 line"
has "$T/out" "+sha256sums=('$EXPECTED_SHA')" && pass "dry run shows the PKGBUILD's new sha256sums" || fail "dry run shows the PKGBUILD's new sha256sums"
has "$T/out" "sha256sums = $EXPECTED_SHA" && pass "dry run shows the regenerated .SRCINFO" || fail "dry run shows the regenerated .SRCINFO"
cp "$T/out" "$T/out.dry1"
run --dry-run --aur "$T/aur" 0.1.0 "$T/sim"
grep -F 'sha256:' "$T/out" >"$T/sha2"
grep -F 'sha256:' "$T/out.dry1" >"$T/sha1"
cmp -s "$T/sha1" "$T/sha2" && pass "the tarball is the same bytes every time" || fail "the tarball is the same bytes every time"

# a tag whose Cargo.toml says another version
$GIT -C "$T/sim" tag v0.3.0
run --aur "$T/aur" 0.3.0 "$T/sim"
if [ "$(rc)" != 0 ] && has "$T/err" "0.1.0" && unchanged; then
  pass "a tag whose crates say another version stops the run"
else fail "a tag whose crates say another version stops the run"; fi

# the real thing, from the tag
$GIT -C "$T/sim" tag v0.1.0
run --aur "$T/aur" 0.1.0 "$T/sim"
[ "$(rc)" = 0 ] && pass "real run from the tag works" || { fail "real run from the tag works"; cat "$T/err"; }
F="$T/tap/Formula/sim.rb"
has "$F" "sha256 \"$EXPECTED_SHA\"" && pass "formula has the sha256" || fail "formula has the sha256"
has "$F" 'url "https://github.com/efg-technologies/sim/releases/download/v0.1.0/sim-0.1.0.tar.gz"' && pass "formula has the url" || fail "formula has the url"
! has "$F" PLACEHOLDER && pass "formula has no placeholder left" || fail "formula has no placeholder left"
P="$T/aur/PKGBUILD"
has "$P" "sha256sums=('$EXPECTED_SHA')" && pass "PKGBUILD has the sha256" || fail "PKGBUILD has the sha256"
has "$P" "pkgver=0.1.0" && has "$P" "pkgrel=1" && pass "PKGBUILD has pkgver and pkgrel=1" || fail "PKGBUILD has pkgver and pkgrel=1"
! has "$P" PLACEHOLDER && pass "PKGBUILD has no placeholder left" || fail "PKGBUILD has no placeholder left"
S="$T/aur/.SRCINFO"
has "$S" "pkgver = 0.1.0" && has "$S" "pkgrel = 1" && has "$S" "sha256sums = $EXPECTED_SHA" && pass ".SRCINFO matches" || fail ".SRCINFO matches"
check "PKGBUILD is valid bash" bash -n "$P"
if command -v ruby >/dev/null 2>&1; then check "formula is valid ruby" ruby -c "$F"; fi
TB="$T/tap/dist/sim-0.1.0.tar.gz"
[ -f "$TB" ] && [ "$(sha256sum "$TB" | cut -d' ' -f1)" = "$EXPECTED_SHA" ] && pass "dist/ has the tarball with that sha256" || fail "dist/ has the tarball with that sha256"
tar -tzf "$TB" >"$T/list"
has "$T/list" "sim-0.1.0/Cargo.lock" && has "$T/list" "sim-0.1.0/LICENSE-MIT" && has "$T/list" "sim-0.1.0/LICENSE-APACHE" && pass "the tarball unpacks to sim-0.1.0/ with the lock file and both licenses" || fail "the tarball unpacks to sim-0.1.0/ with the lock file and both licenses"
has "$T/out" "gh release create v0.1.0" && ! has "$T/out" "DRY RUN" && pass "real run prints the command, not as a dry run" || fail "real run prints the command, not as a dry run"

# the next release, over files that are filled already
(
  cd "$T/sim"
  sed 's/^version = "0.1.0"$/version = "0.2.0"/' core/Cargo.toml >core/Cargo.toml.new && mv core/Cargo.toml.new core/Cargo.toml
  sed 's/^version = "0.1.0"$/version = "0.2.0"/' sim/Cargo.toml >sim/Cargo.toml.new && mv sim/Cargo.toml.new sim/Cargo.toml
  $GIT commit -q -am 'release 0.2.0'
  $GIT tag v0.2.0
)
run --aur "$T/aur" 0.2.0 "$T/sim"
[ "$(rc)" = 0 ] && pass "the next release works over filled files" || { fail "the next release works over filled files"; cat "$T/err"; }
has "$F" "download/v0.2.0/sim-0.2.0.tar.gz" && ! has "$F" "v0.1.0" && pass "formula moves to 0.2.0" || fail "formula moves to 0.2.0"
has "$P" "pkgver=0.2.0" && has "$P" "pkgrel=1" && has "$S" "pkgver = 0.2.0" && pass "PKGBUILD and .SRCINFO move to 0.2.0" || fail "PKGBUILD and .SRCINFO move to 0.2.0"

[ ! -s "$T/shim.log" ] && pass "git push/tag/commit/... and gh were never called" || { fail "git push/tag/commit/... and gh were never called"; cat "$T/shim.log"; }

if [ "$FAILED" -ne 0 ]; then
  printf '\n%s test(s) failed\n' "$FAILED" >&2
  exit 1
fi
printf '\nall passed\n'
