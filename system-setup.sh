#!/bin/bash
# Console colors
COLOR_RESET="\033[0m"
COLOR_CYAN="\033[1;36m"
COLOR_YELLOW="\033[1;33m"
COLOR_MAGENTA="\033[1;35m"
COLOR_GREEN="\033[1;32m"
COLOR_DIM="\033[2m"
COLOR_NIX_BLUE_DARK="\033[38;2;82;120;195m"
COLOR_NIX_BLUE_LIGHT="\033[38;2;126;180;230m"

print_separator() {
  echo -e "${COLOR_DIM}----------------------------------------${COLOR_RESET}"
}

# Cool Nix-themed ASCII art and startup prompt
_art_row=0
while IFS= read -r _line; do
  if (( _art_row % 2 == 0 )); then
    printf "%b%s%b\n" "$COLOR_NIX_BLUE_DARK" "$_line" "$COLOR_RESET"
  else
    printf "%b%s%b\n" "$COLOR_NIX_BLUE_LIGHT" "$_line" "$COLOR_RESET"
  fi
  _art_row=$((_art_row + 1))
done <<'EOF'
                ___          ______         ___               
               J@@@@,        '@@@@@@,     ,@@@@p              
               @@@B@@L        `@@@@@@_   ,@@@@@@              
                Q@ '@@L         @@@@@@L /@@@@@@               
              ., ?jlT@:_        _0'q,@@@@@@@@W                
          ___,9=._  _@_",,__,,@P==4@p_%@@g_'F                 
         /@@@.'@@@,|[@@@',@@j[@P"_~gg_%_%@@@g       ,a        
        A@@@@.'@@@|@'@@@ @|@@L ,@@@"_",q\@@@4`    ,@@@       
       """""" l""""[."""_F'""";"@@"_g,o[|g@@ g@@@'/@@@@@      
              '0qa~gLgmD'   gp._@ @@BB|][@@@'@@@"/@@@@@D      
                Jgg'|gP  '"_~g@g' @gq'@ @@@@@@" @@@@@@P       
               @@@@ g"      %g@L@b__"4N!@@@@B' @@@@@@/        
  _ggggggggggg@@@@@ @         "*==>",''@@. _/,@@@@@@ggggggggp 
 g@@@@@@@@@@@@@@@@@ B,        +@D._    @@   _@@@@@@@@@@@@@@@@@
 '@@@@@@@@@@@@@@@@ ,  B_    _'_"_.@g_  @@@ /@@@@@@@@@@@@@@@@@/
          [@@@@@D @,  [@@@@W,@@@@[Q@@@_ " _@@@@@P             
         g@@@@@P @@@|| @@@@,@@@@@'a'@@@g @@@@@@F              
        @@@@@@/ `@@@ g[,   @@@@@@,@@ _S@ @@@@@/               
      .@@@@@@/    @@.@|@\  @@@@@@@ @@_..BBBBP                 
       \@@@@       Q @ @@L @@@@@@@ @@@l9@@@@@@@@@@@@@@@F      
        '@@         ,@:@@ @ @@@@@P_@@@@|@@@@@@@@@@@@@@/       
                   A]9 @1<@@g_%W,@@@@@ >__g@@@> @@@@@         
                  @@g[| ,  q~~Z %@@@k,<4mmBP>'                
                 @@@@__ ___g@@ _~_,"_" '@@@@@@,               
               _@@@@@@   @@@@@@L   >     @@@@@@L              
               @@@@@@     %@@@@@g         Q@@@@@`             
                @@BP       "BBBBBB         t@@B               
EOF

echo ""
echo -e "🚀 Welcome to ${COLOR_NIX_BLUE_DARK}Re${COLOR_NIX_BLUE_LIGHT}Nix${COLOR_RESET}! 🌌"
echo ""

# Preflight: required temporary key for dotfiles clone
TEMP_GITEA_KEY="$HOME/gitea_masiero_doug"
if [ ! -f "$TEMP_GITEA_KEY" ]; then
  echo -e "${COLOR_YELLOW}Error:${COLOR_RESET} required temporary key ${COLOR_CYAN}$TEMP_GITEA_KEY${COLOR_RESET} not found."
  echo -e "Place ${COLOR_CYAN}gitea_masiero_doug${COLOR_RESET} in your home directory and re-run setup."
  exit 1
fi

# Explanation of what the script will do
echo -e "${COLOR_MAGENTA}This script will:${COLOR_RESET}"
echo "1. Install Determinate Nix to manage packages and configurations."
echo "2. Install Homebrew for additional package management."
echo "3. Set macOS appearance to Dark Mode."
echo "4. Create a solid-color wallpaper file (#1C1C1E) in ~/dotfiles/wallpapers."
echo "5. Apply that wallpaper to all desktops."
echo "6. Clone the Nix configuration repo from GitHub to ~/nix."
echo "7. Switch that repo's origin remote to SSH."
echo "8. Install and switch to the Nix Darwin configuration from ~/nix."
echo "9. Disable macOS Tips notifications/popups."
echo ""

# Prompt user to continue or exit
echo -e "${COLOR_MAGENTA}Do you want to continue with the setup?${COLOR_RESET} ${COLOR_DIM}(y/N)${COLOR_RESET}"
printf "%b" "${COLOR_CYAN}Enter your choice:${COLOR_RESET} "
read choice </dev/tty
if [[ ! "$choice" =~ ^[Yy]$ ]]; then
  echo -e "${COLOR_YELLOW}Setup aborted. Exiting...${COLOR_RESET}"
  exit 0
fi
print_separator

# Prompt for hostname before installing tooling
CURRENT_LOCAL_HOSTNAME="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
CURRENT_COMPUTER_NAME="$(scutil --get ComputerName 2>/dev/null || hostname -s)"

echo -e "${COLOR_YELLOW}Current hostname:${COLOR_RESET} ${COLOR_CYAN}${CURRENT_LOCAL_HOSTNAME}${COLOR_RESET}"
printf "%b" "${COLOR_MAGENTA}Enter desired hostname${COLOR_RESET} ${COLOR_DIM}(leave blank to keep current)${COLOR_RESET}: "
read NEW_HOSTNAME </dev/tty

if [ -n "$NEW_HOSTNAME" ]; then
  echo -e "${COLOR_GREEN}Applying hostname '${NEW_HOSTNAME}' ...${COLOR_RESET}"
  if sudo scutil --set LocalHostName "$NEW_HOSTNAME" \
    && sudo scutil --set HostName "$NEW_HOSTNAME" \
    && sudo scutil --set ComputerName "$NEW_HOSTNAME"; then
    echo -e "${COLOR_GREEN}Hostname updated from${COLOR_RESET} '${CURRENT_COMPUTER_NAME}' ${COLOR_GREEN}to${COLOR_RESET} '${NEW_HOSTNAME}'."
  else
    echo -e "${COLOR_YELLOW}Warning:${COLOR_RESET} failed to set hostname. Continuing with existing hostname."
  fi
else
  echo -e "${COLOR_DIM}Keeping existing hostname:${COLOR_RESET} ${CURRENT_LOCAL_HOSTNAME}"
fi

print_separator

# Install Determinate Nix
echo -e "${COLOR_GREEN}Installing Determinate Nix...${COLOR_RESET}"
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Activate Determinate Nix (Current shell)
echo -e "${COLOR_GREEN}Activating Determinate Nix...${COLOR_RESET}"
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# Install Homebrew
echo -e "${COLOR_GREEN}Installing Homebrew...${COLOR_RESET}"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Activate Homebrew (Current shell)
echo -e "${COLOR_GREEN}Activating Homebrew...${COLOR_RESET}"
eval "$(/opt/homebrew/bin/brew shellenv)"

print_separator

# Clone Nix configuration repo
REPO_DIR="$HOME/nix"
FLAKE_HOST="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"

echo -e "${COLOR_GREEN}Cloning Nix configuration repo to${COLOR_RESET} ${COLOR_CYAN}$REPO_DIR${COLOR_RESET} ..."
if [ -d "$REPO_DIR/.git" ]; then
  echo -e "${COLOR_DIM}$REPO_DIR already exists; pulling latest changes...${COLOR_RESET}"
  git -C "$REPO_DIR" pull --ff-only
else
  git clone https://github.com/dmasiero/nix-darwin.git "$REPO_DIR"
fi

# After initial HTTPS clone, switch origin to SSH for normal day-to-day use
if git -C "$REPO_DIR" remote get-url origin >/dev/null 2>&1; then
  git -C "$REPO_DIR" remote set-url origin git@github.com:dmasiero/nix-darwin.git || true
fi

# Clone dotfiles repo using temporary Gitea key from ~/
DOTFILES_DIR="$HOME/dotfiles"
DOTFILES_REPO="ssh://git@gitea.masiero.internal:2222/masiero/dotfiles.git"

chmod 600 "$TEMP_GITEA_KEY" || true
echo -e "${COLOR_GREEN}Cloning dotfiles repo to${COLOR_RESET} ${COLOR_CYAN}$DOTFILES_DIR${COLOR_RESET} ..."
if [ -d "$DOTFILES_DIR/.git" ]; then
  echo -e "${COLOR_DIM}$DOTFILES_DIR already exists; pulling latest changes...${COLOR_RESET}"
  GIT_SSH_COMMAND="ssh -i $TEMP_GITEA_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
    git -C "$DOTFILES_DIR" pull --ff-only
else
  GIT_SSH_COMMAND="ssh -i $TEMP_GITEA_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# Symlink ~/.ssh -> ~/dotfiles/ssh after dotfiles clone completes
if [ -d "$DOTFILES_DIR/ssh" ]; then
  if [ -e "$HOME/.ssh" ] && [ ! -L "$HOME/.ssh" ]; then
    SSH_BACKUP_PATH="/tmp/ssh.before-dotfiles-link.$(date +%Y%m%d-%H%M%S)"
    echo "Existing ~/.ssh found; creating temporary backup at $SSH_BACKUP_PATH ..."
    mv "$HOME/.ssh" "$SSH_BACKUP_PATH"

    echo ""
    echo -e "${COLOR_YELLOW}Temporary SSH backup created outside your home directory:${COLOR_RESET}"
    echo -e "  ${COLOR_CYAN}$SSH_BACKUP_PATH${COLOR_RESET}"
    printf "%b" "${COLOR_MAGENTA}Keep this backup?${COLOR_RESET} ${COLOR_DIM}(y/N)${COLOR_RESET}: "
    read KEEP_SSH_BACKUP </dev/tty
    if [[ ! "$KEEP_SSH_BACKUP" =~ ^[Yy]$ ]]; then
      echo -e "${COLOR_YELLOW}Deleting temporary SSH backup at${COLOR_RESET} ${COLOR_CYAN}$SSH_BACKUP_PATH${COLOR_RESET} ..."
      rm -rf "$SSH_BACKUP_PATH"
    else
      echo -e "${COLOR_YELLOW}Keeping temporary SSH backup at${COLOR_RESET} ${COLOR_CYAN}$SSH_BACKUP_PATH${COLOR_RESET}"
    fi
  fi
  ln -sfn "$DOTFILES_DIR/ssh" "$HOME/.ssh"
else
  echo -e "${COLOR_YELLOW}Warning:${COLOR_RESET} $DOTFILES_DIR/ssh not found; skipping ~/.ssh symlink."
fi

# Ensure SSH key permissions are locked down after clone/symlink
if [ -e "$HOME/.ssh" ]; then
  echo -e "${COLOR_GREEN}Fixing SSH permissions in ~/.ssh ...${COLOR_RESET}"
  chmod 700 "$HOME/.ssh" || true
  find -L "$HOME/.ssh" -type f ! -name "*.pub" -exec chmod 600 {} \; || true
  find -L "$HOME/.ssh" -type f -name "*.pub" -exec chmod 644 {} \; || true
fi

# Clone smanager repo using temporary Gitea key before deleting it
SMANAGER_PARENT_DIR="$HOME/Dev/masiero"
SMANAGER_DIR="$SMANAGER_PARENT_DIR/smanager"
SMANAGER_REPO="ssh://git@gitea.masiero.internal:2222/masiero/smanager.git"

mkdir -p "$SMANAGER_PARENT_DIR"
echo -e "${COLOR_GREEN}Cloning smanager repo to${COLOR_RESET} ${COLOR_CYAN}$SMANAGER_DIR${COLOR_RESET} ..."
if [ -d "$SMANAGER_DIR/.git" ]; then
  echo -e "${COLOR_DIM}$SMANAGER_DIR already exists; pulling latest changes...${COLOR_RESET}"
  GIT_SSH_COMMAND="ssh -i $TEMP_GITEA_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
    git -C "$SMANAGER_DIR" pull --ff-only
else
  GIT_SSH_COMMAND="ssh -i $TEMP_GITEA_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
    git clone "$SMANAGER_REPO" "$SMANAGER_DIR"
fi

echo -e "${COLOR_GREEN}Deleting temporary key${COLOR_RESET} ${COLOR_CYAN}$TEMP_GITEA_KEY${COLOR_RESET} ..."
rm -f "$TEMP_GITEA_KEY"

print_separator

# Set macOS appearance to Dark Mode
echo -e "${COLOR_GREEN}Setting macOS appearance to Dark Mode...${COLOR_RESET}"
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true' || true

# Create wallpaper file (solid #1C1C1E) if missing
WALLPAPER_FILE="$HOME/dotfiles/wallpapers/solid-1C1C1E.ppm"
if [ -f "$WALLPAPER_FILE" ]; then
  echo -e "${COLOR_DIM}Wallpaper file already exists at $WALLPAPER_FILE; skipping create.${COLOR_RESET}"
else
  echo -e "${COLOR_GREEN}Creating wallpaper file at${COLOR_RESET} ${COLOR_CYAN}$WALLPAPER_FILE${COLOR_RESET} ..."
  mkdir -p "$(dirname "$WALLPAPER_FILE")"
  cat > "$WALLPAPER_FILE" <<'EOF'
P3
1 1
255
28 28 30
EOF
fi

# Apply wallpaper to all desktops
echo -e "${COLOR_GREEN}Applying wallpaper to all desktops...${COLOR_RESET}"
osascript <<EOF
tell application "System Events"
  tell every desktop
    set picture to "${WALLPAPER_FILE}"
  end tell
end tell
EOF

# Preflight: avoid nix-darwin activation abort on existing /etc/zshenv
if [ -f /etc/zshenv ] && [ ! -f /etc/zshenv.before-nix-darwin ]; then
  echo -e "${COLOR_YELLOW}Backing up existing /etc/zshenv to /etc/zshenv.before-nix-darwin ...${COLOR_RESET}"
  sudo mv /etc/zshenv /etc/zshenv.before-nix-darwin
fi

print_separator

# Install Nix Darwin from local flake
# Capture exit code but always continue to post-setup tasks.
echo -e "${COLOR_GREEN}Installing Nix Darwin from${COLOR_RESET} ${COLOR_CYAN}$REPO_DIR${COLOR_RESET} ..."
echo -e "${COLOR_GREEN}Starting Home Manager activation${COLOR_RESET}"
if sudo -H nix run nix-darwin/master#darwin-rebuild -- switch --flake "$REPO_DIR#thismac"; then
  DARWIN_SWITCH_EXIT=0
else
  DARWIN_SWITCH_EXIT=$?
fi

echo -e "${COLOR_CYAN}darwin-rebuild finished with exit code:${COLOR_RESET} ${COLOR_MAGENTA}$DARWIN_SWITCH_EXIT${COLOR_RESET}"
print_separator

# Restart Dock so updated shortcuts are applied
# Must run after darwin-rebuild.
echo -e "${COLOR_GREEN}Restarting Dock to apply shortcut changes...${COLOR_RESET}"
killall Dock || true

# Disable macOS Tips daemon + mark welcome tips as seen
# (prevents the recurring "Tips" nudges/notifications)
echo -e "${COLOR_GREEN}Disabling macOS Tips popups...${COLOR_RESET}"
USER_UID="$(id -u)"
launchctl disable "gui/${USER_UID}/com.apple.tipsd" 2>/dev/null || true
launchctl bootout "gui/${USER_UID}/com.apple.tipsd" 2>/dev/null || true
defaults write com.apple.tipsd TPSWaitingToShowWelcomeNotification -int 0 || true
defaults write com.apple.tipsd TPSWelcomeNotificationReminderState -int 1 || true
defaults write com.apple.tipsd TPSWelcomeNotificationViewedVersion -int "$(sw_vers -productVersion | cut -d. -f1)" || true
killall tipsd 2>/dev/null || true

print_separator
if [ "$DARWIN_SWITCH_EXIT" -eq 0 ]; then
  echo -e "${COLOR_GREEN}✅ Build complete. Renix setup finished successfully.${COLOR_RESET}"
else
  echo -e "${COLOR_YELLOW}⚠️ Build complete with issues. darwin-rebuild exit code:${COLOR_RESET} ${COLOR_MAGENTA}$DARWIN_SWITCH_EXIT${COLOR_RESET}"
fi

exit $DARWIN_SWITCH_EXIT
