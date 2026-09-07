# Lizmap Web Client + py-qgis-server — Installation Stack (Ubuntu 24.04 LTS)

> **Hinweis:** Dies ist die Ubuntu-24.04-Version dieses Projekts. Die aktuell empfohlene
> Standardversion ist **Ubuntu 26.04 LTS** — siehe das [Haupt-README](../README.md) im
> Projekt-Root und den Ordner [`ubuntu-26.04/`](../ubuntu-26.04/). Diese 24.04-Version wird
> weiterhin unterstützt, erhält aber keine neuen Features mehr.

Das Projekt hat es zum Ziel eine komplette Lizmap-Umgebung auf einem Ubuntu 24.04 mit dem py-qgisserver zu installieren. Ausserdem postgres, das Hilfswerkzeug qgis-plugin-manager und eine Xfce4 Desktop-Umgebung.

Diese Scripts wurden mit der KI claude.ai, der günstigsten Pro Version für kapp € 20.-, erstellt. Es brauchte unzählige Interaktionen bis alles sauber lief. Nun ist jedoch das Resultat überzeugend!

Im Skript-Header `SERVER_NAME` auf die eigene Domain anpassen, `QGIS_WORKER_COUNT` auf die Hardware abstimmen (siehe [Worker-Konfiguration](#worker-konfiguration)), dann ausführen. Danach mit `check_installation.sh` prüfen, allenfalls mit `--fix` nachkorrigieren.

Weiter muss nach der Installation "certbot --nginx -d <URL>" ausgeführt werden. Damit werden in der NGIX-Umgebung die Zertifikate generiert und installiert.

Falls man ein System auserhalb, z.B. eine Cloudlösung verwendet, empfehle ich putty und damit einen Tunnel zum Remote Desktop Server konfigurieren. Putty kann man via ein Script starten. Beispiel unter Windows 11 ein Batchfile erstellen mit der Erweiterung *.bat :

cd "C:\Program Files\PuTTY\"
start putty.exe -load "<usernam>@<ip adresse des server>" <username>@<ip adresse des server> -P 22 -pw <passwort> -L localhost:3386:<ip adresse des server>:3389

Bei localhost (localhost:3386) muss man einen anderen Port verwenden, damit man nicht in Konflikt mit dem lokalen RDP-Server kommt! 

Vollautomatische Installation und Diagnose eines **Lizmap Web Client + py-qgis-server**-Stacks auf **Ubuntu 24.04 LTS**.

## Skripte

| Skript | Zweck |
|---|---|
| `install_lizmap_qgisserver.sh` | Vollinstallation — `QGIS_WORKER_COUNT` im Header anpassen |
| `install_lizmap_qgisserver_8cpu.sh` | Vollinstallation — voreingestellt für 8 CPU-Kerne (4 Worker) |
| `install_lizmap_qgisserver_16cpu.sh` | Vollinstallation — voreingestellt für 16 CPU-Kerne (8 Worker) |
| `check_installation.sh` | Diagnose + optionale Fehlerkorrektur (`--fix`) |
| `backup_lizmap_system.sh` | Backup aller Konfigurationen und Daten als `.tar.gz` nach `/root/` |

Andere Hardware → [Worker Rechner](../worker_rechner.html) öffnen, Werte berechnen lassen, dann `QGIS_WORKER_COUNT` im Skript-Header anpassen.

> **Hinweis:** Sektion 10 (xRDP + XFCE4) lädt viele Pakete — Dauer je nach Verbindung 5–15 Minuten. Der Fortschritt wird angezeigt.

## Was wird installiert

| Komponente | Details |
|---|---|
| QGIS Server LTR | via offiziellem QGIS apt-Repository |
| QGIS Desktop LTR | für Projektbearbeitung via RDP |
| py-qgis-server | 3liz Python WSGI-Wrapper für QGIS Server |
| Lizmap Web Client | 3.9.x |
| Nginx + PHP 8.3-FPM | Webserver |
| PostgreSQL + PostGIS | optional |
| pgAdmin4 Web | optional, unter `/pgadmin4` |
| xRDP + XFCE4 | Remote Desktop auf Port 3389, optional |
| Xvfb | virtuelles Display `:99` für QGIS/Qt-Rendering |
| certbot + python3-certbot-nginx | HTTPS via Let's Encrypt |
| UFW + Fail2ban | Firewall + Brute-Force-Schutz, optional |

**QGIS Server Plugins** (via qgis-plugin-manager): `lizmap_server`, `atlasprint`, `wfsOutputExtension`

## Schnellstart

```bash
# Als root auf Ubuntu 24.04 LTS:
git clone https://github.com/tgdbepe4/py-qgisserver-installation-with-bash-shell-script
cd py-qgisserver-installation-with-bash-shell-script/ubuntu-24.04

# Variablen im Skript-Header anpassen (SERVER_NAME, QGIS_WORKER_COUNT, …):
# CERTBOT_EMAIL NICHT hier eintragen — siehe Abschnitt "Konfiguration" unten (Umgebungsvariable).
nano install_lizmap_qgisserver_8cpu.sh    # für 8 CPU-Kerne
# oder
nano install_lizmap_qgisserver_16cpu.sh   # für 16 CPU-Kerne
# oder
nano install_lizmap_qgisserver.sh         # Basis-Skript, QGIS_WORKER_COUNT manuell setzen

sudo bash install_lizmap_qgisserver_8cpu.sh
```

## Konfiguration

Die wichtigsten Variablen befinden sich im Skript-Header:

```bash
SERVER_NAME="localhost karte1.example.com"  # Domain / IP des Servers
QGIS_WORKER_COUNT=4                          # Worker-Prozesse (≈ CPU-Kerne ÷ 2)
INSTALL_POSTGRESQL=true                      # PostgreSQL + PostGIS
INSTALL_XRDP=true                            # Remote Desktop
INSTALL_SECURITY=true                        # UFW + Fail2ban
CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"           # E-Mail → HTTPS automatisch aktivieren
```

**Worker-Anzahl:** `QGIS_WORKER_COUNT` im Skript-Header setzen — das Skript schreibt diesen Wert in `/srv/qgis/server.conf`. Das ist die einzige Stelle, an der die Worker-Anzahl konfiguriert wird (kein `-w` Flag im Supervisor). Siehe [anleitung_worker.md](../anleitung_worker.md) und [worker_rechner.html](../worker_rechner.html).

**HTTPS/Let's Encrypt:** `CERTBOT_EMAIL` liest standardmäßig eine Umgebungsvariable — nicht im Skript editieren, sondern beim Aufruf mitgeben, damit die E-Mail-Adresse nicht im Repo landet:

```bash
export CERTBOT_EMAIL=du@example.com
sudo -E bash install_lizmap_qgisserver_8cpu.sh
```

Vorausgesetzt DNS für die Domain aus `SERVER_NAME` zeigt bereits auf den Server, läuft certbot dann vollautomatisch am Ende der Installation.

Wird `CERTBOT_EMAIL` **nicht** per Umgebungsvariable gesetzt, verhält sich das Skript je nach Umgebung unterschiedlich:

- **Interaktiver Lauf mit Terminal** (auch `curl ... | sudo bash` in einer normalen SSH-Sitzung): Das Skript fragt am Ende kurz nach — `HTTPS via Let's Encrypt für '<domain>' einrichten? E-Mail eingeben (Enter = überspringen):`. Enter drücken überspringt HTTPS genau wie beim Setzen von nichts.
- **Vollautomatisierter Lauf ohne Terminal** (z.B. aus einem Cron-Job oder CI-System ohne TTY): keine Rückfrage, HTTPS wird stillschweigend übersprungen — kein Hänger.

In beiden Fällen bleibt nur das selbstsignierte Zertifikat für IP-Zugriff aktiv, und HTTPS kann jederzeit manuell nachgeholt werden: `sudo certbot --nginx -d deine-domain.example.com`.

## Nach der Installation

1. Lizmap unter `http://<SERVER-IP>/` öffnen → Login `admin / admin` → **Passwort sofort ändern**
2. Via RDP (`mstsc` / Remmina) auf `<SERVER-IP>:3389` verbinden
3. QGIS Desktop in der RDP-Session öffnen → `.qgs`/`.qgz` Projekte nach `/srv/data/` speichern
4. Im QGIS Desktop das **Lizmap QGIS Plugin** installieren und Veröffentlichungsoptionen pro Projekt konfigurieren

**Weitere RDP-Benutzer:** Ein einfaches `adduser` reicht nicht — die RDP-Sitzung startet sonst
nicht. Zusätzlich `~/.xsession` mit `xfce4-session` anlegen, siehe [CLAUDE.md](CLAUDE.md#xrdp-weitere-benutzer-anlegen).

## Diagnose

```bash
sudo bash check_installation.sh          # Vollständige Prüfung
sudo bash check_installation.sh --fix    # Prüfung + automatische Korrekturen
```

Was geprüft wird: Systemdienste, py-qgisserver Status, `server.conf`, Nginx-Konfiguration, Lizmap API, PHP-Extensions, QGIS-Plugins, Verzeichnisse & Berechtigungen, PostgreSQL + PostGIS, Xvfb-Display.

> **Hinweis:** `--fix` behebt einfache Konfigurations- und Berechtigungsfehler.
> Bei komplexeren Problemen (fehlende Pakete, defekte venv, etc.) ist das erneute Ausführen
> des Installationsskripts zuverlässiger — es ist **idempotent** und kann sicher wiederholt werden:
> ```bash
> sudo bash install_lizmap_qgisserver.sh
> ```

## Backup

```bash
sudo bash backup_lizmap_system.sh
```

Erstellt `/root/lizmap_backup_DATUM.tar.gz` mit:

| Inhalt | Pfad |
|---|---|
| QGIS Server Konfiguration | `/srv/qgis/` (ohne Cache) |
| QGIS Projekte | `/srv/data/` |
| Lizmap Konfiguration | `/var/www/lizmap/lizmap/var/config/` |
| Nginx Konfiguration | `/etc/nginx/sites-*`, `nginx.conf`, `lizmap-common.conf`, `ssl/` |
| Supervisor Konfiguration | `/etc/supervisor/conf.d/` |
| PHP Konfiguration | `/etc/php/8.3/fpm/` |
| PostgreSQL Dump | `pg_dump lizmap` + Globals |
| Systemd Units | `xvfb.service`, `qgis.service`, `qgis-server@*` |
| xRDP Konfiguration | `/etc/xrdp/startwm.sh`, `xrdp.ini` |
| System-Informationen | Pakete, Dienste, Plugin-Versionen |

Am Ende zeigt das Skript den korrekten `scp`-Befehl mit der aktuellen Server-IP zum Herunterladen.

## Lizmap Web Client aktualisieren (Bestehendes System)

> **Wichtig:** Die Install-Skripte sind **nicht** zum Updaten einer laufenden Installation gedacht —
> bei abweichender `LIZMAP_VERSION` wird `/var/www/lizmap` komplett gelöscht und die Konfiguration
> (`lizmapConfig.ini.php`, `profiles.ini.php`, `localconfig.ini.php`) aus den `.dist`-Vorlagen neu
> geschrieben. Angepasste Einstellungen gingen dabei verloren. Für ein Update auf einem produktiven
> System stattdessen den offiziellen Lizmap-Upgrade-Weg verwenden:

**1. Backup**

> `backup.sh` legt das Zielverzeichnis **nicht selbst an** — fehlt es, bricht das Skript mit
> `backup directory does not exists` ab, ohne etwas zu sichern. Vorher `mkdir -p` nicht vergessen.

```bash
# Aus diesem Verzeichnis ausführen (hier liegt backup_lizmap_system.sh),
# z.B. ~/py-qgisserver-installation-with-bash-shell-script/ubuntu-24.04/ — nicht /var/www/lizmap!
sudo bash backup_lizmap_system.sh

sudo mkdir -p /tmp/lizmap-backup
cd /var/www/lizmap
sudo bash lizmap/install/backup.sh /tmp/lizmap-backup   # sichert Config + DB (jauth.db, logs.db, *.ini.php)
```

**2. Code austauschen, Konfiguration erhalten**

> Achtung Verschachtelung: Das Release-Archiv `lizmap-web-client-<VERSION>.zip` enthält selbst
> nochmal einen `lizmap/`-Unterordner mit dem eigentlichen Code (`lizmap/install/`, `lizmap/var/`, …).
> Nach `mv lizmap-web-client-<VERSION> lizmap` ist der echte Pfad also `/var/www/lizmap/lizmap/install/…`
> — genau wie im Install-Skript (`LIZMAP_DIR` = `/var/www/lizmap`, Skript referenziert intern ebenfalls
> `lizmap/var/config/…` relativ dazu). Deshalb unbedingt zuerst in den neuen Ordner wechseln:

```bash
cd /var/www
mv lizmap lizmap.bak
wget https://github.com/3liz/lizmap-web-client/releases/download/<NEUE_VERSION>/lizmap-web-client-<NEUE_VERSION>.zip
unzip lizmap-web-client-<NEUE_VERSION>.zip
mv lizmap-web-client-<NEUE_VERSION> lizmap
cd lizmap                                                # ab hier: /var/www/lizmap
sudo bash lizmap/install/restore.sh /tmp/lizmap-backup   # spielt Config + DB zurück
```

> **Fallback, falls `/tmp/lizmap-backup` leer ist oder `restore.sh` mit
> `backup directory does not exists` abbricht:** Solange `lizmap.bak/` noch existiert, liegt die
> echte Konfiguration dort unversehrt. Direkt von dort zurückkopieren statt über `/tmp`:
> ```bash
> cd /var/www
> sudo cp -Rp lizmap.bak/lizmap/var/db      lizmap/lizmap/var/
> sudo cp -Rp lizmap.bak/lizmap/var/config  lizmap/lizmap/var/
> # Falls vorhanden (optional):
> [ -d lizmap.bak/lizmap/var/lizmap-theme-config ] && sudo cp -Rp lizmap.bak/lizmap/var/lizmap-theme-config lizmap/lizmap/var/
> [ -d lizmap.bak/lizmap/my-packages ]              && sudo cp -Rp lizmap.bak/lizmap/my-packages              lizmap/lizmap/
> [ -d lizmap.bak/lizmap/lizmap-modules ]           && sudo cp -Rp lizmap.bak/lizmap/lizmap-modules           lizmap/lizmap/
> ```

**3. Installer/Migrator ausführen** (weiterhin in `/var/www/lizmap`)
```bash
sudo lizmap/install/clean_vartmp.sh
php lizmap/install/configurator.php
php lizmap/install/installer.php
sudo lizmap/install/clean_vartmp.sh
sudo lizmap/install/set_rights.sh www-data www-data
```

> **Danach prüfen, ob `set_rights.sh` wirklich alles erfasst hat** — in der Praxis blieb
> `lizmap/var/cache` nach dem Update leer/fehlend und `lizmap/var`, `lizmap/www`, `temp/` weiterhin
> `root`-owned (z.B. weil vorher als root ge-`unzip`t/kopiert wurde):
> ```bash
> sudo mkdir -p lizmap/var/cache/qgisprojects lizmap/var/cache/requests
> sudo chown -R www-data:www-data lizmap/var lizmap/www /var/www/lizmap/temp
> ```
> Ausserdem `wmsServerType` in `lizmap/var/config/lizmapConfig.ini.php` prüfen — muss `py-qgis-server`
> sein:
> ```bash
> grep -n "wmsServerType" lizmap/var/config/lizmapConfig.ini.php
> sed -i "s|wmsServerType=.*|wmsServerType=py-qgis-server|" lizmap/var/config/lizmapConfig.ini.php
> ```

**4. `lizmap_server`-Plugin auf passende Version bringen** (siehe nächster Abschnitt), dann py-qgis-server
neu starten. **Vorher prüfen, welcher Mechanismus auf diesem Server tatsächlich läuft** — nicht jede
Installation nutzt Supervisor:
```bash
which supervisorctl && systemctl is-active supervisor
```
Falls das leer/inaktiv ist (z.B. `qgis.service` startet `qgisserver` direkt via systemd, `User=root`,
ohne Supervisor-Schicht dazwischen):
```bash
sudo systemctl restart qgis.service
```
Falls Supervisor vorhanden ist:
```bash
supervisorctl restart py-qgisserver
```

**5. Dienste neu laden und prüfen**
```bash
systemctl reload php8.3-fpm nginx
sudo bash check_installation.sh
```
> **Vorsicht mit `--fix`:** Auf Servern, die von der Standard-Architektur abweichen (z.B. kein
> Supervisor, andere Nginx-Struktur, `root` statt `qgis`-Systembenutzer), listet das Diagnoseskript
> teils vorbestehende, nicht update-bezogene Warnungen (Nginx-Vhost, PHP-Extensions, xRDP, PostgreSQL,
> Verzeichnis-Owner). `--fix` automatisiert Änderungen an Nginx/Rechten/Diensten — vor dem Einsatz auf
> einem produktiven, bereits laufenden Server jede Meldung einzeln bewerten statt pauschal zu fixen.

Im Browser testen (Login, Karte laden, Serverinformationen-Seite `.../lizmap/admin/serverInformation`
prüft Lizmap-/QGIS-Server-/Plugin-Versionen auf einen Blick). Danach aufräumen:
```bash
rm -rf /var/www/lizmap.bak
rm /root/lizmap_backup_*.tar.gz   # das backup_lizmap_system.sh-Archiv aus Schritt 1
```

Anschliessend `LIZMAP_VERSION` im Skript-Header von `install_lizmap_qgisserver.sh` (und den CPU-Varianten)
auf die neue Version anpassen, damit künftige Neuinstallationen die aktualisierte Version verwenden.

Falls dabei auch QGIS Server auf eine neue Version gesprungen ist: `sources.list` für
`qgis-plugin-manager` nachziehen (siehe nächster Abschnitt), sonst werden ggf. nicht die zur neuen
QGIS-Version passenden Plugin-Versionen gefunden.

## QGIS-Plugins aktualisieren (Bestehendes System)

> `sources.list` wird nur geschrieben, wenn dieser Block ausgeführt wird — ein reines
> `apt upgrade` von `qgis-server` aktualisiert QGIS Server, aber **nicht** automatisch diese Datei.
> Dadurch kann sie unbemerkt veraltet sein (in der Praxis beobachtet: `sources.list` zeigte noch
> `qgis=3.34`, während QGIS Server längst auf `3.44` lief). Im Zweifel den tatsächlichen Stand über
> die Lizmap-Seite `.../lizmap/admin/serverInformation` gegenprüfen und `sources.list` bei Abweichung
> neu schreiben.

```bash
QGIS_VER=$(dpkg -l qgis-server | awk '/^ii.*qgis-server /{print $3}' | grep -oP '\d+\.\d+' | head -1)
echo "https://plugins.qgis.org/plugins/plugins.xml?qgis=${QGIS_VER}" > /srv/qgis/plugins/sources.list

/opt/local/py-qgis-server/bin/pip install -q qgis-plugin-manager
/opt/local/py-qgis-server/bin/qgis-plugin-manager update
/opt/local/py-qgis-server/bin/qgis-plugin-manager upgrade

supervisorctl restart py-qgisserver   # oder: sudo systemctl restart qgis.service (falls kein Supervisor läuft)
```

## QGIS Stack steuern

```bash
service qgis start|stop|restart|status
supervisorctl status py-qgisserver
```

## Ports

| Port | Dienst |
|---|---|
| 80 | Nginx HTTP |
| 443 | Nginx HTTPS (nach certbot) |
| 7200 | py-qgis-server (nur localhost) |
| 5432 | PostgreSQL (optional) |
| 3389 | xRDP Remote Desktop (optional) |

## Weitere Themen

Worker-Konfiguration, bekannte Probleme (bourbon.3liz.com-Timeout, Preload-Strategie,
Hardware-Empfehlungen, Umlaute/NFD-NFC nach Mac-Sync) und der UFW-Firewall-Anhang sind
OS-unabhängig und stehen im [Haupt-README](../README.md) bzw. [Haupt-CLAUDE.md](../CLAUDE.md)
im Projekt-Root.

## Referenzen

- [Lizmap Dokumentation](https://docs.lizmap.com/)
- [py-qgis-server Dokumentation](https://docs.3liz.org/py-qgis-server/)
- [QGIS Server Dokumentation](https://docs.qgis.org/latest/en/docs/server_manual/)
