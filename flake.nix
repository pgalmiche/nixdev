{
  description = "Portable Neovim + Tmux dev environment, importable via Nix alone (no git required)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixvim.url = "github:nix-community/nixvim";
  };

  outputs = { self, nixpkgs, flake-utils, nixvim }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # claude-code (run directly in a tmux pane, not through nvim) ships
        # under an unfree license in nixpkgs, so allowUnfree has to be set
        # here rather than using the plain legacyPackages instantiation.
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        nvim = nixvim.legacyPackages.${system}.makeNixvimWithModule {
          inherit pkgs;
          module = import ./nvim { inherit pkgs; };
        };

        # Mirrors the TPM plugin list from ~/.tmux.conf. `catppuccin` here is
        # the official catppuccin/tmux plugin (nixpkgs doesn't package the
        # dreamsofcode-io fork) - close in look, configurable via
        # @catppuccin_flavor in tmux/tmux.conf. Order matters: continuum
        # must load after resurrect.
        tmuxPlugins = with pkgs.tmuxPlugins; [
          sensible
          yank
          vim-tmux-navigator
          catppuccin
          resurrect
          continuum
        ];

        tmuxConf = pkgs.writeText "tmux.conf" (
          builtins.readFile ./tmux/tmux.conf
          + "\n"
          + pkgs.lib.concatMapStringsSep "\n" (p: "run-shell ${p.rtp}") tmuxPlugins
          + "\n"
        );

        # -L pins this to its own socket, never the host's default one. Without
        # it, this wrapper's Nix-built tmux (a different version from whatever
        # tmux the host normally runs) would attach to any server already
        # listening on the default socket - a version-mismatched client
        # connecting to a pre-existing server there fails with "open terminal
        # failed: not a terminal", and separately -f/plugin loading never
        # takes effect since no new server actually starts.
        tmuxWrapped = pkgs.writeShellScriptBin "tmux" ''
          exec ${pkgs.tmux}/bin/tmux -L nix-nvim-tmux -f ${tmuxConf} "$@"
        '';

        # Host lazygit (~/.config/lazygit/config.yml) opens edits in VS Code -
        # that's left untouched. Inside this shell we want `e` to open the
        # nvim from this flake instead, so lazygit here is a wrapper pointed
        # at its own config file via -ucf rather than a host file edit.
        lazygitConfig = pkgs.writeText "lazygit-config.yml" ''
          os:
            editPreset: nvim
        '';

        lazygitWrapped = pkgs.writeShellScriptBin "lazygit" ''
          exec ${pkgs.lazygit}/bin/lazygit --use-config-file ${lazygitConfig} "$@"
        '';

        # yazi's stock dark theme colors directories with plain ANSI "blue",
        # which reads as near-illegible navy-on-black in most terminal
        # palettes. Pulling in catppuccin/yazi's mocha-blue theme (pinned to
        # a commit, like the tmux catppuccin plugin) fixes contrast and
        # matches the catppuccin mocha already used for nvim/tmux, rather
        # than hand-rolling a one-off color.
        yaziTheme = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/catppuccin/yazi/baaf5d1c9427b836fbefd126aa855f9eab7a9d0d/themes/mocha/catppuccin-mocha-blue.toml";
          sha256 = "137c4z3i27hrq5h3ff7cmnz4bkbxxrq9jixv2kl0c7b10cqmpibv";
        };

        yaziConfigHome = pkgs.linkFarm "yazi-config-home" [
          { name = "theme.toml"; path = yaziTheme; }
        ];

        yaziWrapped = pkgs.writeShellScriptBin "yazi" ''
          export YAZI_CONFIG_HOME=${yaziConfigHome}
          exec ${pkgs.yazi}/bin/yazi "$@"
        '';

        # btop themes aren't packaged in nixpkgs; pulling in catppuccin/btop's
        # mocha theme (pinned to a commit, like the tmux catppuccin plugin and
        # yazi theme above) matches the catppuccin mocha already used for
        # nvim/tmux/yazi. --themes-dir points at a store dir so no host
        # ~/.config/btop is touched, and -c pins an inline config selecting
        # it as color_theme.
        btopTheme = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/catppuccin/btop/cf50077d8d50e009b5f58aad4bb32603db895f17/themes/catppuccin_mocha.theme";
          sha256 = "0i263xwkkv8zgr71w13dnq6cv10bkiya7b06yqgjqa6skfmnjx2c";
        };

        btopThemesDir = pkgs.linkFarm "btop-themes" [
          { name = "catppuccin_mocha.theme"; path = btopTheme; }
        ];

        btopConfig = pkgs.writeText "btop.conf" ''
          color_theme = "catppuccin_mocha"
          theme_background = false
        '';

        btopWrapped = pkgs.writeShellScriptBin "btop" ''
          exec ${pkgs.btop}/bin/btop --themes-dir ${btopThemesDir} -c ${btopConfig} "$@"
        '';

        # glow (charmbracelet) renders markdown via the glamour library; its
        # style flag also takes a JSON path, so catppuccin/glamour's mocha
        # style (pinned to a commit, same as the other catppuccin themes
        # above) slots in the same way.
        glowTheme = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/catppuccin/glamour/00c97fa3823d272d9d041d5d872ae6335555a776/themes/catppuccin-mocha.json";
          sha256 = "15n3z52hf7f0gixk38bwl3rm6qzgfmdc9l9iydhg5nnfj02m2771";
        };

        glowWrapped = pkgs.writeShellScriptBin "glow" ''
          exec ${pkgs.glow}/bin/glow --style ${glowTheme} "$@"
        '';

        nerdFont = pkgs.nerd-fonts.jetbrains-mono;

        # Nix-built tmux/yazi link against Nix's own glibc, which doesn't
        # see the host's locale data unless told to - on a non-NixOS host
        # this breaks Unicode column-width calculations and can mangle the
        # catppuccin/yazi icon glyphs. C.UTF-8 is compiled into glibc
        # itself (no locale-archive lookup needed), so it works everywhere
        # without pulling in the ~200MB full glibcLocales package.
        localeEnv = pkgs.lib.optionalString pkgs.stdenv.isLinux ''
          export LANG=C.UTF-8
          export LC_ALL=C.UTF-8
        '';

        # `nix develop` always runs bash for the interactive session itself
        # (hardcoded upstream, ignores $SHELL) - so to land in zsh on any
        # machine, regardless of what's installed there, the shellHook execs
        # into a pinned zsh at the end. ZDOTDIR points at a store dir instead
        # of touching ~/.zshrc, so this stays as host-non-invasive as the
        # rest of the shell.
        zshDotDir = pkgs.writeTextDir ".zshrc" ''
          HISTFILE="$HOME/.nix_dev_shell_zsh_history"
          # zsh's HISTSIZE/SAVEHIST default to 0 when unset - no history is
          # kept in memory at all, so Ctrl+R has nothing to search. Every
          # pane (top-level shell and every tmux pane, via the inherited
          # ZDOTDIR below) shares this rc, so this was silently breaking
          # history search everywhere in the shell.
          HISTSIZE=10000
          SAVEHIST=10000
          setopt PROMPT_SUBST
          __nix_git_branch() {
            local branch
            branch=$(git branch --show-current 2>/dev/null)
            if [ -n "$branch" ]; then
              print -n " %F{blue}git:(%F{red}$branch%F{blue})%f"
            fi
          }
          PROMPT='%B%F{magenta}NixDev%f%b %F{cyan}%~%f$(__nix_git_branch) $ '
          eval "$(zoxide init zsh)"

          # Auto-launch tmux on entering the shell. Guarded on $TMUX so
          # panes spawned inside tmux (which inherit this same ZDOTDIR)
          # don't try to nest another tmux server - see README's note on
          # nesting tripping up -f/plugin loading. Not exec'd: quitting
          # tmux should drop back to this prompt, not close the devShell.
          if [ -z "$TMUX" ]; then
            ${tmuxWrapped}/bin/tmux
          fi
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          # Pinned via nixpkgs so these resolve to the same tool everywhere
          # this flake runs, taking precedence over any host-installed
          # version (brew, apt, ...) on $PATH. Nothing here touches the
          # host system - it all lives in the Nix store and disappears the
          # moment you leave the shell / garbage-collect it.
          packages = [ nvim tmuxWrapped yaziWrapped pkgs.git pkgs.ripgrep pkgs.fd lazygitWrapped pkgs.lazydocker btopWrapped glowWrapped pkgs.fzf pkgs.jq pkgs.zoxide pkgs.zsh pkgs.claude-code ];

          shellHook = ''
            export EDITOR=nvim
            __nix_git_branch() {
              local branch
              branch=$(git branch --show-current 2>/dev/null)
              if [ -n "$branch" ]; then
                printf ' \033[1;34mgit:(\033[31m%s\033[1;34m)\033[0m' "$branch"
              fi
            }
            export PS1='\[\033[1;35m\]NixDev\[\033[0m\] \[\033[36m\]\w\[\033[0m\]$(__nix_git_branch)\[\033[0m\]$ '
            eval "$(zoxide init bash)"
            ${localeEnv}

            # One-time: drop the Nerd Font this config expects into the
            # user's font dir so catppuccin/yazi icons render. This is the
            # one intentional exception to "nothing touches the host" -
            # a terminal emulator's font can't be set from inside a shell.
            fontDir="$HOME/.local/share/fonts/nix-nvim-tmux-fonts"
            if [ ! -f "$fontDir/.installed" ]; then
              mkdir -p "$fontDir"
              cp -f ${nerdFont}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNerdFontMono-*.ttf "$fontDir/"
              touch "$fontDir/.installed"
              command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$fontDir" >/dev/null 2>&1
              echo "Installed 'JetBrainsMono Nerd Font Mono' to $fontDir"
              echo "Set it as your terminal's font (GNOME Terminal: Preferences > your profile > Text > Custom font) to fix icon rendering."
            fi

            # Only hand off to zsh for a real interactive session ($- has
            # "i"). `nix develop --command ...` runs this same shellHook
            # non-interactively; exec'ing there would swallow the command.
            if [[ $- == *i* ]] && [ -z "$IN_NIX_DEV_ZSH" ]; then
              export IN_NIX_DEV_ZSH=1
              export ZDOTDIR=${zshDotDir}
              exec ${pkgs.zsh}/bin/zsh
            fi
          '';
        };
      });
}
