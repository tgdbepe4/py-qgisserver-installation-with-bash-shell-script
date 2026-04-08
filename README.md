# Lizmap Web Client + py-qgis-server — Installation Stack

Das Projekt hat es zum Ziel eine komplette Lizmap-Umgebung auf einem Ubuntu 24.04 mit dem py-qgisserver zu installieren. Ausserdem postgres, das Hilfswerkzeug qgis-plugin-manager und eine Xfce4 Desktop-Umgebung.

Diese Scripts wurden mit der KI claude.ai, der günstigsten Pro Version für kapp € 20.-, erstellt. Es brauchte unzählige Interaktionen bis alles sauber lief. Nun ist jedoch das Resultat überzeugend!

Im install_lizmap_qgisserver.sh muss man das URL anpassen von karte1.wandelderzeit.ch auf das gewünschte URL. 

### Anpassbare Variablen (Skript-Header)

| Variable | Standardwert | Beschreibung |
|---|---|---|
| `LIZMAP_VERSION` | `3.9.7` | Lizmap Web Client Version |
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
| `CERTBOT_EMAIL` | *(leer)* | E-Mail für Let's Encrypt — leer = HTTPS überspringen |
| `LOG_FILE` | `/var/log/install_lizmap_qgisserver.log` | Pfad zur Installationslogdatei |

Ausserdem sollte die Anzahl Worker dort angepasst werden.

QGIS_WORKER_COUNT=4          # Number of QGIS Server worker instances

Für ein keines System mit 8 GB Ram auf 2, mit 16 GB auf 4, usw.

Erst danach das Script mit "bash install_lizmap_qgisserver.sh" ausführen. Danach mit "bash check_installation.sh" prüfen ob alles OK ist. Allenfalls mit "bash check_installation.sh --fix" kann man noch nachkorrigieren.

Weiter muss nach der Installation "certbot --nginx -d <URL>" ausgeführt werden. Damit werden in der NGIX-Umgebung die Zertifikate generiert und installiert.

Falls man ein System auserhalb, z.B. eine Cloudlösung verwendet, empfehle ich putty und damit einen Tunnel zum Remote Desktop Server konfigurieren. Putty kann man via ein Script starten. Beispiel unter Windows 11 ein Batchfile erstellen mit der Erweiterung *.bat :

cd "C:\Program Files\PuTTY\"
start putty.exe -load "<usernam>@<ip adresse des server>" <username>@<ip adresse des server> -P 22 -pw <passwort> -L localhost:3386:<ip adresse des server>:3389

Bei localhost (localhost:3386) muss man einen anderen Port verwenden, damit man nicht in Konflikt mit dem lokalen RDP-Server kommt! 

Vollautomatische Installation und Diagnose eines **Lizmap Web Client + py-qgis-server**-Stacks auf **Ubuntu 24.04 LTS**.

## Skripte

| Skript | Zweck |
|---|---|
| `install_lizmap_qgisserver.sh` | Vollinstallation des gesamten Stacks |
| `check_installation.sh` | Diagnose + optionale Fehlerkorrektur (`--fix`) |
| `backup_lizmap_system.sh` | Backup aller Konfigurationen und Daten |

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
wget https://raw.githubusercontent.com/<user>/py-qgisserver/main/install_lizmap_qgisserver.sh
nano install_lizmap_qgisserver.sh   # Variablen oben im Skript anpassen
sudo bash install_lizmap_qgisserver.sh
```

## Konfiguration

Die wichtigsten Variablen befinden sich im Skript-Header:

```bash
SERVER_NAME="localhost karte1.example.com"  # Domain / IP des Servers
INSTALL_POSTGRESQL=true                      # PostgreSQL + PostGIS
INSTALL_XRDP=true                            # Remote Desktop
INSTALL_SECURITY=true                        # UFW + Fail2ban
CERTBOT_EMAIL=""                             # E-Mail → HTTPS automatisch aktivieren
```

Wenn `CERTBOT_EMAIL` gesetzt ist, läuft certbot vollautomatisch am Ende der Installation (inkl. IP-Redirect-Fix nach dem certbot-Eingriff in den Nginx-Vhost).

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

## Referenzen

- [Lizmap Dokumentation](https://docs.lizmap.com/)
- [py-qgis-server Dokumentation](https://docs.3liz.org/py-qgis-server/)
- [QGIS Server Dokumentation](https://docs.qgis.org/latest/en/docs/server_manual/)
