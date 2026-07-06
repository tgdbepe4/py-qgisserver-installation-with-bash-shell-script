# Lizmap + py-qgis-server — Projektdokumentation

## Vorwort

Dieses Projekt richtet sich an alle, die einen **GIS-Webserver auf eigener Infrastruktur**
betreiben möchten — ohne tiefgreifende Linux- oder GIS-Serverkenntnisse vorauszusetzen.

Ziel ist es, den gesamten Stack aus **QGIS Server**, **Lizmap Web Client** und allen
notwendigen Diensten (Nginx, PHP, PostgreSQL, xRDP) mit einem einzigen Skript vollständig
und reproduzierbar auf einem frischen **Ubuntu 24.04 LTS**-Server aufzusetzen.

**Typische Anwendungsfälle:**
- Gemeinden, Planungsbüros oder Organisationen, die QGIS-Projekte im Browser veröffentlichen wollen
- Systemadministratoren, die einen produktionsreifen GIS-Server aufsetzen oder warten
- Entwickler und GIS-Fachleute, die eine reproduzierbare Testumgebung benötigen

**Was dieses Projekt liefert:**
- Vollautomatische Installation per Shell-Skript — ein Befehl, fertig aufgesetzter Server
- Diagnoseskript zur Fehlersuche und optionalen automatischen Korrektur
- Backup-Skript für alle Konfigurationen und Daten
- Vollständige Dokumentation aller Komponenten, Pfade und Konfigurationsoptionen

Vorkenntnisse: grundlegende Linux-Kenntnisse (SSH, Texteditor) genügen.

---

## Übersicht

Dieses Repository enthält Skripte zur vollautomatischen Installation und Diagnose
eines **Lizmap Web Client + py-qgis-server**-Stacks auf **Ubuntu 24.04 LTS**.

| Skript | Zweck |
|---|---|
| `install_lizmap_qgisserver.sh` | Vollinstallation |
| `check_installation.sh` | Diagnose + optionale Fehlerkorrektur (`--fix`) |
| `backup_lizmap_system.sh` | Backup aller Konfigurationen und Daten |

---

## Installierter Stack

### Komponenten

| Komponente | Version / Details |
|---|---|
| QGIS Server LTR | via offiziellem QGIS apt-Repository |
| QGIS Desktop LTR | für Projektbearbeitung via RDP |
| py-qgis-server | 3liz Python WSGI-Wrapper für QGIS Server |
| Lizmap Web Client | 3.9.9 |
| Nginx | mit PHP 8.3-FPM |
| PostgreSQL + PostGIS | optional (Standard: aktiviert) |
| pgAdmin4 Web | optional (unter `/pgadmin4`) |
| xRDP + XFCE4 | Remote Desktop auf Port 3389 (optional) |
| Xvfb | virtuelles Display `:99` für QGIS/Qt-Rendering |
| certbot + python3-certbot-nginx | HTTPS via Let's Encrypt |
| UFW + Fail2ban | Firewall + Brute-Force-Schutz (optional) |

### QGIS Server Plugins

Installation: primär via **qgis-plugin-manager** (3liz CLI), ZIP-Download als Fallback.

| Plugin | Quelle |
|---|---|
| `lizmap_server` | github.com/3liz/qgis-lizmap-server-plugin |
| `atlasprint` | github.com/3liz/qgis-atlasprint |
| `wfsOutputExtension` | github.com/3liz/qgis-wfsOutputExtension |

**Installationsstrategie:**

1. Primär: `qgis-plugin-manager` (CLI) — wird vom Installskript in eigener venv bereitgestellt
2. Fallback: direkter ZIP-Download von GitHub Releases bzw. GitHub master

`qgis-plugin-manager` läuft in einer **eigenen isolierten venv** (`/opt/local/qgis-plugin-manager`),
getrennt von py-qgis-server, um Dependency-Konflikte zu vermeiden.
Symlink: `/usr/local/bin/qgis-plugin-manager`

