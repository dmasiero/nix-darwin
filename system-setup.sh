#!/bin/bash
# Cool Nix-themed ASCII art and startup prompt
echo -e "\033[1;34m" # Blue for a cool Nix vibe
cat <<'EOF'
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
echo -e "\033[0m" # Reset color
echo "🚀 Welcome to renix! 🌌"
echo ""

# Explanation of what the script will do
echo "This script will:"
echo "1. Install Determinate Nix to manage packages and configurations."
echo "2. Install Homebrew for additional package management."
echo "3. Set macOS appearance to Dark Mode."
echo "4. Create a solid-color wallpaper file (#1C1C1E) in ~/dotfiles/wallpapers."
echo "5. Apply that wallpaper to all desktops."
echo "6. Clone the Nix configuration repo from GitHub to ~/nix."
echo "7. Switch that repo's origin remote to SSH."
echo "8. Install and switch to the Nix Darwin configuration from ~/nix."
echo "9. Set Helium as the default browser for macOS."
echo ""

# Prompt user to continue or exit
echo "Do you want to continue with the setup? (y/n)"
read -p "Enter your choice: " choice </dev/tty
if [[ ! "$choice" =~ ^[Yy]$ ]]; then
  echo "Setup aborted. Exiting..."
  exit 0
fi
echo "----------------------------------------"

# Prompt for hostname before installing tooling
CURRENT_LOCAL_HOSTNAME="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"
CURRENT_COMPUTER_NAME="$(scutil --get ComputerName 2>/dev/null || hostname -s)"

echo "Current hostname: ${CURRENT_LOCAL_HOSTNAME}"
read -p "Enter desired hostname (leave blank to keep current): " NEW_HOSTNAME </dev/tty

if [ -n "$NEW_HOSTNAME" ]; then
  echo "Applying hostname '$NEW_HOSTNAME' ..."
  if sudo scutil --set LocalHostName "$NEW_HOSTNAME" \
    && sudo scutil --set HostName "$NEW_HOSTNAME" \
    && sudo scutil --set ComputerName "$NEW_HOSTNAME"; then
    echo "Hostname updated from '${CURRENT_COMPUTER_NAME}' to '${NEW_HOSTNAME}'."
  else
    echo "Warning: failed to set hostname. Continuing with existing hostname."
  fi
else
  echo "Keeping existing hostname: ${CURRENT_LOCAL_HOSTNAME}"
fi

# Preflight: required temporary key for dotfiles clone
TEMP_GITEA_KEY="$HOME/gitea_masiero_doug"
if [ ! -f "$TEMP_GITEA_KEY" ]; then
  echo "Error: required temporary key $TEMP_GITEA_KEY not found."
  echo "Place gitea_masiero_doug in your home directory and re-run setup."
  exit 1
fi

# Install Determinate Nix
echo "Installing Determinate Nix..."
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Activate Determinate Nix (Current shell)
echo "Activating Determinate Nix..."
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# Install Homebrew
echo "Installing Homebrew..."
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Activate Homebrew (Current shell)
echo "Activating Homebrew..."
eval "$(/opt/homebrew/bin/brew shellenv)"

# Clone Nix configuration repo
REPO_DIR="$HOME/nix"
FLAKE_HOST="$(scutil --get LocalHostName 2>/dev/null || hostname -s)"

echo "Cloning Nix configuration repo to $REPO_DIR ..."
if [ -d "$REPO_DIR/.git" ]; then
  echo "$REPO_DIR already exists; pulling latest changes..."
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
echo "Cloning dotfiles repo to $DOTFILES_DIR ..."
if [ -d "$DOTFILES_DIR/.git" ]; then
  echo "$DOTFILES_DIR already exists; pulling latest changes..."
  GIT_SSH_COMMAND="ssh -i $TEMP_GITEA_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
    git -C "$DOTFILES_DIR" pull --ff-only
else
  GIT_SSH_COMMAND="ssh -i $TEMP_GITEA_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# Symlink ~/.ssh -> ~/dotfiles/ssh after dotfiles clone completes
if [ -d "$DOTFILES_DIR/ssh" ]; then
  if [ -e "$HOME/.ssh" ] && [ ! -L "$HOME/.ssh" ]; then
    echo "Backing up existing ~/.ssh to ~/.ssh.before-dotfiles-link ..."
    mv "$HOME/.ssh" "$HOME/.ssh.before-dotfiles-link"
  fi
  ln -sfn "$DOTFILES_DIR/ssh" "$HOME/.ssh"
