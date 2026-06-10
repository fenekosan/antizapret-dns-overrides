#!/bin/bash
#
# Remove antizapret-custom-dns. Config files (config/custom-*.txt) are left intact.

set -u

AZ_DIR=/root/antizapret
KRESD_CONF=/etc/knot-resolver/kresd.conf

[[ "${EUID:-$(id -u)}" -eq 0 ]] || { echo "Run as root (sudo ./uninstall.sh)"; exit 1; }

# Remove the hook line from custom-doall.sh
if [[ -f "$AZ_DIR/custom-doall.sh" ]]; then
	sed -i '/antizapret-custom-dns hook/d; \#custom-dns\.sh#d' "$AZ_DIR/custom-doall.sh"
fi

# Remove the kresd.conf injection
if [[ -f "$KRESD_CONF" ]]; then
	sed -i '/custom-dns-overrides BEGIN/,/custom-dns-overrides END/d' "$KRESD_CONF"
fi

rm -f "$AZ_DIR/custom-dns.sh" /etc/knot-resolver/custom.lua

systemctl reload-or-restart kresd@1 kresd@2 2>/dev/null || true

echo "Uninstalled. Left intact: $AZ_DIR/config/custom-bind.txt, $AZ_DIR/config/custom-upstream.txt"
