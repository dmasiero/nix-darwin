{
  description = "Example nix-darwin system flake";

  # Inputs
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "https://flakehub.com/f/nix-community/home-manager/0.2505.4807.tar.gz";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  # Outputs
  outputs = inputs@{ self, home-manager, nix-darwin, nixpkgs }:
  let
    configuration = { pkgs, lib, ... }:
    let
      disabledHotkeysSettings = import ./disable-apple-default-hotkeys.nix { inherit lib; };
    in
    {
      # System Configuration
      system = {
        configurationRevision = self.rev or self.dirtyRev or null;
        stateVersion = 6;
        primaryUser = "doug";

        # System Defaults
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
            persistent-others = [];
            persistent-apps = [
              { app = "/Applications/Ghostty.app"; }
              { app = "/Applications/Safari.app"; }
            ];
            wvous-tl-corner = 1;  # Top-left: Disabled
            wvous-tr-corner = 10; # Top-right: Put Display to Sleep
            wvous-bl-corner = 1;  # Bottom-left: Disabled
            wvous-br-corner = 12; # Bottom-right: Quick Note
          };
          CustomUserPreferences = {} // disabledHotkeysSettings;
        };

        # Activation Scripts
        activationScripts.postActivation.text = ''
          sudo -u doug /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
        '';
      };

      # User Configuration
      users.users.doug = {
        name = "doug";
        home = "/Users/doug";
      };

      # Nix Configuration
      nix = {
        enable = false;
        settings.experimental-features = "nix-command flakes";
      };

      # Packages
      environment.systemPackages = with pkgs; [];

      # Fonts
      fonts.packages = with pkgs; [
        nerd-fonts.fira-code
        nerd-fonts.jetbrains-mono
      ];

      # Homebrew
      homebrew = {
        enable = true;
        taps = [ "sst/tap" ];
        brews = [ "sst/tap/opencode" ];
        casks = [
          # Communication
          "discord"
          "rocket-chat"
          "telegram"
          # Development
          "docker"
          "utm"
          # Media
          "adobe-creative-cloud"
          "vlc"
          # Productivity
          "appflowy"
          "libreoffice"
          "raycast"
          "ticktick"
          # Security
          "bitwarden"
          "viscosity"
          "wireshark"
          # Terminal
          "ghostty"
          # Utilities
          "balenaetcher"
          "transmission"
          "xquartz"
          # Web
          "arc"
        ];
      };

      # Platform
      nixpkgs.hostPlatform = "aarch64-darwin";
    };
  in
  {
    darwinConfigurations."Dougs-Virtual-Machine" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        home-manager.darwinModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
             users.doug = { pkgs, lib, ... }: {
               home = {
                 username = "doug";
                 homeDirectory = "/Users/doug";
                 stateVersion = "25.05";
                 enableNixpkgsReleaseCheck = false;
               };

               # Home Manager
               programs.home-manager.enable = true;

               # User Packages
              home.packages = with pkgs; [
                neovim
                neofetch
                fzf
                gh
                lazygit
              ];

               # Dotfiles
               home.file = {
                 ".config/nvim" = { source = ./dotfiles/.config/nvim; recursive = true; };
                 ".p10k.zsh" = { source = ./dotfiles/.p10k.zsh; };
               };

               # Environment Variables
               home.sessionVariables = {};

               # ZSH Configuration
              programs.zsh = {
                enable = true;
                initContent = ''
                  [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
                  bindkey '^_' fzf_history_search
                  if [ -f ~/.smanager ]; then
                    . ~/.smanager
                  fi
                  export PATH="/opt/homebrew/bin:$PATH"
                '';
                antidote = {
                  enable = true;
                  package = pkgs.antidote;
                  useFriendlyNames = true;
                  plugins = [
                    "jeffreytse/zsh-vi-mode"
                    "rupa/z"
                    "zsh-users/zsh-autosuggestions"
                    "zsh-users/zsh-syntax-highlighting"
                    "zsh-users/zsh-history-substring-search"
                    "zdharma-continuum/fast-syntax-highlighting kind:defer"
                    "getantidote/use-omz"
                    "ohmyzsh/ohmyzsh path:lib"
                    "ohmyzsh/ohmyzsh path:plugins/git"
                    "ohmyzsh/ohmyzsh path:plugins/extract"
                    "romkatv/powerlevel10k"
                    "joshskidmore/zsh-fzf-history-search"
                    "mattberther/zsh-pyenv"
                  ];
                };
              };

              # TMUX Configuration
              programs.tmux = {
                enable = true;
                baseIndex = 1;
                historyLimit = 10000;
                keyMode = "vi";
                mouse = true;
                terminal = "tmux-256color";
                plugins = with pkgs.tmuxPlugins; [ resurrect ];
                extraConfig = ''
                  # Vim Keybindings
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

                  # Pane Splitting
                  bind - split-window -hbf -c "#{pane_current_path}"
                  bind \\ split-window -hf -c "#{pane_current_path}"
                  bind '"' split-window -v -c "#{pane_current_path}"

                  # Mouse Behavior
                  bind -n MouseDown1Pane select-pane -t= \; send-keys -M

                  # Theme
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

                  # Session Options
                  set -g terminal-overrides "xterm-256color:RGB"
                  set -a terminal-features "xterm*:strikethrough"
                  set -g pane-base-index 1
                  set -g repeat-time 1000
                  set -g display-panes-time 3000
                  set -g detach-on-destroy off
                '';
              };

              # SSH Configuration
              programs.ssh = {
                enable = true;
                matchBlocks = {
                  "hf.co" = {
                    hostname = "hf.co";
                    extraOptions.UseKeychain = "yes";
                    identityFile = [ "~/.ssh/hf-bruari-20231209" ];
                  };
                  "*" = {
                    extraOptions = {
                      UseKeychain = "yes";
                      AddKeysToAgent = "yes";
                      HostkeyAlgorithms = "+ssh-rsa";
                      PubkeyAcceptedAlgorithms = "+ssh-rsa";
                    };
                    identityFile = [
                      "~/.ssh/DMMF-20211104"
                      "~/.ssh/id_DAM_20191006"
                      "~/.ssh/batman_rsa"
                    ];
                  };
                  "github.com" = {
                    hostname = "github.com";
                    extraOptions = {
                      UseKeychain = "yes";
                      AddKeysToAgent = "yes";
                      HostkeyAlgorithms = "+ssh-rsa";
                      PubkeyAcceptedAlgorithms = "+ssh-rsa";
                    };
                    identityFile = [ "~/.ssh/github-dmasiero" ];
                  };
                  "gitea-git" = {
                    hostname = "gitea.masiero.internal";
                    user = "git";
                    port = 2222;
                    extraOptions = {
                      UseKeychain = "yes";
                      AddKeysToAgent = "yes";
                      IdentitiesOnly = "yes";
                    };
                    identityFile = [ "~/.ssh/gitea_masiero_doug" ];
                  };
                  "gitea-mtg" = {
                    hostname = "gitea.masiero.internal";
                    user = "mtg";
                    port = 22;
                    extraOptions = {
                      UseKeychain = "yes";
                      IdentitiesOnly = "yes";
                    };
                    identityFile = [ "~/.ssh/id_rsa" ];
                  };
                };
              };

              # Git Configuration
              programs.git = {
                enable = true;
                userName = "Doug Masiero";
                userEmail = "doug@masiero.tech";
                extraConfig = {
                  init.defaultBranch = "main";
                  pull.rebase = false;
                  color.ui = "auto";
                  core.editor = "nvim";
                  credential.helper = "store";
                };
                aliases = {
                  co = "checkout";
                  st = "status";
                  ci = "commit";
                  br = "branch";
                };
              };

              # Ghostty Configuration
              programs.ghostty = {
                enable = true;
                package = null;
                settings = {
                  theme = "iTerm2 Default";
                  cursor-style = "block";
                  font-size = 18;
                  window-width = 150;
                  window-height = 42;
                  split-divider-color = "727272";
                  font-family = "MonaspiceNe Nerd Font Mono";
                  cursor-click-to-move = true;
                  mouse-hide-while-typing = true;
                  clipboard-paste-protection = false;
                  auto-update = "check";
                };
               };
             };
          };
        }
      ];
    };
  };
}
