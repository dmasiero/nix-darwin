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
echo "🚀 Welcome to Doug's Nix-Darwin System Setup! 🌌"
echo "🔐 Have your secrets ready to transfers via sneaker net! 👟🌎💻"
echo ""

# Explanation of what the script will do
echo "This script will:"
echo "1. Install Determinate Nix to manage packages and configurations."
echo "2. Install Homebrew for additional package management."
echo "3. Create a solid-color wallpaper file (#1C1C1E) in ~/dotfiles/wallpapers."
echo "4. Apply that wallpaper to all desktops."
echo "5. Clone the Nix configuration repo from GitHub to ~/nix."
echo "6. Install and switch to the Nix Darwin configuration from ~/nix."
echo ""

# Prompt user to continue or exit
echo "Do you want to continue with the setup? (y/n)"
read -p "Enter your choice: " choice </dev/tty
if [[ ! "$choice" =~ ^[Yy]$ ]]; then
  echo "Setup aborted. Exiting..."
  exit 0
fi
echo "----------------------------------------"

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

# Create wallpaper file (solid #1C1C1E)
WALLPAPER_FILE="$HOME/dotfiles/wallpapers/solid-1C1C1E.ppm"
echo "Creating wallpaper file at $WALLPAPER_FILE ..."
mkdir -p "$(dirname "$WALLPAPER_FILE")"
cat > "$WALLPAPER_FILE" <<'EOF'
P3
1 1
255
28 28 30
EOF

# Apply wallpaper to all desktops
echo "Applying wallpaper to all desktops..."
osascript <<EOF
tell application "System Events"
  tell every desktop
    set picture to "${WALLPAPER_FILE}"
  end tell
end tell
EOF

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

# Preflight: avoid nix-darwin activation abort on existing /etc/zshenv
if [ -f /etc/zshenv ] && [ ! -f /etc/zshenv.before-nix-darwin ]; then
  echo "Backing up existing /etc/zshenv to /etc/zshenv.before-nix-darwin ..."
  sudo mv /etc/zshenv /etc/zshenv.before-nix-darwin
fi

# Install Nix Darwin from local flake
echo "Installing Nix Darwin from $REPO_DIR#$FLAKE_HOST ..."
sudo -H nix run nix-darwin/master#darwin-rebuild -- switch --flake "$REPO_DIR#$FLAKE_HOST"

# Sneaker net reminder at the end
echo "👟 Reminder: Don't forget to copy your secrets (e.g., SSH keys) into ~/.ssh via sneaker net! 💻"
echo "🎉 Setup complete! Your system is ready to rock and roll! 🤘🏻🎸🚀"
