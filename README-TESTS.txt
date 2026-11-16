Lokaler Review-Arbeitsstand – kein GitHub-Commit.

Dateien:
- node64-cert-bot: vollständiger Ersatz des Hauptskripts (Version 0.6.0)
- install.sh / uninstall.sh: idempotenter Upgrade-Installer und datenschonender Deinstaller
- systemd/: gehärteter oneshot-Service und täglicher Timer
- examples/: kanonische Beispielkonfigurationen
- config.example: globale Beispielkonfiguration für bestehende Paketstruktur
- tests/: lokale Regressionstests
- CHANGELOG-review.md: Änderungen, Grenzen und offene Punkte

Testen:
  bash -n node64-cert-bot install.sh uninstall.sh tests/test-node64-cert-bot.sh
  bash tests/test-node64-cert-bot.sh

Die Tests benötigen Bash, Python 3 und OpenSSL. Ein echter Node64-API-Aufruf,
produktive Zertifikate, systemd auf einem Zielsystem und Reload-Hooks werden
nicht simuliert. Der systemd-Service verwendet standardmäßig
ReadWritePaths=/var/lib/node64-cert-bot und /etc/ssl/node64-cert-bot.
Bei abweichendem CERT_ROOT/DEPLOY_DIR müssen diese Pfade in der Unit ergänzt
werden, sonst blockiert ProtectSystem=full das Schreiben.

Runde 3 ergänzt Retention und atomaren Symlink-Wechsel. Runde 4 ergänzt beim fehlgeschlagenen Reload die Wiederherstellung des vorherigen Releases und einen erneuten Reload-Versuch.
