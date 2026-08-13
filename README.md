# nix-nvim-tmux

Portable Neovim + tmux, declared entirely in Nix. No dotfiles to symlink, no
plugin manager to bootstrap, no host system touched — copy this directory
anywhere Nix runs and get the identical editor and terminal multiplexer.

- [Quick start](#quick-start)
- [Installing Nix](#installing-nix)
- [Key bindings](#key-bindings)
- [What's inside](#whats-inside)
- [Troubleshooting](#troubleshooting)
- [Customizing](#customizing)

## Quick start

```sh
cd nix-nvim-tmux
nix develop
tmux
```

| Tool | Try this |
| --- | --- |
| Neovim | `Space`, then `?` — cheat sheet of the most-used commands |
| tmux | `Ctrl+Space`, then `"` — split the pane |
| lazygit | type `lazygit` — full git UI |
| lazydocker | type `lazydocker` — full Docker UI |
| btop | type `btop` — system resource monitor |
| glow | type `glow README.md` — render markdown in the terminal |
| fzf / jq | fuzzy-find and JSON-filter, pipe anything into them |

No Nix yet? → [Installing Nix](#installing-nix)

To run it from elsewhere without `cd`-ing in: `nix develop path:/absolute/path/to/nix-nvim-tmux`.
To move it to another machine: `rsync`/`scp` the directory over, no git required.

> Launch `tmux` from a plain terminal, not from inside an existing tmux
> session — nesting can break pty handling and plugin loading only applies
> when a *new* server starts.

## Installing Nix

Needs flakes enabled (`experimental-features = nix-command flakes`) — this
project intentionally ships without a `.git`, and flakes work fine on a
plain directory.

<details>
<summary><b>Ubuntu / any Linux</b></summary>

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Close and reopen your terminal afterwards.

</details>

<details>
<summary><b>macOS</b> (Apple Silicon or Intel)</summary>

Same command as Linux above.

</details>

<details>
<summary><b>Windows</b> (via WSL2)</summary>

Nix only runs on Linux/macOS, so Windows needs WSL2 first — on a fresh
machine, don't assume it's already on; it's an optional feature, and
often blocked by a BIOS setting too.

1. `Win+R` → `winver` → confirm Windows 10 build 19041+ or Windows 11.
   Older? Run Windows Update until it isn't.
2. Task Manager → Performance → CPU → confirm **Virtualization: Enabled**.
   If not, enable it in BIOS/UEFI (VT-x / AMD-V / SVM Mode — menu varies by
   manufacturer). The most common reason WSL2 fails on a new prebuilt PC.
3. PowerShell **as Administrator**:
   ```powershell
   wsl --install -d Ubuntu
   ```
   If that errors out, enable the features by hand first, reboot, then
   retry:
   ```powershell
   dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
   dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
   ```
4. Open **Ubuntu** from the Start menu, finish the first-run user setup.
5. Inside that Ubuntu window, run the Linux install command above.

Official docs (in case any of this has shifted):
[learn.microsoft.com/windows/wsl/install](https://learn.microsoft.com/windows/wsl/install)

From here on, `cd`, `nix develop`, `tmux` all run *inside* Ubuntu/WSL, not
in PowerShell directly.

</details>

Verify:

```sh
nix --version
nix flake metadata   # from inside this repo - confirms flakes work
```

<details>
<summary>Removing Nix completely</summary>

Installed via the Determinate installer above:

```sh
/nix/nix-installer uninstall
```

Full teardown — removes `/nix`, its background service, the build
users/group it created, and the lines added to your shell startup files.

Installed via the older `nixos.org/nix/install` script instead? There's no
built-in uninstaller; removal is manual and more involved on macOS (a
separate disk volume is created for `/nix`). See
[nix.dev](https://nix.dev)'s installation docs.

Just want to remove *this project's* footprint and keep Nix? Run
`nix-collect-garbage -d` and see [Troubleshooting](#troubleshooting) for the
one file it places outside the Nix store.

</details>

## Key bindings

**Neovim** — `Space`, then `?` opens an in-editor cheat sheet, ranked by
importance. `Space` alone (pause, no `?`) opens
[which-key](https://github.com/folke/which-key.nvim) instead — exhaustive
and alphabetical rather than curated. `:Telescope keymaps` fuzzy-searches
everything; `:help` for full Neovim docs.

| Action | Key |
| --- | --- |
| Save / quit | `<leader>w` / `<leader>q` |
| Find files / grep / buffers | `<leader>ff` / `<leader>fg` / `<leader>fb` |
| File explorer (Neo-tree) | `<leader>e` |
| Go to definition | `gd` |
| Git status | `<leader>gg` |
| Diagnostics panel | `<leader>xx` |
| Debugger: breakpoint / continue | `<leader>db` / `<leader>dc` |
| Toggle terminal | `<leader>tt` |

<details>
<summary>Full Neovim reference</summary>

| Action | Key |
| --- | --- |
| Help tags / recent files / resume picker | `<leader>fh` / `<leader>fo` / `<leader>fr` |
| Document / workspace symbols | `<leader>fs` / `<leader>fw` |
| Diff view: open / close / file history | `<leader>gd` / `<leader>gD` / `<leader>gh` |
| Stage / reset / preview hunk | `<leader>hs` / `<leader>hr` / `<leader>hp` |
| Next / previous git hunk | `]c` / `[c` |
| Search & replace across files | `<leader>sr` |
| Add / delete / replace surround | `sa` / `sd` / `sr` |
| Select around/inside function or class | `af` `if` `ac` `ic` |
| Debugger: step into / over / out | `<leader>di` / `<leader>do` / `<leader>dO` |
| Toggle debug UI | `<leader>du` |
| Move focus between windows | `<C-h/j/k/l>` |
| Switch / jump to buffer N | `<S-h>` / `<S-l>`, `<leader>b1`…`b9` |
| Close buffer | `<leader>bd` |
| Harpoon: add / menu / jump to slot N | `<leader>a` / `<C-e>` / `<leader>1`…`4` |
| Marks: toggle / next / prev / preview | `m;` / `m]` / `m[` / `m:` |
| Folds: open all / close all / preview | `zR` / `zM` / `zK` |

</details>

**tmux** — prefix `Ctrl+Space`, then `?` lists every binding currently in
effect (or `tmux list-keys` from outside tmux).

| Action | Key |
| --- | --- |
| Split pane vertically / horizontally | prefix `"` / prefix `%` |
| Switch window | `Alt+H` / `Alt+L` (no prefix) |
| Copy mode → select → copy | prefix `[`, then `v`, then `y` |

## What's inside

<details>
<summary><code>flake.nix</code> — wires it all together</summary>

Builds `nvim` via [nixvim](https://github.com/nix-community/nixvim), wraps
`tmux` to always load `tmux/tmux.conf`, and exposes both through a
`devShell`. Also wraps `lazygit` (pointed at this repo's `nvim` for
`e`diting), wraps `btop` and `glow` with the Catppuccin Mocha theme (matches
nvim/tmux/yazi), and pins `lazydocker`, `fzf`, `jq`, `git`, `zoxide`,
`claude-code`.

</details>

<details>
<summary><code>nvim/default.nix</code> — the editor</summary>

- **Fuzzy finding**: Telescope + `fzf-native`, Neo-tree sidebar (follows the
  current buffer), Harpoon for pinning a working set of files.
- **Code intelligence**: LSP for Nix (`nixd`), Lua (`lua_ls`), Python
  (`pyright`), JS/TS (`ts_ls`); linting via `nvim-lint` (`ruff`,
  `eslint_d`); format-on-save via `conform.nvim` (`ruff format`,
  `prettierd`). All binaries pinned through nixpkgs, nothing from the host.
  `eslint_d` still needs a project-local ESLint config to produce
  diagnostics — inherent to ESLint, not something Nix can supply.
- **Editing**: Treesitter + textobjects + sticky context header,
  `mini.surround`, `grug-far` for project-wide search & replace.
- **Git**: gitsigns (inline hunk signs/blame), Neogit, Diffview.
- **Debugging**: `nvim-dap` + `dap-ui` + `dap-python` (debugpy), inline
  variable values while stopped.
- **UI**: Catppuccin Mocha (matches tmux), `noice.nvim` for a floating
  command-line with live completion, Trouble for a persistent
  diagnostics/quickfix panel, `lualine`, `bufferline`.
- **Claude Code**: `claudecode.nvim` lets the `claude` CLI attach to this
  Neovim instance the same way the official VS Code/JetBrains extensions
  do — inline diffs for proposed edits, `<leader>as` to share context.

</details>

<details>
<summary><code>tmux/tmux.conf</code> — the multiplexer</summary>

`Ctrl+Space` prefix, vi-style copy mode, mouse on, status bar on top,
`Alt+H`/`Alt+L` window switching. Plugins (`sensible`, `yank`,
`vim-tmux-navigator`, `catppuccin`, `resurrect`, `continuum`) come from
nixpkgs' `tmuxPlugins` and load via `run-shell` — no TPM, no runtime
`git clone`.

</details>

## Troubleshooting

<details>
<summary>Icons render as boxes/tofu (tmux status bar, yazi)</summary>

Your terminal's font isn't a Nerd Font. The first `nix develop` run drops
`JetBrainsMono Nerd Font Mono` into
`~/.local/share/fonts/nix-nvim-tmux-fonts` and refreshes the font cache —
the one deliberate exception to "nothing touches the host", since a
terminal's font can't be set from inside a shell. Point your terminal at it
once:

- **GNOME Terminal**: Preferences → your profile → Text → uncheck "Use the
  system fixed-width font" → Custom font → `JetBrainsMono Nerd Font Mono`.
- **Other terminals**: set the font in that app's own config (e.g.
  `font_family` in `kitty.conf`, `font.normal.family` in `alacritty.toml`,
  `terminal.integrated.fontFamily` in VS Code's `settings.json`).

Remove it later: `rm -rf ~/.local/share/fonts/nix-nvim-tmux-fonts && fc-cache -f`.

Also note: the devShell exports `LANG`/`LC_ALL=C.UTF-8` on Linux, since
Nix-built tmux/yazi link against Nix's own glibc and won't see the host's
locale data otherwise — which can also corrupt icon rendering.

</details>

## Customizing

Edit `nvim/default.nix` (see the
[nixvim option search](https://nix-community.github.io/nixvim/) for
available plugins/LSP servers) or `tmux/tmux.conf` directly, then rerun
`nix develop` — no separate rebuild step.
