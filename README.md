# Lizmap Web Client + py-qgis-server — Installation Stack

Das Projekt hat es zum Ziel eine komplette Lizmap-Umgebung auf einem Ubuntu 26.04 mit dem py-qgisserver zu installieren. Ausserdem postgres, das Hilfswerkzeug qgis-plugin-manager und eine Xfce4 Desktop-Umgebung.

Diese Scripts wurden mit der KI claude.ai, der günstigsten Pro Version für kapp € 20.-, erstellt. Es brauchte unzählige Interaktionen bis alles sauber lief. Nun ist jedoch das Resultat überzeugend!

Im Skript-Header `SERVER_NAME` auf die eigene Domain anpassen, `QGIS_WORKER_COUNT` auf die Hardware abstimmen (siehe [Worker-Konfiguration](#worker-konfiguration)), dann ausführen. Danach mit `check_installation_26.04.sh` prüfen, allenfalls mit `--fix` nachkorrigieren.

Weiter muss nach der Installation "certbot --nginx -d <URL>" ausgeführt werden. Damit werden in der NGIX-Umgebung die Zertifikate generiert und installiert.

Falls man ein System auserhalb, z.B. eine Cloudlösung verwendet, empfehle ich putty und damit einen Tunnel zum Remote Desktop Server konfigurieren. Putty kann man via ein Script starten. Beispiel unter Windows 11 ein Batchfile erstellen mit der Erweiterung *.bat :

cd "C:\Program Files\PuTTY\"
start putty.exe -load "<usernam>@<ip adresse des server>" <username>@<ip adresse des server> -P 22 -pw <passwort> -L localhost:3386:<ip adresse des server>:3389

Bei localhost (localhost:3386) muss man einen anderen Port verwenden, damit man nicht in Konflikt mit dem lokalen RDP-Server kommt! 

Vollautomatische Installation und Diagnose eines **Lizmap Web Client + py-qgis-server**-Stacks auf **Ubuntu 26.04 LTS** (u. a. arm64/Apple-Silicon-VMs).

## Ubuntu 24.04 Version (`ubuntu-24.04/`)

Für **Ubuntu 24.04 LTS** liegt im Unterverzeichnis [`ubuntu-24.04/`](ubuntu-24.04/) die ursprüngliche,
weiterhin unterstützte Skript-Variante — siehe [`ubuntu-24.04/README.md`](ubuntu-24.04/README.md).
Neue Features (z.B. der convmv-Timer gegen Umlaut-Probleme) werden in beiden Varianten gepflegt,
der Fokus der aktiven Weiterentwicklung liegt aber auf der hier beschriebenen 26.04-Version.

## Skripte (`ubuntu-26.04/`)

| Skript | Zweck |
|---|---|
| `install_lizmap_qgisserver_26.04.sh` | Basis-Skript, `QGIS_WORKER_COUNT` manuell setzen |
| `install_lizmap_qgisserver_2cpu_26.04.sh` | Für kleine VMs (2 vCPU / 4-8 GB RAM) |
| `install_lizmap_qgisserver_8cpu_26.04.sh` | Voreingestellt für 8 CPU-Kerne (4 Worker) |
| `install_lizmap_qgisserver_16cpu_26.04.sh` | Voreingestellt für 16 CPU-Kerne (8 Worker) |
| `install_lizmap_qgisserver_no_desktop_26.04.sh` | Für kleine VMs (2 vCPU/4-8 GB), optimiert auf minimalen RAM-Verbrauch — `INSTALL_XRDP`/`INSTALL_QGIS_DESKTOP` weiterhin standardmässig `true`, aber `xrdp`+`XFCE4` statt einer vollen Desktop-Umgebung |
| `check_installation_26.04.sh` | Diagnose + optionale Fehlerkorrektur (`--fix`) |
| `backup_lizmap_system_26.04.sh` | Backup aller Konfigurationen und Daten |

Andere Hardware → [Worker Rechner](worker_rechner.html) öffnen, Werte berechnen lassen, dann `QGIS_WORKER_COUNT` im Skript-Header anpassen.

> **Hinweis:** Sektion 10 (xRDP + XFCE4) lädt viele Pakete — Dauer je nach Verbindung 5–15 Minuten. Der Fortschritt wird angezeigt.

### Warum xRDP statt GNOME Remote Desktop?

Ein zwischenzeitlicher Versuch, **GNOME Remote Desktop** (`gnome-remote-desktop` / `grdctl`) zu
verwenden — um kein zusätzliches Desktop-Environment installieren zu müssen, da Ubuntu 26.04
Desktop-Installationen bereits GNOME mitbringen — wurde wieder verworfen:

- Ubuntu 26.04 hat die **"GNOME on Xorg"-Session entfernt**, GNOME läuft nur noch unter Wayland.
- GNOME Remote Desktop im `--system`-Modus (headless, ohne vorherigen physischen Login) liefert
  ohne **tatsächlich angeschlossenen Monitor kein Bild** (schwarzer Bildschirm) — für einen
  Server ohne Monitor damit unbrauchbar.
- Zusätzlich verwendete es eine **Zwei-Stufen-Anmeldung** (ein reines `grdctl`-"Türsteher"-
  Credential-Paar für die erste RDP-Verbindung, danach ein echter Linux-Login für die
  eigentliche Session) und war anfällig für einen bekannten FreeRDP-NTLM-MIC-Bug.

xRDP baut pro Verbindung eine eigene virtuelle X11-Session auf (`xorgxrdp`) und ist dadurch
unabhängig vom lokalen Display/Monitor und vom lokalen Wayland/GNOME-Login — funktioniert headless
zuverlässig, ist einstufig (ein normaler Linux-Login), und ist zusätzlich leichter als eine volle
GNOME-Session. Die xRDP-eigene Falle mit fehlender `~/.xsession` ist unter
[CLAUDE.md: xRDP – weitere Benutzer anlegen](CLAUDE.md#xrdp-weitere-benutzer-anlegen) dokumentiert.

## Was wird installiert

| Komponente | Details |
|---|---|
| QGIS Server LTR | via offiziellem QGIS apt-Repository |
| QGIS Desktop LTR | optional (`INSTALL_QGIS_DESKTOP`), für Projektbearbeitung via RDP |
| py-qgis-server | 3liz Python WSGI-Wrapper für QGIS Server |
| Lizmap Web Client | 3.9.x |
| Nginx + PHP 8.5-FPM | Webserver |
| PostgreSQL + PostGIS | optional |
| pgAdmin4 Desktop | optional, nutzbar über die xrdp/XFCE-Session (auf arm64 nicht verfügbar) |
| xRDP + XFCE4 | Remote Desktop auf Port 3389, optional |
| Xvfb | virtuelles Display `:99` für QGIS/Qt-Rendering |
| certbot + python3-certbot-nginx | HTTPS via Let's Encrypt |
| UFW + Fail2ban | Firewall + Brute-Force-Schutz, optional (siehe [UFW-Anhang](#anhang-ufw-firewall-verwalten)) |

**QGIS Server Plugins** (via qgis-plugin-manager): `lizmap_server`, `atlasprint`, `wfsOutputExtension`

> **ARM/Apple Silicon:** Getestet via VMware Fusion auf Apple M4. QGIS Desktop LTR und pgAdmin4
> Desktop stehen auf arm64 nicht zur Verfügung (Hersteller-Repos bauen nur amd64) — QGIS Server
> selbst, PHP, PostgreSQL, Nginx und py-qgis-server laufen auf arm64 nativ.

## Schnellstart

```bash
# Als root auf Ubuntu 26.04 LTS:
git clone https://github.com/tgdbepe4/py-qgisserver-installation-with-bash-shell-script
cd py-qgisserver-installation-with-bash-shell-script/ubuntu-26.04

# Variablen im Skript-Header anpassen (SERVER_NAME, QGIS_WORKER_COUNT, …):
# CERTBOT_EMAIL NICHT hier eintragen — siehe Abschnitt "Konfiguration" unten (Umgebungsvariable).
nano install_lizmap_qgisserver_8cpu_26.04.sh    # für 8 CPU-Kerne
# oder
nano install_lizmap_qgisserver_16cpu_26.04.sh   # für 16 CPU-Kerne
# oder
nano install_lizmap_qgisserver_26.04.sh         # Basis-Skript, QGIS_WORKER_COUNT manuell setzen

sudo bash install_lizmap_qgisserver_8cpu_26.04.sh
```

## Konfiguration

Die wichtigsten Variablen befinden sich im Skript-Header:

```bash
SERVER_NAME="localhost karte1.example.com"  # Domain / IP des Servers
QGIS_WORKER_COUNT=6                          # Worker-Prozesse (≈ CPU-Kerne ÷ 2)
INSTALL_POSTGRESQL=true                      # PostgreSQL + PostGIS
INSTALL_XRDP=true                            # Remote Desktop (xrdp + XFCE4)
INSTALL_QGIS_DESKTOP=true                    # QGIS-Desktop-GUI-Paket (qgis + qgis-plugin-grass)
INSTALL_SECURITY=true                        # UFW + Fail2ban
CERTBOT_EMAIL="${CERTBOT_EMAIL:-}"           # E-Mail → HTTPS automatisch aktivieren
```

**Worker-Anzahl:** `QGIS_WORKER_COUNT` im Skript-Header setzen — das Skript schreibt diesen Wert in `/srv/qgis/server.conf`. Das ist die einzige Stelle, an der die Worker-Anzahl konfiguriert wird (kein `-w` Flag im Supervisor). Siehe [anleitung_worker.md](anleitung_worker.md) und [worker_rechner.html](worker_rechner.html).

**HTTPS/Let's Encrypt:** `CERTBOT_EMAIL` liest standardmäßig eine Umgebungsvariable — nicht im Skript editieren, sondern beim Aufruf mitgeben, damit die E-Mail-Adresse nicht im Repo landet:

```bash
export CERTBOT_EMAIL=du@example.com
sudo -E bash install_lizmap_qgisserver_8cpu_26.04.sh
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
sudo bash check_installation_26.04.sh          # Vollständige Prüfung
sudo bash check_installation_26.04.sh --fix    # Prüfung + automatische Korrekturen
```

Was geprüft wird: Systemdienste, py-qgisserver Status, `server.conf`, Nginx-Konfiguration, Lizmap API, PHP-Extensions, QGIS-Plugins, Verzeichnisse & Berechtigungen, PostgreSQL + PostGIS, Xvfb-Display.

> **Hinweis:** `--fix` behebt einfache Konfigurations- und Berechtigungsfehler.
> Bei komplexeren Problemen (fehlende Pakete, defekte venv, etc.) ist das erneute Ausführen
> des Installationsskripts zuverlässiger — es ist **idempotent** und kann sicher wiederholt werden:
> ```bash
> sudo bash install_lizmap_qgisserver_26.04.sh
> ```

## Backup

```bash
sudo bash backup_lizmap_system_26.04.sh
```

Erstellt `/root/lizmap_backup_DATUM.tar.gz` mit:

| Inhalt | Pfad |
|---|---|
| QGIS Server Konfiguration | `/srv/qgis/` (ohne Cache) |
| QGIS Projekte | `/srv/data/` |
| Lizmap Konfiguration | `/var/www/lizmap/lizmap/var/config/` |
| Nginx Konfiguration | `/etc/nginx/sites-*`, `nginx.conf`, `lizmap-common.conf`, `ssl/` |
| Supervisor Konfiguration | `/etc/supervisor/conf.d/` |
| PHP Konfiguration | `/etc/php/8.5/fpm/` |
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
# Aus dem ubuntu-26.04/-Verzeichnis ausführen (dort liegt backup_lizmap_system_26.04.sh) —
# nicht /var/www/lizmap!
sudo bash backup_lizmap_system_26.04.sh

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
systemctl reload php8.5-fpm nginx
sudo bash check_installation_26.04.sh
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
rm /root/lizmap_backup_*.tar.gz   # das backup_lizmap_system_26.04.sh-Archiv aus Schritt 1
```

Anschliessend `LIZMAP_VERSION` im Skript-Header aller `_26.04.sh`-Varianten auf die neue Version
anpassen, damit künftige Neuinstallationen die aktualisierte Version verwenden.

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
QGIS_VER=$(dpkg-query -W -f='${Version}\n' qgis-server | grep -oP '\d+\.\d+' | head -1)
echo "https://plugins.qgis.org/plugins/plugins.xml?qgis=${QGIS_VER}" > /srv/qgis/plugins/sources.list

qgis-plugin-manager update
qgis-plugin-manager upgrade

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

## Worker-Konfiguration

Siehe [anleitung_worker.md](anleitung_worker.md) für eine vollständige Erklärung der Worker-Parameter und wie sie sich auf RAM und CPU auswirken.

Der interaktive [Worker Rechner](worker_rechner.html) berechnet `QGIS_WORKER_COUNT`, `QGSRV_CACHE_SIZE` und `memory_high_water_mark` basierend auf CPU-Kernen, RAM und erwarteter Nutzerzahl.

Wieso geben die zwei rechner html programme eine unterschiedliche anzahl worker aus?

Die beiden Rechner verwenden **unterschiedliche Formeln und unterschiedliche Standardwerte**. Hier die konkreten Unterschiede:

## Standardwerte (Slider-Defaults)

| | `worker_rechner.html` | `Vereinfachter Worker-Rechner.html` |
|---|---|---|
| CPU | 8 | **16** |
| RAM | 16 GB | **32 GB** |

## Formeln — völlig verschieden

**`worker_rechner.html`** — konservativ, CPU/2:
```
workersByCpu  = max(2, floor(cpu / 2))          → bei 8 CPU: 4
workersByRam  = floor((ram * 0.60 * 1024) / projMB)  → 60% RAM, 500 MB/Worker
workersByUser = max(2, min(users, floor(cpu * 0.75)))
workers       = min(alle drei)
```

**`Vereinfachter Worker-Rechner.html`** — aggressiver, cpu - 3:
```
maxByCpu = max(1, cpu - 3)                      → bei 8 CPU: 5, bei 16 CPU: 13
reserved = OS(2) + Lizmap(1) + PG(2) = 5 GB
maxByRam = floor((ram - reserved) / 1.5)         → 1.5 GB/Worker fest
workers  = min(maxByCpu, maxByRam)
```

## Ergebnis bei gleichen Eingaben (8 CPU / 16 GB / PG aktiv)

| Rechner | Workers |
|---|---|
| `worker_rechner.html` | **4** (cpu/2 = 4) |
| `Vereinfachter` | **7** (cpu−3=5 vs (16−5)/1.5=7 → min=5) |

**Hauptursachen der Divergenz:**
1. `worker_rechner.html` teilt CPU durch 2 — der vereinfachte zieht nur 3 ab (viel grosszügiger)
2. RAM-Modell unterschiedlich: 60 % für QGIS vs. feste Abzüge pro Dienst, andere MB-pro-Worker-Annahme (500 MB vs. 1500 MB)
3. `worker_rechner.html` berücksichtigt zusätzlich die Nutzerzahl, der vereinfachte nicht

Welche Formel ist "richtiger"? Das hängt von der Projektkomplexität ab. Der vereinfachte Rechner ist für leichte Projekte realistischer; `worker_rechner.html` ist konservativer und schützt besser vor RAM-Engpässen bei schweren QGIS-Projekten.

## Bekannte Probleme und Lösungen

### Langsame Anfragen / Timeouts (bourbon.3liz.com)

py-qgis-server sendet bei jeder Karten-Anfrage Telemetrie-Daten an `bourbon.3liz.com`. Wenn der Server keinen stabilen Internetzugang hat, führt dies zu Timeouts von **6–16 Sekunden pro Anfrage** (3× Retry).

**Symptome:** Karten laden sehr langsam, Nginx-Logs zeigen Lücken zwischen Anfragen.

**Fix (bereits im Installationsskript enthalten):**

```bash
echo "0.0.0.0 bourbon.3liz.com" >> /etc/hosts
supervisorctl restart py-qgisserver
```

Das Installationsskript führt diesen Fix automatisch aus.

### Preload-Strategie (RAM-Engpass)

Jedes preloaded QGIS-Projekt belegt ca. 500 MB – 2 GB RAM. Bei vielen Projekten im Preload kann der RAM erschöpft sein, **bevor** die ersten Anfragen ankommen.

**Faustregel:** Maximal 2–3 Projekte pro Worker im Preload. Alle anderen Projekte werden beim ersten Zugriff geladen (~40 Sekunden auf schwacher Hardware).

**Preload konfigurieren** (`/srv/qgis/config/preload_projects.txt`):
```bash
# Nur das wichtigste Projekt preloaden:
/srv/data/hauptkarte.qgs
```

### Hardware-Empfehlungen

QGIS Server ist CPU-intensiv. Zu schwache Hardware führt zu langen Ladezeiten und hoher CPU-Last.

| Hardware | Eignung | Anmerkung |
|---|---|---|
| Intel Atom C2538 (2013) | Ungeeignet | ~550 Passmark, QGIS-Start >40s, dauerhaft hohe CPU-Last |
| Intel N100 (2023) | Minimale Basis | ~3000 Passmark, für 1–2 gleichzeitige Nutzer |
| AMD Ryzen 7 5800X | Gut | ~3800 Passmark/Kern, kurze Ladezeiten, mehrere Nutzer |
| 16+ Kerne Server-CPU | Optimal | Für Produktionsbetrieb mit vielen Nutzern |

**Mindestanforderung:** 4 CPU-Kerne mit >2000 Passmark pro Kern, 16 GB RAM.

> **Tipp:** Passmark-Werte für eigene Hardware: [cpubenchmark.net](https://www.cpubenchmark.net/)

## Anhang: Umlaute im Dateinamen (NFD/NFC) nach Mac-Synchronisation

**Symptom:** Nach dem Synchronisieren von Medien-/Upload-Verzeichnissen zwischen zwei
Ubuntu-Systemen über einen Mac als Zwischenstation (z.B. via ForkLift: Ubuntu → Mac → Ubuntu)
liefert der Lizmap `getMedia`-Endpunkt für Dateien, deren Name Umlaute oder andere
Sonderzeichen enthält (z.B. `Hauptstrasse 26 Bözen 1923 Haus mit Treppe 2.jpg`), einen 404,
obwohl die Datei nachweislich am erwarteten Pfad liegt und die Dateiberechtigungen korrekt
sind. Dateien ohne Sonderzeichen im Namen sind vom Problem nicht betroffen.

**Ursache:** macOS normalisiert Dateinamen mit Sonderzeichen beim Anlegen/Kopieren über
Finder-/Cocoa-Dateisystem-APIs standardmässig nach Unicode **NFD** (zerlegte Form: `o` +
separates Kombinationszeichen für den Trema, statt einem einzelnen `ö`-Zeichen). Das betrifft
praktisch jede App auf dem Mac, die Dateien schreibt oder umbenennt — auch ForkLift. Eine
spezifische Einstellung in ForkLift, um das zu unterbinden, existiert nach aktuellem
Kenntnisstand nicht.

Linux/PHP (und damit Lizmaps `getMedia`-Route) erwartet dagegen **NFC** (vorkomponierte
Form). Der Dateiname, der aus der URL dekodiert wird, ist byte-technisch nicht identisch mit
dem NFD-Dateinamen auf der Platte — die Datei wird trotz identischer optischer Darstellung
nicht gefunden. Sobald eine Datei mit Sonderzeichen im Namen also den Umweg über den Mac
nimmt, kann sie im NFD-Format auf dem Ziel-Ubuntu-System landen und ist dort für Lizmap
unsichtbar.

**Diagnose:** Im betroffenen Verzeichnis (z.B. `.../media/upload/<projekt>/<layer>/`)
prüfen, welche Dateien NFD statt NFC sind:

```bash
cd /pfad/zum/media/upload/verzeichnis/
python3 -c "
import unicodedata, os
for f in os.listdir('.'):
    print(f, '-> NFC' if unicodedata.is_normalized('NFC', f) else '-> NFD/andere Form')
"
```

Alle Zeilen mit `NFD/andere Form` sind potenziell betroffen (nur relevant bei Dateinamen mit
Sonderzeichen). Zusätzlich prüfenswert (in dieser Reihenfolge, um andere Ursachen
auszuschliessen): Dateiberechtigungen entlang des ganzen Pfads (`namei -l /pfad/zur/datei`),
sowie ob der Browser evtl. nur einen veralteten Cache anzeigt (Test per
`curl -o /dev/null -w "%{http_code}\n" "<getMedia-URL>"`, umgeht den Browser-Cache).

**Fix (einmalig, für bereits betroffene Dateien):**

```bash
sudo apt install -y convmv
convmv -f utf8 -t utf8 --nfc -r --notest /srv/data/
```

(`/srv/data/` durch das jeweilige Basisverzeichnis der Repositories ersetzen; `-r` =
rekursiv, `--notest` = tatsächlich ausführen statt nur Vorschau)

**Prävention (dauerhaft, systemd-Timer):** Automatisiert alle 15 Minuten die Normalisierung
neu ankommender Dateien, unabhängig vom Übertragungsweg (ForkLift, Lizmap-Upload,
QFieldCloud, etc.).

Skript `/usr/local/bin/convmv-nfc-watch.sh`:
```bash
#!/bin/bash
set -euo pipefail

# Verzeichnisse, die regelmässig auf NFC normalisiert werden sollen
TARGETS=(
    "/srv/data"
)

for dir in "${TARGETS[@]}"; do
    if [ -d "$dir" ]; then
        echo "Normalisiere Dateinamen (NFD->NFC) unter $dir ..."
        convmv -f utf8 -t utf8 --nfc -r --notest "$dir"
    else
        echo "WARNUNG: $dir existiert nicht, übersprungen."
    fi
done
```

Service-Unit `/etc/systemd/system/convmv-nfc.service`:
```ini
[Unit]
Description=Normalisiert Dateinamen (NFD->NFC) unter /srv/data

[Service]
Type=oneshot
ExecStart=/usr/local/bin/convmv-nfc-watch.sh
```

Timer-Unit `/etc/systemd/system/convmv-nfc.timer`:
```ini
[Unit]
Description=Regelmässige NFD->NFC-Normalisierung für /srv/data

[Timer]
OnBootSec=5min
OnUnitActiveSec=15min
Persistent=true

[Install]
WantedBy=timers.target
```

Installation:
```bash
sudo chmod +x /usr/local/bin/convmv-nfc-watch.sh
sudo systemctl daemon-reload
sudo systemctl enable --now convmv-nfc.timer
```

Kontrolle:
```bash
journalctl -u convmv-nfc.service -n 30 --no-pager
systemctl list-timers convmv-nfc.timer
```

**Automatisch bei der Installation:** Der obige Timer (Skript + Service + Timer) wird vom
Installationsskript optional mit eingerichtet — `INSTALL_CONVMV_TIMER=true` im Skript-Header
setzen, falls der Server Medien-Uploads über einen Mac-Zwischenschritt erhält (Standard:
`false`, siehe [Konfiguration](CLAUDE.md#anpassbare-variablen-skript-header)).

Langfristig/alternativ: Wo möglich den Mac-Umweg beim Sync vermeiden und stattdessen direkt
zwischen den Ubuntu-Systemen syncen (z.B. `rsync -av -e ssh`) — dabei tritt das Problem gar
nicht erst auf, da kein macOS-System beteiligt ist, das normalisieren könnte.

## Anhang: UFW Firewall verwalten

Installation, Grundregeln und ein sicherer Weg zur Aktivierung — ohne sich per SSH auszusperren.
`INSTALL_SECURITY=true` richtet UFW bereits mit sinnvollen Grundregeln ein (SSH, HTTP/HTTPS, RDP-Port);
dieser Anhang ist für alle, die die Firewall darüber hinaus manuell anpassen wollen (z.B. einen
Datenbank-Port nur für eine bestimmte Client-IP öffnen).

### Funktionsprinzip

UFW (Uncomplicated Firewall) ist kein eigener Paketfilter, sondern eine vereinfachte Kommandozeile
vor dem Linux-Kernel-Paketfilter (iptables/nftables). Statt Chains und Tables von Hand zu verwalten,
schreibt man Regeln wie `allow 22/tcp` — UFW übersetzt das dahinter in die passenden Kernel-Regeln.

Das Grundprinzip ist immer **Default Deny, explizit erlauben**: eingehender Verkehr wird
standardmässig verworfen, und nur was durch eine passende ALLOW-Regel abgedeckt ist, kommt durch.

Jedes eingehende Paket durchläuft die Regelliste der Reihe nach — die erste passende Regel
entscheidet. Ohne Treffer greift die Default-Policy (DENY): das Paket wird verworfen, ohne Antwort
oder Reset.

### 1. Installation

Auf aktuellen Ubuntu-Server-Images ist UFW meist schon vorinstalliert, aber (noch) nicht aktiv.
Prüfen und ggf. nachinstallieren:

```bash
# Version / Vorhandensein prüfen
sudo ufw version
# falls nicht vorhanden
sudo apt update
sudo apt install ufw -y
```

### 2. Grundregeln festlegen

Bevor irgendetwas erlaubt wird, die Default-Policies setzen — eingehend zu, ausgehend offen:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

Diese Befehle ändern nur die Konfiguration, nicht den laufenden Zustand — UFW ist an dieser
Stelle noch nicht aktiv (siehe [Aktivieren](#5-aktivieren)).

### 3. Regeln setzen

Regeln lassen sich nach Port, Protokoll, Quelle oder einer Kombination davon definieren. Ein
Kommentar (`comment`) hilft, sich Monate später noch zu erinnern, wofür eine Regel gedacht war.

**Nach Port/Protokoll — für alle:**
```bash
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
```

**Nach Quell-IP — nur für einen bestimmten Client:**
```bash
sudo ufw allow from 203.0.113.10 to any port 5432 proto tcp comment 'Postgres-Client Büro'
```
Diese Regel öffnet ausschliesslich `203.0.113.10` den Zugriff auf Port 5432 — alle anderen
Quellen bleiben durch die Default-Policy blockiert.

**Ganzes Subnetz statt Einzel-IP:**
```bash
sudo ufw allow from 203.0.113.0/24 to any port 5432 proto tcp
```

> **Tipp:** Bei dynamischer IP-Vergabe (z. B. Heimanschluss ohne feste IP) lieber grosszügiger
> fassen (Subnetz statt Einzel-IP) oder den Dienst stattdessen nur per SSH-Tunnel erreichbar
> machen — sonst muss die Regel bei jedem IP-Wechsel des Providers nachgezogen werden.

So sieht ein typisches Regel-Set danach aus (Ausgabe von `ufw status verbose`):

| Aktion | Port | Quelle | Kommentar |
|---|---|---|---|
| ALLOW | 22/tcp | von überall | SSH |
| ALLOW | 80/tcp | von überall | HTTP |
| ALLOW | 443/tcp | von überall | HTTPS |
| ALLOW | 5432/tcp | nur von 203.0.113.10 | — |
| DENY | alles andere | — | Default-Policy |

Regeln vorbereiten, ohne sie sofort zu aktivieren:
```bash
sudo ufw show added
```
Zeigt alle bisher hinzugefügten Regeln, ohne dass UFW selbst schon läuft — praktisch, um die
komplette Liste einmal gegenzuprüfen, bevor man aktiviert.

### 4. IPv6

UFW verwaltet IPv6 automatisch mit, solange `IPV6=yes` in `/etc/default/ufw` steht (Standard auf
Ubuntu). Jede Portregel wird dann zusätzlich als `(v6)`-Variante angelegt — sichtbar in
`ufw status verbose`. Eine IP-spezifische Regel wie `allow from 203.0.113.10` gilt dagegen nur
für die genannte Adressfamilie.

### 5. Aktivieren

> **Achtung:** Auf einem Remote-Server ist das der Schritt, bei dem man sich versehentlich
> aussperren kann — wenn die SSH-Regel fehlt oder falsch ist, ist die Verbindung sofort weg und
> es gibt keine zweite Chance über dieselbe Session.

```bash
sudo ufw enable
sudo ufw status verbose
```

Direkt danach, **ohne die aktuelle Session zu schliessen**: in einem zweiten, separaten Terminal
eine neue SSH-Verbindung aufbauen. Klappt sie, ist bestätigt, dass die Regeln passen. Klappt sie
nicht, bleibt die erste Session offen — dort sofort `sudo ufw disable` zum Zurückrollen, dann die
Regeln korrigieren.

Bei einem Server ohne Netzwerkzugriff als Rückfallebene (z. B. Serial-/Rescue-Console des
Hosting-Anbieters) lohnt es sich, vorher kurz zu prüfen, dass dieser Zugang funktioniert — als
zusätzliches Sicherheitsnetz, falls doch beide SSH-Wege blockiert sind.

### 6. Verwaltung im laufenden Betrieb

```bash
# Regeln mit Nummern anzeigen (für gezieltes Löschen)
sudo ufw status numbered
# Regel Nr. 3 löschen
sudo ufw delete 3
# Regel per Definition statt Nummer löschen
sudo ufw delete allow 8080/tcp
# UFW deaktivieren (Regeln bleiben gespeichert)
sudo ufw disable
# komplett zurücksetzen (alle Regeln löschen)
sudo ufw reset
```

Einmal aktiviert, überstehen die Regeln auch einen Neustart — UFW baut sie beim Boot über einen
eigenen systemd-Dienst automatisch wieder auf.

### 7. Ergänzung: fail2ban gegen Brute-Force

UFW entscheidet nur ob ein Port erreichbar ist — nicht, wie oft jemand von derselben IP
erfolglos versucht, sich anzumelden. Dafür ergänzt fail2ban die Firewall sinnvoll: es liest
Log-Dateien (z. B. `sshd`) und sperrt IPs nach zu vielen Fehlversuchen automatisch — indem es
selbst eine passende UFW/iptables-Regel einfügt.

```bash
sudo apt install fail2ban -y
```

`/etc/fail2ban/jail.local`:
```ini
[sshd]
enabled = true
maxretry = 5
findtime = 10m
bantime = 1h
```

```bash
sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd
```

### Cheat-Sheet

Die Befehle, die im Alltag am häufigsten gebraucht werden.

| Zweck | Befehl |
|---|---|
| Status ansehen | `sudo ufw status verbose` |
| Status mit Regelnummern | `sudo ufw status numbered` |
| Port für alle öffnen | `sudo ufw allow 443/tcp` |
| Port nur für eine IP öffnen | `sudo ufw allow from <ip> to any port <port> proto tcp` |
| Regel entfernen | `sudo ufw delete <nummer>` |
| Aktivieren | `sudo ufw enable` |
| Deaktivieren (Notausstieg) | `sudo ufw disable` |
| Vorbereitete Regeln ansehen | `sudo ufw show added` |
| Alles zurücksetzen | `sudo ufw reset` |

### Häufige Fallstricke

- **SSH-Regel vor dem Aktivieren vergessen.** `ufw enable`, bevor Port 22 erlaubt ist, kappt die
  eigene Verbindung sofort.
- **Zwei Firewalls gleichzeitig aktiv.** Läuft parallel noch eine andere Lösung (z. B. CSF), die
  ebenfalls iptables direkt verwaltet, können sich beide Regelsätze überschreiben oder
  gegenseitig aushebeln. Die alte Lösung sauber deaktivieren, bevor UFW dauerhaft übernimmt.
- **Regeln, die „offen für alle" statt „offen für bekannte Quellen" sind.** Besonders bei
  Datenbank-, RDP- oder SMB-Ports lohnt sich fast immer die Einschränkung auf bestimmte IPs statt
  eines pauschalen `allow <port>`.
- **Reihenfolge bei sich widersprechenden Regeln.** UFW wertet in der Reihenfolge aus, in der
  Regeln existieren — eine weiter gefasste Regel kann eine speziellere, später hinzugefügte,
  wirkungslos machen. Im Zweifel mit `ufw status numbered` die tatsächliche Reihenfolge prüfen.

## Anhang: Ubuntu-Server 1:1 klonen mit Clonezilla

Anleitung: physischen Ubuntu-Server (z. B. HP ProDesk 600 G3 DM, GIS-/Lizmap-Server) auf einen
zweiten, baugleichen PC mit grösserer Festplatte klonen. Stand: 7. September 2026.

### 1. Zweck und Voraussetzungen

Diese Anleitung beschreibt, wie ein bestehender Ubuntu-Server 1:1 auf einen zweiten PC geklont
wird — inklusive Betriebssystem, allen Konfigurationen, xrdp/XFCE-Desktop, PostgreSQL-Datenbank
usw. Der Ziel-PC braucht dafür kein vorinstalliertes Betriebssystem.

**Voraussetzungen:**
- Ein leerer USB-Stick (mind. 1 GB) für den Clonezilla-Live-Boot-Stick.
- Quell- und Ziel-PC im selben LAN (für den Netzwerk-Klon in Kapitel 5).
- Physischer Zugriff auf beide PCs, um vom Stick zu booten (Tastatur/Bildschirm oder Fernzugriff
  über eine Management-Konsole).
- Zielplatte gleich gross oder grösser als die Quellplatte. Ist sie grösser, wird der
  zusätzliche Platz erst nach dem Klonen nutzbar gemacht (Kapitel 6).

### 2. Clonezilla-Live-USB-Stick erstellen

**2.1 ISO herunterladen**

Von clonezilla.org die Version „Clonezilla live (Stable)" herunterladen, Plattform amd64,
Dateityp iso.

**2.2 Stick schreiben unter macOS**

Grafisch mit balenaEtcher (kostenlos, etcher.balena.io): App öffnen, das ISO auswählen, den
USB-Stick als Ziel wählen, „Flash!" klicken.

Alternativ im Terminal:
```bash
diskutil list                                    # richtigen Stick identifizieren
diskutil unmountDisk /dev/diskN
sudo dd if=clonezilla-live-*-amd64.iso of=/dev/rdiskN bs=4m status=progress
diskutil eject /dev/diskN
```
> Unbedingt `/dev/rdiskN` (mit „r" für raw) verwenden und die Disk-Nummer vorher mit
> `diskutil list` prüfen — der Befehl löscht den kompletten Inhalt des gewählten Sticks.

**2.3 Stick schreiben unter Windows**

Mit Rufus (kostenlos, rufus.ie): Gerät = USB-Stick, Startart = Auswahl → heruntergeladenes ISO
angeben → Start.

Fragt Rufus nach ISO-Image-Modus oder DD-Image-Modus: zuerst ISO-Image-Modus probieren
(Standard). Bootet der Stick damit nicht, den Stick mit DD-Image-Modus neu schreiben.

### 3. PC vom Stick booten

- USB-Stick einstecken, PC einschalten.
- Boot-Menü aufrufen (bei HP-Geräten meist F9, manchmal Esc oder F10).
- Den USB-Stick als Boot-Gerät wählen.

Das Live-System startet unabhängig davon, was auf der internen Platte liegt — bei einem leeren
Ziel-PC ist das kein Problem.

> Boot-Modus (UEFI vs. Legacy/CSM) sollte auf beiden PCs gleich eingestellt sein, sonst findet
> der Ziel-PC den geklonten Bootloader später eventuell nicht. Bei zwei ähnlichen
> HP-ProDesk-Geräten ist das im Werkszustand praktisch immer beidseitig UEFI.

### 4. Klon-Methoden im Überblick

Drei grundsätzliche Wege, die beiden Platten zu verbinden:

1. **Über ein Zwischen-Image:** erst am Quell-PC sichern („device-image") auf eine externe
   Platte oder einen Netzwerk-Share, dann am Ziel-PC zurückspielen („image-device"). Mehr
   Schritte, dafür liegt danach auch gleich ein Backup vor.
2. **Beide Platten an einem PC:** Zielplatte zusätzlich einbauen oder per USB-SATA-Adapter
   anschliessen, dann „device-device" direkt in einem Rutsch, ohne Zwischenspeicher.
3. **Beide PCs gleichzeitig übers Netzwerk:** direkter Klon zwischen den beiden laufenden
   Live-Systemen, kein Kabel/Adapter nötig. Siehe Kapitel 5 — dieser Weg wird hier im Detail
   beschrieben.

### 5. Direkter Netzwerk-Klon (PC-zu-PC, ohne Zwischenspeicher)

Clonezillas geführte Oberfläche bietet keinen sauberen Menüpunkt für einen reinen
Netzwerk-Klon ohne Zwischen-Image. Die Netzwerkfunktionen (SSH-/Samba-/NFS-Ziel, „Lite Server")
laufen immer über ein Image. Ein echter direkter Klon zwischen zwei Maschinen läuft daher über
die Shell, die im Live-System bereits mit `dd`, `ssh` und Netzwerk-Tools bereitsteht.

**5.1 In die Shell wechseln**

Im Clonezilla-Startmenü nicht „Start_Clonezilla" wählen, sondern „Enter_shell". Das auf beiden
PCs durchführen.

**5.2 Netzwerk auf dem Ziel-PC einrichten**

Interface-Namen und Status prüfen:
```bash
ip link
```
Zeigt `state DOWN` oder `NO-CARRIER` → Kabel/Switch-Port prüfen, dann Interface aktivieren
(Namen aus obigem Befehl einsetzen):
```bash
sudo ip link set <interface> up
```
Per DHCP eine Adresse anfordern:
```bash
sudo dhclient -v <interface>
ip a
```
Kommt auch über `dhclient` keine Adresse (z. B. weil DHCP auf diesem Port/VLAN eingeschränkt
ist), die IP manuell passend zum Ziel-LAN setzen:
```bash
sudo ip addr add <FREIE-IP>/24 dev <interface>
sudo ip route add default via <GATEWAY-IP>
```

**5.3 SSH-Zugriff auf dem Ziel-PC vorbereiten**
```bash
sudo passwd              # Root-Passwort setzen, für SSH-Login nötig
sudo service ssh start   # falls SSH-Dienst noch nicht läuft
ip a                     # IP-Adresse notieren
```

**5.4 Platten identifizieren**

Auf beiden PCs die Disk-Bezeichnung prüfen — nicht blind übernehmen, da sie je nach Controller
variiert (z. B. `/dev/sda` vs. `/dev/nvme0n1`):
```bash
lsblk
```

**5.5 Klonen: direkter Disk-zu-Disk-Klon über SSH**

Auf dem Quell-PC ausführen (Platzhalter durch die tatsächlichen Werte aus 5.3/5.4 ersetzen):
```bash
sudo dd if=<QUELL-DISK> bs=4M status=progress \
  | ssh root@<ZIEL-IP> "dd of=<ZIEL-DISK> bs=4M"
```
Beispiel mit konkreten Werten:
```bash
sudo dd if=/dev/sda bs=4M status=progress \
  | ssh root@192.168.1.150 "dd of=/dev/sda bs=4M"
```
> Quelle und Ziel nicht verwechseln — der Befehl überschreibt die Zielplatte vollständig und
> ohne Rückfrage. `<QUELL-DISK>` ist immer die Platte des bestehenden Servers, `<ZIEL-DISK>`
> immer die leere Platte des neuen PCs.

Dauer je nach Netzwerktempo und Plattengrösse: bei Gigabit-LAN und einer SSD im hohen
zweistelligen GB-Bereich meist 20–60 Minuten.

**5.6 Alternative: Als komprimierte Image-Datei sichern (statt Direkt-Klon)**

Soll statt eines direkten Klons zunächst nur ein Abbild der Platte auf einen dritten Rechner
(z. B. das NAS) gesichert werden, lässt sich derselbe Mechanismus generalisiert auch dafür
nutzen — Quelle bleibt der Server, Ziel ist diesmal ein beliebiger Rechner mit genug
Speicherplatz und laufendem SSH-Server:
```bash
ssh root@<QUELL-IP> "dd if=<QUELL-DISK> bs=4M status=progress | gzip -1" \
  > <ZIEL-DATEINAME>_$(date +%Y%m%d).img.gz
```
Dieser Befehl läuft auf dem Rechner, der die Datei empfangen und speichern soll (z. B. dem Mac
oder der DS1517+), und zieht die Daten aktiv vom Server (`<QUELL-IP>`). `<ZIEL-DATEINAME>` frei
wählbar, z. B. der Hostname des Quell-Servers.

Rückspielen später auf eine (leere) Zielplatte:
```bash
gunzip -c <ZIEL-DATEINAME>_<DATUM>.img.gz \
  | ssh root@<ZIEL-IP> "dd of=<ZIEL-DISK> bs=4M"
```

### 6. Nach dem Klonen: Ziel-PC anpassen

Der Ziel-PC hat nun eine exakte Kopie des Quell-Systems — inklusive IP-Adresse, Hostname und
SSH-Identität. Damit beide Maschinen gleichzeitig im selben Netz laufen können, vor dem ersten
Produktivbetrieb anpassen:

**6.1 IP-Adresse ändern**

Netzwerk-Konfiguration prüfen und dem Klon eine neue, noch nicht vergebene feste IP zuweisen:
```bash
ip a
cat /etc/netplan/*.yaml
```

**6.2 Hostname ändern**
```bash
sudo hostnamectl set-hostname <neuer-name>
```

**6.3 SSH-Host-Keys neu erzeugen**

Der Klon hat identische SSH-Host-Keys wie das Original — das führt bei jedem, der beide Rechner
per SSH anspricht, zur Warnung „REMOTE HOST IDENTIFICATION HAS CHANGED":
```bash
sudo rm /etc/ssh/ssh_host_*
sudo ssh-keygen -A
```

**6.4 machine-id neu setzen**

Vermeidet u. a. Verwechslungen bei DHCP-Leases und in systemd-Journalen:
```bash
sudo rm /etc/machine-id
sudo systemd-machine-id-setup
```

**6.5 Partition und Dateisystem vergrössern (bei grösserer Zielplatte)**

Da `dd` nur die Partitionstabelle der Quellplatte 1:1 kopiert, bleibt zusätzlicher Speicherplatz
auf einer grösseren Zielplatte zunächst ungenutzt. Partitionsnummer vorher mit `lsblk` bzw.
`sudo fdisk -l` prüfen (bei GPT/UEFI meist Nummer 2 oder 3, nach EFI-Partition und ggf. Swap):
```bash
sudo growpart /dev/sda 2          # Root-Partition auf neuen Platz erweitern
sudo resize2fs /dev/sda2          # ext4-Dateisystem entsprechend mitwachsen lassen
```

### 7. Kurzreferenz

Alle Kernbefehle des direkten Netzwerk-Klons auf einen Blick:
```bash
# Auf dem Ziel-PC (Enter_shell):
sudo passwd
sudo service ssh start
ip a                                             # IP-Adresse notieren
lsblk                                            # Zieldisk notieren

# Auf dem Quell-PC (Enter_shell):
lsblk                                            # Quelldisk notieren
sudo dd if=<QUELL-DISK> bs=4M status=progress \
  | ssh root@<ZIEL-IP> "dd of=<ZIEL-DISK> bs=4M"

# Danach auf dem Ziel-PC:
sudo growpart /dev/sda 2 && sudo resize2fs /dev/sda2
sudo hostnamectl set-hostname <neuer-name>
sudo rm /etc/ssh/ssh_host_* && sudo ssh-keygen -A
sudo rm /etc/machine-id && sudo systemd-machine-id-setup
```

## Referenzen

- [Lizmap Dokumentation](https://docs.lizmap.com/)
- [py-qgis-server Dokumentation](https://docs.3liz.org/py-qgis-server/)
- [QGIS Server Dokumentation](https://docs.qgis.org/latest/en/docs/server_manual/)
