# Node64 Cert Bot – lokaler Review-Arbeitsstand 0.4.0

Nicht in GitHub geschrieben. Der Repository-Zugriff blieb ausschließlich lesend.

## Runde 1 – Basis-Härtung (0.3.0)

- Root-eigene, symlinkfreie und restriktiv berechtigte Shell-Konfigurationen.
- Isolierte Verarbeitung je Zertifikat mit Cleanup temporärer Arbeitsverzeichnisse.
- Gemeinsamer Lock für `sync` und `check`.
- Lokale Informationsbefehle ohne API-Zugangsdaten.
- ZIP-Prüfung auf Pfad-Traversal, Symlinks, Verschlüsselung, Eintragszahl, Größenlimits und Kompressionsverhältnis.
- Abhängigkeiten und globale Beispielkonfiguration korrigiert.

## Runde 2 – Zielpfade, Zertifikatskette und systemd (0.4.0)

- `fullchain.pem` muss exakt aus dem einzelnen `cert.pem` gefolgt von sämtlichen Zertifikaten aus `chain.pem` bestehen; Reihenfolge, fehlende und zusätzliche Zertifikate werden erkannt.
- Zielpfadkomponenten werden vor dem Deployment geprüft: absolute Pfade, keine `.`/`..`-Komponenten, keine Symlinks, root-eigene Verzeichnisse und keine gruppen-/weltbeschreibbaren Verzeichnisse (root-eigene Sticky-Verzeichnisse wie `/tmp` sind als Pfadkomponente zulässig).
- `current` muss ein Symlink auf ein Release unterhalb von `releases/` sein; vorhandene Release-Verzeichnisse werden auf Symlinks und Root-Eigentümer geprüft.
- `check` prüft ebenfalls die Zielpfadstruktur und benötigt Python 3 für die PEM-Kettenprüfung.
- systemd-Service erweitert um `ProtectSystem=full`, `ProtectHome`, `PrivateDevices`, Kernel-/Control-Group-Hardening, `NoNewPrivileges`, eingeschränkte Address Families und explizite `ReadWritePaths`.
- Installer aktualisiert Programm und Units, ohne bestehende lokale Konfigurationen zu überschreiben; Deinstaller entfernt keine Konfigurationen oder Zertifikate.
- README, Beispiele und Upgrade-/Deinstallationshinweise ergänzt.

## Testergebnis

Erfolgreich:

- Bash-Syntax für Hauptskript, Installer, Deinstaller und Tests.
- 15 lokale Regressionstests: Version/List ohne API-Zugangsdaten, Konfigurationsrechte, gültige/unsichere ZIPs, genaue fullchain-Reihenfolge, Symlink-/Schreibrechte bei Zielpfaden und Batch-Fehlerisolation.

Nicht durchgeführt / Einschränkungen:

- ShellCheck ist in der Umgebung nicht installiert.
- `systemd-analyze verify` konnte hier nicht vollständig laufen: Die lokale Container-Root-Umgebung enthält keine vollständige systemd-Basis (u. a. `sysinit.target`); zusätzlich ist der Service-ExecStart-Pfad außerhalb einer Installation erwartungsgemäß nicht vorhanden.
- Kein echter Node64-API-Aufruf, keine produktive Zertifikatskette, kein echter Reload-Hook und kein Test auf einer vollständigen Debian-/Ubuntu-VM.
- Installer/Deinstaller wurden nicht auf dem Host ausgeführt, um dessen systemweite Dateien nicht zu verändern.

## Noch offen vor einer Produktionsfreigabe

1. Integrationstest mit einem echten Node64-Testbundle und der realen API-CA.
2. Test auf einer unterstützten Debian-/Ubuntu-VM inklusive Installations-Upgrade, Timer, Logs und Deinstallation.
3. Test mit den tatsächlich verwendeten `DEPLOY_DIR`-Pfaden und systemd-`ReadWritePaths`.
4. Reload-Fehler-/Rollback- und POST-Deploy-Verhalten mit realen Dienstkommandos testen.
5. Retention alter Releases und definierte Bereinigung/Recovery-Strategie ergänzen.
6. ShellCheck ausführen und alle relevanten Hinweise prüfen.

**Status:** deutlich gehärteter Entwicklungsstand, aber ausdrücklich noch keine Produktionsfreigabe und keine Version 1.0.0.


## Runde 3 – Release-Lebenszyklus und Rollback (0.5.0)

- Konfigurierbare Release-Aufbewahrung über `KEEP_RELEASES` (2–50, Standard 5).
- Aktives Release wird immer geschützt, auch wenn es älter als die jüngsten Releases ist.
- Bereinigung beschränkt sich auf root-eigene reale Verzeichnisse mit 64-stelligem SHA-256-Namen unter `releases/`; Symlinks und fremde Eigentümer werden übersprungen.
- Bereinigung erfolgt erst nach erfolgreichem Reload und erfolgreichem `POST_DEPLOY_CMD`.
- Atomarer Symlink-Wechsel und Rollback in eigene Hilfsfunktionen ausgelagert und regressionsgetestet.
- Dokumentiert: Bei fehlgeschlagenem Reload wird zurückgerollt; bei fehlgeschlagenem `POST_DEPLOY_CMD` bleibt das neue Zertifikat aktiv.

### Runde-3-Tests

- Retention bewahrt die jüngsten Releases und zusätzlich ein altes aktives Release.
- Atomarer Wechsel und Wiederherstellung des vorherigen Symlinks erfolgreich.
- Noch offen: echter Dienst-Reload, Stromausfall-/Crash-Fenster, Integration auf vollständigem systemd-Host und Node64-Test-API.


## Runde 4 – Rollback mit erneutem Dienst-Reload (0.6.0)

- Bei fehlgeschlagenem erstem Reload wird `current` atomar auf das vorherige Release zurückgesetzt.
- Danach wird derselbe Reload-Befehl erneut ausgeführt, damit der Dienst das vorherige Zertifikat tatsächlich wieder lädt.
- Ein erfolgreicher zweiter Reload wird protokolliert. Ein erneut fehlgeschlagener Reload erzeugt eine deutliche Warnung mit dem Hinweis, den Dienststatus manuell zu prüfen.
- Wenn kein vorheriges Release existierte, wird `current` entfernt; ein Reload eines alten Zertifikats ist dann naturgemäß nicht möglich.
- Regressionstest simuliert einen fehlgeschlagenen ersten und erfolgreichen zweiten Reload.

### Runde-4-Tests

- 16 lokale Regressionstests erfolgreich.
- Bash-Syntaxprüfung für Hauptskript, Installer, Deinstaller und Tests erfolgreich.
- Weiterhin nicht durchgeführt: echte Node64-API, produktive Zertifikate, echter Dienst-Reload und vollständige Debian-/Ubuntu-VM-Integration.
