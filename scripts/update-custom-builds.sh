#!/usr/bin/env bash
set -euo pipefail

FLAKE_DIR="${RENIX_FLAKE_DIR:-/Users/doug/nix}"
FLAKE_HOST="${RENIX_FLAKE_HOST:-thismac}"
CHECK_ONLY=false
APPLY_UPDATES=false
ASSUME_YES=false

GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
DIM="\033[2m"
RESET="\033[0m"

show_help() {
  cat <<EOF
Usage: update-custom-builds.sh [options]

Options:
  --flake-dir <path>   Flake directory (default: /Users/doug/nix)
  --host <name>        darwinConfigurations host attr (default: thismac)
  --check-only         Check status only; exit 10 when updates are available
  --apply              Apply updates for outdated supported packages
  --yes                Assume yes for prompts when applying
  -h, --help           Show this help

Exit codes:
  0  success / no updates available
  10 updates are available (check-only mode)
  20 updates were applied (apply mode)
  1  error
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --flake-dir)
      FLAKE_DIR="$2"
      shift 2
      ;;
    --host)
      FLAKE_HOST="$2"
      shift 2
      ;;
    --check-only)
      CHECK_ONLY=true
      shift
      ;;
    --apply)
      APPLY_UPDATES=true
      shift
      ;;
    --yes)
      ASSUME_YES=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      show_help >&2
      exit 1
      ;;
  esac
done

if [ "$CHECK_ONLY" = true ] && [ "$APPLY_UPDATES" = true ]; then
  echo "Cannot use --check-only and --apply together." >&2
  exit 1
fi

if [ "$CHECK_ONLY" != true ] && [ "$APPLY_UPDATES" != true ]; then
  CHECK_ONLY=true
fi

if [ ! -d "$FLAKE_DIR" ]; then
  echo "Flake directory not found: $FLAKE_DIR" >&2
  exit 1
fi

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

get_configured_version() {
  local attr_name=$1
  nix eval --impure --raw --expr \
    "(builtins.getFlake \"$FLAKE_DIR\").darwinConfigurations.\"$FLAKE_HOST\".pkgs.\"$attr_name\".version" \
    2>/dev/null || echo "unknown"
}

get_latest_swo_cli_version() {
  nix eval --impure --raw --expr \
    'let r = builtins.fromJSON (builtins.readFile (builtins.fetchurl "https://api.github.com/repos/solarwinds/swo-cli/releases/latest")); t = r.tag_name or ""; len = builtins.stringLength t; in if len > 1 && builtins.substring 0 1 t == "v" then builtins.substring 1 (len - 1) t else t' \
    2>/dev/null || echo "unknown"
}

update_swo_cli() {
  local new_version=$1
  local derivation_file="$FLAKE_DIR/swo-cli.nix"
  local src_hash_nix32 src_hash archive_url tmpfile expected_vendor_hash

  archive_url="https://github.com/solarwinds/swo-cli/archive/refs/tags/v$new_version.tar.gz"

  echo -e "${DIM}Updating swo-cli package files...${RESET}"

  src_hash_nix32=$(nix-prefetch-url --unpack --type sha256 "$archive_url" 2>/dev/null | tail -n1)
  src_hash=$(nix hash convert --hash-algo sha256 --from nix32 --to sri "$src_hash_nix32")

  perl -i -pe 's|version = ".*";|version = "'"$new_version"'";|' "$derivation_file"
  perl -i -pe 's|hash = "sha256-[^"]+";|hash = "'"$src_hash"'";|' "$derivation_file"
  perl -i -pe 's|vendorHash = "sha256-[^"]+";|vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";|' "$derivation_file"

  for _ in 1 2 3; do
    tmpfile=$(mktemp)
    if nix build --impure --no-link --expr "let flake = builtins.getFlake \"$FLAKE_DIR\"; in flake.darwinConfigurations.\"$FLAKE_HOST\".pkgs.swo-cli" >/dev/null 2>"$tmpfile"; then
      rm -f "$tmpfile"
      echo -e "${GREEN}✓${RESET} Updated swo-cli to ${GREEN}$new_version${RESET}."
      return 0
    fi

    expected_vendor_hash=$(grep -Eo 'got:[[:space:]]+sha256-[A-Za-z0-9+/=]+' "$tmpfile" | awk '{print $2}' | tail -n1 || true)
    rm -f "$tmpfile"

    if [ -n "$expected_vendor_hash" ]; then
      perl -i -pe 's|vendorHash = "sha256-[^"]+";|vendorHash = "'"$expected_vendor_hash"'";|' "$derivation_file"
      continue
    fi

    echo -e "${RED}✗${RESET} Unable to derive swo-cli vendorHash automatically."
    return 1
  done

  echo -e "${RED}✗${RESET} Failed to update swo-cli vendorHash after retries."
  return 1
}

SWO_CONFIGURED=$(get_configured_version "swo-cli")
SWO_LATEST=$(get_latest_swo_cli_version)

OUTDATED_COUNT=0
SWO_OUTDATED=false

if [ "$SWO_CONFIGURED" != "unknown" ] && [ "$SWO_LATEST" != "unknown" ] && [ -n "$SWO_CONFIGURED" ] && [ -n "$SWO_LATEST" ]; then
  if [ "$SWO_CONFIGURED" = "$SWO_LATEST" ]; then
    echo -e "${GREEN}✓${RESET} swo-cli: current (${CYAN}$SWO_CONFIGURED${RESET})"
  else
    echo -e "${YELLOW}⚠${RESET} swo-cli: upgrade available ${GREEN}$SWO_LATEST${RESET} ${DIM}(current: $SWO_CONFIGURED)${RESET}"
    SWO_OUTDATED=true
    OUTDATED_COUNT=$((OUTDATED_COUNT + 1))
  fi
else
  echo -e "${YELLOW}⚠${RESET} swo-cli: unable to determine status (current: ${CYAN}$SWO_CONFIGURED${RESET}, latest: ${CYAN}$SWO_LATEST${RESET})"
fi

if [ "$CHECK_ONLY" = true ]; then
  if [ "$OUTDATED_COUNT" -gt 0 ]; then
    exit 10
  fi
  exit 0
fi

APPLIED=false

if [ "$SWO_OUTDATED" = true ]; then
  if [ "$ASSUME_YES" = true ] || prompt_yes_default_yes "Upgrade swo-cli now? [${GREEN}Y${RESET}/${RED}n${RESET}] "; then
    echo ""
    update_swo_cli "$SWO_LATEST"
    APPLIED=true
    echo ""
  fi
fi

if [ "$APPLIED" = true ]; then
  exit 20
fi

exit 0
