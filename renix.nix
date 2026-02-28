{ pkgs, ... }:

let
  customBuilds = import ./custom-builds.nix;
  toField = value:
    if builtins.isBool value then
      (if value then "1" else "0")
    else if value == null then
      ""
    else
      builtins.toString value;
  buildRow = build: builtins.concatStringsSep "|" [
    build.id
    (build.displayName or build.id)
    build.attrName
    build.source.type
    (toField (build.source.owner or ""))
    (toField (build.source.repo or ""))
    (toField (build.source.package or ""))
    (toField (build.source.distTag or ""))
    (toField (build.source.stripV or false))
    (toField (build.source.flake or ""))
    (toField (build.source.versionPath or ""))
    (toField (build.update.type or "manual"))
    (toField (build.update.target or ""))
    (toField (build.update.derivationFile or ""))
    (toField (build.update.lockfile or ""))
  ];
  customBuildsTsv = builtins.concatStringsSep "\n" (map buildRow customBuilds);

  renix = pkgs.writeShellScriptBin "renix" ''
    set -euo pipefail

    FLAKE_DIR="''${RENIX_FLAKE_DIR:-/Users/doug/nix}"
    FLAKE_HOST="''${RENIX_FLAKE_HOST:-thismac}"

    CUSTOM_BUILDS_TSV=$(cat <<'EOF'
${customBuildsTsv}
EOF
)

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

    get_configured_build_version() {
      local attr_name=$1
      nix eval --impure --raw --expr \
        "(builtins.getFlake \"$FLAKE_DIR\").darwinConfigurations.\"$FLAKE_HOST\".pkgs.\"$attr_name\".version" \
        2>/dev/null || echo "unknown"
    }

    get_latest_build_version() {
      local source_type=$1
      local owner=$2
      local repo=$3
      local package=$4
      local dist_tag=$5
      local strip_v=$6
      local flake=$7
      local version_path=$8

      case "$source_type" in
        flake-input)
          nix eval --impure --raw --expr "(builtins.getFlake \"$flake\").$version_path" 2>/dev/null || echo "unknown"
          ;;
        npm)
          local tag="$dist_tag"
          [ -z "$tag" ] && tag="latest"
          nix eval --impure --raw --expr \
            "let p = builtins.fromJSON (builtins.readFile (builtins.fetchurl \"https://registry.npmjs.org/$package\")); in p.\"dist-tags\".\"$tag\" or \"unknown\"" \
            2>/dev/null || echo "unknown"
          ;;
        github-release)
          if [ "$strip_v" = "1" ]; then
            nix eval --impure --raw --expr \
              "let r = builtins.fromJSON (builtins.readFile (builtins.fetchurl \"https://api.github.com/repos/$owner/$repo/releases/latest\")); t = r.tag_name or \"\"; len = builtins.stringLength t; in if len > 1 && builtins.substring 0 1 t == \"v\" then builtins.substring 1 (len - 1) t else t" \
              2>/dev/null || echo "unknown"
          else
            nix eval --impure --raw --expr \
              "let r = builtins.fromJSON (builtins.readFile (builtins.fetchurl \"https://api.github.com/repos/$owner/$repo/releases/latest\")); in r.tag_name or \"unknown\"" \
              2>/dev/null || echo "unknown"
          fi
          ;;
        *)
          echo "unknown"
          ;;
      esac
    }

    update_npm_package() {
      local display_name=$1
      local npm_package=$2
      local derivation_file_rel=$3
      local lockfile_rel=$4
      local new_version=$5

      local pkg_base
      local tarball_url
      local derivation_file
      local lockfile
      local tmpdir
      local src_hash_nix32
      local src_hash
      local npm_deps_hash

      pkg_base="''${npm_package##*/}"
      tarball_url="https://registry.npmjs.org/$npm_package/-/$pkg_base-$new_version.tgz"
      derivation_file="$FLAKE_DIR/$derivation_file_rel"
      lockfile="$FLAKE_DIR/$lockfile_rel"

      tmpdir=$(mktemp -d)
      trap 'rm -rf "$tmpdir"' RETURN

      echo -e "''${DIM}Updating $display_name package files...''${RESET}"

      curl -fsSL -o "$tmpdir/package.tgz" "$tarball_url"

      src_hash_nix32=$(nix-prefetch-url --type sha256 "$tarball_url" 2>/dev/null | tail -n1)
      src_hash=$(nix hash convert --hash-algo sha256 --from nix32 --to sri "$src_hash_nix32")

      tar -xzf "$tmpdir/package.tgz" -C "$tmpdir"
      (
        cd "$tmpdir/package"
        nix shell nixpkgs#nodejs --command \
          npm install --package-lock-only --ignore-scripts --no-audit --no-fund >/dev/null
      )

      cp "$tmpdir/package/package-lock.json" "$lockfile"
      npm_deps_hash=$(nix run nixpkgs#prefetch-npm-deps -- "$lockfile" 2>/dev/null | tail -n1)

      perl -i -pe 's|version = ".*";|version = "'"$new_version"'";|' "$derivation_file"
      perl -i -pe 's|hash = "sha256-[^"]+";|hash = "'"$src_hash"'";|' "$derivation_file"
      perl -i -pe 's|npmDepsHash = "sha256-[^"]+";|npmDepsHash = "'"$npm_deps_hash"'";|' "$derivation_file"

      rm -rf "$tmpdir"
      trap - RETURN

      echo -e "''${GREEN}✓''${RESET} Updated $display_name to ''${GREEN}$new_version''${RESET}."
    }

    run_rebuild() {
      local action=$1
      local msg="''${2:-Rebuilding system...}"
      local out_pipe
      local rebuild_pid
      local spin_pid
      local rebuild_status

      echo -e "''${DIM}Running:''${RESET} ''${CYAN}sudo -H nix run nix-darwin/master#darwin-rebuild -- $action --flake $FLAKE_DIR#$FLAKE_HOST --option warn-dirty false''${RESET}"
      echo ""

      out_pipe=$(mktemp -u)
      mkfifo "$out_pipe"

      (
        sudo -H env NIX_CONFIG="warn-dirty = false" \
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

    VERSION_FILE=""
    VERSION_PID=""

    if [ "$SKIP_BUILD_UPDATES" != true ]; then
      VERSION_FILE=$(mktemp)
      (
        while IFS='|' read -r id display_name attr_name source_type owner repo package dist_tag strip_v flake version_path update_type update_target update_derivation_file update_lockfile; do
          [ -z "$id" ] && continue
          configured=$(get_configured_build_version "$attr_name")
          latest=$(get_latest_build_version "$source_type" "$owner" "$repo" "$package" "$dist_tag" "$strip_v" "$flake" "$version_path")

          printf "%s|%s|%s|%s|%s|%s|%s|%s|%s\n" \
            "$id" "$display_name" "$update_type" "$update_target" "$package" "$update_derivation_file" "$update_lockfile" "$configured" "$latest"
        done <<< "$CUSTOM_BUILDS_TSV" > "$VERSION_FILE"
      ) &
      VERSION_PID=$!
    fi

    REBUILD_ACTION="switch"
    REBUILD_MSG="Rebuilding system..."
    if [ "$DRY_RUN" = true ]; then
      REBUILD_ACTION="build"
      REBUILD_MSG="Building system..."
    fi
    run_rebuild "$REBUILD_ACTION" "$REBUILD_MSG"

    if [ "$SKIP_BUILD_UPDATES" = true ] || [ "$DRY_RUN" = true ] || [ "$BARE_MODE" = true ]; then
      [ -n "$VERSION_PID" ] && wait "$VERSION_PID" 2>/dev/null || true
      [ -n "$VERSION_FILE" ] && rm -f "$VERSION_FILE"
      exit 0
    fi

    if [ -n "$VERSION_PID" ] && kill -0 "$VERSION_PID" 2>/dev/null; then
      spin "$VERSION_PID" "Finalizing version checks..."
    fi
    [ -n "$VERSION_PID" ] && wait "$VERSION_PID" || true

    UPDATES_APPLIED=false
    UPDATED_ITEMS=()

    echo -e "''${DIM}Checking custom build versions...''${RESET}"
    echo ""

    if [ -n "$VERSION_FILE" ] && [ -s "$VERSION_FILE" ]; then
      while IFS='|' read -r id display_name update_type update_target package update_derivation_file update_lockfile configured latest; do
        [ -z "$id" ] && continue

        if [ "$configured" = "$latest" ] && [ "$configured" != "unknown" ] && [ -n "$configured" ]; then
          echo -e "''${GREEN}✓''${RESET} $display_name: current (''${CYAN}$configured''${RESET})"
          continue
        fi

        if [ "$latest" = "unknown" ] || [ -z "$latest" ] || [ "$configured" = "unknown" ] || [ -z "$configured" ]; then
          echo -e "''${YELLOW}⚠''${RESET} $display_name: unable to determine version status (current: ''${CYAN}$configured''${RESET}, latest: ''${CYAN}$latest''${RESET})"
          continue
        fi

        echo -e "''${YELLOW}⚠''${RESET} $display_name upgrade available: ''${GREEN}$latest''${RESET} ''${DIM}(current: $configured)''${RESET}"

        case "$update_type" in
          npm-package)
            echo ""
            if prompt_yes "Upgrade $display_name? [''${GREEN}y''${RESET}/''${RED}N''${RESET}] "; then
              echo ""
              if [ -z "$package" ] || [ -z "$update_derivation_file" ] || [ -z "$update_lockfile" ]; then
                echo -e "''${RED}✗''${RESET} Missing npm-package metadata for $display_name in custom-builds.nix"
              else
                update_npm_package "$display_name" "$package" "$update_derivation_file" "$update_lockfile" "$latest"
                UPDATES_APPLIED=true
                UPDATED_ITEMS+=("$display_name")
              fi
              echo ""
            else
              echo -e "''${DIM}Skipping $display_name upgrade.''${RESET}"
              echo ""
            fi
            ;;
          *)
            echo -e "''${DIM}    manual update required in $update_target''${RESET}"
            ;;
        esac
      done < "$VERSION_FILE"
    fi

    rm -f "$VERSION_FILE"

    if [ "$UPDATES_APPLIED" = true ]; then
      echo ""
      echo -e "''${BLUE}══════════════════════════════════════════''${RESET}"
      echo -e "  ''${BOLD}''${WHITE}Applying Package Upgrades''${RESET}"
      echo -e "''${BLUE}══════════════════════════════════════════''${RESET}"
      echo ""
      echo -e "''${DIM}Rebuilding again to apply upgraded packages...''${RESET}"
      run_rebuild "switch" "Applying package upgrades..."
      echo -e "''${GREEN}✓''${RESET} Upgrade rebuild complete."
    fi
  '';
in
{
  environment.systemPackages = [ renix ];
}
