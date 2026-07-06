#!/bin/bash
# =============================================================================
# Lizmap Web Client + py-qgis-server Installation Script — 8 CPU variant
# Ubuntu 24.04 LTS (Noble Numbat)
# Optimiert für Server mit 8 CPU-Kernen (QGIS_WORKER_COUNT=4)
# =============================================================================
# Usage: sudo bash install_lizmap_qgisserver_8cpu.sh
#
# What this script installs:
#   - QGIS Server LTR (via official QGIS apt repository)
#   - QGIS Desktop LTR (for project authoring via RDP)
#   - py-qgis-server (3liz Python WSGI wrapper for QGIS Server)
#   - QGIS Server plugins: atlasprint, lizmap_server, wfsOutputExtension
#   - qgis.service meta-unit ("service qgis start/stop/restart")
#   - Xvfb virtual display :99 (fixes QGIS Server X11/Qt rendering)
#   - Lizmap Web Client (see LIZMAP_VERSION below)
#   - Nginx + PHP-FPM
#   - PostgreSQL + PostGIS (optional)
#   - pgAdmin4 Desktop (optional, via RDP)
#   - xRDP + XFCE4 desktop (optional, remote desktop access on port 3389)
#   - Firefox (native .deb via Mozilla PPA)
#   - certbot + python3-certbot-nginx (HTTPS via Let's Encrypt)
#   - UFW firewall + Fail2ban (optional security hardening)
# =============================================================================

set -uo pipefail
# Note: -e (exit on error) deliberately NOT set — individual sections handle
# their own errors so a non-critical failure does not abort the whole script.
# Every section uses explicit error checking and || true guards.

# ---- CONFIGURABLE VARIABLES -------------------------------------------------
LIZMAP_VERSION="3.9.9"
LIZMAP_DIR="/var/www/lizmap"
QGIS_PROJECTS_DIR="/srv/data"
QGIS_WORKER_COUNT=4          # Number of QGIS Server worker instances (8 CPU: 4 Worker)
SERVER_NAME="localhost karte1.wandelderzeit.ch"  # Change to your domain or IP
LIZMAP_USER="www-data"
LIZMAP_GROUP="www-data"
INSTALL_POSTGRESQL=true       # Set to false to skip PostgreSQL
PG_LIZMAP_DB="lizmap"
PG_LIZMAP_USER="lizmap"
PG_LIZMAP_PASS="${PG_LIZMAP_PASS:-lizmap_secret_$(openssl rand -hex 6)}"
INSTALL_XRDP=true             # Set to false to skip xRDP + XFCE4
XRDP_USER="gisadmin"          # Dedicated RDP user (created if missing)
XRDP_PASS="${XRDP_PASS:-GisAdmin_$(openssl rand -hex 4)}"  # Auto-generated, shown at end
XRDP_PORT=3389
INSTALL_SECURITY=true         # Set to false to skip UFW + Fail2ban hardening
CERTBOT_EMAIL=""              # Set to your email to enable automatic HTTPS via Let's Encrypt
                              # Leave empty to skip certbot (configure manually later)
LOG_FILE="/var/log/install_lizmap_qgisserver.log"
# -----------------------------------------------------------------------------

