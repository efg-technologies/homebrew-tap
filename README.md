# homebrew-tap

Homebrew tap for [sim](https://github.com/efg-technologies/sim), the next-generation Vim: it shows even what is hidden, it is secure, and it is written in Rust.

## Install

```sh
brew install efg-technologies/tap/sim
```

Or tap it first:

```sh
brew tap efg-technologies/tap
brew install sim
```

The formula builds from source (`cargo install`), so Rust is installed as a build dependency. The source is the release asset `sim-<version>.tar.gz` of [efg-technologies/sim](https://github.com/efg-technologies/sim/releases).

Then, if you like it as your editor:

```sh
export EDITOR=sim
git config --global core.editor sim
export SUDO_EDITOR='sim --plain'
```

`git` and `rg` ([ripgrep](https://github.com/BurntSushi/ripgrep)) are optional: sim uses them when they are on `PATH` (change marks, faster content search).

## Update and uninstall

```sh
brew update && brew upgrade sim
brew uninstall sim
```

## What is here

| Path | What |
|---|---|
| `Formula/sim.rb` | the formula |
| `tools/release.sh` | makes the release tarball and fills this formula and the AUR package `sim-editor` for a version |
| `tests/release_test.sh` | tests of `tools/release.sh` (they touch only temporary copies) |
| `drafts/` | `CHANGELOG.md` and release notes drafts, until they move into the sim repository |

## Releasing a version

Nothing here pushes, tags or publishes. Each public step is yours.

1. In the sim repository: bump the version of both crates, commit, and tag `vX.Y.Z` (locally).
2. Try it without a tag, on `main`. This changes no file and prints what would change:

   ```sh
   tools/release.sh --dry-run X.Y.Z ~/ghq/github.com/efg-technologies/sim
   ```

3. Make the real thing. It archives the tag, writes `dist/sim-X.Y.Z.tar.gz`, fills `Formula/sim.rb` and the AUR `PKGBUILD` and `.SRCINFO` (`makepkg --printsrcinfo`, so run it on Arch), and prints the `gh release create` command. It does not run it:

   ```sh
   tools/release.sh X.Y.Z ~/ghq/github.com/efg-technologies/sim
   ```

4. Run the printed `gh release create` (it makes a draft with the tarball as its asset), check the draft, publish it.
5. Check that the published asset has the sha256 that was filled in (the script prints the command), then commit the formula here and the AUR package, and push them.

The tarball is `git archive` piped through `gzip -n`, so the same tag gives the same bytes; the sha256 that matters is that of the file you upload.

## Issues

- sim: <https://github.com/efg-technologies/sim/issues>
- This formula: <https://github.com/efg-technologies/homebrew-tap/issues>

## License

The formula and tools in this repository are released under the [BSD 2-Clause License](LICENSE), as in [homebrew-zeed](https://github.com/efg-technologies/homebrew-zeed). sim itself is dual-licensed under MIT or Apache-2.0.
