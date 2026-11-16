# Node64 Cert Bot

Node64 Cert Bot synchronisiert TLS-Zertifikate, die bereits in Node64 ausgestellt und verwaltet werden, auf Linux-Server. Er ist kein ACME-Client und stellt selbst keine Zertifikate aus. Die Ausstellung und Erneuerung erfolgen in Node64; der Bot holt die jeweils aktuelle Version ab, validiert sie und aktiviert sie lokal.

## Funktionen

- tägliche automatische Synchronisierung über systemd-Timer
- beliebig viele Zertifikate über einzelne Konfigurationsdateien
- Node64 API-Zugriff über HTTPS mit eigener CA-Prüfung
- API-Token in separater root-lesbarer curl-Datei
- Prüfung von Hostname, Ablaufdatum, Schlüssel-Zertifikat-Paar und Zertifikatskette
- versionierte Releases und atomarer `current`-Symlink
- Reload-Hook nur bei tatsächlicher Zertifikatsänderung
- Rollback des Symlinks bei fehlgeschlagenem Reload
- manuelle Befehle für Sync, Check, Liste und Status
- Deinstallation entfernt Programm und Timer, lässt Konfiguration und Zertifikate bestehen

## Voraussetzungen

Debian/Ubuntu oder ein vergleichbares systemd-Linux mit `bash`, `curl`, `unzip`, `openssl`, `coreutils` und `systemd`.

## Installation

Entpacken und im Projektverzeichnis ausführen:

```bash
sudo ./install.sh
```

Die Installation legt an:

- `/usr/local/sbin/node64-cert-bot`
- `/etc/node64-cert-bot/config`
- `/etc/node64-cert-bot/certs/`
- systemd-Service und Timer

Die Beispielkonfiguration ist absichtlich neutral und enthält nur Platzhalter.

## Konfiguration

### 1. Globale API-Konfiguration

`/etc/node64-cert-bot/config` bearbeiten:

- `API_BASE_URL`: HTTPS-Basisadresse der Node64-API
- `API_CURL_CONFIG`: Datei mit dem Bearer-Token
- `API_CA_FILE`: CA-Zertifikat zur TLS-Prüfung der API
- `CERT_ROOT`: Ablage der lokalen Releases

### 2. API-Token

Beispiel für `/etc/node64-cert-bot/api.curl`:

```text
header = "Authorization: Bearer YOUR_NODE64_API_TOKEN"
```

Datei absichern:

```bash
sudo chown root:root /etc/node64-cert-bot/api.curl
sudo chmod 600 /etc/node64-cert-bot/api.curl
```

Token niemals committen oder veröffentlichen.

### 3. Zertifikate definieren

Für jedes Zertifikat eine Datei in `/etc/node64-cert-bot/certs/` anlegen, z. B. `web.conf`. Vorlage: `examples/certificate.example.conf`.

Pflichtwerte:

- `NAME`: eindeutiger lokaler Name
- `CERT_ID`: Zertifikats-ID in Node64
- `CERT_HOSTNAME`: erwarteter DNS-Name

`RELOAD_CMD` ist optional und wird nur nach Aktivierung eines neuen Zertifikats ausgeführt.

### 4. API-CA und Zertifikatskette

`API_CA_FILE` dient ausschließlich zur Prüfung der HTTPS-Verbindung zum Node64-API-Server. Für eine streng private Zertifikatskette kann optional in einer Zertifikatskonfiguration `BUNDLE_CA_FILE` gesetzt werden; diese Variable muss auf eine Datei mit vertrauenswürdigen Root-CA-Zertifikaten zeigen. Ohne diese Option prüft der Bot gegen den System-CA-Speicher und protokolliert eine Warnung, falls die Kette dort nicht validiert werden kann.

## Erst testen, dann Automatik aktivieren

Nach dem Einrichten der Konfiguration:

```bash
sudo node64-cert-bot list
sudo node64-cert-bot sync
sudo node64-cert-bot check
```

Wenn der manuelle Lauf erfolgreich war, täglichen Timer aktivieren:

```bash
sudo systemctl enable --now node64-cert-bot.timer
```

Timer prüfen:

```bash
systemctl list-timers node64-cert-bot.timer
systemctl status node64-cert-bot.timer
```

Logs:

```bash
journalctl -u node64-cert-bot.service
```

## Befehle

```text
node64-cert-bot sync [NAME]    Alle oder ein bestimmtes Zertifikat synchronisieren
node64-cert-bot check [NAME]   Aktive Zertifikate lokal validieren
node64-cert-bot list           Konfigurierte Zertifikate anzeigen
node64-cert-bot status         Timerstatus anzeigen
node64-cert-bot version        Version anzeigen
```

## Dateistruktur

Jedes Zertifikat wird getrennt abgelegt:

```text
<CERT_ROOT>/<NAME>/
├── current -> releases/<SHA256-Fingerprint>
└── releases/
    └── <SHA256-Fingerprint>/
        ├── cert.pem
        ├── chain.pem
        ├── fullchain.pem
        └── privkey.pem
```

Dienste müssen `current/fullchain.pem` und `current/privkey.pem` verwenden, damit sie nach dem atomaren Wechsel das neue Zertifikat sehen.

## Wie die automatische Aktualisierung funktioniert

Der systemd-Timer startet den Bot einmal täglich. Der Bot fragt für jedes konfigurierte Zertifikat das zugehörige Node64-Bundle ab. Ist der SHA-256-Fingerprint unverändert, bleibt alles unangetastet. Bei einem neuen Zertifikat wird es geprüft, als neues Release abgelegt, `current` atomar umgeschaltet und optional der konfigurierte Reload-Befehl ausgeführt.

Node64 muss das erneuerte Zertifikat bereits bereitstellen, bevor der Bot es abruft. Der Bot löst keine ACME-Challenges aus und beantragt keine Zertifikate bei Let's Encrypt.

## Deinstallation

```bash
sudo ./uninstall.sh
```

Der Deinstaller entfernt Programm und systemd-Dateien. Konfigurationen, API-Zugangsdaten und Zertifikats-Releases bleiben erhalten.

## Sicherheit

- Die Konfiguration enthält ausführbare Shell-Zuweisungen und muss root gehören sowie nur für root lesbar sein.
- `RELOAD_CMD` und `POST_DEPLOY_CMD` sind Shell-Befehle. Nur vertrauenswürdige Administratoren dürfen die Konfiguration bearbeiten.
- Private Schlüssel werden mit Modus `0600` gespeichert.
- API-Token, private Schlüssel und produktive Konfigurationen gehören nicht in Git.
- Vor Produktiveinsatz API-Antwortformat und Zertifikatskette mit der eigenen Node64-Installation testen.

## Projektumfang

Ausschließlich Zertifikatsabruf, Validierung, lokale Bereitstellung und Synchronisierung von Node64-Zertifikaten. Kein Monitoring, keine allgemeine Serververwaltung und kein ACME-Server.
