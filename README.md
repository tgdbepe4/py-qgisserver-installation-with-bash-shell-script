# Lizmap Web Client + py-qgis-server — Installation Stack

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

Andere Hardware → [Worker Rechner](worker_rechner.html) öffnen, Werte berechnen lassen, dann `QGIS_WORKER_COUNT` im Skript-Header anpassen.

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
cd py-qgisserver-installation-with-bash-shell-script

# Variablen im Skript-Header anpassen (SERVER_NAME, CERTBOT_EMAIL, QGIS_WORKER_COUNT, …):
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
CERTBOT_EMAIL=""                             # E-Mail → HTTPS automatisch aktivieren
```

**Worker-Anzahl:** `QGIS_WORKER_COUNT` im Skript-Header setzen — das Skript schreibt diesen Wert in `/srv/qgis/server.conf`. Das ist die einzige Stelle, an der die Worker-Anzahl konfiguriert wird (kein `-w` Flag im Supervisor). Siehe [anleitung_worker.md](anleitung_worker.md) und [worker_rechner.html](worker_rechner.html).

Wenn `CERTBOT_EMAIL` gesetzt ist, läuft certbot vollautomatisch am Ende der Installation.

## Nach der Installation

1. Lizmap unter `http://<SERVER-IP>/` öffnen → Login `admin / admin` → **Passwort sofort ändern**
2. Via RDP (`mstsc` / Remmina) auf `<SERVER-IP>:3389` verbinden
3. QGIS Desktop in der RDP-Session öffnen → `.qgs`/`.qgz` Projekte nach `/srv/data/` speichern
4. Im QGIS Desktop das **Lizmap QGIS Plugin** installieren und Veröffentlichungsoptionen pro Projekt konfigurieren

## Diagnose

```bash
sudo bash check_installation.sh          # Vollständige Prüfung
sudo bash check_installation.sh --fix    # Prüfung + automatische Korrekturen
```

Was geprüft wird: Systemdienste, py-qgisserver Status, `server.conf`, Nginx-Konfiguration, Lizmap API, PHP-Extensions, QGIS-Plugins, Verzeichnisse & Berechtigungen, PostgreSQL + PostGIS, Xvfb-Display.

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

## QGIS-Plugins aktualisieren (Bestehendes System)

```bash
QGIS_VER=$(dpkg -l qgis-server | awk '/^ii.*qgis-server /{print $3}' | grep -oP '\d+\.\d+' | head -1)
echo "https://plugins.qgis.org/plugins/plugins.xml?qgis=${QGIS_VER}" > /srv/qgis/plugins/sources.list

/opt/local/py-qgis-server/bin/pip install -q qgis-plugin-manager
/opt/local/py-qgis-server/bin/qgis-plugin-manager update
/opt/local/py-qgis-server/bin/qgis-plugin-manager upgrade

supervisorctl restart py-qgisserver
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

## Referenzen

- [Lizmap Dokumentation](https://docs.lizmap.com/)
- [py-qgis-server Dokumentation](https://docs.3liz.org/py-qgis-server/)
- [QGIS Server Dokumentation](https://docs.qgis.org/latest/en/docs/server_manual/)