else
  echo "Warning: $DOTFILES_DIR/ssh not found; skipping ~/.ssh symlink."
fi

# Ensure SSH key permissions are locked down after clone/symlink
if [ -e "$HOME/.ssh" ]; then
  echo "Fixing SSH permissions in ~/.ssh ..."
  chmod 700 "$HOME/.ssh" || true
  find -L "$HOME/.ssh" -type f ! -name "*.pub" -exec chmod 600 {} \; || true
  find -L "$HOME/.ssh" -type f -name "*.pub" -exec chmod 644 {} \; || true
fi

# Clone smanager repo using temporary Gitea key before deleting it
SMANAGER_PARENT_DIR="$HOME/Dev/masiero"
SMANAGER_DIR="$SMANAGER_PARENT_DIR/smanager"
SMANAGER_REPO="ssh://git@gitea.masiero.internal:2222/masiero/smanager.git"

mkdir -p "$SMANAGER_PARENT_DIR"
echo "Cloning smanager repo to $SMANAGER_DIR ..."
if [ -d "$SMANAGER_DIR/.git" ]; then
  echo "$SMANAGER_DIR already exists; pulling latest changes..."
  GIT_SSH_COMMAND="ssh -i $TEMP_GITEA_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
    git -C "$SMANAGER_DIR" pull --ff-only
else
  GIT_SSH_COMMAND="ssh -i $TEMP_GITEA_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new" \
    git clone "$SMANAGER_REPO" "$SMANAGER_DIR"
fi

echo "Deleting temporary key $TEMP_GITEA_KEY ..."
rm -f "$TEMP_GITEA_KEY"

# Set macOS appearance to Dark Mode
echo "Setting macOS appearance to Dark Mode..."
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true' || true

# Create wallpaper file (solid #1C1C1E) if missing
WALLPAPER_FILE="$HOME/dotfiles/wallpapers/solid-1C1C1E.ppm"
if [ -f "$WALLPAPER_FILE" ]; then
  echo "Wallpaper file already exists at $WALLPAPER_FILE; skipping create."
else
  echo "Creating wallpaper file at $WALLPAPER_FILE ..."
  mkdir -p "$(dirname "$WALLPAPER_FILE")"
  cat > "$WALLPAPER_FILE" <<'EOF'
P3
1 1
255
28 28 30
EOF
fi

# Apply wallpaper to all desktops
echo "Applying wallpaper to all desktops..."
osascript <<EOF
tell application "System Events"
  tell every desktop
    set picture to "${WALLPAPER_FILE}"
  end tell
end tell
EOF

# Preflight: avoid nix-darwin activation abort on existing /etc/zshenv
if [ -f /etc/zshenv ] && [ ! -f /etc/zshenv.before-nix-darwin ]; then
  echo "Backing up existing /etc/zshenv to /etc/zshenv.before-nix-darwin ..."
  sudo mv /etc/zshenv /etc/zshenv.before-nix-darwin
fi

# Install Nix Darwin from local flake
echo "Installing Nix Darwin from $REPO_DIR ..."
set +e
sudo -H nix run nix-darwin/master#darwin-rebuild -- switch --flake "$REPO_DIR#thismac"
DARWIN_SWITCH_EXIT=$?
set -e

# Restart Dock so updated shortcuts are applied
# Must run after darwin-rebuild.
echo "Restarting Dock to apply shortcut changes..."
killall Dock || true

# Set Helium as default browser for HTTP/HTTPS + HTML
# (requires duti; install via Homebrew if missing)
echo "Setting Helium as default browser..."
if [ -d "/Applications/Helium.app" ]; then
  if ! command -v duti >/dev/null 2>&1; then
    brew install duti || true
  fi

  if command -v duti >/dev/null 2>&1; then
    HELIUM_BUNDLE_ID="$(osascript -e 'id of app "Helium"' 2>/dev/null || true)"
    if [ -z "$HELIUM_BUNDLE_ID" ]; then
      HELIUM_BUNDLE_ID="com.imobie.Helium"
    fi

    duti -s "$HELIUM_BUNDLE_ID" http all || true
    duti -s "$HELIUM_BUNDLE_ID" https all || true
    duti -s "$HELIUM_BUNDLE_ID" public.html all || true
    duti -s "$HELIUM_BUNDLE_ID" public.xhtml all || true
    killall cfprefsd 2>/dev/null || true
  else
    echo "Warning: duti unavailable; could not set default browser automatically."
  fi
else
  echo "Warning: /Applications/Helium.app not found; skipping default browser setup."
fi

exit $DARWIN_SWITCH_EXIT
