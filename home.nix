{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "doug";
  home.homeDirectory = "/Users/doug";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = [
    pkgs.neovim pkgs.neofetch pkgs.fzf pkgs.gh pkgs.lazygit
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    ".config/nvim" = { source = ./dotfiles/.config/nvim; recursive = true; };
    ".p10k.zsh" = { source = ./dotfiles/.p10k.zsh; };
    ".ssh" = { source = ./dotfiles/.ssh; recursive = true; };

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

# zsh Configuration
  programs.zsh = {
    enable = true;
    initContent = ''
      [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
      bindkey '^_' fzf_history_search
      
      # masiero - smanager
      if [ -f ~/.smanager ]; then
        . ~/.smanager
      fi

      # Add Homebrew bin to PATH
      export PATH="/opt/homebrew/bin:$PATH"
    '';
    antidote = {
      enable = true; # Enable Antidote
      package = pkgs.antidote; # Use the Antidote package from nixpkgs
      useFriendlyNames = true; # Optional: Use friendly names for cloned plugins
      plugins = [
        # zsh vi mode
        "jeffreytse/zsh-vi-mode"
        # jump around - Tracks your most used directories, based on 'frecency'
        "rupa/z"
        # fish-like plugins
        "zsh-users/zsh-autosuggestions"
        "zsh-users/zsh-syntax-highlighting"
        "zsh-users/zsh-history-substring-search"
        "zdharma-continuum/fast-syntax-highlighting kind:defer"
        # oh-my-zsh
        "getantidote/use-omz"
        "ohmyzsh/ohmyzsh path:lib"
        "ohmyzsh/ohmyzsh path:plugins/git"
        "ohmyzsh/ohmyzsh path:plugins/extract"
        # prompts
        "romkatv/powerlevel10k"
        # fzf
        "joshskidmore/zsh-fzf-history-search"
        # pyenv
        "mattberther/zsh-pyenv"
      ];
    };
  };

# tmux Configuration
  programs.tmux = {
  enable = true;
  baseIndex = 1;
  historyLimit = 10000;
  keyMode = "vi";
  mouse = true;
  terminal = "tmux-256color";

  plugins = with pkgs.tmuxPlugins; [
    resurrect
  ];

  extraConfig = ''
    # Vim stuff
    bind -T copy-mode-vi v send-keys -X begin-selection
    bind -T copy-mode-vi y send-keys -X copy-selection
    # Select panes with vim keys (lowercase)
    bind h select-pane -L
    bind j select-pane -D
    bind k select-pane -U
    bind l select-pane -R
    # Resize panes with vim keys (uppercase)
    bind -r H resize-pane -L 2
    bind -r J resize-pane -D 2
    bind -r K resize-pane -U 2
    bind -r L resize-pane -R 2

    # Mouse behavior for pane switching (tmux 2.1+)
    bind -n MouseDown1Pane select-pane -t= \; send-keys -M

    # The following are custom keys for creating a new pane full height left and right
    bind - split-window -hbf -c "#{pane_current_path}"
    bind \\ split-window -hf -c "#{pane_current_path}"
    bind '"' split-window -v -c "#{pane_current_path}"

    # Snazzy Theme for tmux
    # default statusbar colors
    set-option -g status-style bg=colour0,fg=colour205
    # default window title colors
    set-window-option -g window-status-style fg=colour123,bg=default,dim
    # active window title colors
    set-window-option -g window-status-current-style fg=colour84,bg=default,bright
    # pane border
    set-option -g pane-border-style fg=colour81
    set-option -g pane-active-border-style fg=colour84
    # message text
    set-option -g message-style bg=colour81,fg=colour17
    # pane number display
    set-option -g display-panes-active-colour colour203
    set-option -g display-panes-colour colour84
    # clock
    set-window-option -g clock-mode-colour colour205

    set -g status-right '%H:%M %d-%b-%y'

    # Session options
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
        extraOptions = {
          UseKeychain = "yes";
        };
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
  # git
  programs.git = {
    enable = true;

    # Set your Git user information
    userName = "Doug Masiero";
    userEmail = "doug@masiero.tech";

    # Optional: Additional Git configurations
    extraConfig = {
      # Set default branch name to 'main'
      init.defaultBranch = "main";

      # Configure pull behavior
      pull.rebase = false;

      # Enable colored output
      color.ui = "auto";

      # Optional: Set a default editor (e.g., nano, vim, or vscode)
      core.editor = "nvim";

      # Optional: Configure credential helper (useful for HTTPS authentication)
      credential.helper = "store"; # Stores credentials unencrypted; use 'cache' for temporary storage
    };

    # Optional: Define aliases for common Git commands
    aliases = {
      co = "checkout";
      st = "status";
      ci = "commit";
      br = "branch";
    };
  };

  # ghostty
  programs.ghostty = {
    enable = true;
    package = null;
    settings = {
      theme = "iTerm2 Default";
      cursor-style = "block";
      # background-opacity = 0.95;
      font-size = 18;
      window-width = 150;
      window-height = 42;
      split-divider-color = "727272";
      font-family = "MonaspiceNe Nerd Font Mono";
      cursor-click-to-move = true;
      mouse-hide-while-typing = true;
      clipboard-paste-protection = false;
    };
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/doug/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "nvim";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
