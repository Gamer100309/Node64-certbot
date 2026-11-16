#!/usr/bin/env bash
set -Eeuo pipefail
[[ $EUID -eq 0 ]] || { echo "Bitte als root ausführen." >&2; exit 1; }
echo "Dies entfernt Programm und systemd-Dateien, aber NICHT Konfigurationen oder Zertifikate."
read -r -p "Fortfahren? [y/N] " answer
[[ "$answer" == "y" || "$answer" == "Y" ]] || exit 0
systemctl disable --now node64-cert-bot.timer 2>/dev/null || true
rm -f /etc/systemd/system/node64-cert-bot.timer /etc/systemd/system/node64-cert-bot.service
rm -f /usr/local/sbin/node64-cert-bot
systemctl daemon-reload
echo "Programm entfernt. Konfiguration und Zertifikate bleiben erhalten."
