# Node64 Cert Bot

Node64 Cert Bot synchronisiert TLS-Zertifikate, die bereits in Node64 ausgestellt und verwaltet werden, auf Linux-Server. Es ist **kein ACME-Client** und stellt selbst keine Zertifikate aus. Die Ausstellung und Erneuerung erfolgen in Node64; der Bot lädt die aktuelle Version, validiert sie und aktiviert sie lokal.

## Funktionen

- mehrere Zertifikate über einzelne Konfigurationsdateien
- Node64-API-Zugriff über HTTPS mit eigener API-CA
- API-Token in separater, rootgeschützter curl-Konfiguration
- Prüfung von Hostname, Ablaufdatum, Schlüssel-Zertifikat-Paar und Zertifikatskette
- strikte Konsistenzprüfung: `fullchain.pem` muss exakt `cert.pem` gefolgt von `chain.pem` enthalten
- ZIP-Prüfung gegen Pfad-Traversal, Symlinks, Verschlüsselung und übergroße Archive
- versionierte Releases und atomarer `current`-Symlink
- Reload-Hook nur bei Zertifikatsänderung; bei fehlgeschlagenem Reload wird das vorherige Release wiederhergestellt und dessen Reload erneut versucht
- tägliche Synchronisierung über systemd-Timer

## Voraussetzungen

Debian/Ubuntu oder vergleichbares systemd-Linux mit Bash, curl, unzip, OpenSSL, Python 3, coreutils und systemd. Installation und Betrieb erfolgen als root.

## Installation und Upgrade

```bash
sudo ./install.sh
```

Der Installer ersetzt Programm- und systemd-Dateien, überschreibt aber keine vorhandenen Konfigurationen, Tokens oder Zertifikate. Der Timer wird nicht automatisch aktiviert.

## Konfiguration

Globale Datei: `/etc/node64-cert-bot/config` (Vorlage `examples/config.example`)

- `API_BASE_URL`: HTTPS-Basisadresse der Node64-API
- `API_CURL_CONFIG`: Datei mit dem Bearer-Token
- `API_CA_FILE`: CA-Datei zur TLS-Prüfung der Node64-API
- `CERT_ROOT`: Basisverzeichnis für Zertifikate
- `CONNECT_TIMEOUT`, `MAX_TIME`: HTTP-Timeouts
- `EXPIRY_WARNING_DAYS`: Warnschwelle für `check`
- `KEEP_RELEASES`: Anzahl jüngster Releases je Zertifikat (2–50, Standard 5); das aktive Release bleibt zusätzlich immer erhalten

Beispiel für die Token-Datei:

```text
header = "Authorization: Bearer YOUR_NODE64_API_TOKEN"
```

Sie muss root gehören und Modus `0600` haben. Token niemals in Git einchecken.

Für jedes Zertifikat eine Datei unter `/etc/node64-cert-bot/certs/` anlegen (Vorlage `examples/certificate.example.conf`):

- `NAME`: eindeutiger lokaler Name
- `CERT_ID`: numerische Zertifikats-ID in Node64
- `CERT_HOSTNAME`: erwarteter DNS-Name
- `DEPLOY_DIR`: optionales Zielverzeichnis; Standard `$CERT_ROOT/$NAME`
- `BUNDLE_CA_FILE`: optionales CA-Bundle zur Verifikation der vom Zertifikat gelieferten Kette
- `RELOAD_CMD`: optionaler Shell-Befehl nach Aktivierung
- `POST_DEPLOY_CMD`: optionaler Shell-Befehl nach erfolgreichem Reload

Konfigurationsdateien werden als root-Shell-Code geladen. Sie müssen root gehören, reguläre Dateien ohne Symlink sein und Modus `0600` haben. Konfigurationsverzeichnisse müssen root gehören und dürfen nicht gruppen-/weltbeschreibbar sein. Reload- und Post-Deploy-Befehle sind ausschließlich vertrauenswürdigen Administratoren vorbehalten.

