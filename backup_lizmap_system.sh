#!/bin/bash
# =============================================================================
# backup_lizmap_system.sh — Sicherung des laufenden Lizmap + py-qgis-server Stack
# Ubuntu 24.04 LTS
# Verwendung: sudo bash backup_lizmap_system.sh
# Erstellt: /root/lizmap_backup_DATUM.tar.gz
# =============================================================================

set -uo pipefail

[[ $EUID -ne 0 ]] && { echo "Als root ausführen: sudo bash $0"; exit 1; }

BACKUP_DATE=$(date '+%Y%m%d_%H%M%S')
BACKUP_DIR="/root/lizmap_backup_${BACKUP_DATE}"
BACKUP_TAR="/root/lizmap_backup_${BACKUP_DATE}.tar.gz"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log()     { echo -e "${GREEN}[BACKUP]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
section() { echo -e "\n${BLUE}===== $* =====${NC}"; }

mkdir -p "${BACKUP_DIR}"
log "Backup-Verzeichnis: ${BACKUP_DIR}"
log "Archiv wird erstellt: ${BACKUP_TAR}"

# =============================================================================
section "1. Konfigurationsdateien"
# =============================================================================

# /srv/qgis — komplette QGIS-Server-Konfiguration
log "Sichere /srv/qgis ..."
mkdir -p "${BACKUP_DIR}/srv"
cp -a /srv/qgis "${BACKUP_DIR}/srv/"
# Cache nicht sichern (gross, regenerierbar)
rm -rf "${BACKUP_DIR}/srv/qgis/cache/data8" \
       "${BACKUP_DIR}/srv/qgis/cache/prepared" \
       "${BACKUP_DIR}/srv/qgis/__pycache__" 2>/dev/null || true
find "${BACKUP_DIR}/srv/qgis/plugins" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# /srv/data — QGIS-Projekte
if [ -d /srv/data ] && [ "$(ls -A /srv/data 2>/dev/null)" ]; then
    log "Sichere /srv/data (QGIS-Projekte) ..."
    cp -a /srv/data "${BACKUP_DIR}/srv/"
else
    log "/srv/data ist leer — übersprungen."
    mkdir -p "${BACKUP_DIR}/srv/data"
fi

# =============================================================================
section "2. Lizmap Web Client"
# =============================================================================

log "Sichere Lizmap-Konfiguration (/var/www/lizmap/lizmap/var/config) ..."
mkdir -p "${BACKUP_DIR}/var/www/lizmap/lizmap/var"
cp -a /var/www/lizmap/lizmap/var/config "${BACKUP_DIR}/var/www/lizmap/lizmap/var/" 2>/dev/null || \
    warn "Lizmap config-Verzeichnis nicht gefunden"

# Repositories-Verzeichnis
if [ -d /var/www/lizmap/lizmap/var/lizmap ]; then
    cp -a /var/www/lizmap/lizmap/var/lizmap "${BACKUP_DIR}/var/www/lizmap/lizmap/var/" 2>/dev/null || true
fi

# =============================================================================
section "3. Nginx-Konfiguration"
# =============================================================================

log "Sichere Nginx-Konfiguration ..."
mkdir -p "${BACKUP_DIR}/etc/nginx"
cp -a /etc/nginx/sites-available "${BACKUP_DIR}/etc/nginx/" 2>/dev/null || true
cp -a /etc/nginx/sites-enabled   "${BACKUP_DIR}/etc/nginx/" 2>/dev/null || true
cp    /etc/nginx/nginx.conf       "${BACKUP_DIR}/etc/nginx/" 2>/dev/null || true

# =============================================================================
section "4. Supervisor-Konfiguration"
# =============================================================================

log "Sichere Supervisor-Konfiguration ..."
mkdir -p "${BACKUP_DIR}/etc/supervisor"
cp -a /etc/supervisor/conf.d "${BACKUP_DIR}/etc/supervisor/" 2>/dev/null || true

# =============================================================================
section "5. PHP-Konfiguration"
# =============================================================================

log "Sichere PHP-Konfiguration ..."
mkdir -p "${BACKUP_DIR}/etc/php"
cp -a /etc/php/8.3/fpm/php.ini    "${BACKUP_DIR}/etc/php/" 2>/dev/null || true
cp -a /etc/php/8.3/fpm/pool.d     "${BACKUP_DIR}/etc/php/" 2>/dev/null || true

# =============================================================================
section "6. PostgreSQL-Datenbank"
# =============================================================================

if systemctl is-active --quiet postgresql 2>/dev/null; then
    log "Sichere PostgreSQL-Datenbank 'lizmap' ..."
    mkdir -p "${BACKUP_DIR}/postgresql"
    sudo -u postgres pg_dump lizmap \
        > "${BACKUP_DIR}/postgresql/lizmap_dump.sql" 2>/dev/null \
        && log "  pg_dump: OK" \
        || warn "  pg_dump fehlgeschlagen"

    # Benutzer/Rollen exportieren
    sudo -u postgres pg_dumpall --globals-only \
        > "${BACKUP_DIR}/postgresql/globals.sql" 2>/dev/null \
        && log "  pg_dumpall globals: OK" \
        || warn "  pg_dumpall fehlgeschlagen"
else
    warn "PostgreSQL nicht aktiv — übersprungen"
fi

# =============================================================================
section "7. Systemd Units"
# =============================================================================

log "Sichere Systemd Units ..."
mkdir -p "${BACKUP_DIR}/etc/systemd"
for unit in xvfb.service qgis.service qgis-server@.service qgis-server@.socket; do
    [ -f "/etc/systemd/system/${unit}" ] && \
        cp "/etc/systemd/system/${unit}" "${BACKUP_DIR}/etc/systemd/" && \
        log "  ${unit}"
done

# =============================================================================
section "8. xRDP-Konfiguration"
# =============================================================================

if [ -f /etc/xrdp/startwm.sh ]; then
    log "Sichere xRDP-Konfiguration ..."
    mkdir -p "${BACKUP_DIR}/etc/xrdp"
    cp /etc/xrdp/startwm.sh "${BACKUP_DIR}/etc/xrdp/" 2>/dev/null || true
    cp /etc/xrdp/xrdp.ini   "${BACKUP_DIR}/etc/xrdp/" 2>/dev/null || true
fi

# =============================================================================
section "9. System-Informationen speichern"
# =============================================================================

log "Speichere System-Informationen ..."
{
    echo "=== Backup erstellt: $(date) ==="
    echo ""
    echo "--- OS ---"
    lsb_release -a 2>/dev/null
    echo ""
    echo "--- Installierte Pakete (relevant) ---"
    dpkg -l | grep -E "qgis|nginx|php|postgresql|xrdp|supervisor|python3" | awk '{print $2, $3}'
    echo ""
    echo "--- py-qgis-server ---"
    /opt/local/py-qgis-server/bin/pip show py-qgis-server 2>/dev/null
    echo ""
    echo "--- Supervisor Status ---"
    supervisorctl status 2>/dev/null
    echo ""
    echo "--- Dienste ---"
    systemctl is-active nginx php8.3-fpm xvfb supervisor postgresql xrdp 2>/dev/null
    echo ""
    echo "--- Lizmap Plugin API ---"
    curl -s http://127.0.0.1:7200/lizmap/server.json 2>/dev/null | python3 -m json.tool
    echo ""
    echo "--- Nginx vhosts ---"
    ls -la /etc/nginx/sites-enabled/
    echo ""
    echo "--- QGIS Plugins ---"
    for p in /srv/qgis/plugins/*/metadata.txt; do
        echo "Plugin: $(dirname $p | xargs basename)"
        grep "^version\|^name" "$p" 2>/dev/null
    done
} > "${BACKUP_DIR}/system_info.txt" 2>&1

log "System-Informationen gespeichert."

# =============================================================================
section "10. Archiv erstellen"
# =============================================================================

log "Erstelle Archiv ${BACKUP_TAR} ..."
tar -czf "${BACKUP_TAR}" -C "$(dirname ${BACKUP_DIR})" "$(basename ${BACKUP_DIR})"
rm -rf "${BACKUP_DIR}"

BACKUP_SIZE=$(du -sh "${BACKUP_TAR}" | cut -f1)
echo ""
echo -e "${GREEN}=====================================================${NC}"
echo -e "${GREEN}  Backup abgeschlossen!${NC}"
echo -e "${GREEN}  Archiv:  ${BACKUP_TAR}${NC}"
echo -e "${GREEN}  Grösse:  ${BACKUP_SIZE}${NC}"
echo -e "${GREEN}=====================================================${NC}"
echo ""
echo "Auf lokalem PC herunterladen:"
echo "  scp root@65.21.3.77:${BACKUP_TAR} ."
echo ""
echo "Wiederherstellen (nach Neuinstall):"
echo "  scp lizmap_backup_*.tar.gz root@SERVER:~/"
echo "  sudo bash restore_lizmap_system.sh lizmap_backup_*.tar.gz"
