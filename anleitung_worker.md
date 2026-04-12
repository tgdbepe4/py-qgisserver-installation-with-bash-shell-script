# Worker-Konfiguration für py-qgis-server

## Überblick

py-qgis-server startet eine definierte Anzahl **Worker-Prozesse**, die QGIS-Anfragen parallel bearbeiten.

## Wo wird die Worker-Anzahl konfiguriert?

**Einzige massgebliche Stelle: `/srv/qgis/server.conf`**

```ini
[server]
workers = 4    # <— hier anpassen
```

Der `-w`-Flag im Supervisor-Kommando (`/etc/supervisor/conf.d/py-qgisserver.conf`) wird **nicht** verwendet.
Worker-Anzahl nur an einer Stelle zu definieren vermeidet Widersprüche zwischen Supervisor und `server.conf`.

Vor der Installation: `QGIS_WORKER_COUNT` im Skript-Header setzen — das Skript schreibt diesen Wert automatisch in `server.conf`.

---

## Welche Dateien steuern die Worker-Parameter?

| Datei | Parameter | Wirkung |
|---|---|---|
| `server.conf` | `workers = N` | Anzahl Worker-Prozesse — **massgeblich** |
| `server.conf` | `memory_high_water_mark = 0.75` | RAM-Schwelle, ab der Worker neu gestartet werden |
| Supervisor `environment=` | `QGSRV_CACHE_SIZE="N"` | Max. QGIS-Projekte gleichzeitig im RAM |
| Supervisor `environment=` | `QGIS_SERVER_PARALLEL_RENDERING="1"` | Paralleles Tile-Rendering je Worker |

> Der `-w` Flag im `qgisserver`-Kommando wird **nicht** gesetzt — Worker werden nur via `server.conf` konfiguriert, um Doppelkonfiguration zu vermeiden.

---

## Faustregel: Worker-Anzahl wählen

```
Workers = min(CPU-Kerne ÷ 2, verfügbarer RAM ÷ RAM-pro-Worker)
```

| Server | CPU-Kerne | RAM | Empfehlung |
|---|---|---|---|
| Klein | 2–4 | 8 GB | 2 Worker |
| Mittel | 8 | 16 GB | 4 Worker |
| Gross | 16 | 32 GB | 8 Worker |
| XL | 32 | 64 GB | 12–16 Worker |

**RAM pro Worker:** ca. 500 MB – 2 GB, abhängig von Projektkomplexität (Layeranzahl, Raster, WMS-Verbindungen).

Der interaktive **[Worker Rechner](worker_rechner.html)** berechnet die Werte automatisch.

---

## Varianten-Skripte

| Skript | CPU | Worker | Cache |
|---|---|---|---|
| `install_lizmap_qgisserver_8cpu.sh` | 8 Kerne | 4 | 6 |
| `install_lizmap_qgisserver_16cpu.sh` | 16 Kerne | 8 | 12 |

Andere Hardware: Werte im Skript-Header und in `server.conf` anpassen — oder den [Worker Rechner](worker_rechner.html) verwenden.

---

## Konfiguration anpassen

### 1. `server.conf`

```ini
[server]
workers = 4                    # <— hier anpassen
memory_high_water_mark = 0.75  # RAM-Schwelle (0.0–1.0)
```

Pfad: `/srv/qgis/server.conf`

### 2. Supervisor-Umgebungsvariablen

In `/etc/supervisor/conf.d/py-qgisserver.conf`:

```ini
environment=...,QGIS_SERVER_PARALLEL_RENDERING="1",QGSRV_CACHE_SIZE="6"
```

- `QGIS_SERVER_PARALLEL_RENDERING="1"` — aktiviert paralleles Tile-Rendering innerhalb eines Workers
- `QGSRV_CACHE_SIZE="6"` — wie viele QGIS-Projekte maximal gleichzeitig im RAM gehalten werden (LRU-Cache). Empfehlung: 1–2× Worker-Anzahl.

### 3. Änderungen aktivieren

```bash
# server.conf geändert → Worker neu starten:
supervisorctl restart py-qgisserver

# Supervisor-Config geändert → neu laden:
supervisorctl reread
supervisorctl update
supervisorctl restart py-qgisserver
```

---

## qgis.service — was steuert er?

`qgis.service` orchestriert den **gesamten QGIS-Stack** mit einem einzigen Befehl:

```bash
service qgis start    # startet Xvfb + Supervisor + py-qgisserver
service qgis stop     # stoppt alles
service qgis restart  # Neustart
```

Die FastCGI-Socket-Units (`qgis-server@*.socket`) werden vom `qgis.service` **nicht** mehr referenziert — Nginx leitet alle Anfragen direkt an py-qgis-server (HTTP auf Port 7200) weiter.

---

## Diagnose

```bash
# Worker-Status prüfen:
supervisorctl status py-qgisserver

# Aktive Verbindungen zur py-qgis-server API:
curl -s http://127.0.0.1:7200/lizmap/server.json | python3 -m json.tool

# Logs:
tail -f /var/log/supervisor/py-qgisserver.log
tail -f /var/log/supervisor/py-qgisserver-err.log

# RAM-Verbrauch der QGIS-Prozesse:
ps aux | grep qgisserver | awk '{sum += $6} END {print sum/1024 " MB"}'
```
