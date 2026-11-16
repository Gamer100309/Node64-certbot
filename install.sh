#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
[[ $EUID -eq 0 ]] || { echo "Bitte als root ausführen." >&2; exit 1; }
BASE_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
for cmd in bash curl unzip openssl sha256sum flock install systemctl; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Fehlt: $cmd" >&2; exit 1; }
done
install -d -o root -g root -m 700 /etc/node64-cert-bot/certs
install -d -o root -g root -m 700 /var/lib/node64-cert-bot
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
echo
echo "Node64 Cert Bot wurde installiert."
echo "Jetzt /etc/node64-cert-bot/config und /etc/node64-cert-bot/certs/example.conf bearbeiten."
echo "API-Zugang und CA-Datei bereitstellen; danach: node64-cert-bot sync"
echo "Timer erst nach erfolgreichem Test aktivieren: systemctl enable --now node64-cert-bot.timer"
