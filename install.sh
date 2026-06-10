#!/bin/bash
#
# Installer for antizapret-custom-dns on a stock AntiZapret-VPN server.
# Wires the feature through the custom-doall.sh hook, so it survives updates.
#
#   git clone https://github.com/<you>/antizapret-custom-dns
#   cd antizapret-custom-dns && sudo ./install.sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AZ_DIR=/root/antizapret
CONF_DIR="$AZ_DIR/config"
HOOK="$AZ_DIR/custom-doall.sh"

[[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo "Run as root (sudo ./install.sh)"; exit 1; }
[[ -d "$AZ_DIR" ]] || { echo "AntiZapret not found at $AZ_DIR — is this an AntiZapret-VPN server?"; exit 1; }

# 1) Worker script
install -m 0755 "$SCRIPT_DIR/custom-dns.sh" "$AZ_DIR/custom-dns.sh"
echo "installed: $AZ_DIR/custom-dns.sh"

# 2) Config files — never overwrite a user's existing ones
for f in custom-bind.txt custom-upstream.txt; do
	if [[ -f "$CONF_DIR/$f" ]]; then
		echo "kept existing: $CONF_DIR/$f"
	else
		install -m 0644 "$SCRIPT_DIR/config/$f" "$CONF_DIR/$f"
		echo "created: $CONF_DIR/$f"
	fi
done

# 3) Hook into custom-doall.sh (idempotent)
[[ -f "$HOOK" ]] || printf '#!/bin/bash\n' > "$HOOK"
chmod +x "$HOOK"
if grep -q 'custom-dns.sh' "$HOOK"; then
	echo "hook already present: $HOOK"
else
	printf '\n# antizapret-custom-dns hook\n[ -x %s/custom-dns.sh ] && %s/custom-dns.sh "$1" || true\n' "$AZ_DIR" "$AZ_DIR" >> "$HOOK"
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