Plugins manuell aktualisieren (auf bestehendem System):
```bash
export QGIS_PLUGINPATH=/srv/qgis/plugins

# QGIS-Version ermitteln (Epoch-Präfix "1:" beachten → grep mitten im String)
QGIS_VER=$(dpkg -l qgis-server | awk '/^ii.*qgis-server /{print $3}' | grep -oP '\d+\.\d+' | head -1)
# sources.list mit Version setzen (qgis-plugin-manager 1.7.5 kennt kein --qgis-version Flag)
echo "https://plugins.qgis.org/plugins/plugins.xml?qgis=${QGIS_VER}" > /srv/qgis/plugins/sources.list

qgis-plugin-manager update
qgis-plugin-manager upgrade   # alle Plugins auf neueste Version

supervisorctl restart py-qgisserver
```

> Falls `qgis-plugin-manager` nicht im PATH: `/opt/local/qgis-plugin-manager/bin/qgis-plugin-manager`

### Lizmap Web Client aktualisieren (bestehendes System)

**Nicht** das Install-Skript mit neuer `LIZMAP_VERSION` erneut auf einem laufenden System ausführen —
Sektion 8 macht bei Versionswechsel ein `rm -rf "${LIZMAP_DIR}"` und schreibt `lizmapConfig.ini.php`,
`localconfig.ini.php` und `profiles.ini.php` aus den `.dist`-Vorlagen neu (siehe
`install_lizmap_qgisserver.sh`, Abschnitt "8. Lizmap Web Client"). Angepasste Konfiguration ginge
dabei verloren. Stattdessen der offizielle Lizmap-Upgrade-Pfad:

```bash
# 1. Backup
# Aus dem Repo-Verzeichnis ausführen (dort liegt backup_lizmap_system.sh),
# z.B. ~/py-qgisserver-installation-with-bash-shell-script/ — nicht /var/www/lizmap!
sudo bash backup_lizmap_system.sh

# backup.sh legt das Zielverzeichnis NICHT selbst an — fehlt es, bricht es mit
# "backup directory does not exists" ab, ohne etwas zu sichern.
sudo mkdir -p /tmp/lizmap-backup
cd /var/www/lizmap
sudo bash lizmap/install/backup.sh /tmp/lizmap-backup

# 2. Code austauschen, Konfiguration erhalten
# Achtung Verschachtelung: das Release-Archiv enthält selbst nochmal einen lizmap/-Unterordner
# mit dem eigentlichen Code (lizmap/install/, lizmap/var/, …) — genau wie LIZMAP_DIR im
# Install-Skript intern auch relativ auf lizmap/var/config/… zugreift. Deshalb erst reinwechseln:
cd /var/www
mv lizmap lizmap.bak
wget https://github.com/3liz/lizmap-web-client/releases/download/<NEUE_VERSION>/lizmap-web-client-<NEUE_VERSION>.zip
unzip lizmap-web-client-<NEUE_VERSION>.zip
mv lizmap-web-client-<NEUE_VERSION> lizmap
cd lizmap                                                # ab hier: /var/www/lizmap
sudo bash lizmap/install/restore.sh /tmp/lizmap-backup

# Fallback, falls /tmp/lizmap-backup leer ist oder restore.sh mit
# "backup directory does not exists" abbricht: solange lizmap.bak/ noch existiert,
# liegt die echte Konfiguration dort unversehrt — direkt von dort zurückkopieren:
#   cd /var/www
#   sudo cp -Rp lizmap.bak/lizmap/var/db      lizmap/lizmap/var/
#   sudo cp -Rp lizmap.bak/lizmap/var/config  lizmap/lizmap/var/
#   [ -d lizmap.bak/lizmap/var/lizmap-theme-config ] && sudo cp -Rp lizmap.bak/lizmap/var/lizmap-theme-config lizmap/lizmap/var/
#   [ -d lizmap.bak/lizmap/my-packages ]              && sudo cp -Rp lizmap.bak/lizmap/my-packages              lizmap/lizmap/
#   [ -d lizmap.bak/lizmap/lizmap-modules ]           && sudo cp -Rp lizmap.bak/lizmap/lizmap-modules           lizmap/lizmap/

# 3. Installer/Migrator (weiterhin in /var/www/lizmap)
sudo lizmap/install/clean_vartmp.sh
php lizmap/install/configurator.php
php lizmap/install/installer.php
sudo lizmap/install/clean_vartmp.sh
sudo lizmap/install/set_rights.sh www-data www-data

# set_rights.sh hat in der Praxis nicht immer alles erfasst — danach prüfen:
#   lizmap/var/cache fehlte komplett (leer/nicht angelegt nach clean_vartmp.sh):
sudo mkdir -p lizmap/var/cache/qgisprojects lizmap/var/cache/requests
#   lizmap/var, lizmap/www, temp/ blieben root-owned (z.B. weil vorher als root unzip/cp lief):
sudo chown -R www-data:www-data lizmap/var lizmap/www /var/www/lizmap/temp
#   wmsServerType muss 'py-qgis-server' sein — nach Restore ggf. leer:
grep -n "wmsServerType" lizmap/var/config/lizmapConfig.ini.php
sed -i "s|wmsServerType=.*|wmsServerType=py-qgis-server|" lizmap/var/config/lizmapConfig.ini.php

# 4. lizmap_server-Plugin auf passende Version bringen (siehe oben), dann py-qgis-server neu starten.
# Vorher prüfen, welcher Mechanismus auf diesem Server tatsächlich läuft — nicht jede Installation
# nutzt Supervisor (auf manchen Servern startet qgis.service qgisserver direkt via systemd,
# User=root, ganz ohne Supervisor-Schicht):
which supervisorctl && systemctl is-active supervisor
supervisorctl restart py-qgisserver        # falls Supervisor vorhanden
sudo systemctl restart qgis.service        # falls nicht (direkter systemd-Service)

# 5. Dienste neu laden + prüfen
systemctl reload php8.3-fpm nginx
sudo bash check_installation.sh
```

