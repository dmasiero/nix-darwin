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
        A@@@@.'@@@|@'@@@ @|@@L ,@@@@"_",q\@@@4`    ,@@@       
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
echo "👟 Have Your Sneaker Net Secrets Transfer Ready! 💻"
echo ""

# Explanation of what the script will do
echo "This script will:"
echo "1. Install Determinate Nix to manage packages and configurations."
echo "2. Install Homebrew for additional package management."
echo "3. Clone a Nix Darwin configuration from GitHub to /etc/nix-darwin."
echo "4. Pause for you to manually copy secrets (e.g., SSH keys) into ~/.ssh."
echo "5. Install and switch to the Nix Darwin configuration."
echo ""

# Prompt user to continue or exit
echo "Do you want to continue with the setup? (y/n)"
read -p "Enter your choice: " choice </dev/tty
if [[ ! "$choice" =~ ^[Yy]$ ]]; then
  echo "Setup aborted. Exiting..."
  exit 0
fi
echo "----------------------------------------"

# Rest of the script (unchanged)
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

# Clone Nix Darwin Configuration
echo "Cloning Nix Darwin configuration..."
sudo git clone https://github.com/dmasiero/nix-darwin.git /etc/nix-darwin
sudo chown -R "$USER":staff /etc/nix-darwin

# Install Nix Darwin
echo "Installing Nix Darwin..."
sudo nix run nix-darwin/master#darwin-rebuild -- switch

# Additional darwin-rebuild switch
echo "Running additional darwin-rebuild switch..."
sudo darwin-rebuild switch

# Sneaker net reminder at the end
echo "👟 Reminder: Don't forget to copy your secrets (e.g., SSH keys) into ~/.ssh via sneaker net! 💻"

echo "🎉 Setup complete! Your system is ready to roll! 🚀"
