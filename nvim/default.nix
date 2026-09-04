# nixvim config module, imported by ../flake.nix via `makeNixvim`.
{ pkgs, ... }:
{
  viAlias = true;
  vimAlias = true;

  # Pinned so telescope/gitsigns work identically anywhere this flake runs,
  # regardless of what's (or isn't) installed on the host PATH.
  extraPackages = with pkgs; [ git ripgrep fd typescript-language-server typescript ];

  # nvim-nio: dap-ui's async/UI-component dependency. Nixvim's dap-ui module
  # doesn't pull this in automatically, so it has to be added to the
  # runtimepath by hand.
  extraPlugins = with pkgs.vimPlugins; [ nvim-nio ];

  colorschemes.catppuccin = {
    enable = true;
    settings = {
      flavour = "mocha";
      integrations = {
        treesitter = true;
        telescope.enabled = true;
        lualine = true;
        cmp = true;
        gitsigns = true;
        neogit = true;
      };
    };
  };

  globals.mapleader = " ";

  opts = {
    number = true;
    relativenumber = true;
    expandtab = true;
    shiftwidth = 2;
    tabstop = 2;
    smartindent = true;
    ignorecase = true;
    smartcase = true;
    termguicolors = true;
    mouse = "a";
    splitright = true;
    splitbelow = true;
    scrolloff = 8;
    signcolumn = "yes";
    cursorline = true;

    # Every yank/delete/paste goes through the OS clipboard automatically,
    # same as VSCode/GUI editors - no more "+y/"+p prefixing to move text in
    # and out of the terminal.
    clipboard = "unnamedplus";

    # `:%s/foo/bar/g` opens a live preview split of what will change, before
    # you hit enter.
    inccommand = "split";

    # Sharper diffs everywhere that rides on Neovim's native diff engine -
    # gitsigns' hunk preview, neogit's file diff, `:DiffviewOpen`, and
    # claudecode's default side-by-side review layout all sit on top of this
    # same `diffopt`, so tuning it once improves every one of them.
    # `histogram` groups hunks more sensibly than the default `myers`
    # algorithm; `linematch:60` (up from Neovim's own default of 40) pushes
    # character-level highlighting inside a changed line further before it
    # gives up and highlights the whole line.
    diffopt = "internal,filler,closeoff,indent-heuristic,algorithm:histogram,linematch:60,inline:char";

    # Default (4000ms) makes gitsigns' blame/hunk signs and CursorHold-based
    # popups (hover, etc.) feel sluggish; this is the commonly-recommended
    # value for snappier response without hammering the CPU on every move.
    updatetime = 250;

    # nvim-ufo (below) takes over computing/displaying folds; it needs a
    # large foldlevel so nothing starts folded, and the gutter column to
    # show fold indicators (VSCode-style fold arrows).
    foldcolumn = "1";
    foldlevel = 99;
    foldlevelstart = 99;
    foldenable = true;
  };

  plugins = {
    treesitter = {
      enable = true;
      settings = {
        highlight.enable = true;
        indent.enable = true;
      };
    };

    # Sticky header showing the enclosing function/class while you scroll
    # (VSCode-style "sticky scroll"), driven by the same treesitter parsers.
    treesitter-context.enable = true;

    # Ships without keymaps or an automatic setup() call (upstream moved
    # keymap wiring out of plugin config) - both are hand-rolled below via
    # extraConfigLua + the top-level `keymaps` list.
    treesitter-textobjects.enable = true;

    telescope = {
      enable = true;
      extensions.fzf-native.enable = true;
      keymaps = {
        "<leader>ff" = "find_files";
        "<leader>fg" = "live_grep";
        "<leader>fb" = "buffers";
        "<leader>fh" = "help_tags";
        "<leader>fo" = "oldfiles";
        "<leader>fr" = "resume";
        "<leader>fd" = "diagnostics";
        "<leader>fs" = "lsp_document_symbols";
        "<leader>fw" = "lsp_dynamic_workspace_symbols";
      };
      settings = {
        # Applies inside every picker's floating window (find_files, live_grep, ...),
        # in both insert mode (typing the query) and normal mode (after <Esc>).
        defaults.mappings = {
          i = {
            "<C-j>".__raw = "require('telescope.actions').move_selection_next";
            "<C-k>".__raw = "require('telescope.actions').move_selection_previous";
          };
          n = {
            "<C-j>".__raw = "require('telescope.actions').move_selection_next";
            "<C-k>".__raw = "require('telescope.actions').move_selection_previous";
          };
        };

        # Dotfiles (.env.development, .eslintrc, ...) are invisible to both
        # find_files and live_grep by default for two stacked reasons: rg/fd
        # skip hidden files, AND they skip anything .gitignore'd (which is
        # exactly where secrets/env files usually live). --hidden alone only
        # fixes the first; --no-ignore drops the second. Only .git/ itself is
        # excluded so its internal object store doesn't flood results.
        defaults.vimgrep_arguments = [
          "rg"
          "--color=never"
          "--no-heading"
          "--with-filename"
          "--line-number"
          "--column"
          "--smart-case"
          "--hidden"
          "--no-ignore"
        ];
        # Lua patterns (NOT globs/regex), matched against the relative path, so
        # a literal "." must be escaped as "%.". --no-ignore above re-surfaces
        # .gitignore'd files on purpose (to see .env*), which also drags build
        # artifacts back in - subtract those out here. Trailing "/" (rather than
        # a leading anchor) matches both root-level "dist/..." and nested
        # "packages/app/dist/...", while sparing "redistribute/".
        defaults.file_ignore_patterns = [
          "%.git/"

          # JS / React / NestJS build output + caches
          "dist/"
          "build/"
          "node_modules/"
          "%.next/"
          "%.turbo/"
          "%.vite/"
          "%.cache/"
          "coverage/"
          "storybook%-static/"
          "%.eslintcache"
          "package%-lock%.json"
          "yarn%.lock"
          "pnpm%-lock%.yaml"

          # Python bytecode, virtualenvs, tool caches, coverage
          "__pycache__/"
          "%.pyc"
          "%.venv/"
          "venv/"
          "%.mypy_cache/"
          "%.pytest_cache/"
          "%.ruff_cache/"
          "%.egg%-info/"
          "htmlcov/"
          "%.coverage"

          # Misc noise
          "%.DS_Store"
          "%.log"
        ];
        pickers.find_files.hidden = true;
        pickers.find_files.no_ignore = true;

        # VSCode-style "recent files": <leader>fo (oldfiles, below) otherwise
        # lists every file ever opened across every project on the machine,
        # not just this one - cwd_only scopes it to the current project,
        # matching what VSCode's Ctrl+P shows on an empty query.
        pickers.oldfiles.cwd_only = true;
      };
    };

    # File-tree sidebar; needs web-devicons for the file/folder glyphs.
    # VSCode-style cut/copy/paste of files AND folders is built in, no config
    # needed - with a node selected: y=copy, x=cut, p=paste, <C-r>=clear
    # clipboard, c=duplicate in place (prompts new name), m=move, d=delete,
    # a/A=new file/dir, r=rename. Press `?` inside the tree for the full list.
    web-devicons.enable = true;
    neo-tree = {
      enable = true;
      settings = {
        close_if_last_window = true;
        filesystem.follow_current_file.enabled = true;
      };
    };

    # Tabline showing every open buffer as a VSCode-style tab, with LSP
    # diagnostic icons per tab and an offset so it doesn't overlap neo-tree.
    bufferline = {
      enable = true;
      settings = {
        options = {
          mode = "buffers";
          diagnostics = "nvim_lsp";
          separator_style = "slant";
          always_show_bufferline = true;
          show_buffer_close_icons = true;
          show_close_icon = false;
          offsets = [
            {
              filetype = "neo-tree";
              text = "File Explorer";
              highlight = "Directory";
              text_align = "left";
            }
          ];
        };
      };
    };

    # `:bdelete` closes the split/window along with the buffer; this closes
    # just the buffer and keeps the window layout intact (bound below).
    mini-bufremove.enable = true;

    # Snippet engine; only needed here as nvim-cmp's expansion backend.
    luasnip.enable = true;

    # Completion menu. Listing "nvim_lsp" in sources auto-enables
    # cmp-nvim-lsp AND wires its capabilities into every LSP client below -
    # no extra plumbing needed for LSP-powered completion.
    cmp = {
      enable = true;
      settings = {
        snippet.expand = "function(args) require('luasnip').lsp_expand(args.body) end";
        sources = [
          { name = "nvim_lsp"; }
          { name = "luasnip"; }
          { name = "path"; }
          { name = "buffer"; }
        ];
        mapping = {
          "<C-Space>" = "cmp.mapping.complete()";
          "<C-e>" = "cmp.mapping.abort()";
          "<CR>" = "cmp.mapping.confirm({ select = true })";
          "<C-j>" = "cmp.mapping.select_next_item()";
          "<C-k>" = "cmp.mapping.select_prev_item()";
          "<Tab>" = "cmp.mapping(function(fallback) if cmp.visible() then cmp.select_next_item() else fallback() end end, {'i', 's'})";
          "<S-Tab>" = "cmp.mapping(function(fallback) if cmp.visible() then cmp.select_prev_item() else fallback() end end, {'i', 's'})";
        };
      };
    };

    # Inline git-change signs in the gutter, hunk stage/reset/preview, and
    # blame - buffer-local keymaps are wired in on_attach (gitsigns'
    # recommended pattern) so they only apply to buffers it attaches to.
    gitsigns = {
      enable = true;
      settings = {
        current_line_blame = false;
        on_attach = # Lua
          ''
            function(bufnr)
              local gitsigns = require("gitsigns")

              vim.keymap.set("n", "]c", function()
                if vim.wo.diff then return "]c" end
                vim.schedule(function() gitsigns.nav_hunk("next") end)
                return "<Ignore>"
              end, { buffer = bufnr, expr = true, desc = "Next git hunk" })

              vim.keymap.set("n", "[c", function()
                if vim.wo.diff then return "[c" end
                vim.schedule(function() gitsigns.nav_hunk("prev") end)
                return "<Ignore>"
              end, { buffer = bufnr, expr = true, desc = "Previous git hunk" })

              local function map(mode, lhs, rhs, desc)
                vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
              end

              map("n", "<leader>hs", gitsigns.stage_hunk, "Stage hunk")
              map("n", "<leader>hr", gitsigns.reset_hunk, "Reset hunk")
              map("n", "<leader>hS", gitsigns.stage_buffer, "Stage buffer")
              map("n", "<leader>hp", gitsigns.preview_hunk_inline, "Preview hunk")
              map("n", "<leader>hb", gitsigns.blame_line, "Blame line")
              map("n", "<leader>tb", gitsigns.toggle_current_line_blame, "Toggle line blame")
            end
          '';
      };
    };

    # Magit-style git porcelain: stage/commit/push/pull/branch from one
    # status buffer instead of shelling out. <leader>gg opens it (below).
    neogit = {
      enable = true;
      settings.integrations.telescope = true;
    };

    # Code folding with a fold-preview popup and per-filetype fold providers
    # (treesitter scopes, falling back to indent); native za/zo/zc still work
    # as-is, zR/zM/zK below get ufo's richer versions.
    nvim-ufo = {
      enable = true;
      setupLspCapabilities = true;
      settings.provider_selector = # Lua
        ''
          function(bufnr, filetype, buftype)
            return { "treesitter", "indent" }
          end
        '';
    };

    # Pops up a hint for available continuations of any pending key sequence
    # (e.g. after <leader>f) - makes all the keymaps below discoverable
    # without memorizing them up front.
    which-key.enable = true;

    lualine.enable = true;

    # Pin a handful of files you're actively working across and jump between
    # them by slot number - faster recall than fuzzy-finding through
    # Telescope when you already know which files you're juggling.
    harpoon = {
      enable = true;
      enableTelescope = true;
    };

    # Visual gutter signs for marks + next/prev navigation between them.
    # Default keymaps (all "m"/"dm"-prefixed, nothing below overrides them):
    # m; toggle mark, m]/m[ next/prev mark, m: preview, m0-m9 numbered
    # bookmarks, dm delete mark under cursor. Native `` `a ``/`'a` jump-to-
    # mark still work unchanged.
    marks.enable = true;

    # Persistent, live-updating list for diagnostics/quickfix/loclist/LSP
    # references - VSCode "Problems panel" style, as opposed to Telescope's
    # <leader>fd which is a one-shot picker that closes as soon as you jump.
    trouble.enable = true;

    lint = {
      enable = true;
      autoInstall.enable = true;
      lintersByFt = {
        python = [ "ruff" ];
        javascript = [ "eslint_d" ];
        javascriptreact = [ "eslint_d" ];
        typescript = [ "eslint_d" ];
        typescriptreact = [ "eslint_d" ];
      };
    };

    conform-nvim = {
      enable = true;
      autoInstall.enable = true;
      settings = {
        formatters_by_ft = {
          python = [ "ruff_format" ];
          javascript = [ "prettierd" ];
          javascriptreact = [ "prettierd" ];
          typescript = [ "prettierd" ];
          typescriptreact = [ "prettierd" ];
          markdown = [ "prettierd" ];
        };
        format_on_save = {
          lsp_format = "fallback";
          timeout_ms = 1000;
        };
      };
    };

    # Replaces the plain bottom-line `:` cmdline with a floating popup that
    # shows a live completion dropdown as you type (e.g. `:Te` lists
    # Tabnew/Telescope/Terminal) - VSCode-command-palette-adjacent, but for
    # the actual Ex command-line rather than a separate picker. Also styles
    # `:messages`/notifications/LSP hover into popups. nui.nvim is a hard
    # runtime dependency for its popup/split views; nvim-notify backs the
    # default "notify" message view.
    nui.enable = true;
    notify.enable = true;
    noice.enable = true;

    # Claude Code's `/ide` command only auto-detects VS Code/JetBrains out of
    # the box (via their bundled extensions). claudecode.nvim reverse-engineers
    # the same WebSocket/MCP protocol those extensions speak, so the `claude`
    # CLI (run in a terminal split here) auto-detects and attaches to this
    # Neovim instance instead - inline diffs, `:ClaudeCodeAdd`/<leader>as to
    # share file/selection context, etc. snacks.nvim is its one dependency.
    snacks = {
      enable = true;
      # Swaps the plain command-line vim.ui.input() prompt for a floating
      # window - used by neo-tree's rename/copy/move/add prompts (below)
      # and by LSP rename, so those feel like a proper dialog instead of a
      # ":" command line.
      settings.input.enabled = true;
    };
    # layout = "unified": proposed edits render inline in the buffer itself
    # (green add / red strikethrough delete via extmarks) instead of opening
    # a second diff-split window - more compact than the default
    # side-by-side layout. Its highlight groups are re-pointed at the
    # existing DiffAdd/DiffDelete/GitSigns colors below (extraConfigLua) so
    # it matches the catppuccin theme instead of the plugin's hardcoded
    # defaults.
    claudecode = {
      enable = true;
      settings.diff_opts.layout = "unified";
    };

    # Side-by-side diff view + merge-conflict resolution UI, complementing
    # neogit/gitsigns (which don't have a proper multi-pane diff view of
    # their own). Keymaps below under <leader>g*. enhanced_diff_hl sharpens
    # diffview's own changed/added/removed highlighting beyond the bare
    # `diffopt` tuning above (opts block).
    diffview = {
      enable = true;
      settings.enhanced_diff_hl = true;
    };

    # Project-wide interactive search-and-replace with a live preview
    # buffer, across as many files as ripgrep matches - Telescope's live_grep
    # (<leader>fg) is find-only. Opened via <leader>sr below.
    grug-far.enable = true;

    # VSCode-style "reopen previous tabs": saves a session (open buffers +
    # window layout) per project directory on exit. Auto-restore-on-startup
    # isn't a plugin option (same upstream, not just here) - it's wired
    # below via extraConfigLua, same as persistence.nvim's own recommended
    # setup.
    persistence.enable = true;

    # Surround text objects: sa=add, sd=delete, sr=replace surrounding
    # quotes/brackets/tags (e.g. `saiw)` wraps a word in parens, `sd'`
    # strips surrounding quotes). Defaults are already sensible; only
    # search_method is upgraded so it also matches surroundings ahead of the
    # cursor on the current line, not just ones already enclosing it.
    mini-surround = {
      enable = true;
      settings.search_method = "cover_or_next";
    };

    # Debugger: real breakpoints/step-through/variable inspection, unlike
    # anything achievable with print statements or the REPL alone.
    # dap-python wires up a debugpy adapter + standard launch configs for
    # free; dap-ui is the VSCode-style scopes/stacks/breakpoints/watches
    # panel; dap-virtual-text shows variable values inline while stopped.
    # extraConfigLua below auto-opens/closes dap-ui around debug sessions.
    dap.enable = true;
    dap-ui.enable = true;
    dap-virtual-text.enable = true;
    dap-python = {
      enable = true;
      adapterPythonPath = pkgs.lib.getExe (pkgs.python3.withPackages (ps: [ ps.debugpy ]));
      settings.includeConfigs = true;
    };

    # Live-reloading HTML preview in whatever browser is already installed/
    # default on the host (opened via xdg-open/open/start - not something
    # Nix needs to provide). Toggle with <leader>mp below.
    markdown-preview = {
      enable = true;
      settings.theme = "dark";
    };

  };

  # Ships default cmd/filetypes/root_markers for `lsp.servers.*` below —
  # without it, `vim.lsp.enable(name)` has nothing to enable and no LSP
  # client ever starts (confirmed: 0 clients attached before this was added).
  plugins.lspconfig.enable = true;

  lsp.servers = {
    nixd.enable = true;
    lua_ls.enable = true;
    # Ruff (via none-ls/conform above) is the source of truth for Python
    # linting + formatting. Pyright is kept only for navigation/hover/
    # completion. Since deps live in Docker containers and not the local
    # env, Pyright's import resolution and type checking produce false
    # positives (reportMissingImports on numpy/pandas/... etc.), so all of
    # its diagnostics are silenced here - let Ruff own the diagnostics.
    pyright = {
      enable = true;
      config.settings.python.analysis = {
        # Don't try to type-check against a Python env we don't have.
        typeCheckingMode = "off";
        # Only analyse open files, and don't reach into (missing) library
        # code or auto-discover import search paths.
        diagnosticMode = "openFilesOnly";
        useLibraryCodeForTypes = false;
        autoSearchPaths = false;
        # Belt-and-braces: even with type checking off, explicitly mute the
        # import-resolution diagnostics that fire when packages aren't
        # installed locally.
        diagnosticSeverityOverrides = {
          reportMissingImports = "none";
          reportMissingModuleSource = "none";
          reportAttributeAccessIssue = "none";
          reportUndefinedVariable = "none";
        };
      };
    };
    # JS/TS LSP: typescript-language-server (ts_ls). It runs the project's own
    # TypeScript (5.x, from node_modules), so its module resolution matches the
    # build exactly. We tried tsgo (typescript-go 7.0.x) for speed, but TS 7.0
    # has *removed* `baseUrl`, so it can't resolve baseUrl-based `src/...`
    # imports and floods those buffers with false TS2307 errors that the real
    # `tsc` 5.x build never reports. ts_ls doesn't have that problem. Binary is
    # provided by pkgs.typescript-language-server in extraPackages above;
    # nvim-lspconfig ships the `ts_ls` server def.
    ts_ls.enable = true;
  };

  # Registered on `LspAttach` (buffer-local, only where a language server is
  # actually running) rather than globally, so plain `gd` keeps its vanilla
  # Vim "jump to local declaration" behaviour in buffers with no LSP client.
  # Neovim's built-in default LSP keymaps (grr, gra, gri, gO, ...) don't
  # include `gd` - it's deliberately left alone so this doesn't clobber that
  # behaviour. Routed through Telescope rather than vim.lsp.buf.definition
  # directly so multiple candidates open as a fuzzy list instead of jumping
  # to whichever one the server returns first.
  lsp.keymaps = [
    {
      key = "gd";
      action.__raw = ''function() require("telescope.builtin").lsp_definitions() end'';
      options.desc = "Go to definition";
    }
  ];

  # nvim-treesitter-textobjects (main branch) configures itself via its own
  # setup() call rather than through nixvim's plugin options - see the
  # `treesitter-textobjects` keymaps below for the matching select/move binds.
  extraConfigLua = ''
    require("nvim-treesitter-textobjects").setup({
      select = {
        lookahead = true,
        selection_modes = {
          ["@function.outer"] = "V",
          ["@class.outer"] = "V",
        },
      },
      move = {
        set_jumps = true,
      },
    })

    -- Restores the last session's buffers/window layout for the current
    -- project directory when nvim is opened with no file argument (`nvim`,
    -- not `nvim somefile.txt`) - `nested` so plugins' own FileType/BufRead
    -- autocmds still fire for the restored buffers (treesitter highlighting,
    -- LSP attach, etc.), which they wouldn't under a plain non-nested
    -- VimEnter callback.
    vim.api.nvim_create_autocmd("VimEnter", {
      nested = true,
      callback = function()
        if vim.fn.argc() == 0 then
          require("persistence").load()
        end
      end,
    })

    -- Neo-tree's buffer isn't a plain file buffer, so mksession can't
    -- reconstruct it - restoring one leaves a broken neo-tree pane that
    -- errors until it's manually :bd'd. Close it before the session is
    -- written so it's never captured in the first place.
    vim.api.nvim_create_autocmd("User", {
      pattern = "PersistenceSavePre",
      callback = function()
        vim.cmd("Neotree close")
      end,
    })

    -- Auto-open the dap-ui scopes/stacks/breakpoints/watches panel when a
    -- debug session starts, and close it again once the session ends -
    -- otherwise it has to be toggled by hand every time (upstream-recommended
    -- wiring; not exposed as a typed nixvim option since it hooks dap's
    -- listener tables directly).
    local dap, dapui = require("dap"), require("dapui")
    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close()
    end

    -- claudecode's unified diff layout (plugins.claudecode above) hardcodes
    -- its own highlight groups rather than following the colorscheme; link
    -- them to the equivalents catppuccin already themes well, so a Claude
    -- edit reads with the same colors as a git diff/gitsigns sign instead of
    -- the plugin's built-in green/red. Re-applied on every colorscheme
    -- change, not just at startup.
    local function apply_claudecode_diff_highlights()
      vim.api.nvim_set_hl(0, "ClaudeCodeInlineDiffAdd", { link = "DiffAdd" })
      vim.api.nvim_set_hl(0, "ClaudeCodeInlineDiffDelete", { link = "DiffDelete" })
      vim.api.nvim_set_hl(0, "ClaudeCodeInlineDiffAddSign", { link = "GitSignsAdd" })
      vim.api.nvim_set_hl(0, "ClaudeCodeInlineDiffDeleteSign", { link = "GitSignsDelete" })
    end
    apply_claudecode_diff_highlights()
    vim.api.nvim_create_autocmd("ColorScheme", { callback = apply_claudecode_diff_highlights })

    -- Quick-reference cheat sheet, opened via <leader>? (keymaps below).
    -- Hand-curated and importance-ordered - which-key (triggered by pausing
    -- on any <leader> prefix) already covers exhaustive, alphabetical
    -- discovery of every registered keymap; this is deliberately the
    -- opposite: a short, ranked "what matters most" list, so it has to be
    -- maintained by hand rather than generated from the keymaps below.
    local CHEATSHEET = [[
# Cheat Sheet

<leader> = Space

## Navigate & find
  <leader>e    Toggle file explorer (neo-tree)
  <leader>ff   Find files
  <leader>fg   Live grep (project search)
  <leader>fo   Recent files
  <leader>fb   Open buffers
  <leader>fm   Harpoon marks
  / (visual)   Search selection in buffer (then n/N)

## Code intelligence
  gd           Go to definition (cross-file)
  K            Hover docs
  <leader>fd   Diagnostics (picker)
  <leader>xx   Diagnostics (persistent panel)
  <leader>xr   LSP references/definitions (panel)

## Git
  <leader>gg   Git status (Neogit)
  <leader>lg   Lazygit (floating)
  <leader>gd   Open diff view
  <leader>gD   Close diff view
  <leader>gh   File history (repo)
  <leader>gH   File history (current file)
  ]c / [c      Next/previous git hunk
  <leader>hs   Stage hunk
  <leader>hr   Reset hunk
  <leader>hp   Preview hunk

## Editing
  sa{motion}{char}   Add surround (e.g. saiw) )
  sd{char}           Delete surround
  sr{char}{char}     Replace surround
  af / if            Select around/inside function
  ac / ic            Select around/inside class
  <leader>sr         Search & replace across files

## Debugging
  <leader>db   Toggle breakpoint
  <leader>dc   Continue / start
  <leader>di   Step into
  <leader>do   Step over
  <leader>dO   Step out
  <leader>du   Toggle debug UI

## Buffers & windows
  <S-h> / <S-l>      Previous/next buffer
  <leader>b1..b9     Go to buffer N
  <leader>bd         Close buffer
  <C-h/j/k/l>        Focus window left/down/up/right

## Harpoon
  <leader>a    Add file
  <C-e>        Toggle quick menu
  <leader>1..4 Jump to slot N

## Terminal & misc
  <leader>tt   Toggle floating terminal
  <leader>ld   Lazydocker (floating)
  zR / zM      Open/close all folds

Press q or <Esc> to close.
]]

    -- Hide any floating terminal window (e.g. the lazygit/lazydocker snacks
    -- floats bound to <leader>lg/<leader>ld). Called over RPC by the
    -- `lazygitEdit` helper (flake.nix) the instant an edit is triggered from
    -- lazygit running *inside* nvim's own floating terminal: the file opens
    -- in a buffer underneath via --remote, but without this the float stays
    -- on top and hides it. Hiding (not closing) leaves lazygit's terminal job
    -- running, so re-pressing <leader>lg brings it straight back where you
    -- left off. No-op when no float is open - e.g. lazygit run from a sibling
    -- tmux pane, the original cross-pane workflow - so it's safe on both paths.
    function _G.NixvimHideFloatTerms()
      for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
          local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
          if ok and cfg.relative ~= "" then
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].buftype == "terminal" then
              pcall(vim.api.nvim_win_hide, win)
            end
          end
        end
      end
      return ""
    end

    _G.NixvimCheatsheet = {
      show = function()
        Snacks.win({
          text = CHEATSHEET,
          ft = "markdown",
          border = "rounded",
          title = " Cheat Sheet ",
          title_pos = "center",
          width = 0.6,
          height = 0.8,
        })
      end,
    }
  '';

  keymaps = [
    { mode = "i"; key = "jj"; action = "<Esc>"; options.desc = "Escape insert mode"; }
    { mode = "i"; key = "kj"; action = "<Esc>"; options.desc = "Escape insert mode"; }
    { mode = "v"; key = "kj"; action = "<Esc>"; options.desc = "Clear visual selection"; }
    { mode = "n"; key = "<leader>w"; action = ":w<CR>"; options.desc = "Save file"; }
    { mode = "n"; key = "<leader>q"; action = ":q<CR>"; options.desc = "Quit"; }
    { mode = "n"; key = "<C-h>"; action = "<C-w>h"; options.desc = "Focus left window"; }
    { mode = "n"; key = "<C-l>"; action = "<C-w>l"; options.desc = "Focus right window"; }
    { mode = "n"; key = "<C-j>"; action = "<C-w>j"; options.desc = "Focus below window"; }
    { mode = "n"; key = "<C-k>"; action = "<C-w>k"; options.desc = "Focus above window"; }

    # Same window-focus jumps, usable from inside a terminal buffer (e.g. a
    # :terminal split) - terminal mode intercepts <C-h/j/k/l> for the job
    # running inside it, so the normal-mode maps above never fire there.
    # <C-\><C-n> first drops out of terminal mode into the terminal buffer's
    # normal mode, then the window motion runs as usual.
    { mode = "t"; key = "<C-h>"; action = "<C-\\><C-n><C-w>h"; options.desc = "Focus left window"; }
    { mode = "t"; key = "<C-l>"; action = "<C-\\><C-n><C-w>l"; options.desc = "Focus right window"; }
    { mode = "t"; key = "<C-j>"; action = "<C-\\><C-n><C-w>j"; options.desc = "Focus below window"; }
    { mode = "t"; key = "<C-k>"; action = "<C-\\><C-n><C-w>k"; options.desc = "Focus above window"; }

    { mode = "n"; key = "<leader>e"; action = ":Neotree toggle<CR>"; options.desc = "Toggle file explorer"; }
    { mode = "n"; key = "<leader>gg"; action = ":Neogit<CR>"; options.desc = "Open git status"; }
    { mode = "n"; key = "<leader>?"; action.__raw = "function() NixvimCheatsheet.show() end"; options.desc = "Cheat sheet"; }

    # Diffview: side-by-side diff / merge-conflict resolution (see plugins.diffview comment above).
    { mode = "n"; key = "<leader>gd"; action = ":DiffviewOpen<CR>"; options.desc = "Open diff view"; }
    { mode = "n"; key = "<leader>gD"; action = ":DiffviewClose<CR>"; options.desc = "Close diff view"; }
    { mode = "n"; key = "<leader>gh"; action = ":DiffviewFileHistory<CR>"; options.desc = "File history (repo)"; }
    { mode = "n"; key = "<leader>gH"; action = ":DiffviewFileHistory %<CR>"; options.desc = "File history (current file)"; }

    # lazygit / lazydocker in a snacks floating terminal - the same TUIs you
    # run in a sibling tmux pane, but toggleable over the current buffer for a
    # quick check without leaving nvim. No new package: nvim always runs inside
    # this flake's devShell, so `lazygit` (the RPC-edit-aware `lazygitWrapped`
    # from flake.nix) and `lazydocker` are already on PATH - deliberately NOT
    # added to extraPackages, since nixvim prepends those and a plain
    # pkgs.lazygit would shadow the wrapper. Snacks.terminal keys the terminal
    # by command, so re-pressing the key toggles the same instance rather than
    # spawning a second one.
    { mode = "n"; key = "<leader>lg"; action.__raw = ''function() Snacks.terminal("lazygit") end''; options.desc = "Lazygit"; }
    { mode = "n"; key = "<leader>ld"; action.__raw = ''function() Snacks.terminal("lazydocker") end''; options.desc = "Lazydocker"; }

    # grug-far: project-wide search & replace (see plugins.grug-far comment above).
    { mode = "n"; key = "<leader>sr"; action.__raw = ''function() require("grug-far").open() end''; options.desc = "Search and replace"; }

    # markdown-preview: toggle the browser preview (see plugins.markdown-preview comment above).
    { mode = "n"; key = "<leader>mp"; action = ":MarkdownPreviewToggle<CR>"; options.desc = "Toggle markdown preview"; }

    # Toggleable floating terminal (snacks.nvim, already installed for claudecode).
    { mode = "n"; key = "<leader>tt"; action.__raw = "function() Snacks.terminal() end"; options.desc = "Toggle terminal"; }
    { mode = "t"; key = "<leader>tt"; action.__raw = "function() Snacks.terminal() end"; options.desc = "Toggle terminal"; }

    # Debugger (see plugins.dap*/extraConfigLua comments above). Mirrors the
    # familiar VSCode debug-bar actions: toggle a breakpoint, run/continue,
    # step in/over/out, kill the session, inspect state.
    { mode = "n"; key = "<leader>db"; action.__raw = ''function() require("dap").toggle_breakpoint() end''; options.desc = "Toggle breakpoint"; }
    { mode = "n"; key = "<leader>dc"; action.__raw = ''function() require("dap").continue() end''; options.desc = "Continue/start debugging"; }
    { mode = "n"; key = "<leader>di"; action.__raw = ''function() require("dap").step_into() end''; options.desc = "Step into"; }
    { mode = "n"; key = "<leader>do"; action.__raw = ''function() require("dap").step_over() end''; options.desc = "Step over"; }
    { mode = "n"; key = "<leader>dO"; action.__raw = ''function() require("dap").step_out() end''; options.desc = "Step out"; }
    { mode = "n"; key = "<leader>dt"; action.__raw = ''function() require("dap").terminate() end''; options.desc = "Terminate session"; }
    { mode = "n"; key = "<leader>du"; action.__raw = ''function() require("dapui").toggle() end''; options.desc = "Toggle debug UI"; }
    { mode = "n"; key = "<leader>dr"; action.__raw = ''function() require("dap").repl.open() end''; options.desc = "Open debug REPL"; }

    # Trouble: persistent problem-list panel (see plugins.trouble comment above).
    { mode = "n"; key = "<leader>xx"; action = ":Trouble diagnostics toggle<CR>"; options.desc = "Diagnostics (workspace)"; }
    { mode = "n"; key = "<leader>xX"; action = ":Trouble diagnostics toggle filter.buf=0<CR>"; options.desc = "Diagnostics (buffer)"; }
    { mode = "n"; key = "<leader>xL"; action = ":Trouble loclist toggle<CR>"; options.desc = "Location list"; }
    { mode = "n"; key = "<leader>xQ"; action = ":Trouble qflist toggle<CR>"; options.desc = "Quickfix list"; }
    { mode = "n"; key = "<leader>xr"; action = ":Trouble lsp toggle focus=false<CR>"; options.desc = "LSP references/definitions"; }

    # Harpoon: pin/jump between a small working set of files.
    { mode = "n"; key = "<leader>a"; action.__raw = ''function() require("harpoon"):list():add() end''; options.desc = "Harpoon: add file"; }
    { mode = "n"; key = "<C-e>"; action.__raw = ''function() local harpoon = require("harpoon"); harpoon.ui:toggle_quick_menu(harpoon:list()) end''; options.desc = "Harpoon: toggle quick menu"; }
    { mode = "n"; key = "<leader>fm"; action = ":Telescope harpoon marks<CR>"; options.desc = "Harpoon: find marks"; }

    # Folding (za/zo/zc to toggle/open/close a single fold are Neovim
    # built-ins that work unmodified). zR/zM/zK are ufo's richer versions.
    { mode = "n"; key = "zR"; action.__raw = ''function() require("ufo").openAllFolds() end''; options.desc = "Open all folds"; }
    { mode = "n"; key = "zM"; action.__raw = ''function() require("ufo").closeAllFolds() end''; options.desc = "Close all folds"; }
    { mode = "n"; key = "zK"; action.__raw = ''function() require("ufo").peekFoldedLinesUnderCursor() end''; options.desc = "Preview folded lines under cursor"; }

    # Project-wide search, VSCode Ctrl+Shift+F style: <leader>fg already
    # opens a live-grep prompt; this variant greps the visually selected
    # text across the whole project instead of typing the query by hand.
    { mode = "v"; key = "<leader>fg"; action.__raw = ''function() vim.cmd('noau normal! "vy"'); local text = vim.fn.getreg("v"):gsub("\n", " "); require("telescope.builtin").grep_string({ search = text }) end''; options.desc = "Grep selection in project"; }

    # In-buffer search of the visual selection: select text (e.g. `viw`), hit
    # `/`, and it becomes the active search pattern - then n/N navigate matches,
    # exactly like typing `/word<CR>` but without retyping. Yanked via register
    # `v` (leaves the unnamed register untouched) and searched as a `\V` literal
    # so regex metacharacters and multi-line selections match verbatim.
    { mode = "x"; key = "/"; action.__raw = ''function() vim.cmd('noau normal! "vy'); local text = vim.fn.escape(vim.fn.getreg("v"), [[\]]):gsub("\n", [[\n]]); vim.fn.setreg("/", [[\V]] .. text); vim.fn.histadd("search", vim.fn.getreg("/")); vim.o.hlsearch = true; vim.cmd("normal! n") end''; options.desc = "Search selection in buffer"; }

    # Buffer ("tab") navigation via bufferline.
    { mode = "n"; key = "<S-h>"; action = ":BufferLineCyclePrev<CR>"; options.desc = "Previous buffer"; }
    { mode = "n"; key = "<S-l>"; action = ":BufferLineCycleNext<CR>"; options.desc = "Next buffer"; }
    { mode = "n"; key = "<leader>bp"; action = ":BufferLineTogglePin<CR>"; options.desc = "Pin buffer"; }
    { mode = "n"; key = "<leader>bo"; action = ":BufferLineCloseOthers<CR>"; options.desc = "Close other buffers"; }
    { mode = "n"; key = "<leader>bd"; action.__raw = ''function() require("mini.bufremove").delete(0, false) end''; options.desc = "Close buffer"; }
    { mode = "n"; key = "<leader>bD"; action.__raw = ''function() require("mini.bufremove").delete(0, true) end''; options.desc = "Force-close buffer (discard changes)"; }

    # Treesitter textobjects: select "a function"/"inner function"/"a class"/"inner class".
    { mode = [ "x" "o" ]; key = "af"; action.__raw = ''function() require("nvim-treesitter-textobjects.select").select_textobject("@function.outer", "textobjects") end''; options.desc = "Select around function"; }
    { mode = [ "x" "o" ]; key = "if"; action.__raw = ''function() require("nvim-treesitter-textobjects.select").select_textobject("@function.inner", "textobjects") end''; options.desc = "Select inside function"; }
    { mode = [ "x" "o" ]; key = "ac"; action.__raw = ''function() require("nvim-treesitter-textobjects.select").select_textobject("@class.outer", "textobjects") end''; options.desc = "Select around class"; }
    { mode = [ "x" "o" ]; key = "ic"; action.__raw = ''function() require("nvim-treesitter-textobjects.select").select_textobject("@class.inner", "textobjects") end''; options.desc = "Select inside class"; }

    # Treesitter textobjects: jump to next/previous function start/end.
    { mode = [ "n" "x" "o" ]; key = "]m"; action.__raw = ''function() require("nvim-treesitter-textobjects.move").goto_next_start("@function.outer", "textobjects") end''; options.desc = "Next function start"; }
    { mode = [ "n" "x" "o" ]; key = "]M"; action.__raw = ''function() require("nvim-treesitter-textobjects.move").goto_next_end("@function.outer", "textobjects") end''; options.desc = "Next function end"; }
    { mode = [ "n" "x" "o" ]; key = "[m"; action.__raw = ''function() require("nvim-treesitter-textobjects.move").goto_previous_start("@function.outer", "textobjects") end''; options.desc = "Previous function start"; }
    { mode = [ "n" "x" "o" ]; key = "[M"; action.__raw = ''function() require("nvim-treesitter-textobjects.move").goto_previous_end("@function.outer", "textobjects") end''; options.desc = "Previous function end"; }
  ]
  # <leader>b1..<leader>b9: jump straight to the Nth tab, like VSCode's Ctrl+1..9.
  ++ (map
    (n: {
      mode = "n";
      key = "<leader>b${toString n}";
      action = ":BufferLineGoToBuffer ${toString n}<CR>";
      options.desc = "Go to buffer ${toString n}";
    })
    (pkgs.lib.range 1 9)
  )
  # <leader>1..<leader>4: jump straight to Harpoon slot N. Deliberately not
  # Alt+N - Alt-modified keys get mangled differently by every
  # terminal/tmux/keyboard-layout combo (e.g. AZERTY sends the unshifted
  # symbol under the digit instead of the digit itself), so plain leader
  # sequences are the only binding that's reliable everywhere.
  ++ (map
    (n: {
      mode = "n";
      key = "<leader>${toString n}";
      action.__raw = ''function() require("harpoon"):list():select(${toString n}) end'';
      options.desc = "Harpoon: go to slot ${toString n}";
    })
    (pkgs.lib.range 1 4)
  );
}