# ---- Installation log -------------------------------------------------------
# All stdout and stderr — including every command's output — is written to
# LOG_FILE in addition to the terminal. The log is created before anything
# else runs so the full run (including errors) is always captured.
mkdir -p "$(dirname "${LOG_FILE}")"
exec > >(tee -a "${LOG_FILE}") 2>&1
echo "======================================================================"
echo " Installation started : $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo " Log file             : ${LOG_FILE}"
echo "======================================================================"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()  { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
section(){ echo -e "\n${BLUE}===== $* =====${NC}"; }

# ---- Pre-flight checks -------------------------------------------------------
[[ $EUID -ne 0 ]] && error "Run this script as root: sudo bash $0"
[[ $(lsb_release -rs) != "24.04" ]] && warn "Script tested on Ubuntu 24.04 only. Proceeding anyway."

section "1. System update and base dependencies"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    wget \
    unzip \
    git \
    software-properties-common \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    libzmq3-dev \
    supervisor \
    nginx \
    openssl \
    xvfb \
    x11-utils \
    libgl1 \
    libgl1-mesa-dri \
    mesa-utils \
    certbot \
    python3-certbot-nginx

log "Base dependencies installed."

# ---- QGIS Server -------------------------------------------------------------
section "2. QGIS Server (LTR) installation"

mkdir -p /etc/apt/keyrings
wget -qO /etc/apt/keyrings/qgis-archive-keyring.gpg \
    https://download.qgis.org/downloads/qgis-archive-keyring.gpg

cat > /etc/apt/sources.list.d/qgis.sources <<EOF
Types: deb deb-src
URIs: https://qgis.org/ubuntu-ltr
Suites: noble
Architectures: amd64
Components: main
Signed-By: /etc/apt/keyrings/qgis-archive-keyring.gpg
EOF

apt-get update -qq
apt-get install -y -qq \
    qgis-server \
    qgis \
    python3-qgis \
    qgis-plugin-grass \
    qgis-providers

log "QGIS Server + Desktop installed: $(qgis_mapserv.fcgi --version 2>&1 | head -1 || echo 'see /usr/lib/cgi-bin/qgis_mapserv.fcgi')"

# ---- PHP and extensions ------------------------------------------------------
section "3. PHP 8.3-FPM and extensions"
apt-get install -y -qq \
    php8.3-fpm \
    php8.3-cli \
    php8.3-curl \
    php8.3-dom \
    php8.3-gd \
    php8.3-intl \
    php8.3-mbstring \
    php8.3-pgsql \
    php8.3-sqlite3 \
    php8.3-xml \
    php8.3-zip \
    php8.3-ldap

# Tune PHP-FPM
sed -i 's/^upload_max_filesize.*/upload_max_filesize = 200M/' /etc/php/8.3/fpm/php.ini
sed -i 's/^post_max_size.*/post_max_size = 200M/'             /etc/php/8.3/fpm/php.ini
sed -i 's/^memory_limit.*/memory_limit = 256M/'               /etc/php/8.3/fpm/php.ini
sed -i 's/^max_execution_time.*/max_execution_time = 300/'     /etc/php/8.3/fpm/php.ini

# Explicitly enable pgsql/pdo_pgsql for both CLI and FPM.
# apt installs the extension files but phpenmod ensures the .ini symlinks
# exist in every SAPI conf.d directory.
phpenmod -v 8.3 pgsql pdo_pgsql

systemctl enable php8.3-fpm
systemctl restart php8.3-fpm
log "PHP 8.3-FPM configured."

# ---- PostgreSQL (optional) ---------------------------------------------------
if [[ "$INSTALL_POSTGRESQL" == "true" ]]; then
    section "4. PostgreSQL + PostGIS + pgAdmin4 installation"

    # ── PostgreSQL + PostGIS ───────────────────────────────────────────────────
    apt-get install -y -qq postgresql postgresql-contrib postgis

    # Install the matching postgresql-XX-postgis-3 package
    PG_VERSION=$(pg_lsclusters -h 2>/dev/null | awk '{print $1}' | head -1 || echo "")
    if [ -z "${PG_VERSION}" ]; then
        PG_VERSION=$(sudo -u postgres psql -tAc "SHOW server_version_num;" 2>/dev/null | cut -c1-2 || echo "16")
    fi
    apt-get install -y -qq "postgresql-${PG_VERSION}-postgis-3" 2>/dev/null || \
        warn "postgresql-${PG_VERSION}-postgis-3 not found — PostGIS installed via postgis meta-package only."

    systemctl enable postgresql
    systemctl start postgresql

    sudo -u postgres psql -c "CREATE USER ${PG_LIZMAP_USER} WITH PASSWORD '${PG_LIZMAP_PASS}';" 2>/dev/null || \
        warn "PostgreSQL user '${PG_LIZMAP_USER}' already exists."
    sudo -u postgres psql -c "CREATE DATABASE ${PG_LIZMAP_DB} OWNER ${PG_LIZMAP_USER};" 2>/dev/null || \
        warn "PostgreSQL database '${PG_LIZMAP_DB}' already exists."

    # Enable PostGIS extension in the Lizmap database
    sudo -u postgres psql -d "${PG_LIZMAP_DB}" \
        -c "CREATE EXTENSION IF NOT EXISTS postgis;" 2>/dev/null || true
    sudo -u postgres psql -d "${PG_LIZMAP_DB}" \
        -c "CREATE EXTENSION IF NOT EXISTS postgis_topology;" 2>/dev/null || true
    log "PostGIS enabled in database '${PG_LIZMAP_DB}'."

    # PostgreSQL 15+ revoked CREATE on the public schema from PUBLIC by default.
    sudo -u postgres psql -d "${PG_LIZMAP_DB}" \
        -c "GRANT ALL ON SCHEMA public TO ${PG_LIZMAP_USER};" 2>/dev/null || true
    sudo -u postgres psql -d "${PG_LIZMAP_DB}" \
        -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${PG_LIZMAP_USER};" 2>/dev/null || true
    sudo -u postgres psql -d "${PG_LIZMAP_DB}" \
        -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${PG_LIZMAP_USER};" 2>/dev/null || true

    # Add an explicit pg_hba.conf entry for the lizmap user using md5 auth.
    PG_HBA=$(sudo -u postgres psql -tAc "SHOW hba_file;")
    if ! grep -q "^host.*${PG_LIZMAP_DB}.*${PG_LIZMAP_USER}" "${PG_HBA}" 2>/dev/null; then
        sed -i "/^# TYPE/a host    ${PG_LIZMAP_DB}    ${PG_LIZMAP_USER}    127.0.0.1/32    md5" "${PG_HBA}"
        sudo -u postgres psql -c "SELECT pg_reload_conf();" > /dev/null
        log "pg_hba.conf: added md5 entry for ${PG_LIZMAP_USER}@${PG_LIZMAP_DB}."
    fi
    sudo -u postgres psql -c \
        "ALTER USER ${PG_LIZMAP_USER} WITH PASSWORD '${PG_LIZMAP_PASS}';" > /dev/null

    log "PostgreSQL + PostGIS configured. DB: ${PG_LIZMAP_DB} / User: ${PG_LIZMAP_USER}"
fi

# ---- py-qgis-server ----------------------------------------------------------
section "5. py-qgis-server installation"

# Install in a Python venv with --system-site-packages so that QGIS Python
# bindings (python3-qgis, PyQGIS) installed via apt remain accessible.
# This is the approach documented at docs.lizmap.com/3.9/en/install/py-qgis-server.html
apt-get install -y -qq python3-psutil python3-venv

python3 -m venv /opt/local/py-qgis-server --system-site-packages
/opt/local/py-qgis-server/bin/pip install -q -U pip setuptools wheel pysocks typing_extensions
/opt/local/py-qgis-server/bin/pip install -q py-qgis-server \
    || { /opt/local/py-qgis-server/bin/pip install py-qgis-server; \
         error "pip install py-qgis-server fehlgeschlagen — Abbruch."; }

# qgis-plugin-manager in eigene isolierte venv installieren (Ubuntu 24.04 PEP 668).
# Eigene venv verhindert Dependency-Konflikte mit py-qgis-server.
python3 -m venv /opt/local/qgis-plugin-manager
if /opt/local/qgis-plugin-manager/bin/pip install -q qgis-plugin-manager; then
    ln -sf /opt/local/qgis-plugin-manager/bin/qgis-plugin-manager \
           /usr/local/bin/qgis-plugin-manager
    log "qgis-plugin-manager installiert (/opt/local/qgis-plugin-manager)."
else
    /opt/local/qgis-plugin-manager/bin/pip install qgis-plugin-manager
    warn "qgis-plugin-manager: Installation fehlgeschlagen — Plugin-Installation läuft via ZIP-Fallback."
fi

# Symlink so "qgisserver" is available system-wide (used by supervisor command)
ln -sf /opt/local/py-qgis-server/bin/qgisserver /usr/local/bin/qgisserver 2>/dev/null || true

# Restart monitor directory — py-qgis-server watches this file for graceful restarts
mkdir -p /var/lib/py-qgis-server /var/log/qgis
touch /var/lib/py-qgis-server/py-qgis-restartmon

# qgis-reload: touch the restart monitor to trigger graceful worker restart
cat > /usr/bin/qgis-reload <<'RELOAD'
#!/bin/bash
touch /var/lib/py-qgis-server/py-qgis-restartmon
RELOAD
chmod 750 /usr/bin/qgis-reload

# Create dedicated user for QGIS workers
id qgis &>/dev/null || useradd --system --home /srv/qgis --shell /bin/false qgis

# ── /srv/qgis directory structure (matches production layout) ─────────────────
mkdir -p \
    "${QGIS_PROJECTS_DIR}" \
    /srv/qgis/cache/prepared \
    /srv/qgis/config \
    /srv/qgis/fonts \
    /srv/qgis/gdal_pam \
    /srv/qgis/oauth2-cache \
    /srv/qgis/palettes \
    /srv/qgis/plugins \
    /srv/qgis/QGIS

# Minimal QGIS3.ini — tells QGIS Server where plugins and cache live
cat > /srv/qgis/QGIS/QGIS3.ini <<'INI'
[cache]
directory=/srv/qgis/cache
size=524288000

[qgis]
symbolsDir=/srv/qgis/palettes
svgPaths=/srv/qgis/fonts

[server]
pluginspath=/srv/qgis/plugins
INI

# Empty bookmarks file expected by QGIS
cat > /srv/qgis/bookmarks.xml <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<Bookmarks/>
XML

# ── SQLite databases required by QGIS Server ──────────────────────────────────
# QGIS needs these three database files to be present at QGIS_AUTH_DB_DIR_PATH.
# Without them, QGIS Server cannot fully initialize → plugins load but register
# no API paths ("paths": {}). We create minimal valid SQLite files here;
# QGIS will initialize the schema on first start.
#
# Verified against working production system at /srv/qgis/:
#   qgis-auth.db       — authentication database (QGIS_AUTH_DB_DIR_PATH)
#   qgis.db            — QGIS internal database
#   symbology-style.db — symbology/style database

python3 - <<'PYDB'
import sqlite3, os
for db in ['/srv/qgis/qgis-auth.db', '/srv/qgis/qgis.db', '/srv/qgis/symbology-style.db']:
    if not os.path.exists(db):
        conn = sqlite3.connect(db)
        conn.close()
        print(f"Created: {db}")
    else:
        print(f"Already exists: {db}")
PYDB

# Preload-projects list (empty by default — add .qgs paths one per line)
cat > /srv/qgis/config/preload_projects.txt <<'TXT'
# List QGIS project files to preload on startup, one absolute path per line.
# Example:
# /srv/qgis/projects/mymap.qgs
TXT

# Environment file for QGIS Server workers
# Stored under /srv/qgis/config/ to keep all QGIS config in one place.
# DISPLAY=:99    — virtual Xvfb framebuffer (Qt needs a real display)
# QGIS_PLUGINPATH — where the server-side plugins live
cat > /srv/qgis/config/qgis-service.env <<EOF
# --- Locale ---
LC_ALL=en_US.UTF-8

# --- X11 virtual display (Xvfb :99) ---
DISPLAY=:99
QT_QPA_PLATFORM=xcb
LIBGL_ALWAYS_SOFTWARE=1

# --- QGIS paths (docs.lizmap.com/3.9/en/install/py-qgis-server.html) ---
# QGIS_OPTIONS_PATH: tells QGIS Server where to find QGIS3.ini (plugin paths,
# cache config, etc.). Without this QGIS ignores /srv/qgis/QGIS/QGIS3.ini!
QGIS_OPTIONS_PATH=/srv/qgis/
QGIS_AUTH_DB_DIR_PATH=/srv/qgis/
HOME=/srv/qgis
XDG_RUNTIME_DIR=/run/qgis

# --- QGIS Server ---
QGIS_SERVER_LOG_STDERR=1
QGIS_SERVER_LOG_LEVEL=1
QGIS_SERVER_MAX_THREADS=2
QGIS_SERVER_IGNORE_BAD_LAYERS=1
QGIS_SERVER_CACHE_DIRECTORY=/srv/qgis/cache
QGIS_SERVER_FORCE_READONLY_LAYERS=TRUE
# QGSRV_SERVER_PLUGINPATH = py-qgis-server native plugin path variable
# QGIS_PLUGINPATH          = QGIS Server native plugin path variable (fallback)
QGSRV_SERVER_PLUGINPATH=/srv/qgis/plugins
QGIS_PLUGINPATH=/srv/qgis/plugins
# Required to expose the Lizmap API endpoint (/lizmap/server.json)
# Must be TRUE (uppercase) as per official Lizmap documentation
QGIS_SERVER_LIZMAP_REVEAL_SETTINGS=TRUE
QGIS_DEBUG=0

# --- py-qgis-server API endpoints (default: disabled!) ---
# QGSRV_API_ENABLED_LIZMAP=yes activates the /lizmap/ REST API in py-qgis-server.
# Without this, /lizmap/server.json always returns 404 regardless of the plugin.
QGSRV_API_ENABLED_LIZMAP=yes
QGSRV_API_ENDPOINTS_LIZMAP=/lizmap
QGSRV_API_ENABLED_LANDING_PAGE=no
EOF

# py-qgis-server configuration (lives alongside other QGIS config in /srv/qgis)
# Port 7200 — matches the URL Lizmap uses: http://127.0.0.1:7200/ows/
# IMPORTANT: rootdir belongs under [projects.cache], NOT [server]
cat > /srv/qgis/server.conf <<EOF
#
# Py-QGIS-Server configuration
# https://docs.3liz.org/py-qgis-server/
#
[server]
port = 7200
interfaces = 127.0.0.1
workers = ${QGIS_WORKER_COUNT}
memory_high_water_mark = 0.8
pluginpath = /srv/qgis/plugins
timeout = 200
restartmon = /var/lib/py-qgis-server/py-qgis-restartmon

[logging]
level = debug

[projects.cache]
strict_check = false
rootdir = ${QGIS_PROJECTS_DIR}
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
EOF

chown -R qgis:qgis /srv/qgis

log "py-qgis-server installed."

# ---- Xvfb virtual framebuffer -----------------------------------------------
# QGIS Server uses Qt's rendering engine for map output. Even when running
# headless, Qt must initialise a QScreen object. Without a real or virtual
# X display the process aborts with:
#   "could not connect to display :99" / "QXcbConnection: Could not connect"
# Solution: run a persistent Xvfb process on display :99 that all QGIS Server
# workers and the py-qgis-server supervisor process inherit via the env file.
section "5b. Xvfb virtual display :99"

# Systemd unit — runs Xvfb on :99 with 24-bit colour, no access control,
# GLX extension enabled so Qt's OpenGL paths don't error out.
cat > /etc/systemd/system/xvfb.service <<'UNIT'
[Unit]
Description=Xvfb virtual framebuffer for QGIS Server (display :99)
Documentation=man:Xvfb(1)
# Must be up before py-qgis-server starts

[Service]
Type=simple
# -screen 0 1280x1024x24   — 24-bit colour, sufficient for all Qt rendering
# -ac                       — disable access control (loopback-only, safe)
# +extension GLX            — enable GLX so Qt's OpenGL renderer initialises
# +extension RANDR          — some QGIS symbol renderers query screen geometry
# -nolisten tcp             — no TCP socket, Unix socket only (security)
# -noreset                  — keep Xvfb alive even when last client disconnects
ExecStart=/usr/bin/Xvfb :99 -screen 0 1280x1024x24 -ac +extension GLX +extension RANDR -nolisten tcp -noreset
Restart=always
RestartSec=3
# Run as www-data so QGIS workers (same user) can connect without xhost calls
User=www-data
Group=www-data

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable xvfb
systemctl start  xvfb

# Verify Xvfb is actually listening on :99
sleep 2
if DISPLAY=:99 xdpyinfo &>/dev/null; then
    log "Xvfb started successfully on display :99."
else
    warn "Xvfb may not have started correctly — check: systemctl status xvfb"
fi

# ---- QGIS Server plugins -------------------------------------------------------
section "5c. QGIS Server plugins (atlasprint, lizmap_server, wfsOutputExtension)"

# Methode 1 (primär): qgis-plugin-manager — offizielle 3liz CLI für QGIS Server Plugins
# Installiert direkt aus dem QGIS Plugin Repository, erkennt kompatible Versionen automatisch.
# https://github.com/3liz/qgis-plugin-manager
# Läuft in eigener venv /opt/local/qgis-plugin-manager (kein Konflikt mit py-qgis-server)
PLUGIN_MGR_BIN=""
# qgis-plugin-manager wurde in Sektion 5 in eigene venv installiert + Symlink gesetzt.
# Suche: zuerst Symlink /usr/local/bin, dann direkt in der venv.
if [ -x "/usr/local/bin/qgis-plugin-manager" ]; then
    PLUGIN_MGR_BIN="/usr/local/bin/qgis-plugin-manager"
    log "qgis-plugin-manager verfügbar: ${PLUGIN_MGR_BIN}"
elif [ -x "/opt/local/qgis-plugin-manager/bin/qgis-plugin-manager" ]; then
    PLUGIN_MGR_BIN="/opt/local/qgis-plugin-manager/bin/qgis-plugin-manager"
    log "qgis-plugin-manager verfügbar (venv): ${PLUGIN_MGR_BIN}"
else
    warn "qgis-plugin-manager Binary nicht gefunden — Plugin-Installation läuft via ZIP-Fallback."
fi

if [ -n "${PLUGIN_MGR_BIN}" ]; then
    log "qgis-plugin-manager verfügbar — verwende Plugin-Manager als primäre Methode."
    export QGIS_PLUGINPATH=/srv/qgis/plugins
    # QGIS-Version für plugins.qgis.org ermitteln (URL braucht ?qgis=X.Y als Parameter)
    # Epoch-Präfix "1:" in der dpkg-Version muss entfernt werden, daher grep auf \d+\.\d+ mitten im String
    QGIS_VER=$(dpkg -l qgis-server 2>/dev/null | awk '/^ii.*qgis-server /{print $3}' \
               | grep -oP '\d+\.\d+' | head -1)
    if [ -n "${QGIS_VER}" ]; then
        log "QGIS Version erkannt: ${QGIS_VER}"
        # Version direkt in sources.list eintragen — qgis-plugin-manager v1.7.5 kennt kein --qgis-version Flag
        echo "https://plugins.qgis.org/plugins/plugins.xml?qgis=${QGIS_VER}" \
            > /srv/qgis/plugins/sources.list
    else
        warn "QGIS-Version nicht erkannt — verwende Standard-URL ohne Version."
        echo "https://plugins.qgis.org/plugins/plugins.xml" \
            > /srv/qgis/plugins/sources.list
    fi
    "${PLUGIN_MGR_BIN}" update 2>/dev/null || true
    for plugin in lizmap_server atlasprint wfsOutputExtension; do
        if [ -d "/srv/qgis/plugins/${plugin}" ] && [ -f "/srv/qgis/plugins/${plugin}/metadata.txt" ]; then
            log "Plugin '${plugin}' bereits vorhanden — übersprungen."
        else
            log "Installiere Plugin '${plugin}' via qgis-plugin-manager ..."
            "${PLUGIN_MGR_BIN}" install "${plugin}" 2>/dev/null || \
                warn "qgis-plugin-manager: '${plugin}' fehlgeschlagen — ZIP-Fallback wird verwendet."
        fi
    done
else
    warn "qgis-plugin-manager nicht verfügbar — verwende ZIP-basierte Fallback-Installation."
fi

# Methode 2 (Fallback): GitHub Release / ZIP Download
install_qgis_plugin() {
    local name="$1"       # plugin directory name
    local repo="$2"       # e.g. 3liz/qgis-atlasprint
    local zip_name="$3"   # filename inside the archive that contains the plugin

    if [ -d "/srv/qgis/plugins/${name}" ]; then
        log "Plugin '${name}' already installed — skipping."
        return
    fi

    log "Installing QGIS plugin: ${name} (${repo})..."
    local latest_url
    local _curl_auth=()
    [ -n "${GITHUB_TOKEN:-}" ] && _curl_auth=(-H "Authorization: token ${GITHUB_TOKEN}")
    latest_url=$(curl -s --max-time 15 "${_curl_auth[@]}" \
        "https://api.github.com/repos/${repo}/releases/latest" \
        | grep '"browser_download_url"' \
        | grep '\.zip"' \
        | head -1 \
        | sed 's/.*"browser_download_url": "\(.*\)"/\1/' || echo "")

    if [ -z "${latest_url}" ]; then
        latest_url="https://github.com/${repo}/archive/refs/heads/master.zip"
        warn "No release found for ${repo} — using master branch."
    fi

    local tmp_zip="/tmp/qgis_plugin_${name}.zip"
    if ! wget -q --timeout=30 -O "${tmp_zip}" "${latest_url}"; then
        warn "Failed to download plugin '${name}' from ${latest_url} — skipping."
        return 0
    fi
    if ! unzip -q "${tmp_zip}" -d "/tmp/qgis_plugin_${name}_extract"; then
        warn "Failed to unzip plugin '${name}' — skipping."
        rm -f "${tmp_zip}"
        return 0
    fi

    # The archive extracts to <repo>-<version>/ or <zip_name>/ — find it
    local extracted_dir
    extracted_dir=$(find "/tmp/qgis_plugin_${name}_extract" -mindepth 1 -maxdepth 1 -type d | head -1)

    # If the plugin code is inside a subdirectory (e.g. src/plugin_name/)
    if [ -n "${zip_name}" ] && [ -d "${extracted_dir}/${zip_name}" ]; then
        mv "${extracted_dir}/${zip_name}" "/srv/qgis/plugins/${name}"
    else
        mv "${extracted_dir}" "/srv/qgis/plugins/${name}"
    fi

    rm -rf "${tmp_zip}" "/tmp/qgis_plugin_${name}_extract"
    log "Plugin '${name}' installed at /srv/qgis/plugins/${name}"
}

# ZIP-Fallback nur für Plugins, die der Manager nicht installieren konnte
if [ ! -d "/srv/qgis/plugins/atlasprint" ] || [ ! -f "/srv/qgis/plugins/atlasprint/metadata.txt" ]; then
    install_qgis_plugin "atlasprint" "3liz/qgis-atlasprint" "atlasprint"
fi
if [ ! -d "/srv/qgis/plugins/wfsOutputExtension" ] || [ ! -f "/srv/qgis/plugins/wfsOutputExtension/metadata.txt" ]; then
    install_qgis_plugin "wfsOutputExtension" "3liz/qgis-wfsOutputExtension" "wfsOutputExtension"
fi

# lizmap_server: zuverlässige Installation via plugins.qgis.org (primär) + GitHub (Fallback)
# Strategie: find -type d -name "lizmap_server" — sucht direkt nach dem Verzeichnisnamen,
# unabhängig von der Archiv-Struktur. Sicherer als metadata.txt oder __init__.py zu suchen.
install_lizmap_server_plugin() {
    local dest="/srv/qgis/plugins/lizmap_server"
    local tmp_zip="/tmp/lizmap_server_dl.zip"
    local tmp_dir="/tmp/lizmap_server_extract"

    rm -rf "${tmp_zip}" "${tmp_dir}"

    # Hilfsfunktion: Zip entpacken, lizmap_server-Verzeichnis finden und installieren
    try_install_from_zip() {
        local url="$1"
        local label="$2"
        if ! curl -L --silent --max-time 60 -o "${tmp_zip}" "${url}"; then
            warn "lizmap_server: Download fehlgeschlagen (${label})"
            return 1
        fi
        if ! file "${tmp_zip}" | grep -qi "zip"; then
            warn "lizmap_server: Kein gültiges ZIP (${label})"
            return 1
        fi
        unzip -q "${tmp_zip}" -d "${tmp_dir}" 2>/dev/null || true
        # Suche direkt nach Verzeichnis mit Name "lizmap_server" das metadata.txt enthält
        local src
        src=$(find "${tmp_dir}" -type d -name "lizmap_server" \
              | while read -r d; do [ -f "${d}/metadata.txt" ] && echo "${d}" && break; done)
        if [ -n "${src}" ] && [ -d "${src}" ]; then
            mv "${src}" "${dest}"
            rm -rf "${tmp_zip}" "${tmp_dir}"
            log "Plugin 'lizmap_server' installiert (${label})."
            return 0
        fi
        rm -rf "${tmp_zip}" "${tmp_dir}"
        warn "lizmap_server: Verzeichnis 'lizmap_server' nicht im Archiv gefunden (${label})"
        return 1
    }

    if [ -d "${dest}" ] && [ -f "${dest}/metadata.txt" ]; then
        log "Plugin 'lizmap_server' already installed — skipping."
        return
    fi
    # Unvollständiges Verzeichnis entfernen (z.B. von fehlgeschlagenem früheren Versuch)
    [ -d "${dest}" ] && rm -rf "${dest}"

    log "Installing QGIS plugin: lizmap_server ..."

    # Methode 1: GitHub releases API (dynamisch — immer aktuellste kompatible Version)
    local gh_url
    local _curl_auth=()
    [ -n "${GITHUB_TOKEN:-}" ] && _curl_auth=(-H "Authorization: token ${GITHUB_TOKEN}")
    gh_url=$(curl -s --max-time 15 "${_curl_auth[@]}" \
        "https://api.github.com/repos/3liz/qgis-lizmap-server-plugin/releases/latest" \
        | grep '"browser_download_url"' | grep '\.zip"' | head -1 \
        | sed 's/.*"browser_download_url": "\(.*\)"/\1/')
    if [ -n "${gh_url}" ]; then
        try_install_from_zip "${gh_url}" "GitHub release" && return
    fi

    # Methode 2: GitHub master branch
    try_install_from_zip \
        "https://github.com/3liz/qgis-lizmap-server-plugin/archive/refs/heads/master.zip" \
        "GitHub master" && return

    # Methode 3: QGIS Plugin Repository (Fallback mit bekannter stabiler Version)
    # LIZMAP_SERVER_PLUGIN_VERSION kann als Env-Variable überschrieben werden
    local _lzm_ver="${LIZMAP_SERVER_PLUGIN_VERSION:-2.14.1}"
    try_install_from_zip \
        "https://plugins.qgis.org/plugins/lizmap_server/version/${_lzm_ver}/download/" \
        "plugins.qgis.org v${_lzm_ver}" && return

    warn "lizmap_server: Alle Download-Methoden fehlgeschlagen!"
    warn "Manuell installieren:"
    warn "  curl -L -o /tmp/lzm.zip https://github.com/3liz/qgis-lizmap-server-plugin/archive/refs/heads/master.zip"
    warn "  unzip /tmp/lzm.zip -d /tmp/lzm_ex && mv /tmp/lzm_ex/*/lizmap_server /srv/qgis/plugins/"
}

if [ ! -d "/srv/qgis/plugins/lizmap_server" ] || [ ! -f "/srv/qgis/plugins/lizmap_server/metadata.txt" ]; then
    install_lizmap_server_plugin
fi

# Plugin sources list — Format: eine Repository-URL pro Zeile (wird von qgis-plugin-manager gelesen)
# init überspringt die Datei wenn sie bereits existiert, daher hier direkt schreiben.
cat > /srv/qgis/plugins/sources.list <<'SRC'
https://plugins.qgis.org/plugins/plugins.xml
SRC
# Hinweis: Update via qgis-plugin-manager:
#   export QGIS_PLUGINPATH=/srv/qgis/plugins
#   /opt/local/py-qgis-server/bin/qgis-plugin-manager update && upgrade

chown -R qgis:qgis /srv/qgis/plugins
log "QGIS Server plugins installed."

# ---- Systemd socket + service for QGIS Server (FastCGI mode) ----------------
section "6. Systemd units for QGIS Server workers"

for i in $(seq 1 ${QGIS_WORKER_COUNT}); do
cat > /etc/systemd/system/qgis-server@.socket <<'UNIT'
[Unit]
Description=QGIS Server Socket %i

[Socket]
ListenStream=/run/qgis-server-%i.sock
Accept=no
SocketUser=www-data
SocketGroup=www-data
SocketMode=0660

[Install]
WantedBy=sockets.target
UNIT
break
done

cat > /etc/systemd/system/qgis-server@.service <<UNIT
[Unit]
Description=QGIS Server Instance %i
# Require both the activation socket and the Xvfb virtual display.
# Without Xvfb, Qt cannot initialise QScreen and map rendering fails.
Requires=qgis-server@%i.socket xvfb.service
After=network.target xvfb.service

[Service]
Type=simple
User=${LIZMAP_USER}
Group=${LIZMAP_GROUP}
StandardInput=socket
EnvironmentFile=/srv/qgis/config/qgis-service.env
ExecStart=/usr/lib/cgi-bin/qgis_mapserv.fcgi
Restart=on-failure
RestartSec=5s
RuntimeDirectory=qgis

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload

for i in $(seq 1 ${QGIS_WORKER_COUNT}); do
    systemctl enable --now "qgis-server@${i}.socket"
done

log "${QGIS_WORKER_COUNT} QGIS Server worker sockets enabled."

# ---- py-qgis-server Supervisor service ---------------------------------------
section "7. py-qgis-server Supervisor configuration"

cat > /etc/supervisor/conf.d/py-qgisserver.conf <<EOF
[program:py-qgisserver]
; Use the venv binary (--system-site-packages gives access to PyQGIS).
; Flag is -c (short form), not --conf — as per official Lizmap docs.
command=/opt/local/py-qgis-server/bin/qgisserver -c /srv/qgis/server.conf
user=qgis
; Full environment as per docs.lizmap.com/3.9/en/install/py-qgis-server.html
; QGIS_OPTIONS_PATH  → QGIS finds QGIS3.ini (plugin paths, cache config)
; QGIS_AUTH_DB_DIR_PATH → authentication database location
; QGIS_SERVER_LIZMAP_REVEAL_SETTINGS=TRUE (uppercase!) → enables /lizmap/server.json
; QGIS_SERVER_PARALLEL_RENDERING=1 → enables parallel tile rendering per worker
; QGSRV_CACHE_SIZE → max number of QGIS projects held in memory (LRU)
environment=LC_ALL="en_US.UTF-8",HOME="/srv/qgis",DISPLAY=":99",QT_QPA_PLATFORM="xcb",LIBGL_ALWAYS_SOFTWARE="1",QGIS_OPTIONS_PATH="/srv/qgis/",QGIS_AUTH_DB_DIR_PATH="/srv/qgis/",QGIS_SERVER_LOG_LEVEL="1",QGIS_DEBUG="0",QGSRV_SERVER_PLUGINPATH="/srv/qgis/plugins",QGIS_PLUGINPATH="/srv/qgis/plugins",QGIS_SERVER_LIZMAP_REVEAL_SETTINGS="TRUE",QGIS_SERVER_FORCE_READONLY_LAYERS="TRUE",QGSRV_API_ENABLED_LIZMAP="yes",QGSRV_API_ENDPOINTS_LIZMAP="/lizmap",QGIS_SERVER_PARALLEL_RENDERING="1",QGSRV_CACHE_SIZE="6"
autostart=true
autorestart=true
stdout_logfile=/var/log/supervisor/py-qgisserver.log
stderr_logfile=/var/log/supervisor/py-qgisserver-err.log
stopasgroup=true
killasgroup=true
EOF

systemctl enable supervisor
systemctl restart supervisor
log "py-qgis-server registered with Supervisor."

# ---- 3liz Telemetrie prüfen (bourbon.3liz.com) -------------------------------
# py-qgis-server sendet bei jeder Anfrage Telemetrie-Daten an bourbon.3liz.com.
# Ist der Host nicht erreichbar, entstehen Timeouts von 6–16s pro Anfrage.
# Fix wird nur angewendet wenn bourbon.3liz.com nicht erreichbar ist.
if grep -q "bourbon.3liz.com" /etc/hosts; then
    log "bourbon.3liz.com bereits in /etc/hosts blockiert (kein erneuter Check)."
elif curl -sf --max-time 2 --connect-timeout 2 https://bourbon.3liz.com/api/event \
        -o /dev/null 2>/dev/null; then
    log "bourbon.3liz.com erreichbar — kein /etc/hosts-Eintrag nötig."
else
    echo "0.0.0.0 bourbon.3liz.com" >> /etc/hosts
    log "bourbon.3liz.com nicht erreichbar → in /etc/hosts blockiert (verhindert 6–16s Timeouts pro Anfrage)."
fi

# ---- qgis.service — meta service for "service qgis start/stop/restart" ------
section "7b. qgis.service meta-unit"

# This oneshot unit lets operators manage the whole QGIS stack with a single
# command: service qgis start | stop | restart | status
# It orchestrates: Xvfb → QGIS worker sockets → py-qgis-server (supervisor)

# (FastCGI socket units are no longer used — Nginx routes all traffic to py-qgis-server)

cat > /etc/systemd/system/qgis.service <<UNIT
[Unit]
Description=QGIS Server Stack (Xvfb + py-qgis-server)
Documentation=https://docs.lizmap.com
After=network.target postgresql.service
Wants=xvfb.service supervisor.service

[Service]
Type=oneshot
RemainAfterExit=yes

ExecStart=/bin/bash -c 'systemctl start xvfb.service supervisor.service && supervisorctl start py-qgisserver'
ExecStop=/bin/bash  -c 'supervisorctl stop py-qgisserver; systemctl stop xvfb.service'
ExecReload=/bin/bash -c 'systemctl restart xvfb.service; supervisorctl restart py-qgisserver'

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable qgis.service
log "qgis.service created — use: service qgis start | stop | restart | status"

# ---- Lizmap Web Client -------------------------------------------------------
section "8. Lizmap Web Client ${LIZMAP_VERSION}"

LIZMAP_ARCHIVE="lizmap-web-client-${LIZMAP_VERSION}.zip"
LIZMAP_URL="https://github.com/3liz/lizmap-web-client/releases/download/${LIZMAP_VERSION}/${LIZMAP_ARCHIVE}"

# Skip download + install if this exact version is already in place.
# This makes re-runs safe after a mid-script failure (e.g. Nginx error).
LIZMAP_INSTALLED_VER=""
[[ -f "${LIZMAP_DIR}/project.xml" ]] && \
    LIZMAP_INSTALLED_VER=$(grep -oP '(?<=<version>)[^<]+' "${LIZMAP_DIR}/project.xml" 2>/dev/null || true)

if [[ "${LIZMAP_INSTALLED_VER}" == "${LIZMAP_VERSION}" ]]; then
    log "Lizmap ${LIZMAP_VERSION} already installed at ${LIZMAP_DIR} — skipping download."
else
    cd /tmp
    wget -q --show-progress -O "${LIZMAP_ARCHIVE}" "${LIZMAP_URL}"
    unzip -q "${LIZMAP_ARCHIVE}" -d /tmp/lizmap-extract

    # Install to web root
    rm -rf "${LIZMAP_DIR}"
    mv "/tmp/lizmap-extract/lizmap-web-client-${LIZMAP_VERSION}" "${LIZMAP_DIR}"
    rm -f "/tmp/${LIZMAP_ARCHIVE}"
fi

# Configure + install only when freshly extracted (installer.php writes a
# installed.json / installer.ini marker when it completes successfully).
cd "${LIZMAP_DIR}"
if [[ -f "lizmap/var/config/installer.ini.php" ]]; then
    log "Lizmap installer already ran — skipping configuration and installer steps."
else

cp lizmap/var/config/lizmapConfig.ini.php.dist   lizmap/var/config/lizmapConfig.ini.php
cp lizmap/var/config/localconfig.ini.php.dist    lizmap/var/config/localconfig.ini.php
cp lizmap/var/config/profiles.ini.php.dist       lizmap/var/config/profiles.ini.php

# Set QGIS Server URL in lizmapConfig
sed -i "s|wmsServerURL=.*|wmsServerURL=http://127.0.0.1/qgis/|" \
    lizmap/var/config/lizmapConfig.ini.php 2>/dev/null || true

# PostgreSQL profile (if installed)
# Replace ALL existing [jdb:default] and [jdb:jauth] sections so there are no
# duplicates — duplicate section names cause Jelix to use unpredictable values.
if [[ "$INSTALL_POSTGRESQL" == "true" ]]; then
    # Wait until PostgreSQL is actually accepting connections (max 30 s)
    log "Waiting for PostgreSQL to accept connections..."
    for i in $(seq 1 30); do
        pg_isready -h localhost -p 5432 -U "${PG_LIZMAP_USER}" -d "${PG_LIZMAP_DB}" \
            -q && break || sleep 1
    done
    pg_isready -h localhost -p 5432 -U "${PG_LIZMAP_USER}" -d "${PG_LIZMAP_DB}" \
        || error "PostgreSQL is not ready after 30 s — check: systemctl status postgresql"

    # Write a clean profiles.ini.php with only PostgreSQL sections.
    # The dist file uses SQLite; we overwrite it entirely to avoid duplicate keys.
    cat > lizmap/var/config/profiles.ini.php <<PROFILES
; Lizmap database profiles — managed by install script
; jdb:default  is used by Jelix core (sessions, rights cache)
; jdb:jauth    is used by jCommunity / authentication module
; jdb:lizlog   is used by Lizmap for request logging

[jdb:default]
driver=pgsql
host=127.0.0.1
port=5432
database=${PG_LIZMAP_DB}
user=${PG_LIZMAP_USER}
password=${PG_LIZMAP_PASS}

[jdb:jauth]
driver=pgsql
host=127.0.0.1
port=5432
database=${PG_LIZMAP_DB}
user=${PG_LIZMAP_USER}
password=${PG_LIZMAP_PASS}

[jdb:lizlog]
driver=pgsql
host=127.0.0.1
port=5432
database=${PG_LIZMAP_DB}
user=${PG_LIZMAP_USER}
password=${PG_LIZMAP_PASS}
PROFILES
    log "PostgreSQL profiles written to profiles.ini.php."

    # jcache profiles — Jelix file-based cache for QGIS projects and requests
    cat >> lizmap/var/config/profiles.ini.php <<PROFILES

[jcache:default]
driver=file
storage_dir=${LIZMAP_DIR}/lizmap/var/cache
ttl=300

[jcache:qgisprojects]
driver=file
storage_dir=${LIZMAP_DIR}/lizmap/var/cache/qgisprojects
ttl=300

[jcache:requests]
driver=file
storage_dir=${LIZMAP_DIR}/lizmap/var/cache/requests
ttl=300
PROFILES
    log "profiles.ini.php: jcache-Profile hinzugefügt."
else
    # SQLite mode (default): ensure the db directory exists and is writable
    mkdir -p lizmap/var/db
    log "SQLite mode: lizmap/var/db created."
fi

# Create all directories the installer will write into BEFORE setting rights.
# Missing dirs cause "Permission denied" even after set_rights.sh runs.
# IMPORTANT: use absolute paths — CWD is ${LIZMAP_DIR} (/var/www/lizmap),
# so relative "lizmap/temp" would create the wrong path lizmap/lizmap/temp.
# temp/ lives at ${LIZMAP_DIR}/temp/ (one level above the app's lizmap/ dir).
mkdir -p "${LIZMAP_DIR}/lizmap/var/db"
mkdir -p "${LIZMAP_DIR}/lizmap/var/log"
mkdir -p "${LIZMAP_DIR}/lizmap/var/cache"
mkdir -p "${LIZMAP_DIR}/lizmap/var/cache/qgisprojects"
mkdir -p "${LIZMAP_DIR}/lizmap/var/cache/requests"
chown -R "${LIZMAP_USER}:${LIZMAP_GROUP}" "${LIZMAP_DIR}/lizmap/var/cache"
mkdir -p "${LIZMAP_DIR}/temp"
mkdir -p "${LIZMAP_DIR}/temp/lizmap"
mkdir -p "${LIZMAP_DIR}/lizmap/www/assets/jelix"

# Set ownership and permissions via the official script
bash lizmap/install/set_rights.sh "${LIZMAP_USER}" "${LIZMAP_GROUP}"

# Extra: recursively ensure www-data owns the entire tree.
# ${LIZMAP_DIR}/temp parent is created by root (mkdir) — explicitly fix it.
chown -R "${LIZMAP_USER}:${LIZMAP_GROUP}" "${LIZMAP_DIR}/lizmap/www/"
chown -R "${LIZMAP_USER}:${LIZMAP_GROUP}" "${LIZMAP_DIR}/lizmap/var/"
chown -R "${LIZMAP_USER}:${LIZMAP_GROUP}" "${LIZMAP_DIR}/temp/"

# ---- Pre-flight: verify PHP can reach the database before handing off --------
if [[ "$INSTALL_POSTGRESQL" == "true" ]]; then
    log "Testing PHP -> PostgreSQL connectivity..."
    PHP_TEST_RESULT=$(sudo -u "${LIZMAP_USER}" php -r "
        error_reporting(E_ALL);
        \$ok = false;
        // Test 1: pgsql extension
        if (!extension_loaded('pgsql')) { echo 'FAIL: pgsql extension not loaded'; exit(1); }
        // Test 2: pdo_pgsql extension
        if (!extension_loaded('pdo_pgsql')) { echo 'FAIL: pdo_pgsql extension not loaded'; exit(1); }
        // Test 3: actual TCP connection
        \$dsn = 'pgsql:host=127.0.0.1;port=5432;dbname=${PG_LIZMAP_DB}';
        try {
            \$pdo = new PDO(\$dsn, '${PG_LIZMAP_USER}', '${PG_LIZMAP_PASS}',
                           [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
            echo 'OK';
        } catch (PDOException \$e) {
            echo 'FAIL: ' . \$e->getMessage();
            exit(1);
        }
    " 2>&1)
    if [[ "${PHP_TEST_RESULT}" == "OK" ]]; then
        log "PHP -> PostgreSQL: connection OK."
    else
        error "PHP -> PostgreSQL connection FAILED: ${PHP_TEST_RESULT}
  Diagnostics:
    php -m | grep pgsql       -> $(php -m 2>/dev/null | grep -i pgsql || echo 'none')
    pg_hba.conf               -> $(sudo -u postgres psql -tAc 'SHOW hba_file;' 2>/dev/null)
    PostgreSQL listen_addr    -> $(sudo -u postgres psql -tAc 'SHOW listen_addresses;' 2>/dev/null)
  Fix: check pg_hba.conf and restart postgresql, then re-run the script."
    fi
fi

# Run installer as www-data (same user PHP-FPM runs as) to avoid permission
# mismatches on SQLite files or PostgreSQL socket authentication.
log "Running Lizmap installer..."
sudo -u "${LIZMAP_USER}" php lizmap/install/installer.php \
    || error "Lizmap installer failed — check output above and /var/log/install_lizmap_qgisserver.log"

# Fix basePath so Jelix generates correct asset URLs when served from /
MAIN_CONFIG="${LIZMAP_DIR}/lizmap/app/system/mainconfig.ini.php"
if [ -f "${MAIN_CONFIG}" ]; then
    sed -i 's/^basePath=$/basePath=\//' "${MAIN_CONFIG}"
    log "mainconfig.ini.php: basePath=/ gesetzt."
fi

fi  # end: fresh-install-only block

# QGIS projects symlink inside Lizmap
ln -sf "${QGIS_PROJECTS_DIR}" "${LIZMAP_DIR}/lizmap/var/lizmap-theme-config" 2>/dev/null || true
mkdir -p "${LIZMAP_DIR}/lizmap/var/lizmap-theme-config"

log "Lizmap Web Client ${LIZMAP_VERSION} installed at ${LIZMAP_DIR}."

# ---- Lizmap: set OGC / QGIS Server URL in lizmapConfig.ini.php --------------
# Lizmap must know where to send OGC requests (WMS/WFS).
# py-qgis-server listens on 127.0.0.1:8080 — Nginx proxies this as /qgis/.
# We write the URL into lizmapConfig.ini.php so it is set from the start.
LIZMAP_CONFIG="${LIZMAP_DIR}/lizmap/var/config/lizmapConfig.ini.php"
if [ -f "${LIZMAP_CONFIG}" ]; then
    # Set wmsServerURL to the Nginx proxy path (internal loopback)
    # py-qgis-server port 7200, OGC path /ows/, Lizmap API path /lizmap/
    if grep -q "^wmsServerURL" "${LIZMAP_CONFIG}"; then
        sed -i "s|^wmsServerURL.*|wmsServerURL=\"http://127.0.0.1:7200/ows/\"|" "${LIZMAP_CONFIG}"
    else
        sed -i '/^\[services\]/a wmsServerURL="http://127.0.0.1:7200/ows/"' "${LIZMAP_CONFIG}"
    fi
    if grep -q "^wmsServerType" "${LIZMAP_CONFIG}"; then
        sed -i "s|^wmsServerType.*|wmsServerType=\"py-qgis-server\"|" "${LIZMAP_CONFIG}"
    else
        sed -i '/^\[services\]/a wmsServerType="py-qgis-server"' "${LIZMAP_CONFIG}"
    fi
    # Lizmap plugin API base URL (used for GetFeatureInfo extensions etc.)
    if grep -q "^lizmapPluginAPIURL" "${LIZMAP_CONFIG}"; then
        sed -i "s|^lizmapPluginAPIURL.*|lizmapPluginAPIURL=\"http://127.0.0.1:7200/lizmap/\"|" "${LIZMAP_CONFIG}"
    else
        sed -i '/^\[services\]/a lizmapPluginAPIURL="http://127.0.0.1:7200/lizmap/"' "${LIZMAP_CONFIG}"
    fi
    chown "${LIZMAP_USER}:${LIZMAP_GROUP}" "${LIZMAP_CONFIG}"
    log "lizmapConfig.ini.php: wmsServerURL=http://127.0.0.1:7200/ows/ / lizmapPluginAPIURL=http://127.0.0.1:7200/lizmap/"
else
    warn "lizmapConfig.ini.php not found — set wmsServerURL manually in Lizmap admin panel."
fi

# ---- localconfig.ini.php: disable FCGI wrapper warning ----------------------
# Lizmap 3.9+ shows an informational banner "does not allow QGIS with FCGI"
# on every page until the admin confirms py-qgis-server in localconfig.ini.php.
# Setting wrapperCheckDisabled=true suppresses the banner (we ARE using
# py-qgis-server, so the check is satisfied).
LOCAL_CONFIG="${LIZMAP_DIR}/lizmap/var/config/localconfig.ini.php"
if [ -f "${LOCAL_CONFIG}" ]; then
    if ! grep -q "wrapperCheckDisabled" "${LOCAL_CONFIG}"; then
        cat >> "${LOCAL_CONFIG}" <<'LOCALCFG'

[modules]
lizmap.installparam={"wrapperCheckDisabled":true}
LOCALCFG
        chown "${LIZMAP_USER}:${LIZMAP_GROUP}" "${LOCAL_CONFIG}"
        log "localconfig.ini.php: wrapperCheckDisabled=true gesetzt (py-qgis-server wird verwendet)."
    fi
fi

# ---- Nginx configuration -----------------------------------------------------
section "9. Nginx virtual host configuration"

# Lizmap 3.9+ requires py-qgis-server as HTTP wrapper — direct FastCGI is no
# longer supported. Nginx proxies /ows/ and /lizmap/ to py-qgis-server on port 7200.

# Remove default vhost — it listens on port 80 and blocks the lizmap site
rm -f /etc/nginx/sites-enabled/default
log "Nginx: default vhost deaktiviert."

# Shared location blocks — included by both server blocks below.
# This avoids duplicating the full Lizmap config.
cat > /etc/nginx/lizmap-common.conf <<'NGINXCOMMON'
    # ---- Lizmap Web Client --------------------------------------------------
    root LIZMAP_WWW_ROOT;
    index index.php;

    client_max_body_size 200M;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript
               text/xml application/xml application/xml+rss text/javascript;

    location / {
        try_files $uri $uri/ /index.php$is_args$args;
    }

    location ~ [^/]\.php(/|$) {
        fastcgi_split_path_info ^(.+?\.php)(/.*)$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_read_timeout 300;
        fastcgi_buffers 8 256k;
        fastcgi_buffer_size 128k;
    }

    # ---- py-qgis-server (HTTP proxy, NOT FastCGI) ---------------------------
    # /ows/    — OGC requests (WMS, WFS, WCS, WMTS)
    # /lizmap/ — Lizmap plugin API
    # /api/    — py-qgis-server REST management API
    location /ows/ {
        proxy_pass         http://127.0.0.1:7200/ows/;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 120s;
        proxy_buffering    off;
        gzip               off;
        add_header 'Access-Control-Allow-Origin'  '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
    }

    location /lizmap/api/ {
        proxy_pass         http://127.0.0.1:7200/lizmap/;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 120s;
        proxy_buffering    off;
        gzip               off;
    }

    location /api/ {
        proxy_pass         http://127.0.0.1:7200/api/;
        proxy_set_header   Host $host;
        proxy_read_timeout 30s;
    }

    # ---- Static assets cache ------------------------------------------------
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # ---- Security headers ---------------------------------------------------
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Block access to sensitive files
    location ~ /\.ht              { deny all; }
    location ~ /\.git             { deny all; }
    location ~ /lizmap/var/config { deny all; }
    location ~ /lizmap/var/db     { deny all; }
    location ~ /lizmap/var/log    { deny all; }
NGINXCOMMON

# Replace placeholder with actual path
sed -i "s|LIZMAP_WWW_ROOT|${LIZMAP_DIR}/lizmap/www|g" /etc/nginx/lizmap-common.conf

# ---- Self-signed certificate for IP access (HTTPS on Block 1) ---------------
# Generates a 10-year self-signed cert with the server's public IP as SAN.
# Browser will show a warning on first visit — add exception once and done.
# certbot does NOT touch Block 1 → this cert remains valid after HTTPS setup.
SSL_DIR="/etc/nginx/ssl"
SSL_CERT="${SSL_DIR}/lizmap-selfsigned.crt"
SSL_KEY="${SSL_DIR}/lizmap-selfsigned.key"

mkdir -p "${SSL_DIR}"
PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout "${SSL_KEY}" \
    -out "${SSL_CERT}" \
    -subj "/CN=lizmap-server" \
    -addext "subjectAltName=IP:${PUBLIC_IP},IP:127.0.0.1" \
    2>/dev/null

chmod 600 "${SSL_KEY}"
chmod 644 "${SSL_CERT}"
log "Selbstsigniertes Zertifikat erstellt: ${SSL_CERT} (IP: ${PUBLIC_IP})"

cat > /etc/nginx/sites-available/lizmap <<NGINX
# Lizmap + py-qgis-server — generated by install script
#
# Two server blocks:
#   Block 1 (default_server): IP and any other hostname → serves Lizmap directly
#              via HTTP and HTTPS (self-signed cert). NOT touched by certbot.
#   Block 2 (domain):         karte1.wandelderzeit.ch → certbot adds HTTPS here.
#
# Result:
#   http://<IP>/                     → Lizmap direkt
#   https://<IP>/                    → Lizmap direkt (self-signed cert, Browserwarnung)
#   http://karte1.wandelderzeit.ch/  → Lizmap (vor HTTPS) / 301 HTTPS (nach certbot)
#   https://karte1.wandelderzeit.ch/ → Lizmap (Let's Encrypt Zertifikat)

# ---- Block 1: IP / catch-all (certbot never touches this) -------------------
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    server_name _;

    ssl_certificate     ${SSL_CERT};
    ssl_certificate_key ${SSL_KEY};
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    access_log /var/log/nginx/lizmap-access.log;
    error_log  /var/log/nginx/lizmap-error.log warn;

    include /etc/nginx/lizmap-common.conf;
}

# ---- Block 2: Domain (certbot modifies this for HTTPS) ----------------------
server {
    listen 80;
    listen [::]:80;
    server_name ${SERVER_NAME};

    access_log /var/log/nginx/lizmap-access.log;
    error_log  /var/log/nginx/lizmap-error.log warn;

    include /etc/nginx/lizmap-common.conf;
}
NGINX

# Enable site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/lizmap /etc/nginx/sites-enabled/lizmap

nginx -t || error "Nginx Konfiguration ungültig — bitte Fehler oben prüfen."
systemctl enable nginx
systemctl restart nginx
log "Nginx configured."

# ---- xRDP + XFCE4 desktop ---------------------------------------------------
if [[ "$INSTALL_XRDP" == "true" ]]; then
    section "10. xRDP + XFCE4 desktop environment"

    log "Installing xRDP + XFCE4 — this may take 5–15 minutes depending on your connection..."
    apt-get install -y -q \
        xfce4 \
        xfce4-goodies \
        xfce4-terminal \
        xfce4-power-manager \
        thunar \
        mousepad \
        xorg \
        dbus-x11 \
        xrdp \
        xorgxrdp \
        pulseaudio \
        pavucontrol \
        xdg-utils \
        xdg-user-dirs \
        mate-polkit \
        at-spi2-core

    # ---- Firefox (native .deb via Mozilla PPA — Snap version fails in RDP) ---
    # Ubuntu 24.04 ships Firefox as a Snap which has no display access in RDP.
    # Install the official Mozilla .deb instead.
    if ! command -v firefox &>/dev/null; then
        log "Installing Firefox (native .deb from Mozilla PPA)..."
        # Remove snap version if present
        snap remove firefox 2>/dev/null || true
        # Add Mozilla apt repository
        install -d -m 0755 /etc/apt/keyrings
        wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg \
             -O /etc/apt/keyrings/packages.mozilla.org.asc
        echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
             > /etc/apt/sources.list.d/mozilla.list
        # Ensure Mozilla PPA takes priority over any Ubuntu firefox stub
        cat > /etc/apt/preferences.d/mozilla <<'MОЗPREF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
MОЗPREF
        apt-get update -qq
        apt-get install -y -qq firefox
        log "Firefox installed successfully."
    else
        log "Firefox already installed — skipping."
    fi

    # ---- Dedicated RDP user --------------------------------------------------
    if ! id "${XRDP_USER}" &>/dev/null; then
        useradd -m -s /bin/bash -G sudo,xrdp "${XRDP_USER}"
        echo "${XRDP_USER}:${XRDP_PASS}" | chpasswd
        log "RDP user '${XRDP_USER}' created."
    else
        # User exists — still set/update password and groups
        echo "${XRDP_USER}:${XRDP_PASS}" | chpasswd
        usermod -aG sudo,xrdp "${XRDP_USER}" 2>/dev/null || true
        warn "User '${XRDP_USER}' already existed — password updated."
    fi

    # Allow QGIS projects dir access
    usermod -aG qgis "${XRDP_USER}" 2>/dev/null || true
    chown -R qgis:qgis "${QGIS_PROJECTS_DIR}"
    chmod -R g+rw "${QGIS_PROJECTS_DIR}"
    chmod g+s "${QGIS_PROJECTS_DIR}"

    # ---- xRDP: use XFCE4 session for all users --------------------------------
    # Global fallback session script
    cat > /etc/xrdp/startwm.sh <<'STARTWM'
#!/bin/sh
# xRDP session startup — uses XFCE4

unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR

if [ -r /etc/default/locale ]; then
    . /etc/default/locale
    export LANG LANGUAGE
fi

# Use XFCE4
exec /usr/bin/startxfce4
STARTWM
    chmod +x /etc/xrdp/startwm.sh

    # Per-user .xsessionrc (applied to XRDP_USER and root skeleton)
    for HOME_DIR in "/home/${XRDP_USER}" "/etc/skel"; do
        mkdir -p "${HOME_DIR}"
        cat > "${HOME_DIR}/.xsessionrc" <<'XSESSION'
export DESKTOP_SESSION=xfce
export GDMSESSION=xfce
export XDG_SESSION_DESKTOP=xfce
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_TYPE=x11
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
XSESSION
        # Ensure XFCE4 is the preferred session
        mkdir -p "${HOME_DIR}/.config"
        cat > "${HOME_DIR}/.config/xfce4-session.rc" <<'XFCERC'
[General]
SessionName=Default
XFCERC
    done
    chown -R "${XRDP_USER}:${XRDP_USER}" "/home/${XRDP_USER}" 2>/dev/null || true

    # ---- Fix: black screen / PolicyKit authentication agent ------------------
    # mate-polkit binary path (Ubuntu 24.04)
    MATE_POLKIT_BIN="/usr/lib/x86_64-linux-gnu/mate-polkit/polkit-mate-authentication-agent-1"
    POLKIT_XFCE="/etc/xdg/autostart/mate-polkit-autostart.desktop"
    if [ ! -f "${POLKIT_XFCE}" ]; then
        cat > "${POLKIT_XFCE}" <<POLKIT
[Desktop Entry]
Type=Application
Name=PolicyKit Authentication Agent
Comment=PolicyKit Authentication Agent (mate-polkit)
Exec=${MATE_POLKIT_BIN}
Terminal=false
NoDisplay=true
StartupNotify=false
Categories=XFCE;
OnlyShowIn=XFCE;
POLKIT
    fi

    # ---- Fix: xrdp colour depth and session bus ------------------------------
    # Ensure xrdp uses 24-bit colour (avoids palette glitches)
    sed -i 's/^#\?max_bpp=.*/max_bpp=32/'       /etc/xrdp/xrdp.ini
    sed -i 's/^#\?xserverbpp=.*/xserverbpp=24/'  /etc/xrdp/xrdp.ini
    # Allow users to reconnect to their existing session
    sed -i 's/^#\?use_vsock=.*/use_vsock=false/' /etc/xrdp/xrdp.ini

    # ---- Fix: /tmp/.X11-unix permissions (needed on Ubuntu 24.04) ------------
    if ! grep -q 'X11DisplayOffset' /etc/xrdp/xrdp.ini; then
        echo "X11DisplayOffset=10" >> /etc/xrdp/xrdp.ini
    fi

    # ---- SSL certificate for xRDP (self-signed) ------------------------------
    if [ ! -f /etc/xrdp/cert.pem ]; then
        openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
            -keyout /etc/xrdp/key.pem \
            -out  /etc/xrdp/cert.pem \
            -subj "/CN=${SERVER_NAME}/O=GIS Server/C=US" 2>/dev/null
        chmod 640 /etc/xrdp/key.pem /etc/xrdp/cert.pem
        chown root:ssl-cert /etc/xrdp/key.pem /etc/xrdp/cert.pem
    fi

    # xrdp must be in ssl-cert group to read the key
    usermod -aG ssl-cert xrdp

    # Update xrdp.ini to use the certificate
    sed -i "s|^#\?certificate=.*|certificate=/etc/xrdp/cert.pem|" /etc/xrdp/xrdp.ini
    sed -i "s|^#\?key_file=.*|key_file=/etc/xrdp/key.pem|"        /etc/xrdp/xrdp.ini

    # ---- Custom xRDP port (if changed from default 3389) ---------------------
    if [[ "${XRDP_PORT}" != "3389" ]]; then
        sed -i "s/^port=.*/port=${XRDP_PORT}/" /etc/xrdp/xrdp.ini
    fi

    # ---- Tune xRDP performance -----------------------------------------------
    sed -i 's/^#\?tcp_nodelay=.*/tcp_nodelay=true/'         /etc/xrdp/xrdp.ini
    sed -i 's/^#\?tcp_keepalive=.*/tcp_keepalive=true/'     /etc/xrdp/xrdp.ini
    sed -i 's/^#\?bulk_compression=.*/bulk_compression=true/' /etc/xrdp/xrdp.ini

    # ---- Systemd: enable and start xRDP -------------------------------------
    systemctl daemon-reload
    systemctl enable xrdp xrdp-sesman
    systemctl restart xrdp xrdp-sesman

    log "xRDP configured on port ${XRDP_PORT}. Desktop: XFCE4."
fi

# ---- pgAdmin4 Desktop --------------------------------------------------------
# Installed AFTER xRDP so that any display manager pulled in as a dependency
# (gdm3 etc.) can be safely purged without breaking xRDP configuration.
if [[ "$INSTALL_POSTGRESQL" == "true" ]]; then
    section "10b. pgAdmin4 Desktop"

    if ! dpkg -l pgadmin4-desktop &>/dev/null; then
        log "Installing pgAdmin4 Desktop (official pgAdmin repository)..."
        install -d -m 0755 /etc/apt/keyrings
        curl -fsSL https://www.pgadmin.org/static/packages_pgadmin_org.pub \
            | gpg --dearmor -o /etc/apt/keyrings/pgadmin.gpg
        echo "deb [signed-by=/etc/apt/keyrings/pgadmin.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" \
            > /etc/apt/sources.list.d/pgadmin4.list
        apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
            --no-install-recommends pgadmin4-desktop

        # Purge any display manager that pgadmin4-desktop may have pulled in.
        # gdm3 / lightdm would take over session management and break xRDP.
        for dm in gdm3 lightdm sddm; do
            if dpkg -l "$dm" &>/dev/null 2>&1; then
                warn "${dm} was pulled in by pgadmin4-desktop — purging to protect xRDP."
                DEBIAN_FRONTEND=noninteractive apt-get purge -y -qq "$dm"
            fi
            systemctl disable "$dm" 2>/dev/null || true
            systemctl stop    "$dm" 2>/dev/null || true
        done
        apt-get autoremove -y -qq

        # xRDP must be restarted after display-manager purge
        if [[ "$INSTALL_XRDP" == "true" ]]; then
            systemctl restart xrdp xrdp-sesman
            log "xRDP restarted after pgAdmin4 install."
        fi

        log "pgAdmin4 Desktop installed — launch via RDP: Applications > Development > pgAdmin 4"
    else
        log "pgAdmin4 Desktop already installed — skipping."
    fi
fi

# ---- Firewall + Fail2ban -----------------------------------------------------
section "11. Firewall and security hardening"

if [[ "$INSTALL_SECURITY" == "true" ]]; then
    # UFW
    if command -v ufw &>/dev/null; then
        ufw allow OpenSSH
        ufw allow 'Nginx Full'
        if [[ "$INSTALL_XRDP" == "true" ]]; then
            ufw allow "${XRDP_PORT}/tcp" comment "xRDP remote desktop"
        fi
        ufw --force enable
        log "UFW firewall configured."
    else
        warn "ufw not found - configure firewall manually."
    fi

    # Fail2ban
    apt-get install -y -qq fail2ban
    cat > /etc/fail2ban/jail.local <<'F2B'
[DEFAULT]
allowipv6 = auto
findtime  = 10m
maxretry  = 5
bantime   = 1h
ignoreip  = 127.0.0.1/8 ::1

[sshd]
enabled  = true
port     = 22
logpath  = /var/log/auth.log
maxretry = 5
bantime  = 1h

[nginx-http-auth]
enabled = true

[nginx-botsearch]
enabled = true
F2B
    systemctl enable fail2ban
    systemctl restart fail2ban
    log "Fail2ban configured (SSH + Nginx)."
else
    log "Security hardening skipped (INSTALL_SECURITY=false)."
fi

# ---- Log directories ---------------------------------------------------------
mkdir -p /var/log/lizmap
chown -R "${LIZMAP_USER}:${LIZMAP_GROUP}" /var/log/lizmap

# ---- HTTPS via Let's Encrypt (certbot) ---------------------------------------
section "12. HTTPS via Let's Encrypt (certbot)"

# Ersten echten Domainnamen aus SERVER_NAME extrahieren (nicht localhost, nicht IP)
CERTBOT_DOMAIN=""
for name in ${SERVER_NAME}; do
    if [[ "${name}" != "localhost" ]] && ! [[ "${name}" =~ ^[0-9]+\.[0-9.]+$ ]]; then
        CERTBOT_DOMAIN="${name}"
        break
    fi
done

if [ -z "${CERTBOT_EMAIL}" ]; then
    log "HTTPS skipped — CERTBOT_EMAIL not set. To enable HTTPS later:"
    log "  certbot --nginx -d ${CERTBOT_DOMAIN:-yourdomain.com}"
elif [ -z "${CERTBOT_DOMAIN}" ]; then
    warn "HTTPS skipped — no real domain found in SERVER_NAME='${SERVER_NAME}'."
    warn "Add your domain to SERVER_NAME and set CERTBOT_EMAIL, then re-run."
else
    log "Running certbot for domain: ${CERTBOT_DOMAIN} (email: ${CERTBOT_EMAIL}) ..."
    if certbot --nginx -d "${CERTBOT_DOMAIN}" \
        --non-interactive --agree-tos -m "${CERTBOT_EMAIL}" \
        --redirect 2>/dev/null; then
        log "certbot: HTTPS configured for ${CERTBOT_DOMAIN}"
        # Block 1 (default_server / IP) ist von certbot unberührt — kein Fix nötig.
        # http://<IP>/ funktioniert weiterhin direkt über Nginx Block 1.
        nginx -t && systemctl reload nginx
        log "Nginx: https://${CERTBOT_DOMAIN} aktiv. IP-Zugriff läuft weiterhin via Block 1."
    else
        warn "certbot failed — DNS für ${CERTBOT_DOMAIN} zeigt möglicherweise nicht auf diesen Server."
        warn "Manuell ausführen: certbot --nginx -d ${CERTBOT_DOMAIN}"
    fi
fi

# ---- Summary -----------------------------------------------------------------
section "Installation complete"

echo ""
echo "============================================================"
echo " Lizmap Web Client  : http://${PUBLIC_IP}/"
echo " Lizmap (HTTPS/IP)  : https://${PUBLIC_IP}/  (self-signed, Browserwarnung einmalig bestätigen)"
echo " QGIS Server WMS    : http://${PUBLIC_IP}/qgis/?SERVICE=WMS"
echo " QGIS projects dir  : ${QGIS_PROJECTS_DIR}"
echo " Lizmap config dir  : ${LIZMAP_DIR}/lizmap/var/config/"
echo "------------------------------------------------------------"
echo " Lizmap admin login : admin / admin"
echo " CHANGE THE PASSWORD immediately after first login!"
echo "------------------------------------------------------------"
if [[ "$INSTALL_POSTGRESQL" == "true" ]]; then
echo " PostgreSQL DB      : ${PG_LIZMAP_DB}  (PostGIS enabled)"
echo " PostgreSQL user    : ${PG_LIZMAP_USER}"
echo " PostgreSQL pass    : ${PG_LIZMAP_PASS}"
echo " pgAdmin4           : Desktop-App (RDP > Applications > Development)"
echo " (save the password — shown only once)"
echo "------------------------------------------------------------"
fi
if [[ "$INSTALL_XRDP" == "true" ]]; then
echo " Remote Desktop     : ${PUBLIC_IP}:${XRDP_PORT}  (RDP / mstsc)"
echo " RDP user           : ${XRDP_USER}"
echo " RDP password       : ${XRDP_PASS}"
echo " (save this password — shown only once)"
echo " Desktop            : XFCE4"
echo " QGIS Desktop       : available inside RDP session"
echo "------------------------------------------------------------"
fi
echo " Xvfb display       : :99  (virtual framebuffer for QGIS rendering)"
echo " Qt platform        : xcb (X11 backend via Xvfb)"
echo "------------------------------------------------------------"
echo " QGIS Stack control:"
echo "   service qgis start   — start Xvfb + workers + py-qgis-server"
echo "   service qgis stop    — stop  all QGIS services"
echo "   service qgis restart — restart all QGIS services"
echo "   service qgis status  — show status"
echo " QGIS Server plugins    : /srv/qgis/plugins/"
echo " QGIS config            : /srv/qgis/server.conf"
echo " QGIS env               : /srv/qgis/config/qgis-service.env"
echo " QGIS projects          : ${QGIS_PROJECTS_DIR}"
echo "------------------------------------------------------------"
echo " Logs:"
echo "   Nginx      : /var/log/nginx/lizmap-*.log"
echo "   PHP-FPM    : /var/log/php8.3-fpm.log"
echo "   QGIS Server: journalctl -u 'qgis-server@*.service'"
echo "   Xvfb       : journalctl -u xvfb.service"
echo "   Supervisor : /var/log/supervisor/py-qgisserver*.log"
if [[ "$INSTALL_XRDP" == "true" ]]; then
echo "   xRDP       : /var/log/xrdp.log  /var/log/xrdp-sesman.log"
fi
if [[ "$INSTALL_SECURITY" == "true" ]]; then
echo "   Fail2ban   : /var/log/fail2ban.log"
fi
echo "============================================================"
echo ""
echo " Install log         : ${LOG_FILE}"
echo "============================================================"
echo ""
echo "Next steps:"
echo "  1. Log in at http://${PUBLIC_IP}/ and change the Lizmap admin password"
echo "  2. Connect via RDP (mstsc / Remmina) to ${PUBLIC_IP}:${XRDP_PORT}"
echo "  3. Open QGIS Desktop in the RDP session to author .qgs/.qgz projects"
echo "  4. Save projects to: ${QGIS_PROJECTS_DIR}"
echo "  5. Install the Lizmap QGIS plugin inside QGIS Desktop to configure"
echo "     per-project publishing options"
if [ -z "${CERTBOT_EMAIL}" ]; then
echo "  6. HTTPS not configured — set CERTBOT_EMAIL in the script header and re-run,"
echo "     or run manually: certbot --nginx -d ${CERTBOT_DOMAIN:-yourdomain.com}"
fi
echo ""
echo "======================================================================"
echo " Installation finished: $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo " Full log saved to   : ${LOG_FILE}"
echo "======================================================================"