## Befehle

```bash
sudo node64-cert-bot version
sudo node64-cert-bot list
sudo node64-cert-bot sync [NAME]
sudo node64-cert-bot check [NAME]
sudo node64-cert-bot status
```

`sync` und `check` verwenden denselben Lock. Fehler eines einzelnen Zertifikats verhindern nicht die Verarbeitung der übrigen Zertifikate; der Gesamtbefehl liefert anschließend einen Fehlerstatus, wenn mindestens ein Zertifikat fehlschlug.

## systemd-Härtung und eigene Zielpfade

Der oneshot-Service verwendet unter anderem `ProtectSystem=full`, `ProtectHome=true`, `PrivateDevices=true`, `NoNewPrivileges=true` und eingeschränkte Address Families. Schreibbar sind standardmäßig nur:

- `/var/lib/node64-cert-bot`
- `/etc/ssl/node64-cert-bot`

Wenn `CERT_ROOT` oder `DEPLOY_DIR` außerhalb dieses Standardpfads liegt, muss der Administrator den entsprechenden Pfad in `ReadWritePaths=` in `/etc/systemd/system/node64-cert-bot.service` ergänzen. Ziele unter `/home` sind durch `ProtectHome=true` absichtlich nicht zugänglich. Danach `systemctl daemon-reload` ausführen. Der Bot prüft Zielpfadkomponenten auf Symlinks, Root-Eigentümer und unsichere Schreibrechte.

Erst nach erfolgreichem manuellen Test den Timer aktivieren:

```bash
sudo node64-cert-bot list
sudo node64-cert-bot sync
sudo node64-cert-bot check
sudo systemctl enable --now node64-cert-bot.timer
```

Status und Logs:

```bash
systemctl list-timers node64-cert-bot.timer
systemctl status node64-cert-bot.timer
journalctl -u node64-cert-bot.service
```

## Release-Aufbewahrung

`KEEP_RELEASES=5` bewahrt standardmäßig die fünf jüngsten fingerprint-basierten Releases je Zertifikat. Das aktive Release wird unabhängig vom Alter niemals entfernt. Es werden ausschließlich root-eigene Verzeichnisse mit gültigem SHA-256-Fingerprint-Namen unter `releases/` bereinigt. Symlinks und fremde Verzeichnisse werden übersprungen. Die Bereinigung läuft erst nach erfolgreichem Reload und `POST_DEPLOY_CMD`. Schlägt der erste Reload fehl, wird `current` auf das vorherige Release zurückgesetzt und der Reload-Befehl mit diesem alten Zertifikat erneut ausgeführt. Schlägt auch dieser zweite Reload fehl, wird dies ausdrücklich protokolliert; der Dienststatus muss dann manuell geprüft werden. Existierte zuvor kein Release, wird `current` entfernt und es gibt kein altes Zertifikat, das erneut geladen werden könnte.

## Deinstallation

```bash
sudo ./uninstall.sh
```

Nach Bestätigung werden Timer, Service-Dateien und Programm entfernt. Konfigurationen, API-Zugangsdaten, private Schlüssel und Zertifikats-Releases bleiben erhalten.

## Grenzen / Freigabe

Die lokale Test-Suite deckt Shell-Syntax, ZIP-Sicherheit, Zertifikatsketten-Reihenfolge, Zielpfadschutz, Batch-Fehlerisolation, Release-Aufbewahrung sowie Rollback inklusive erneutem Reload des vorherigen Zertifikats ab. Vor einem produktiven Release sind zusätzlich ein echter Node64-API-Integrationstest, ein Test auf der unterstützten Debian/Ubuntu-Version sowie Tests mit den tatsächlichen Reload-Hooks und den realen Zertifikatsbundles erforderlich. Der lokale Arbeitsstand ist deshalb noch keine Produktionsfreigabe.
