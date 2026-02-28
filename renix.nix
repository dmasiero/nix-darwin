{ pkgs, ... }:

let
  renix = pkgs.writeShellScriptBin "renix" ''
    set -euo pipefail

    FLAKE_DIR="''${RENIX_FLAKE_DIR:-/Users/doug/nix}"
    FLAKE_HOST="''${RENIX_FLAKE_HOST:-thismac}"

    BOLD="\033[1m"
    DIM="\033[2m"
    RESET="\033[0m"
    CYAN="\033[36m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    RED="\033[31m"
    BLUE="\033[34m"
    WHITE="\033[97m"

    show_help() {
      echo "Usage: renix [OPTION]..."
      echo "Rebuild nix-darwin and optionally update custom package files."
      echo ""
      echo "Options:"
      echo "  -b, --bare                Rebuild only (skip custom package checks/updates)"
      echo "  -d, --dry                 Run darwin-rebuild build (no switch)"
      echo "  -sb, --no-build-updates   Skip custom package checks/updates"
      echo "  -h, --help                Display this help and exit"
      echo ""
      echo "Environment overrides:"
      echo "  RENIX_FLAKE_DIR           Flake directory (default: /Users/doug/nix)"
      echo "  RENIX_FLAKE_HOST          Darwin configuration attr (default: thismac)"
    }

    show_banner() {
      echo ""
      echo -e "''${BLUE}══════════════════════════════════════════''${RESET}"
      echo -e "  ''${BOLD}''${WHITE}Renixing System''${RESET}"
      echo -e "''${BLUE}══════════════════════════════════════════''${RESET}"
      echo ""
    }

    spin() {
      local pid=$1
      local msg=$2
      local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
      local i=0
      while kill -0 "$pid" 2>/dev/null; do
        printf "\r''${CYAN}%s''${RESET} ''${DIM}%s''${RESET}" "''${frames[$i]}" "$msg"
        i=$(( (i + 1) % ''${#frames[@]} ))
        sleep 0.08
      done
      printf "\r\033[2K"
    }

    prompt_yes() {
      local prompt=$1
      local answer=""
      printf "%b" "$prompt"
      if { read -r answer < /dev/tty; } 2>/dev/null; then
        [[ "$answer" =~ ^[Yy]$ ]]
      else
        false
      fi
    }

    prompt_yes_default_yes() {
      local prompt=$1
      local answer=""
      printf "%b" "$prompt"
      if { read -r answer < /dev/tty; } 2>/dev/null; then
        [[ -z "$answer" || "$answer" =~ ^[Yy]$ ]]
      else
        false
      fi
    }

    run_rebuild() {
      local action=$1
      local msg="''${2:-Renixing system...}"
      local out_pipe
      local rebuild_pid
      local spin_pid
      local rebuild_status

      echo -e "''${DIM}Running:''${RESET} ''${CYAN}sudo -H nix run nix-darwin/master#darwin-rebuild -- $action --flake $FLAKE_DIR#$FLAKE_HOST --option warn-dirty false''${RESET}"
      echo ""

      # Prompt for sudo before starting spinner so password prompt is clean.
      if ! sudo -n true 2>/dev/null; then
        sudo -v
      fi

      out_pipe=$(mktemp -u)
      mkfifo "$out_pipe"

      (
        sudo -n -H env NIX_CONFIG="warn-dirty = false" \
          nix run nix-darwin/master#darwin-rebuild -- \
          "$action" --flake "$FLAKE_DIR#$FLAKE_HOST" --option warn-dirty false >"$out_pipe" 2>&1
      ) &
      rebuild_pid=$!

      spin "$rebuild_pid" "$msg" &
      spin_pid=$!

      while IFS= read -r line || [ -n "$line" ]; do
        printf "\r\033[2K\033[1A\r\033[2K%s\n\n" "$line"
      done < "$out_pipe"

      if wait "$rebuild_pid"; then
        rebuild_status=0
      else
        rebuild_status=$?
      fi
      wait "$spin_pid" 2>/dev/null || true
      rm -f "$out_pipe"

      return "$rebuild_status"
    }

    run_brew_maintenance() {
      local out_pipe
      local brew_pid
      local spin_pid
      local brew_status

      if ! command -v brew >/dev/null 2>&1; then
        echo -e "''${YELLOW}⚠''${RESET} Homebrew not found in PATH; skipping brew update/upgrade."
        return 0
      fi

      if ! prompt_yes_default_yes "Update and upgrade Homebrew packages now? [''${GREEN}Y''${RESET}/''${RED}n''${RESET}] "; then
        echo ""
        echo -e "''${DIM}Skipping Homebrew update/upgrade.''${RESET}"
        echo ""
        return 0
      fi

      echo ""
      echo -e "''${DIM}Running:''${RESET} ''${CYAN}brew update && brew upgrade''${RESET}"
      echo ""

      out_pipe=$(mktemp -u)
      mkfifo "$out_pipe"

      (
        {
          brew update
          brew upgrade
        } >"$out_pipe" 2>&1
      ) &
      brew_pid=$!

      spin "$brew_pid" "Updating Homebrew packages..." &
      spin_pid=$!

      while IFS= read -r line || [ -n "$line" ]; do
        printf "\r\033[2K\033[1A\r\033[2K%s\n\n" "$line"
      done < "$out_pipe"

      if wait "$brew_pid"; then
        brew_status=0
      else
        brew_status=$?
      fi
      wait "$spin_pid" 2>/dev/null || true
      rm -f "$out_pipe"

      if [ "$brew_status" -eq 0 ]; then
        echo -e "''${GREEN}✓''${RESET} Homebrew update/upgrade complete."
      else
        echo -e "''${YELLOW}⚠''${RESET} Homebrew update/upgrade failed (exit $brew_status). Continuing."
      fi
      echo ""
      return 0
    }

    SKIP_BUILD_UPDATES=false
    BARE_MODE=false
    DRY_RUN=false

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --help|-h)
          show_help
          exit 0
          ;;
        -sb|--no-build-updates)
          SKIP_BUILD_UPDATES=true
          ;;
        -b|--bare)
          BARE_MODE=true
          SKIP_BUILD_UPDATES=true
          ;;
        -d|--dry)
          DRY_RUN=true
          ;;
        *)
          echo -e "''${RED}Unknown option:''${RESET} $1"
          show_help
          exit 1
          ;;
      esac
      shift
    done

    cd "$FLAKE_DIR"

    show_banner

    CUSTOM_UPDATER="$FLAKE_DIR/scripts/update-custom-builds.sh"

    REBUILD_ACTION="switch"
    REBUILD_MSG="Renixing system..."
    if [ "$DRY_RUN" = true ]; then
      REBUILD_ACTION="build"
      REBUILD_MSG="Building system..."
    fi
    run_rebuild "$REBUILD_ACTION" "$REBUILD_MSG"

    if [ "$DRY_RUN" != true ] && [ "$BARE_MODE" != true ]; then
      run_brew_maintenance
    fi

    if [ "$SKIP_BUILD_UPDATES" = true ] || [ "$DRY_RUN" = true ] || [ "$BARE_MODE" = true ]; then
      exit 0
    fi

    UPDATES_APPLIED=false

    if [ -f "$CUSTOM_UPDATER" ]; then
      echo -e "''${DIM}Checking custom build versions...''${RESET}"
      echo ""

      if bash "$CUSTOM_UPDATER" --flake-dir "$FLAKE_DIR" --host "$FLAKE_HOST" --check-only; then
        :
      else
        CHECK_EXIT=$?
        if [ "$CHECK_EXIT" -eq 10 ]; then
          echo ""
          if prompt_yes "Apply available custom package updates now? [''${GREEN}y''${RESET}/''${RED}N''${RESET}] "; then
            echo ""
            if bash "$CUSTOM_UPDATER" --flake-dir "$FLAKE_DIR" --host "$FLAKE_HOST" --apply --yes; then
              :
            else
              APPLY_EXIT=$?
              if [ "$APPLY_EXIT" -eq 20 ]; then
                UPDATES_APPLIED=true
              else
                echo -e "''${YELLOW}⚠''${RESET} Custom updater exited with code $APPLY_EXIT; continuing."
              fi
            fi
          else
            echo -e "''${DIM}Skipping custom package updates.''${RESET}"
            echo ""
          fi
        else
          echo -e "''${YELLOW}⚠''${RESET} Custom update check failed (exit $CHECK_EXIT); continuing."
          echo ""
        fi
      fi
    else
      echo -e "''${YELLOW}⚠''${RESET} Custom updater not found at $CUSTOM_UPDATER; skipping custom package update checks."
      echo ""
    fi

    if [ "$UPDATES_APPLIED" = true ]; then
      echo ""
      echo -e "''${BLUE}══════════════════════════════════════════''${RESET}"
      echo -e "  ''${BOLD}''${WHITE}Applying Package Upgrades''${RESET}"
      echo -e "''${BLUE}══════════════════════════════════════════''${RESET}"
      echo ""
      echo -e "''${DIM}Renixing again to apply upgraded packages...''${RESET}"
      run_rebuild "switch" "Applying package upgrades..."
      echo -e "''${GREEN}✓''${RESET} Upgrade rebuild complete."
    fi
  '';
in
{
  environment.systemPackages = [ renix ];
}
