#!/bin/bash

# Package Selector TUI for flake.nix
# Parses flake.nix and allows interactive selection of packages

FLAKE_FILE="flake.nix"

# Function to extract packages from a section
extract_packages() {
    local section="$1"
    local start_pattern="$2"
    local end_pattern="$3"
    awk "/$start_pattern/,/$end_pattern/" "$FLAKE_FILE" | grep -E '^[^#]*"' | sed 's/.*"\([^"]*\)".*/\1/' | sed 's/.*\b\([a-zA-Z0-9_-]*\)\b.*/\1/' | grep -v '^$' | sort | uniq
}

# Function to get current packages with status
get_packages_with_status() {
    local section="$1"
    local start_pattern="$2"
    local end_pattern="$3"
    awk "/$start_pattern/,/$end_pattern/" "$FLAKE_FILE" | grep -E '(^[^#]*"|^#.*")' | sed 's/.*"\([^"]*\)".*/\1/' | sed 's/.*\b\([a-zA-Z0-9_-]*\)\b.*/\1/' | grep -v '^$' | while read pkg; do
        if awk "/$start_pattern/,/$end_pattern/" "$FLAKE_FILE" | grep -q "^#.*$pkg"; then
            echo "OFF $pkg"
        else
            echo "ON $pkg"
        fi
    done | sort | uniq
}

# Function to update flake.nix section
update_section() {
    local section="$1"
    local start_pattern="$2"
    local end_pattern="$3"
    local selected="$4"
    local temp_file=$(mktemp)
    
    # Create new list content
    local new_list=""
    for pkg in $selected; do
        new_list="$new_list\n          \"$pkg\""
    done
    
    # Replace the section
    awk "
    BEGIN { in_section=0 }
    /$start_pattern/ { in_section=1; print; next }
    /$end_pattern/ { 
        if (in_section) {
            print \"$new_list\"
            in_section=0
        }
        print
        next
    }
    { if (!in_section) print }
    " "$FLAKE_FILE" > "$temp_file"
    
    mv "$temp_file" "$FLAKE_FILE"
}

# Main menu
while true; do
    choice=$(dialog --clear --title "Package Selector" \
        --menu "Choose a category:" 15 50 5 \
        1 "Homebrew Casks" \
        2 "Homebrew Brews" \
        3 "Homebrew Taps" \
        4 "Nix Fonts" \
        5 "Home Packages" \
        6 "Add Custom Package" \
        7 "Exit" \
        2>&1 >/dev/tty)
    
    case $choice in
        1)
            # Homebrew Casks
            packages=$(get_packages_with_status "homebrew.casks" "casks = \[" "];")
            selected=$(dialog --checklist "Select Homebrew Casks:" 20 60 15 $packages 2>&1 >/dev/tty)
            if [ $? -eq 0 ]; then
                update_section "homebrew.casks" "casks = \[" "];" "$selected"
            fi
            ;;
        2)
            # Homebrew Brews
            packages=$(get_packages_with_status "homebrew.brews" "brews = \[" "];")
            selected=$(dialog --checklist "Select Homebrew Brews:" 20 60 15 $packages 2>&1 >/dev/tty)
            if [ $? -eq 0 ]; then
                update_section "homebrew.brews" "brews = \[" "];" "$selected"
            fi
            ;;
        3)
            # Homebrew Taps
            packages=$(get_packages_with_status "homebrew.taps" "taps = \[" "];")
            selected=$(dialog --checklist "Select Homebrew Taps:" 20 60 15 $packages 2>&1 >/dev/tty)
            if [ $? -eq 0 ]; then
                update_section "homebrew.taps" "taps = \[" "];" "$selected"
            fi
            ;;
        4)
            # Nix Fonts
            packages=$(get_packages_with_status "fonts.packages" "packages = with pkgs; \[" "\];")
            selected=$(dialog --checklist "Select Nix Fonts:" 20 60 15 $packages 2>&1 >/dev/tty)
            if [ $? -eq 0 ]; then
                update_section "fonts.packages" "packages = with pkgs; \[" "\];" "$selected"
            fi
            ;;
        5)
            # Home Packages
            packages=$(get_packages_with_status "home.packages" "packages = with pkgs; \[" "\];")
            selected=$(dialog --checklist "Select Home Packages:" 20 60 15 $packages 2>&1 >/dev/tty)
            if [ $? -eq 0 ]; then
                update_section "home.packages" "packages = with pkgs; \[" "\];" "$selected"
            fi
            ;;
        6)
            # Add Custom Package
            category=$(dialog --menu "Choose category for custom package:" 15 50 5 \
                1 "Homebrew Casks" \
                2 "Homebrew Brews" \
                3 "Homebrew Taps" \
                4 "Nix Fonts" \
                5 "Home Packages" \
                2>&1 >/dev/tty)
            pkg=$(dialog --inputbox "Enter package name:" 8 40 2>&1 >/dev/tty)
            if [ $? -eq 0 ] && [ -n "$pkg" ]; then
                case $category in
                    1) section="homebrew.casks"; start="casks = \["; end="];" ;;
                    2) section="homebrew.brews"; start="brews = \["; end="];" ;;
                    3) section="homebrew.taps"; start="taps = \["; end="];" ;;
                    4) section="fonts.packages"; start="packages = with pkgs; \["; end="\];" ;;
                    5) section="home.packages"; start="packages = with pkgs; \["; end="\];" ;;
                esac
                current=$(extract_packages "$section" "$start" "$end")
                new_selected="$current $pkg"
                update_section "$section" "$start" "$end" "$new_selected"
            fi
            ;;
        7)
            break
            ;;
    esac
done

clear