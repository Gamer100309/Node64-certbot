#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
[[ $EUID -eq 0 ]] || { echo "Bitte als root ausführen." >&2; exit 1; }
BASE_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
for cmd in bash curl unzip openssl sha256sum flock install systemctl python3 awk find stat; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Fehlt: $cmd" >&2; exit 1; }
done
for file in node64-cert-bot systemd/node64-cert-bot.service systemd/node64-cert-bot.timer examples/config.example examples/certificate.example.conf; do
  [[ -s "$BASE_DIR/$file" ]] || { echo "Paketdatei fehlt: $file" >&2; exit 1; }
done
bash -n "$BASE_DIR/node64-cert-bot"

# Idempotent upgrade: replace program/unit files, never overwrite local config or keys.
install -d -o root -g root -m 700 /etc/node64-cert-bot/certs
install -d -o root -g root -m 700 /var/lib/node64-cert-bot
install -d -o root -g root -m 755 /etc/ssl/node64-cert-bot
install -d -o root -g root -m 755 /usr/local/sbin
install -o root -g root -m 755 "$BASE_DIR/node64-cert-bot" /usr/local/sbin/node64-cert-bot
if [[ ! -e /etc/node64-cert-bot/config ]]; then
  install -o root -g root -m 600 "$BASE_DIR/examples/config.example" /etc/node64-cert-bot/config
fi
if [[ ! -e /etc/node64-cert-bot/certs/example.conf ]]; then
  install -o root -g root -m 600 "$BASE_DIR/examples/certificate.example.conf" /etc/node64-cert-bot/certs/example.conf
fi
install -o root -g root -m 644 "$BASE_DIR/systemd/node64-cert-bot.service" /etc/systemd/system/node64-cert-bot.service
install -o root -g root -m 644 "$BASE_DIR/systemd/node64-cert-bot.timer" /etc/systemd/system/node64-cert-bot.timer
systemctl daemon-reload
if command -v systemd-analyze >/dev/null 2>&1; then
  systemd-analyze verify /etc/systemd/system/node64-cert-bot.service /etc/systemd/system/node64-cert-bot.timer
fi
echo
echo "Node64 Cert Bot wurde installiert/aktualisiert."
echo "Bestehende Konfigurationen und Zertifikate wurden nicht überschrieben."
echo "WICHTIG: Bei abweichendem CERT_ROOT/DEPLOY_DIR die ReadWritePaths im Service ergänzen."
echo "Timer erst nach erfolgreichem manuellem Test aktivieren: systemctl enable --now node64-cert-bot.timer"
