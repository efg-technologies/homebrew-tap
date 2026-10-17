# sim 0.1.0

**sim is the next-generation Vim.** It shows even what is hidden, it is secure, and it is written from scratch in Rust. The name is short for *Secure vIM*.

This is the first public release.

Files that other processes rewrite: you read them as fast as possible, fix them, and save them without losing anything. A project's files a few keys away, several of them open at once, and syntax colors that never take the change color's hue.

## What makes it different

- **Changes from outside are marked.** When a file changes on disk while you edit it, sim merges what doesn't conflict with your edits and marks it, word by word, until you've looked at it; `]c` goes to the next mark. Where it does conflict, your text stays, marked, and nothing is written over the file: `:w!` keeps yours and `:e!` takes the disk's, and each copies the version it gives up into the state directory first.
- **Saves that can't lose.** Saves are atomic (temp file, fsync, rename, directory fsync) and compare-and-swap: if the file changed since you read it, nothing is overwritten. Unsaved changes are snapshotted every second; after a crash, `kill -9` or a closed terminal, reopening the file offers them back as one undo step.
- **Hidden things are shown.** A character that must not reach the terminal, or that looks like another, is drawn as itself in the alert's block (`^X`, `<U+202E>`), and nothing around it can hide it.
- **Readable by measurement.** Text is 90 Lc and secondary text 60 Lc (APCA), computed from your terminal's background; the one change color stays distinguishable under protan, deutan and tritan color vision; prose wraps with Japanese kinsoku.
- **Meaning without color.** With `NO_COLOR` set, or on a terminal that cannot do 8 colors, sim writes no color at all: weight, underline and inverse video say what the colors said.
- **Keys your hands already know.** The vi grammar, minus vi's accidents: `Y` yanks to the end of the line, `U` redoes, search is smartcase, every yank reaches the system clipboard (also through tmux), Ctrl-s saves, `q` quits, arrows and Home/End work everywhere.

## And a place to live in

- A **tree** of the project (`Ctrl-n`) that never reorders, with git status, and the five files you are most likely to open next marked with `•`.
- **Several files** open at once, each one a complete editor with its own undo, snapshots and saves (`Tab`, `Shift-Tab`).
- **Find a file** (`Ctrl-p`, or `/` in the tree) and **search the contents** of the files as you type (`Ctrl-f`, with ripgrep if it is on your `PATH`), in a picker with a preview. A search never writes and never runs code a repository controls.
- **Syntax colors** in your terminal's own palette, three looks (`zl`: calm, flat, depth), a mouse that never edits by itself.
- **`sim --plain`**: the core alone, with no program of its own run (no git, ripgrep, filter or hook). It is what sim is as root and as the editor of `sudoedit`.

```sh
export EDITOR=sim                     # crontab -e, …
git config --global core.editor sim   # git commit (ZZ commits, :cq aborts)
export SUDO_EDITOR='sim --plain'      # sudoedit
```

## Finding the keys

- **A leader and which-key.** `Space` is the leader. Pause after a prefix (`Space`, `g`, `z`, `[`, `]` or an operator) and a small window lists the keys that can come next; keep typing and it is not in the way.
- **`:help` and `F1`.** Every key and command, fuzzy-filtered, with the longer text in a preview: `:help tab` finds `Tab`, `Shift-Tab` and `<Space>bp`.
- **Tabs by letter.** `<Space>bp` puts a letter on each tab and the letter shows that file; `<Space>bc` closes one the same way (a file with changes stays open, as with `:q`).
- **Hints and counts.** The second file you open shows a one-time hint for `Tab` and `Shift-Tab`; a search shows `[i/n]` in the status line while its matches are lit.
- `sim --version` prints `sim 0.1.0`; `sim --help` prints the usage.

## Install

```sh
brew install efg-technologies/tap/sim     # Homebrew: builds from source
```

- **From source:** `git clone https://github.com/efg-technologies/sim.git && cd sim && cargo install --locked --path sim`.
- The AUR package (`sim-editor`) and the crates on crates.io (`sim-editor`, `sim-editor-core`) follow shortly.

Needs Rust 1.88 or later to build. Runs on Linux and macOS, in any terminal; colors, the kitty keyboard protocol and OSC 52 are used when the terminal offers them (Ghostty, kitty, WezTerm, tmux). `git` and `rg` are optional: sim uses them when they are on `PATH`. sim makes no network connection.

Release asset: `sim-0.1.0.tar.gz`, the source of tag `v0.1.0`. sim is distributed as source; the package managers above build it.

## What to know

- "More readable than existing editors" is a hypothesis, not a claim: the benchmark that would test it (time and accuracy to find a change) is not built yet. Flat and depth use red and green for changes and set color vision aside; calm is the look for anyone who cannot tell red from green.
- Icons need a Nerd Font. They start on in Ghostty, kitty and WezTerm and off elsewhere, with a hint to turn them on (`zi`).
- By design sim has no plugins, no config files and no network access; split windows are left to tmux. Its choices live in `~/.local/state/sim` (or `$XDG_STATE_HOME/sim`).
- Everything sim promises, it promises for every file open in it: without an explicit action, nobody's text is lost.

Why each choice was made, with the research it rests on, is in [CONCEPT.md](https://github.com/efg-technologies/sim/blob/main/CONCEPT.md); what sim must do is in [SPEC.md](https://github.com/efg-technologies/sim/blob/main/SPEC.md), where every requirement has an ID and every ID has tests. The full list of changes is in [CHANGELOG.md](https://github.com/efg-technologies/sim/blob/main/CHANGELOG.md).

Dual-licensed under MIT or Apache-2.0, at your option.
