#!/bin/bash
#
# Installer for antizapret-dns-overrides on a stock AntiZapret-VPN server.
# Wires the feature through the custom-doall.sh hook, so it survives updates.
#
# Works both ways:
#   from a clone:   git clone … && sudo ./install.sh
#   one-liner:      bash <(wget -qO- --no-hsts --inet4-only \
#                     https://raw.githubusercontent.com/fenekosan/antizapret-dns-overrides/main/install.sh)

set -eu

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/fenekosan/antizapret-dns-overrides/main}"
AZ_DIR=/root/antizapret
CONF_DIR="$AZ_DIR/config"
HOOK="$AZ_DIR/custom-doall.sh"

[[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo "Run as root (sudo ./install.sh)"; exit 1; }
[[ -d "$AZ_DIR" ]] || { echo "AntiZapret not found at $AZ_DIR — is this an AntiZapret-VPN server?"; exit 1; }

# Local source dir when run from a clone; empty when piped via wget/curl.
SRC=''
if [[ -n "${BASH_SOURCE[0]:-}" && -f "$(dirname "${BASH_SOURCE[0]}")/custom-dns.sh" ]]; then
	SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

TMPS=()
cleanup() { [[ ${#TMPS[@]} -gt 0 ]] && rm -f "${TMPS[@]}"; }
trap cleanup EXIT

dl() {  # dl <url> -> stdout
	if command -v wget >/dev/null 2>&1; then
		wget -qO- --no-hsts --inet4-only "$1"
	elif command -v curl >/dev/null 2>&1; then
		curl -fsSL --connect-timeout 30 "$1"
	else
		echo "Neither wget nor curl found" >&2; return 1
	fi
}

# resolve <relative-path> -> sets RESOLVED to a usable local path (from clone or downloaded)
resolve() {
	local rel="$1"
	if [[ -n "$SRC" && -f "$SRC/$rel" ]]; then
		RESOLVED="$SRC/$rel"; return 0
	fi
	RESOLVED="$(mktemp)"; TMPS+=("$RESOLVED")
	dl "$REPO_RAW/$rel" > "$RESOLVED" && [[ -s "$RESOLVED" ]] || { echo "Failed to fetch $rel" >&2; return 1; }
}

# 1) Worker script
resolve custom-dns.sh
install -m 0755 "$RESOLVED" "$AZ_DIR/custom-dns.sh"
echo "installed: $AZ_DIR/custom-dns.sh"

# 2) Config files — never overwrite a user's existing ones
for f in custom-bind.txt custom-upstream.txt; do
	if [[ -f "$CONF_DIR/$f" ]]; then
		echo "kept existing: $CONF_DIR/$f"
	else
		resolve "config/$f"
		install -m 0644 "$RESOLVED" "$CONF_DIR/$f"
		echo "created: $CONF_DIR/$f"
	fi
done

# 3) Hook into custom-doall.sh (idempotent)
[[ -f "$HOOK" ]] || printf '#!/bin/bash\n' > "$HOOK"
chmod +x "$HOOK"
if grep -q 'custom-dns.sh' "$HOOK"; then
	echo "hook already present: $HOOK"
else
	printf '\n# antizapret-dns-overrides hook\n[ -x %s/custom-dns.sh ] && %s/custom-dns.sh "$1" || true\n' "$AZ_DIR" "$AZ_DIR" >> "$HOOK"
	echo "hooked into: $HOOK"
fi

# 4) Apply now
echo "---"
"$AZ_DIR/custom-dns.sh" "${1:-}"
echo "---"
echo "Done."
echo "Edit your overrides:"
echo "  $CONF_DIR/custom-upstream.txt   (домен -> свой DNS-резолвер)"
echo "  $CONF_DIR/custom-bind.txt       (домен -> фиксированный IP)"
echo "Then apply with:  $AZ_DIR/custom-dns.sh   (or the regular $AZ_DIR/doall.sh)"
