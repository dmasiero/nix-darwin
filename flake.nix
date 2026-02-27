{
  description = "Example nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "https://flakehub.com/f/nix-community/home-manager/0.2505.4807.tar.gz";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, home-manager, nix-darwin, ... }:
    let
      configuration = { pkgs, lib, ... }:
        let
          disabledHotkeysSettings = import ./disable-apple-default-hotkeys.nix { inherit lib; };
        in
        {
          system = {
            configurationRevision = self.rev or self.dirtyRev or null;
            stateVersion = 6;
            primaryUser = "doug";

            defaults = {
              WindowManager = {
                StandardHideWidgets = true;
                StageManagerHideWidgets = true;
                EnableStandardClickToShowDesktop = false;
                HideDesktop = true;
              };
              finder.FXPreferredViewStyle = "Nlsv";
              dock = {
                autohide = true;
                show-recents = false;
                persistent-others = [ ];
                persistent-apps = [
                  { app = "/Applications/Ghostty.app"; }
                  { app = "/Applications/Helium.app"; }
                ];
                wvous-tl-corner = 1;
                wvous-tr-corner = 10;
                wvous-bl-corner = 1;
                wvous-br-corner = 12;
              };
              CustomUserPreferences = { } // disabledHotkeysSettings;
            };

            activationScripts.postActivation.text = ''
              (
                sudo -u doug /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u || true
              ) &
            '';
          };

          nixpkgs = {
            hostPlatform = "aarch64-darwin";
            config.allowUnfree = true;
            overlays = [
              (final: prev: {
                pi-coding-agent = prev.callPackage ./pi-coding-agent.nix { };
                swo-cli = prev.callPackage ./swo-cli.nix { };
              })
            ];
          };

          time.timeZone = "America/New_York";

          users.users.doug = {
            name = "doug";
            home = "/Users/doug";
            shell = pkgs.fish;
          };

          programs.fish.enable = true;
          programs.zsh.enable = true;

          nix = {
            enable = false;
            settings.experimental-features = "nix-command flakes";
          };

          documentation.enable = false;

          environment.systemPackages = with pkgs; [ fish ];

          environment.shells = [ pkgs.fish ];

          fonts.packages = with pkgs; [
            nerd-fonts.fira-code
            nerd-fonts.jetbrains-mono
            nerd-fonts.monaspace
            font-awesome
          ];

          homebrew = {
            enable = true;
            taps = [ "sst/tap" ];
            brews = [ "sst/tap/opencode" ];
            casks = [
              "ghostty"
              "helium-browser"
              "raycast"
              "discord"
              "telegram"
              "orbstack"
              "utm"
              "vlc"
              "libreoffice"
              "ticktick"
              "bitwarden"
              "viscosity"
              "balenaetcher"
              "transmission"
              "adobe-creative-cloud"
              "xquartz"
              "wireshark-app"
            ];
          };
        };
    in
    {
      darwinConfigurations."thismac" = nix-darwin.lib.darwinSystem {
        modules = [
          configuration
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              users.doug = { pkgs, lib, config, ... }:
                {
                  home = {
                    username = "doug";
                    homeDirectory = "/Users/doug";
                    stateVersion = "25.05";
                    enableNixpkgsReleaseCheck = false;
                  };

                  programs.home-manager.enable = true;
                  xdg.enable = true;

                  manual.manpages.enable = false;

                  home.packages = with pkgs;
                    [
                      bind
                      fd
                      font-awesome
                      fping
                      fzf
                      gh
                      git
                      htop
                      keychain
                      lazygit
                      mtr
                      pi-coding-agent
                      python3
                      ripgrep
                      swo-cli
                      unzip
                      uv
                      weechat
                      wget
                      whois
                    ]
                    ++ lib.optionals (builtins.hasAttr "trzsz-ssh" pkgs) [ pkgs."trzsz-ssh" ]
                    ++ lib.optionals (builtins.hasAttr "puppet-bolt" pkgs) [ pkgs."puppet-bolt" ];

                  fonts.fontconfig.enable = true;

                  home.file = {
                    ".config/lazygit" = {
                      source = config.lib.file.mkOutOfStoreSymlink "/Users/doug/dotfiles/lazygit";
                    };
                    ".pi" = {
                      source = config.lib.file.mkOutOfStoreSymlink "/Users/doug/dotfiles/pi";
                    };
                    ".config/opencode" = {
                      source = config.lib.file.mkOutOfStoreSymlink "/Users/doug/dotfiles/opencode";
                    };
                    ".config/weechat" = {
                      source = config.lib.file.mkOutOfStoreSymlink "/Users/doug/dotfiles/weechat";
                    };
                    ".swo-cli.yml" = {
                      source = config.lib.file.mkOutOfStoreSymlink "/Users/doug/dotfiles/.swo-cli.yml";
                    };
                    ".config/ghostty" = {
                      source = config.lib.file.mkOutOfStoreSymlink "/Users/doug/dotfiles/ghostty";
                    };
                  };

                  home.activation.fixSshPerms = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                    if [ -e "$HOME/.ssh" ]; then
                      SSH_DIR="$(readlink "$HOME/.ssh" 2>/dev/null || printf "%s" "$HOME/.ssh")"

                      chmod 700 "$SSH_DIR" || true
                      find "$SSH_DIR" -type d -exec chmod 700 {} \; || true
                      # Do not chmod symlinks (e.g. Home Manager generated ~/.ssh/config in /nix/store)
                      find "$SSH_DIR" -type f ! -name "*.pub" -exec chmod 600 {} \; || true
                      find "$SSH_DIR" -type f -name "*.pub" -exec chmod 644 {} \; || true
                    fi
                  '';

                  programs.zsh = {
                    enable = true;
                    initContent = ''
                      if [[ -o interactive ]] && command -v fish >/dev/null 2>&1; then
                        exec fish -l
                      fi
                    '';
                  };

                  programs.fish = {
                    enable = true;

                    loginShellInit = ''
                      if test -x /opt/homebrew/bin/brew
                        eval (/opt/homebrew/bin/brew shellenv)
                      end

                      set -l _kc_keys
                      for k in ~/.ssh/DM-20260211 ~/.ssh/id_DAM_20191006 ~/.ssh/github-dmasiero ~/.ssh/batman_rsa
                        if test -f $k
                          set _kc_keys $_kc_keys $k
                        end
                      end

                      if type -q keychain; and test (count $_kc_keys) -gt 0
                        set -lx SHELL (command -v fish)
                        keychain --eval --quiet $_kc_keys | source
                      end
                    '';

                    plugins = [
                      # bass: lets fish source bash/POSIX scripts (used for smanager)
                      { name = "bass"; src = pkgs.fishPlugins.bass.src; }
                    ];

                    shellAliases = {
                      vi = "nvim";
                      vim = "nvim";
                      oc = "opencode";
                    };

                    interactiveShellInit = ''
                      set fish_greeting ""

                      # Force fish-native Ctrl-R history UI (override plugin bindings like fzf)
                      bind \cr history-pager
                      bind -M insert \cr history-pager
                      bind -M default \cr history-pager

                      # Source smanager (bash script — requires bass)
                      if test -f ~/Dev/masiero/smanager/smanager
                        bass source ~/Dev/masiero/smanager/smanager
                      end

                      if test -z "$TMUX"
                          set -l _is_ssh 0
                          test -n "$SSH_TTY"; and set _is_ssh 1
                          test -n "$SSH_CONNECTION"; and set _is_ssh 1
                          test -n "$SSH_CLIENT"; and set _is_ssh 1
                          if test $_is_ssh -eq 1
                              if tmux has-session 2>/dev/null
                                  exec tmux attach-session
                              else
                                  exec tmux new-session
                              end
                          end
                      end
                    '';

                    functions = {
                      _prompt_duration = ''
                        set -l ms $argv[1]
                        set -l s (math --scale=0 $ms / 1000)
                        if test $s -lt 60
                            echo -n $s"s"
                        else if test $s -lt 3600
                            set -l m (math --scale=0 "$s / 60")
                            set -l r (math --scale=0 "$s % 60")
                            if test $r -gt 0
                                echo -n $m"m "$r"s"
                            else
                                echo -n $m"m"
                            end
                        else if test $s -lt 86400
                            set -l h (math --scale=0 "$s / 3600")
                            set -l m (math --scale=0 "$s % 3600 / 60")
                            if test $m -gt 0
                                echo -n $h"h "$m"m"
                            else
                                echo -n $h"h"
                            end
                        else
                            set -l d (math --scale=0 "$s / 86400")
                            set -l h (math --scale=0 "$s % 86400 / 3600")
                            if test $h -gt 0
                                echo -n $d"d "$h"h"
                            else
                                echo -n $d"d"
                            end
                        end
                      '';

                      _git_info = ''
                        set -l branch (git symbolic-ref --short HEAD 2>/dev/null)
                        if test $status -ne 0
                            set -l sha (git rev-parse --short HEAD 2>/dev/null)
                            test $status -ne 0; and return
                            set branch '@'$sha
                        end

                        set -l dirty ""
                        if not git diff --quiet 2>/dev/null
                            set dirty "*"
                        else if not git diff --cached --quiet 2>/dev/null
                            set dirty "*"
                        else
                            set -l untracked (git ls-files --others --exclude-standard 2>/dev/null | head -1)
                            if test -n "$untracked"
                                set dirty "*"
                            end
                        end

                        set_color '#585858'
                        printf ' %s%s' $branch $dirty
                        set_color normal

                        set -l upstream (git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null)
                        if test -n "$upstream"
                            set -l ahead (git rev-list --count '@{upstream}..HEAD' 2>/dev/null)
                            set -l behind (git rev-list --count 'HEAD..@{upstream}' 2>/dev/null)
                            if test "$ahead" -gt 0; and test "$behind" -gt 0
                                set_color cyan
                                printf '⇣⇡'
                                set_color normal
                            else if test "$behind" -gt 0
                                set_color '#585858'
                                printf ':'
                                set_color cyan
                                printf '⇣'
                                set_color normal
                            else if test "$ahead" -gt 0
                                set_color '#585858'
                                printf ':'
                                set_color cyan
                                printf '⇡'
                                set_color normal
                            end
                        end
                      '';

                      fish_prompt = ''
                        set -l last_status $status

                        set_color '#585858'
                        printf '%s@%s' (whoami) (hostname -s)
                        set_color normal

                        printf ' '
                        set_color blue
                        printf '%s' (prompt_pwd)
                        set_color normal

                        _git_info

                        if test $CMD_DURATION -ge 1000
                            printf ' '
                            set_color yellow
                            printf '%s' (_prompt_duration $CMD_DURATION)
                            set_color normal
                        end

                        printf ' '
                        if test $last_status -eq 0
                            set_color magenta
                        else
                            set_color red
                        end
                        printf '❯'
                        set_color normal
                        printf ' '
                      '';
                    };
                  };

                  programs.neovim = {
                    enable = true;
                    defaultEditor = true;
                    plugins = with pkgs.vimPlugins; [
                      vim-surround
                      vim-commentary
                      vim-repeat
                      vim-unimpaired
                      vim-fugitive
                      catppuccin-nvim
                      lualine-nvim
                      nvim-web-devicons
                      gitsigns-nvim
                      bufferline-nvim
                      mini-nvim
                      telescope-nvim
                      plenary-nvim
                      telescope-fzf-native-nvim
                      oil-nvim
                    ];

                    extraLuaConfig = ''
                      vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })
                      vim.g.mapleader = " "
                      vim.g.maplocalleader = " "
                      vim.opt.clipboard = "unnamedplus"
                      local function paste()
                        return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
                      end
                      vim.g.clipboard = {
                        name = "OSC 52",
                        copy = {
                          ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
                          ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
                        },
                        paste = {
                          ["+"] = paste,
                          ["*"] = paste,
                        },
                      }
                      vim.api.nvim_set_hl(0, "Normal",     { bg = "none" })
                      vim.api.nvim_set_hl(0, "NonText",    { bg = "none" })
                      vim.api.nvim_set_hl(0, "EndOfBuffer", { bg = "none" })
                      require("mini.pairs").setup()
                      require("mini.jump").setup()

                      require("oil").setup({
                        view_options = {
                          show_hidden = true,
                          is_always_hidden = function(name, _)
                            return name == ".."
                          end,
                        },
                        win_options = {
                          number = false,
                          relativenumber = false,
                        },
                        keymaps = {
                          ["<BS>"] = "actions.parent",
                          ["h"] = "actions.parent",
                          ["-"] = "actions.parent",
                        },
                      })
                      vim.keymap.set("n", "<leader>e", "<CMD>Oil<CR>", { desc = "Open parent directory" })

                      require("catppuccin").setup({ flavour = "mocha", transparent_background = true })
                      vim.cmd.colorscheme "catppuccin"

                      require("lualine").setup({ options = { theme = "catppuccin", globalstatus = true } })

                      require("telescope").setup({
                        extensions = {
                          fzf = {
                            fuzzy = true,
                            case_mode = "smart_case",
                          },
                        },
                      })

                      require("gitsigns").setup({
                        signs = {
                          add          = { text = "▎" },
                          change       = { text = "▎" },
                          delete       = { text = "" },
                          topdelete    = { text = "" },
                          changedelete = { text = "▎" },
                        },
                        current_line_blame = false,
                        signcolumn = true,
                        numhl = false,
                        linehl = false,
                        word_diff = false,
                      })

                      vim.opt.number = true
                      vim.opt.relativenumber = true

                      vim.api.nvim_create_autocmd({ "InsertEnter" }, {
                        pattern = "*",
                        callback = function() vim.opt.relativenumber = false end,
                      })
                      vim.api.nvim_create_autocmd({ "InsertLeave" }, {
                        pattern = "*",
                        callback = function() vim.opt.relativenumber = true end,
                      })

                      require("bufferline").setup({
                        options = {
                          mode = "buffers",
                          separator_style = "thin",
                          always_show_bufferline = false,
                          show_buffer_close_icons = true,
                          show_close_icon = false,
                          color_icons = true,
                          diagnostics = "nvim_lsp",
                        },
                      })

                      vim.keymap.set("n", "<Tab>",   "<cmd>BufferLineCycleNext<CR>", { silent = true })
                      vim.keymap.set("n", "<S-Tab>", "<cmd>BufferLineCyclePrev<CR>", { silent = true })

                      for i = 1, 9 do
                        vim.keymap.set("n", "<leader>" .. i, "<cmd>BufferLineGoToBuffer " .. i .. "<CR>", { silent = true })
                      end
                      vim.keymap.set("n", "<leader>$", "<cmd>BufferLineGoToBuffer -1<CR>", { desc = "Last buffer" })

                      require("telescope").load_extension("fzf")
                      local builtin = require("telescope.builtin")
                      vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
                      vim.keymap.set("n", "<leader>fg", builtin.live_grep,  { desc = "Grep project" })
                      vim.keymap.set("n", "<leader>fb", builtin.buffers,    { desc = "Buffers" })
                      vim.keymap.set("n", "<leader>fr", builtin.oldfiles,   { desc = "Recent files" })
                    '';
                  };

                  programs.tmux = {
                    enable = true;
                    baseIndex = 1;
                    historyLimit = 10000;
                    keyMode = "vi";
                    mouse = true;
                    terminal = "tmux-256color";
                    plugins = with pkgs.tmuxPlugins; [ resurrect ];
                    extraConfig = ''
                      bind -T copy-mode-vi v send-keys -X begin-selection
                      bind -T copy-mode-vi y send-keys -X copy-selection
                      bind h select-pane -L
                      bind j select-pane -D
                      bind k select-pane -U
                      bind l select-pane -R
                      bind -r H resize-pane -L 2
                      bind -r J resize-pane -D 2
                      bind -r K resize-pane -U 2
                      bind -r L resize-pane -R 2

                      bind - split-window -hbf -c "#{pane_current_path}"
                      bind \\ split-window -hf -c "#{pane_current_path}"
                      bind '"' split-window -v -c "#{pane_current_path}"

                      bind -n MouseDown1Pane select-pane -t= \; send-keys -M

                      set-option -g status-style bg=colour0,fg=colour205
                      set-window-option -g window-status-style fg=colour123,bg=default,dim
                      set-window-option -g window-status-current-style fg=colour84,bg=default,bright
                      set-option -g pane-border-style fg=colour81
                      set-option -g pane-active-border-style fg=colour84
                      set-option -g message-style bg=colour81,fg=colour17
                      set-option -g display-panes-active-colour colour203
                      set-option -g display-panes-colour colour84
                      set-window-option -g clock-mode-colour colour205
                      set -g status-right '%H:%M %d-%b-%y'

                      set -s set-clipboard on
                      set -g mouse on
                      set -g allow-passthrough on
                      set -g terminal-overrides "xterm-256color:RGB"
                      set -a terminal-features "xterm*:strikethrough"
                      set -g pane-base-index 1
                      set -g repeat-time 1000
                      set -g display-panes-time 3000
                      set -g detach-on-destroy off
                    '';
                  };

                  programs.ssh = {
                    enable = true;
                    matchBlocks = {
                      "hf.co" = {
                        identityFile = [ "~/.ssh/hf-bruari-20231209" ];
                      };
                      "github.com" = {
                        extraOptions = {
                          AddKeysToAgent = "yes";
                          HostkeyAlgorithms = "+ssh-rsa";
                          PubkeyAcceptedAlgorithms = "+ssh-rsa";
                          UseKeychain = "yes";
                        };
                        identityFile = [ "~/.ssh/github-dmasiero" ];
                      };
                      "gitea.masiero.internal" = {
                        user = "git";
                        port = 2222;
                        extraOptions = {
                          IdentitiesOnly = "yes";
                          UseKeychain = "yes";
                        };
                        identityFile = [ "~/.ssh/gitea_masiero_doug" ];
                      };
                      "*" = {
                        extraOptions = {
                          HostkeyAlgorithms = "+ssh-rsa";
                          PubkeyAcceptedAlgorithms = "+ssh-rsa";
                          IdentitiesOnly = "yes";
                          LogLevel = "ERROR";
                          UseKeychain = "yes";
                        };
                        identityFile = [
                          "~/.ssh/DMMF-20211104"
                          "~/.ssh/id_DAM_20191006"
                          "~/.ssh/batman_rsa"
                        ];
                      };
                    };
                  };

                  programs.git = {
                    enable = true;
                    userName = "Doug Masiero";
                    userEmail = "doug@masie.ro";
                    extraConfig = {
                      init.defaultBranch = "main";
                      pull.rebase = false;
                      color.ui = "auto";
                      core.editor = "nvim";
                      credential.helper = "store";
                    };
                  };

                };
            };
          }
        ];
      };
    };
}