> **Vorsicht mit `check_installation.sh --fix`:** Auf Servern, die von der Standard-Architektur
> abweichen (kein Supervisor, andere Nginx-Struktur, `root` statt `qgis`-Systembenutzer), meldet das
> Diagnoseskript teils vorbestehende, nicht update-bezogene Warnungen (Nginx-Vhost, PHP-Extensions,
> xRDP, PostgreSQL, Verzeichnis-Owner). `--fix` ändert automatisiert Nginx/Rechte/Dienste — auf einem
> laufenden produktiven Server jede Meldung einzeln bewerten statt pauschal zu fixen.

Im Browser verifizieren (Login, Karte laden, `.../lizmap/admin/serverInformation` zeigt Lizmap-/QGIS-
Server-/Plugin-Versionen auf einen Blick). Danach aufräumen:
```bash
rm -rf /var/www/lizmap.bak
rm /root/lizmap_backup_*.tar.gz   # das backup_lizmap_system.sh-Archiv aus Schritt 1
```

Anschliessend `LIZMAP_VERSION` im Skript-Header aller Install-Skript-Varianten auf die neue Version
anpassen, damit künftige Neuinstallationen den aktuellen Stand verwenden. Falls dabei auch QGIS Server
auf eine neue Version gesprungen ist: `sources.list` für `qgis-plugin-manager` nachziehen (siehe oben,
Abschnitt "QGIS Server Plugins") — ein reines `apt upgrade` von `qgis-server` aktualisiert diese Datei
**nicht** automatisch, sie kann dadurch unbemerkt veraltet sein.

---

## Konfiguration

### Anpassbare Variablen (Skript-Header)

| Variable | Standardwert | Beschreibung |
|---|---|---|
| `LIZMAP_VERSION` | `3.9.9` | Lizmap Web Client Version |
| `LIZMAP_DIR` | `/var/www/lizmap` | Installationspfad Lizmap |
| `QGIS_PROJECTS_DIR` | `/srv/data` | Verzeichnis für QGIS-Projektdateien |
| `QGIS_WORKER_COUNT` | `4` | Anzahl QGIS Server Worker-Instanzen |
| `SERVER_NAME` | `localhost karte1.wandelderzeit.ch` | Domain oder IP des Servers |
| `LIZMAP_USER` | `www-data` | Webserver-Benutzer (PHP-FPM / Nginx) |
| `LIZMAP_GROUP` | `www-data` | Webserver-Gruppe |
| `INSTALL_POSTGRESQL` | `true` | PostgreSQL + PostGIS installieren (`true`/`false`) |
| `PG_LIZMAP_DB` | `lizmap` | PostgreSQL Datenbankname |
| `PG_LIZMAP_USER` | `lizmap` | PostgreSQL Benutzername |
| `PG_LIZMAP_PASS` | *(auto-generiert)* | PostgreSQL Passwort — stabil bei Re-Run wenn als Env-Variable exportiert |
| `INSTALL_XRDP` | `true` | xRDP + XFCE4 installieren (`true`/`false`) |
| `XRDP_USER` | `gisadmin` | Dedizierter RDP-Benutzer |
| `XRDP_PASS` | *(auto-generiert)* | RDP-Passwort — stabil bei Re-Run wenn als Env-Variable exportiert |
| `XRDP_PORT` | `3389` | RDP-Port |
| `INSTALL_SECURITY` | `true` | UFW + Fail2ban installieren (`true`/`false`) |
| `CERTBOT_EMAIL` | *(leer, liest Env-Variable)* | E-Mail für Let's Encrypt — nicht im Skript editieren, per `export CERTBOT_EMAIL=... ; sudo -E bash ...` setzen. Leer = HTTPS überspringen |
| `LOG_FILE` | `/var/log/install_lizmap_qgisserver.log` | Pfad zur Installationslogdatei |

Passwörter bei Re-Run stabil halten:

```bash
export PG_LIZMAP_PASS="mein-passwort"
export XRDP_PASS="mein-passwort"
sudo -E bash install_lizmap_qgisserver.sh
```

**Optionale Umgebungsvariablen:**

| Variable | Zweck |
|---|---|
| `GITHUB_TOKEN` | GitHub Personal Access Token — erhöht API-Limit von 60 auf 5000 req/h beim Plugin-Download |
| `LIZMAP_SERVER_PLUGIN_VERSION` | Überschreibt die Fallback-Version für `lizmap_server` (Standard: `2.14.1`) |

### Nginx

- Konfiguration: `/etc/nginx/sites-available/lizmap`
- Gemeinsame Location-Blöcke: `/etc/nginx/lizmap-common.conf`
- Web Root: `/var/www/lizmap/lizmap/www`
- Proxy: `/ows/` → `http://127.0.0.1:7200/ows/`
- Logs: `/var/log/nginx/lizmap-access.log`, `/var/log/nginx/lizmap-error.log`

**Zwei Server-Blöcke:**

| Block | `listen` | `server_name` | Zweck |
|---|---|---|---|
| Block 1 | `80 default_server` | `_` | IP-Zugriff — immer Lizmap direkt, certbot-unabhängig |
| Block 2 | `80` | `karte1.wandelderzeit.ch localhost` | Domain — certbot setzt hier HTTPS auf |

| Zugriff | Vor HTTPS | Nach HTTPS (certbot) |
|---|---|---|
| `http://<IP>/` | Lizmap direkt | Lizmap direkt |
| `https://<IP>/` | Lizmap direkt (self-signed) | Lizmap direkt (self-signed) |
| `http://karte1.wandelderzeit.ch/` | Lizmap direkt | 301 → `https://...` |
| `https://karte1.wandelderzeit.ch/` | — | Lizmap direkt (Let's Encrypt) |

**Self-signed Zertifikat** (`/etc/nginx/ssl/lizmap-selfsigned.crt`):
- Wird beim Install automatisch generiert (10 Jahre gültig)
- Enthält die öffentliche IP als Subject Alternative Name (SAN)
- Browser zeigt einmalige Warnung → Ausnahme hinzufügen, danach funktioniert HTTPS
- certbot berührt dieses Zertifikat nicht

### py-qgis-server — `/srv/qgis/server.conf`

```ini
#
# Py-QGIS-Server configuration
# https://docs.3liz.org/py-qgis-server/
#
[server]
port = 7200
interfaces = 127.0.0.1
workers = 4                  # = QGIS_WORKER_COUNT
memory_high_water_mark = 0.8
pluginpath = /srv/qgis/plugins
timeout = 200
restartmon = /var/lib/py-qgis-server/py-qgis-restartmon

[logging]
level = debug

[projects.cache]
strict_check = false
rootdir = /srv/data          # = QGIS_PROJECTS_DIR
size = 50
advanced_report = no
preload_config = /srv/qgis/config/preload_projects.txt

[monitor:amqp]
routing_key =
default_routing_key=
host =

[api.endpoints]
lizmap_api=/lizmap

[api.enabled]
lizmap_api=yes
```

### QGIS Umgebungsvariablen — `/srv/qgis/config/qgis-service.env`

| Variable | Wert | Bedeutung |
|---|---|---|
| `DISPLAY` | `:99` | Xvfb virtuelles Display |
| `QT_QPA_PLATFORM` | `xcb` | Qt X11-Backend |
| `LIBGL_ALWAYS_SOFTWARE` | `1` | Software-Rendering (kein GPU erforderlich) |
| `QGIS_OPTIONS_PATH` | `/srv/qgis/` | Pfad zu `QGIS3.ini` |
| `QGIS_AUTH_DB_DIR_PATH` | `/srv/qgis/` | Authentifizierungs-DB |
| `QGIS_SERVER_LIZMAP_REVEAL_SETTINGS` | `TRUE` | Aktiviert `/lizmap/server.json` |
| `QGSRV_API_ENABLED_LIZMAP` | `yes` | Aktiviert Lizmap REST API |
| `QGSRV_API_ENDPOINTS_LIZMAP` | `/lizmap` | API-Endpunkt |
| `QGIS_SERVER_FORCE_READONLY_LAYERS` | `TRUE` | Schreibschutz für Layer |
| `QGSRV_SERVER_PLUGINPATH` | `/srv/qgis/plugins` | Plugin-Verzeichnis |

### Supervisor — `/etc/supervisor/conf.d/py-qgisserver.conf`

- Kommando: `/opt/local/py-qgis-server/bin/qgisserver -c /srv/qgis/server.conf`
- User: `qgis`
- Logs: `/var/log/supervisor/py-qgisserver.log` und `py-qgisserver-err.log`

**Worker-Anzahl:** wird **nicht** per `-w` Flag im Kommando gesetzt, sondern ausschliesslich über
`/srv/qgis/server.conf → [server] workers = N`. So gibt es nur eine einzige Konfigurationsstelle.

Vor der Installation `QGIS_WORKER_COUNT` im Skript-Header setzen — das Skript schreibt diesen Wert
in `server.conf`. Empfehlung: ~50 % der CPU-Kerne. Siehe `anleitung_worker.md` und `worker_rechner.html`.

---

## Verzeichnisstruktur

```
/srv/qgis/
├── server.conf              # py-qgis-server Konfiguration
├── config/
│   ├── qgis-service.env     # Umgebungsvariablen für QGIS
│   └── preload_projects.txt # Projekte, die beim Start geladen werden
├── plugins/
│   ├── lizmap_server/
│   ├── atlasprint/
│   └── wfsOutputExtension/
├── cache/                   # QGIS Server Cache
├── QGIS/
│   └── QGIS3.ini            # QGIS Optionen
├── qgis-auth.db             # Authentifizierungs-Datenbank
├── qgis.db
└── symbology-style.db

/srv/data/                   # QGIS Projektdateien (.qgs / .qgz)

/opt/local/
├── py-qgis-server/          # Python venv: py-qgis-server (mit --system-site-packages)
└── qgis-plugin-manager/     # Python venv: qgis-plugin-manager (isoliert, kein Konflikt)

/usr/local/bin/
├── qgisserver               # Symlink → /opt/local/py-qgis-server/bin/qgisserver
└── qgis-plugin-manager      # Symlink → /opt/local/qgis-plugin-manager/bin/qgis-plugin-manager

/var/www/lizmap/             # Lizmap Web Client
├── lizmap/www/              # Nginx Web Root (index.php)
└── lizmap/var/config/       # Lizmap Konfiguration
```

---

## Ports

| Port | Dienst |
|---|---|
| 80 | Nginx HTTP |
| 443 | Nginx HTTPS (nach certbot) |
| 7200 | py-qgis-server (nur localhost) |
| 5432 | PostgreSQL (optional) |
| 3389 | xRDP Remote Desktop (optional) |

---

## QGIS Stack steuern

```bash
service qgis start    # Startet Xvfb + Worker + py-qgis-server
service qgis stop     # Stoppt alle QGIS-Dienste
service qgis restart  # Neustart aller QGIS-Dienste
service qgis status   # Status anzeigen
```

Einzelne Dienste:
```bash
supervisorctl status py-qgisserver
supervisorctl restart py-qgisserver
systemctl status xvfb
```

---

## HTTPS einrichten

### Automatisch (empfohlen)

`CERTBOT_EMAIL` als Umgebungsvariable setzen (nicht im Skript-Header editieren), dann Skript
mit `sudo -E` ausführen, z.B.:

```bash
export CERTBOT_EMAIL=du@example.com
curl -s <raw-script-url> | sudo -E bash
```

Sektion 12 läuft dann vollautomatisch am Ende der Installation:

1. Erste Nicht-localhost-Domain aus `SERVER_NAME` wird als Zieldomain verwendet
2. `certbot --nginx -d <domain> --non-interactive --agree-tos` wird aufgerufen
3. Certbot modifiziert nur **Block 2** (Domain) — **Block 1** (IP/default_server) bleibt
   unberührt → `http://<IP>/` funktioniert weiterhin direkt, kein Fix nötig

### Manuell (nachträglich)

certbot und das nginx-Plugin sind bereits installiert:

```bash
certbot --nginx -d karte1.wandelderzeit.ch
```

Da Block 1 (`default_server`) von certbot nicht angefasst wird, ist kein zusätzlicher
Fix für den IP-Zugriff nötig. `http://<IP>/` bleibt nach certbot weiterhin erreichbar.

---

## Diagnose

```bash
# Vollständige Prüfung
sudo bash check_installation.sh

# Prüfung + automatische Fehlerbehebung
sudo bash check_installation.sh --fix
```

Was geprüft wird:
- Systemdienste (nginx, php-fpm, xvfb, supervisor, postgresql)
- py-qgisserver Status und Uptime
- server.conf: alle Sektionen und Keys
- Nginx: server_name, root, proxy_pass
- Lizmap API (`/lizmap/server.json`)
- PHP Extensions
- QGIS Plugins (Vollständigkeit)
- Verzeichnisse und Berechtigungen
- PostgreSQL + PostGIS
- Xvfb Display

---

## Logs

| Dienst | Log |
|---|---|
| Nginx | `/var/log/nginx/lizmap-access.log`, `/var/log/nginx/lizmap-error.log` |
| PHP-FPM | `/var/log/php8.3-fpm.log` |
| py-qgis-server | `/var/log/supervisor/py-qgisserver*.log` |
| QGIS Worker | `journalctl -u 'qgis-server@*.service'` |
| Xvfb | `journalctl -u xvfb.service` |
| xRDP | `/var/log/xrdp.log`, `/var/log/xrdp-sesman.log` |
| Fail2ban | `/var/log/fail2ban.log` |
| Installation | `/var/log/install_lizmap_qgisserver.log` |

---

## Nach der Installation

1. Lizmap unter `http://<SERVER-IP>/` öffnen → Login `admin / admin` → **Passwort sofort ändern**
2. Via RDP (mstsc / Remmina) auf `<SERVER-IP>:3389` verbinden
3. QGIS Desktop in der RDP-Session öffnen und `.qgs`/`.qgz` Projekte nach `/srv/data/` speichern
4. Im QGIS Desktop das **Lizmap QGIS Plugin** installieren und pro Projekt Veröffentlichungsoptionen konfigurieren
5. HTTPS: wird automatisch konfiguriert wenn `CERTBOT_EMAIL` als Umgebungsvariable gesetzt war. Sonst manuell nachholen:
```bash
certbot --nginx -d karte1.wandelderzeit.ch
```

---

## Referenzen

- Lizmap Dokumentation: https://docs.lizmap.com/
- py-qgis-server Dokumentation: https://docs.3liz.org/py-qgis-server/
- QGIS Server Dokumentation: https://docs.qgis.org/latest/en/docs/server_manual/
