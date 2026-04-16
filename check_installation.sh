#!/bin/bash
# =============================================================================
# check_installation.sh — Diagnose-Script für Lizmap + py-qgis-server Stack
# Ubuntu 24.04 LTS
# Verwendung: sudo bash check_installation.sh
#             sudo bash check_installation.sh --fix   (versucht Fehler zu beheben)
# =============================================================================

FIX_MODE=false
[[ "${1:-}" == "--fix" ]] && FIX_MODE=true

# ── Farben ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[1;34m'; CYAN='\033[0;36m'; NC='\033[0m'

OK()      { echo -e "  ${GREEN}[OK]${NC}    $*"; }
FAIL()    { echo -e "  ${RED}[FAIL]${NC}  $*"; }
WARN()    { echo -e "  ${YELLOW}[WARN]${NC}  $*"; }
INFO()    { echo -e "  ${CYAN}[INFO]${NC}  $*"; }
FIX()     { echo -e "  ${YELLOW}[FIX]${NC}   $*"; }
section() { echo -e "\n${BLUE}══════════════════════════════════════════════${NC}"
            echo -e "${BLUE}  $*${NC}"
            echo -e "${BLUE}══════════════════════════════════════════════${NC}"; }

ERRORS=0; WARNINGS=0
fail() { FAIL "$*"; ((ERRORS++)); }
warn() { WARN "$*"; ((WARNINGS++)); }

# ── Konfiguration ─────────────────────────────────────────────────────────────
LIZMAP_DIR="/var/www/lizmap"
LIZMAP_WEBROOT="${LIZMAP_DIR}/lizmap/www"
QGIS_PROJECTS_DIR="/srv/data"
PYQGIS_PORT=7200
PYQGIS_CONF="/srv/qgis/server.conf"
PYQGIS_ENV="/srv/qgis/config/qgis-service.env"
NGINX_CONF="/etc/nginx/sites-enabled/lizmap"
NGINX_AVAILABLE="/etc/nginx/sites-available/lizmap"
NGINX_COMMON="/etc/nginx/lizmap-common.conf"
PHP_VERSION="8.3"
PG_DB="lizmap"
PG_USER="lizmap"
PLUGIN_DIR="/srv/qgis/plugins"
PROFILES="${LIZMAP_DIR}/lizmap/var/config/profiles.ini.php"
LIZMAPCONF="${LIZMAP_DIR}/lizmap/var/config/lizmapConfig.ini.php"

# =============================================================================
section "1. Systemdienste"
# =============================================================================

check_service() {
    local svc="$1" optional="${2:-false}"
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        OK "systemctl: $svc aktiv"
    elif [[ "$optional" == "true" ]]; then
        warn "$svc nicht aktiv (optional)"
    else
        fail "$svc ist NICHT aktiv"
        INFO "  → systemctl start $svc && systemctl enable $svc"
        if $FIX_MODE; then
            FIX "Starte $svc ..."; systemctl start "$svc" 2>/dev/null && OK "  gestartet" || FAIL "  fehlgeschlagen"
        fi
    fi
}

check_service nginx
check_service "php${PHP_VERSION}-fpm"
check_service xvfb
check_service supervisor
check_service postgresql  optional
check_service xrdp        optional

# Supervisor-Prozess py-qgisserver
PY_STATUS=$(supervisorctl status py-qgisserver 2>/dev/null)
if echo "${PY_STATUS}" | grep -q "RUNNING"; then
    UPTIME=$(echo "${PY_STATUS}" | grep -oP 'uptime \K[^\s]+.*')
    OK "py-qgisserver läuft (uptime: ${UPTIME})"
else
    fail "py-qgisserver läuft NICHT"
    INFO "  → supervisorctl start py-qgisserver"
    INFO "  → tail -30 /var/log/supervisor/py-qgisserver-err.log"
    if $FIX_MODE; then
        FIX "Starte py-qgisserver ..."; supervisorctl start py-qgisserver 2>/dev/null
    fi
fi

# =============================================================================
section "2. Ports und Netzwerk"
# =============================================================================

check_port() {
    local port="$1" desc="$2" optional="${3:-false}"
    if ss -tlnp 2>/dev/null | grep -q ":${port}[[:space:]]"; then
        OK "Port ${port} offen (${desc})"
    elif [[ "$optional" == "true" || "$optional" == "optional" ]]; then
        INFO "Port ${port} nicht offen (${desc} — optional)"
    else
        fail "Port ${port} NICHT offen (${desc})"
    fi
}

check_port 80   "Nginx HTTP"
check_port 443  "Nginx HTTPS"       optional   # HTTPS ist optional
check_port 7200 "py-qgis-server"
check_port 5432 "PostgreSQL"        optional
check_port 3389 "xRDP"             optional

# =============================================================================
section "3. py-qgis-server"
# =============================================================================

if [ -f "${PYQGIS_CONF}" ]; then
    OK "server.conf: ${PYQGIS_CONF}"

    # Helper: Wert aus einer bestimmten Sektion lesen
    conf_get() {
        local section="$1" key="$2"
        awk -v sec="[${section}]" -v k="$key" '
            /^\[/ { in_sec = ($0 == sec) }
            in_sec && $0 ~ "^[[:space:]]*"k"[[:space:]]*=" {
                sub(/^[^=]*=[[:space:]]*/, ""); print; exit
            }
        ' "${PYQGIS_CONF}"
    }

    # [server] port
    port_conf=$(conf_get "server" "port" | tr -d ' ')
    if [ "${port_conf}" = "${PYQGIS_PORT}" ]; then
        OK "server.conf: [server] port=${port_conf}"
    else
        fail "server.conf: [server] port=${port_conf:-nicht gesetzt} (erwartet: ${PYQGIS_PORT})"
    fi

    # [server] interfaces
    iface=$(conf_get "server" "interfaces" | tr -d ' ')
    if [ "${iface}" = "127.0.0.1" ]; then
        OK "server.conf: [server] interfaces=127.0.0.1"
    else
        warn "server.conf: [server] interfaces='${iface:-nicht gesetzt}' (erwartet: 127.0.0.1)"
    fi

    # [server] workers
    workers_conf=$(conf_get "server" "workers" | tr -d ' ')
    if [ -n "${workers_conf}" ] && [ "${workers_conf}" -gt 0 ] 2>/dev/null; then
        OK "server.conf: [server] workers=${workers_conf}"
    else
        warn "server.conf: [server] workers='${workers_conf:-nicht gesetzt}'"
    fi

    # [server] memory_high_water_mark
    mhwm=$(conf_get "server" "memory_high_water_mark" | tr -d ' ')
    [ -n "${mhwm}" ] && OK "server.conf: [server] memory_high_water_mark=${mhwm}" \
                       || warn "server.conf: [server] memory_high_water_mark fehlt"

    # [server] timeout
    timeout_conf=$(conf_get "server" "timeout" | tr -d ' ')
    [ -n "${timeout_conf}" ] && OK "server.conf: [server] timeout=${timeout_conf}" \
                               || warn "server.conf: [server] timeout fehlt"

    # [server] restartmon
    restartmon=$(conf_get "server" "restartmon" | tr -d ' ')
    [ -n "${restartmon}" ] && OK "server.conf: [server] restartmon=${restartmon}" \
                             || warn "server.conf: [server] restartmon fehlt"

    # [logging] level
    log_level=$(conf_get "logging" "level" | tr -d ' ')
    [ -n "${log_level}" ] && OK "server.conf: [logging] level=${log_level}" \
                            || warn "server.conf: [logging] level fehlt"

    # [projects.cache] rootdir
    rootdir=$(conf_get "projects.cache" "rootdir" | tr -d ' "')
    if [ -n "${rootdir}" ] && [[ "${rootdir}" == /* ]]; then
        OK "server.conf: [projects.cache] rootdir=${rootdir}"
        [ -d "${rootdir}" ] && OK "  rootdir-Verzeichnis existiert" \
                             || fail "  rootdir ${rootdir} existiert NICHT → mkdir -p ${rootdir}"
    else
        fail "server.conf: rootdir fehlt oder kein absoluter Pfad ('${rootdir}')"
        INFO "  → Muss unter [projects.cache] stehen, z.B.: rootdir=/srv/data"
        if $FIX_MODE; then
            FIX "Korrigiere rootdir in ${PYQGIS_CONF} ..."
            grep -q "^\[projects.cache\]" "${PYQGIS_CONF}" || echo -e "\n[projects.cache]" >> "${PYQGIS_CONF}"
            grep -q "^rootdir" "${PYQGIS_CONF}" \
                && sed -i "s|^rootdir.*|rootdir=${QGIS_PROJECTS_DIR}|" "${PYQGIS_CONF}" \
                || sed -i "/^\[projects\.cache\]/a rootdir=${QGIS_PROJECTS_DIR}" "${PYQGIS_CONF}"
            supervisorctl restart py-qgisserver 2>/dev/null
        fi
    fi

    # [projects.cache] size
    cache_size=$(conf_get "projects.cache" "size" | tr -d ' ')
    [ -n "${cache_size}" ] && OK "server.conf: [projects.cache] size=${cache_size}" \
                             || warn "server.conf: [projects.cache] size fehlt"

    # [projects.cache] strict_check
    strict=$(conf_get "projects.cache" "strict_check" | tr -d ' ')
    [ -n "${strict}" ] && OK "server.conf: [projects.cache] strict_check=${strict}" \
                         || warn "server.conf: [projects.cache] strict_check fehlt"

    # [projects.cache] preload_config
    preload=$(conf_get "projects.cache" "preload_config" | tr -d ' ')
    [ -n "${preload}" ] && OK "server.conf: [projects.cache] preload_config=${preload}" \
                          || warn "server.conf: [projects.cache] preload_config fehlt"

    # [api.endpoints] lizmap_api
    api_ep=$(conf_get "api.endpoints" "lizmap_api" | tr -d ' ')
    if [ "${api_ep}" = "/lizmap" ]; then
        OK "server.conf: [api.endpoints] lizmap_api=/lizmap"
    else
        fail "server.conf: [api.endpoints] lizmap_api='${api_ep:-nicht gesetzt}' (erwartet: /lizmap)"
        INFO "  → Abschnitt [api.endpoints] mit lizmap_api=/lizmap in ${PYQGIS_CONF} eintragen"
    fi

    # [api.enabled] lizmap_api
    api_en=$(conf_get "api.enabled" "lizmap_api" | tr -d ' ')
    if [ "${api_en}" = "yes" ]; then
        OK "server.conf: [api.enabled] lizmap_api=yes"
    else
        fail "server.conf: [api.enabled] lizmap_api='${api_en:-nicht gesetzt}' (erwartet: yes)"
        INFO "  → Abschnitt [api.enabled] mit lizmap_api=yes in ${PYQGIS_CONF} eintragen"
    fi

    # [monitor:amqp] Sektion vorhanden
    if grep -q "^\[monitor:amqp\]" "${PYQGIS_CONF}"; then
        OK "server.conf: [monitor:amqp] Sektion vorhanden"
    else
        warn "server.conf: [monitor:amqp] Sektion fehlt"
    fi

else
    fail "server.conf NICHT gefunden: ${PYQGIS_CONF}"
fi

# HTTP-Antwort testen
RESP=$(curl -s --max-time 5 \
    "http://127.0.0.1:${PYQGIS_PORT}/ows/?SERVICE=WMS&REQUEST=GetCapabilities" 2>/dev/null)
if echo "${RESP}" | grep -q "ServerException\|WMS_Capabilities\|WMT_MS_Capabilities"; then
    if echo "${RESP}" | grep -q "WMS_Capabilities\|WMT_MS_Capabilities"; then
        OK "py-qgis-server: GetCapabilities erfolgreich (Projekt geladen)"
    else
        OK "py-qgis-server antwortet korrekt auf Port ${PYQGIS_PORT}"
        INFO "  ServerException 'No project defined' ist normal ohne geladenes Projekt"
    fi
elif [ -z "${RESP}" ]; then
    fail "py-qgis-server: keine Antwort auf Port ${PYQGIS_PORT}"
    INFO "  → supervisorctl restart py-qgisserver"
    INFO "  → tail -50 /var/log/supervisor/py-qgisserver-err.log"
else
    fail "py-qgis-server: unerwartete Antwort"
    echo "${RESP}" | head -3 | sed 's/^/         /'
fi

# Lizmap-API testen (/lizmap/server.json — benötigt QGSRV_API_ENABLED_LIZMAP=yes)
RESP_API=$(curl -s --max-time 5 "http://127.0.0.1:${PYQGIS_PORT}/lizmap/server.json" 2>/dev/null)
if echo "${RESP_API}" | grep -q '"version"'; then
    LZ_VER=$(echo "${RESP_API}" | python3 -c "
import sys,json
d=json.load(sys.stdin)
# Version liegt unter qgis_server.plugins.lizmap_server.version
v = d.get('qgis_server',{}).get('plugins',{}).get('lizmap_server',{}).get('version')
# Fallback: py_qgis_server.version
if not v: v = d.get('qgis_server',{}).get('py_qgis_server',{}).get('version')
print(v or '?')
" 2>/dev/null)
    OK "Lizmap Plugin API /lizmap/server.json antwortet (lizmap_server v${LZ_VER})"
elif echo "${RESP_API}" | grep -q "Invalid resource path"; then
    fail "Lizmap Plugin API /lizmap/server.json → 404 (QGSRV_API_ENABLED_LIZMAP=yes fehlt!)"
    INFO "  → echo 'QGSRV_API_ENABLED_LIZMAP=yes' >> ${PYQGIS_ENV}"
    INFO "  → supervisorctl restart py-qgisserver"
    if $FIX_MODE; then
        FIX "Aktiviere QGSRV_API_ENABLED_LIZMAP ..."
        grep -q "QGSRV_API_ENABLED_LIZMAP" "${PYQGIS_ENV}" \
            || echo -e "\nQGSRV_API_ENABLED_LIZMAP=yes\nQGSRV_API_ENDPOINTS_LIZMAP=/lizmap" >> "${PYQGIS_ENV}"
        SUPCONF="/etc/supervisor/conf.d/py-qgisserver.conf"
        if [ -f "${SUPCONF}" ] && ! grep -q "QGSRV_API_ENABLED_LIZMAP" "${SUPCONF}"; then
            sed -i 's/\(environment=.*\)"/\1,QGSRV_API_ENABLED_LIZMAP="yes",QGSRV_API_ENDPOINTS_LIZMAP="\/lizmap"/' "${SUPCONF}"
        fi
        supervisorctl reread && supervisorctl update && supervisorctl restart py-qgisserver 2>/dev/null
        sleep 5
        RESP_API2=$(curl -s --max-time 5 "http://127.0.0.1:${PYQGIS_PORT}/lizmap/server.json" 2>/dev/null)
        echo "${RESP_API2}" | grep -q '"version"' && OK "  Lizmap API aktiv nach Fix" || FAIL "  Lizmap API immer noch nicht erreichbar"
    fi
else
    warn "Lizmap Plugin API /lizmap/server.json: unerwartete Antwort"
fi

# Venv prüfen (offizieller Install-Pfad)
PYQGIS_VENV="/opt/local/py-qgis-server"
if [ -x "${PYQGIS_VENV}/bin/qgisserver" ]; then
    OK "py-qgis-server venv: ${PYQGIS_VENV}/bin/qgisserver"
    PY_VER=$("${PYQGIS_VENV}/bin/qgisserver" --version 2>/dev/null | head -1)
    [ -n "${PY_VER}" ] && INFO "  Version: ${PY_VER}"
else
    fail "py-qgis-server venv fehlt: ${PYQGIS_VENV}/bin/qgisserver"
    INFO "  → python3 -m venv ${PYQGIS_VENV} --system-site-packages"
    INFO "  → ${PYQGIS_VENV}/bin/pip install py-qgis-server"
    if $FIX_MODE; then
        FIX "Installiere py-qgis-server in venv ..."
        apt-get install -y -q python3-psutil python3-venv 2>/dev/null
        python3 -m venv "${PYQGIS_VENV}" --system-site-packages
        "${PYQGIS_VENV}/bin/pip" install -q -U pip setuptools wheel pysocks typing_extensions
        "${PYQGIS_VENV}/bin/pip" install -q py-qgis-server
        ln -sf "${PYQGIS_VENV}/bin/qgisserver" /usr/local/bin/qgisserver 2>/dev/null || true
        # Supervisor-Befehl auf venv-Pfad aktualisieren
        SUPCONF="/etc/supervisor/conf.d/py-qgisserver.conf"
        if [ -f "${SUPCONF}" ]; then
            sed -i "s|^command=.*qgisserver.*|command=${PYQGIS_VENV}/bin/qgisserver -c /srv/qgis/server.conf|" "${SUPCONF}"
            supervisorctl reread && supervisorctl update && supervisorctl restart py-qgisserver 2>/dev/null
            OK "Supervisor auf venv-Pfad aktualisiert"
        fi
    fi
fi

# Fehlerlog — "No project defined" und "Invalid resource path" filtern (erwartet)
ERRLOG="/var/log/supervisor/py-qgisserver-err.log"
if [ -f "${ERRLOG}" ]; then
    REAL_ERRORS=$(tail -30 "${ERRLOG}" \
        | grep -i "error\|exception\|fatal" \
        | grep -iv "No project defined\|Invalid resource path\|No project defined for WMS\|Service unknown or unsupported\|ServiceException\|SampleService" \
        | tail -5)
    if [ -n "${REAL_ERRORS}" ]; then
        warn "Fehler in py-qgisserver-err.log:"
        echo "${REAL_ERRORS}" | sed 's/^/         /'
    else
        OK "py-qgisserver-err.log: keine kritischen Fehler"
    fi
fi

# =============================================================================
section "4. Nginx"
# =============================================================================

nginx -t 2>/dev/null && OK "nginx -t: Konfiguration gültig" \
    || { fail "nginx -t: Fehler"; nginx -t 2>&1 | sed 's/^/         /'; }

[ -f "${NGINX_CONF}" ] && OK "Nginx vhost aktiviert: ${NGINX_CONF}" \
    || { fail "Nginx vhost nicht aktiviert"
         INFO "  → ln -sf ${NGINX_AVAILABLE} ${NGINX_CONF} && systemctl restart nginx"; }

# Default-Vhost blockiert Port 80 wenn aktiv
if [ -f "/etc/nginx/sites-enabled/default" ]; then
    fail "Nginx: default-Vhost aktiv — blockiert Port 80 für Lizmap!"
    INFO "  → rm /etc/nginx/sites-enabled/default && systemctl restart nginx"
    if $FIX_MODE; then
        FIX "Entferne Nginx default-Vhost ..."
        rm -f /etc/nginx/sites-enabled/default
        systemctl restart nginx && OK "nginx neu gestartet"
    fi
else
    OK "Nginx: default-Vhost deaktiviert ✓"
fi

# lizmap-common.conf (shared location blocks)
if [ -f "${NGINX_COMMON}" ]; then
    OK "Nginx: lizmap-common.conf vorhanden"
else
    warn "Nginx: ${NGINX_COMMON} fehlt — gemeinsame Location-Blöcke nicht gefunden"
fi

# root-Direktive — steht in lizmap-common.conf (bevorzugt) oder direkt im vhost
NGINX_ROOT=$(grep -h "^\s*root " "${NGINX_COMMON}" "${NGINX_CONF}" 2>/dev/null \
             | grep -v "^\s*#" | head -1 | awk '{print $2}' | tr -d ';')
if [ -n "${NGINX_ROOT}" ]; then
    if [ -f "${NGINX_ROOT}/index.php" ]; then
        OK "Nginx root: ${NGINX_ROOT} (index.php vorhanden)"
    else
        fail "Nginx root: ${NGINX_ROOT} — index.php fehlt"
        INFO "  → Korrekt: root ${LIZMAP_WEBROOT};"
        if $FIX_MODE; then
            FIX "Korrigiere Nginx root in lizmap-common.conf ..."
            sed -i "s|^\s*root .*;|    root ${LIZMAP_WEBROOT};|" "${NGINX_COMMON}"
            nginx -t && systemctl restart nginx
        fi
    fi
else
    warn "Nginx root-Direktive nicht gefunden (weder in ${NGINX_COMMON} noch ${NGINX_CONF})"
fi

# server_name — über alle server_name-Zeilen im vhost prüfen (zwei Blöcke)
ALL_SERVER_NAMES=$(grep -h "^\s*server_name " "${NGINX_CONF}" 2>/dev/null \
    | grep -v "^\s*#" | sed 's/.*server_name[[:space:]]*//;s/;//' | tr '\n' ' ')
# default_server Block hat server_name _ — das ist korrekt für IP-Zugriff
if grep -q "server_name\s*_" "${NGINX_CONF}" 2>/dev/null; then
    OK "Nginx: Block 1 (default_server) mit server_name _ vorhanden → IP-Zugriff direkt"
else
    warn "Nginx: kein default_server-Block mit server_name _ gefunden"
    INFO "  → IP-Zugriff funktioniert möglicherweise nicht direkt"
fi
if echo "${ALL_SERVER_NAMES}" | grep -qw "karte1.wandelderzeit.ch"; then
    OK "Nginx: Block 2 enthält server_name 'karte1.wandelderzeit.ch'"
else
    warn "Nginx: 'karte1.wandelderzeit.ch' nicht in server_name gefunden (aktuell: '${ALL_SERVER_NAMES}')"
    INFO "  → server_name in Block 2 von ${NGINX_AVAILABLE} setzen"
fi

# Proxy zu py-qgis-server auf Port 7200
if grep -qh "proxy_pass.*${PYQGIS_PORT}" "${NGINX_COMMON}" "${NGINX_CONF}" 2>/dev/null; then
    OK "Nginx: proxy_pass → http://127.0.0.1:${PYQGIS_PORT}"
else
    fail "Nginx: kein proxy_pass auf Port ${PYQGIS_PORT} gefunden"
    INFO "  → /ows/ muss auf http://127.0.0.1:${PYQGIS_PORT}/ows/ proxyen"
fi

# HTTP-Status
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://127.0.0.1/" 2>/dev/null)
case "${HTTP_CODE}" in
    200|301|302) OK "HTTP http://127.0.0.1/ → ${HTTP_CODE}" ;;
    403) fail "HTTP → 403 Forbidden — Nginx root falsch konfiguriert"
         INFO "  → root muss auf ${LIZMAP_WEBROOT} zeigen" ;;
    500) fail "HTTP → 500 Internal Server Error — PHP/Lizmap Fehler"
         INFO "  → tail -20 /var/log/nginx/lizmap-error.log"
         INFO "  → tail -20 /var/log/php${PHP_VERSION}-fpm.log"
         if $FIX_MODE; then
             FIX "Repariere Verzeichnisse und Berechtigungen ..."
             mkdir -p "${LIZMAP_DIR}/temp/lizmap" "${LIZMAP_DIR}/lizmap/var/cache" \
                      "${LIZMAP_DIR}/lizmap/var/log" "${LIZMAP_DIR}/lizmap/var/db"
             chown -R www-data:www-data "${LIZMAP_DIR}/temp" "${LIZMAP_DIR}/lizmap/var"
             bash "${LIZMAP_DIR}/lizmap/install/set_rights.sh" www-data www-data 2>/dev/null
             systemctl restart "php${PHP_VERSION}-fpm" nginx
         fi ;;
    502) fail "HTTP → 502 Bad Gateway — PHP-FPM Socket fehlt"
         INFO "  → systemctl restart php${PHP_VERSION}-fpm" ;;
    *)   fail "HTTP → ${HTTP_CODE:-keine Antwort}" ;;
esac

# HTTPS via self-signed cert (Block 1 / IP)
SSL_CERT="/etc/nginx/ssl/lizmap-selfsigned.crt"
SSL_KEY="/etc/nginx/ssl/lizmap-selfsigned.key"

if [ -f "${SSL_CERT}" ] && [ -f "${SSL_KEY}" ]; then
    # Ablaufdatum prüfen
    EXPIRY=$(openssl x509 -enddate -noout -in "${SSL_CERT}" 2>/dev/null \
             | sed 's/notAfter=//')
    DAYS_LEFT=$(( ( $(date -d "${EXPIRY}" +%s 2>/dev/null || echo 0) - $(date +%s) ) / 86400 ))
    # SAN prüfen
    SAN=$(openssl x509 -text -noout -in "${SSL_CERT}" 2>/dev/null \
          | grep -A1 "Subject Alternative Name" | tail -1 | tr -d ' ')
    OK "Self-signed cert: ${SSL_CERT} (gültig noch ${DAYS_LEFT} Tage, SAN: ${SAN})"

    # HTTPS-Antwort testen
    HTTPS_CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 5 \
                 "https://127.0.0.1/" 2>/dev/null)
    case "${HTTPS_CODE}" in
        200|301|302) OK "HTTPS https://127.0.0.1/ → ${HTTPS_CODE}" ;;
        *)           fail "HTTPS https://127.0.0.1/ → ${HTTPS_CODE:-keine Antwort}"
                     INFO "  → nginx -t && systemctl reload nginx" ;;
    esac
else
    warn "Self-signed Zertifikat fehlt: ${SSL_CERT}"
    INFO "  → HTTPS über IP nicht verfügbar. Zertifikat neu generieren:"
    INFO "    PUBLIC_IP=\$(curl -s ifconfig.me)"
    INFO "    mkdir -p /etc/nginx/ssl"
    INFO "    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \\"
    INFO "      -keyout ${SSL_KEY} -out ${SSL_CERT} \\"
    INFO "      -subj '/CN=lizmap-server' \\"
    INFO "      -addext \"subjectAltName=IP:\${PUBLIC_IP},IP:127.0.0.1\""
    INFO "    nginx -t && systemctl reload nginx"
    if $FIX_MODE; then
        FIX "Generiere self-signed Zertifikat ..."
        PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null \
                    || hostname -I | awk '{print $1}')
        mkdir -p /etc/nginx/ssl
        openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
            -keyout "${SSL_KEY}" -out "${SSL_CERT}" \
            -subj "/CN=lizmap-server" \
            -addext "subjectAltName=IP:${PUBLIC_IP},IP:127.0.0.1" 2>/dev/null \
            && chmod 600 "${SSL_KEY}" && chmod 644 "${SSL_CERT}" \
            && OK "Zertifikat erstellt (${PUBLIC_IP})" \
            || warn "Zertifikat-Generierung fehlgeschlagen"
        # HTTPS-Listener in Block 1 prüfen/ergänzen
        if ! grep -q "listen 443 ssl default_server" "${NGINX_AVAILABLE}" 2>/dev/null; then
            warn "listen 443 ssl default_server fehlt in ${NGINX_AVAILABLE} — manuell ergänzen"
        else
            nginx -t && systemctl reload nginx
        fi
    fi
fi

# =============================================================================
section "5. PHP"
# =============================================================================

PHP_VER=$(php -r "echo PHP_VERSION;" 2>/dev/null)
[ -n "${PHP_VER}" ] && OK "PHP: ${PHP_VER}" || fail "PHP nicht gefunden"

for ext in pgsql pdo_pgsql curl json mbstring zip gd xml; do
    if php -m 2>/dev/null | grep -qi "^${ext}$"; then
        OK "PHP Extension: ${ext}"
    else
        fail "PHP Extension fehlt: ${ext}"
        INFO "  → phpenmod -v ${PHP_VERSION} ${ext} && systemctl restart php${PHP_VERSION}-fpm"
        if $FIX_MODE; then
            FIX "Aktiviere PHP Extension ${ext} ..."
            phpenmod -v "${PHP_VERSION}" "${ext}" 2>/dev/null
        fi
    fi
done

PHP_FPM_SOCK="/run/php/php${PHP_VERSION}-fpm.sock"
[ -S "${PHP_FPM_SOCK}" ] && OK "PHP-FPM Socket: ${PHP_FPM_SOCK}" \
    || fail "PHP-FPM Socket fehlt: ${PHP_FPM_SOCK}"

# =============================================================================
section "6. Lizmap Web Client"
# =============================================================================

[ -d "${LIZMAP_DIR}" ]            && OK  "Lizmap-Verzeichnis: ${LIZMAP_DIR}" \
                                  || fail "Lizmap-Verzeichnis fehlt: ${LIZMAP_DIR}"
[ -f "${LIZMAP_WEBROOT}/index.php" ] && OK  "Web Root: ${LIZMAP_WEBROOT}/index.php" \
                                       || fail "index.php fehlt in ${LIZMAP_WEBROOT}"

if [ -f "${LIZMAPCONF}" ]; then
    OK "lizmapConfig.ini.php vorhanden"
    WMS_URL=$(grep "^wmsServerURL"       "${LIZMAPCONF}" | cut -d= -f2- | tr -d '" ')
    WMS_TYPE=$(grep "^wmsServerType"     "${LIZMAPCONF}" | cut -d= -f2- | tr -d '" ')
    LZAPI_URL=$(grep "^lizmapPluginAPIURL" "${LIZMAPCONF}" | cut -d= -f2- | tr -d '" ')
    INFO "wmsServerURL:       ${WMS_URL:-nicht gesetzt}"
    INFO "wmsServerType:      ${WMS_TYPE:-nicht gesetzt}"
    INFO "lizmapPluginAPIURL: ${LZAPI_URL:-nicht gesetzt}"
    [ "${WMS_TYPE}" = "py-qgis-server" ] \
        && OK  "wmsServerType = py-qgis-server ✓" \
        || fail "wmsServerType muss 'py-qgis-server' sein (ist: '${WMS_TYPE}')"
    [[ "${WMS_URL}" == *":${PYQGIS_PORT}"* ]] \
        && OK  "wmsServerURL enthält Port ${PYQGIS_PORT} ✓" \
        || warn "wmsServerURL enthält Port ${PYQGIS_PORT} nicht"
else
    fail "lizmapConfig.ini.php fehlt"
fi

# Installer-Marker
[ -f "${LIZMAP_DIR}/lizmap/var/config/installer.ini.php" ] \
    && OK  "Lizmap Installer durchgelaufen ✓" \
    || warn "Lizmap Installer noch nicht durchgelaufen"

# Schreibrechte
[ -w "${LIZMAP_DIR}/lizmap/var/cache" ] \
    && OK  "Schreibrechte: lizmap/var/cache ✓" \
    || fail "Keine Schreibrechte: ${LIZMAP_DIR}/lizmap/var/cache"

# temp/lizmap Verzeichnis
[ -d "${LIZMAP_DIR}/temp/lizmap" ] \
    && OK  "Verzeichnis: temp/lizmap ✓" \
    || { fail "Verzeichnis fehlt: ${LIZMAP_DIR}/temp/lizmap"
         INFO "  → mkdir -p ${LIZMAP_DIR}/temp/lizmap && chown -R www-data:www-data ${LIZMAP_DIR}/temp"
         if $FIX_MODE; then
             FIX "Erstelle temp/lizmap ..."
             mkdir -p "${LIZMAP_DIR}/temp/lizmap"
             chown -R www-data:www-data "${LIZMAP_DIR}/temp"
         fi; }

# =============================================================================
section "7. PostgreSQL"
# =============================================================================

if systemctl is-active --quiet postgresql 2>/dev/null; then
    OK "PostgreSQL aktiv"

    sudo -u postgres psql -d "${PG_DB}" -c "SELECT 1" &>/dev/null 2>&1 \
        && OK  "Datenbank '${PG_DB}' erreichbar" \
        || fail "Datenbank '${PG_DB}' nicht erreichbar"

    if sudo -u postgres psql -d "${PG_DB}" -c "SELECT PostGIS_Version()" &>/dev/null 2>&1; then
        PGIS_VER=$(sudo -u postgres psql -tAc "SELECT PostGIS_Version();" "${PG_DB}" 2>/dev/null | head -1)
        OK "PostGIS: ${PGIS_VER}"
    else
        warn "PostGIS nicht in '${PG_DB}' aktiviert"
        INFO "  → sudo -u postgres psql -d ${PG_DB} -c 'CREATE EXTENSION IF NOT EXISTS postgis;'"
    fi

    # PHP-Verbindungstest mit Passwort aus profiles.ini.php
    PG_PASS_TEST=$(grep "^password=" "${PROFILES}" 2>/dev/null | head -1 | cut -d= -f2)
    if [ -n "${PG_PASS_TEST}" ]; then
        PHP_PG=$(php -r "
            if(!extension_loaded('pdo_pgsql')){echo 'NO_EXT';exit;}
            try{
                new PDO('pgsql:host=127.0.0.1;dbname=${PG_DB}','${PG_USER}','${PG_PASS_TEST}',
                    [PDO::ATTR_TIMEOUT=>3,PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
                echo 'OK';
            }catch(Exception \$e){echo 'FAIL:'.\$e->getMessage();}
        " 2>/dev/null)
        case "${PHP_PG}" in
            OK)      OK  "PHP → PostgreSQL Verbindung OK" ;;
            NO_EXT)  fail "PHP pdo_pgsql Extension nicht geladen" ;;
            *)       fail "PHP → PostgreSQL: ${PHP_PG}"
                     INFO "  → Passwort in ${PROFILES} prüfen" ;;
        esac
    else
        warn "Kein Passwort in ${PROFILES} gefunden — PHP-Verbindungstest übersprungen"
    fi
else
    INFO "PostgreSQL nicht aktiv — übersprungen"
fi

# =============================================================================
section "8. Xvfb (virtueller Display für QGIS)"
# =============================================================================

if systemctl is-active --quiet xvfb 2>/dev/null; then
    OK "Xvfb aktiv"
    DISPLAY=:99 xdpyinfo &>/dev/null 2>&1 \
        && OK  "Display :99 erreichbar" \
        || warn "Display :99 nicht erreichbar (Xvfb läuft aber Display antwortet nicht)"
else
    fail "Xvfb läuft NICHT"
    INFO "  → systemctl start xvfb"
    if $FIX_MODE; then FIX "Starte Xvfb ..."; systemctl start xvfb; fi
fi

ENV_DISPLAY=$(grep "^DISPLAY" "${PYQGIS_ENV}" 2>/dev/null | head -1)
[ -n "${ENV_DISPLAY}" ] \
    && OK  "qgis-service.env: ${ENV_DISPLAY}" \
    || warn "DISPLAY nicht in ${PYQGIS_ENV} gesetzt"

# Pflicht-Vars aus offizieller Doku prüfen
check_env_var() {
    local var="$1" file="$2" fix_val="$3"
    # auch Supervisor-Conf durchsuchen
    local val
    val=$(grep "${var}" "${file}" 2>/dev/null | head -1 | grep -v "^#")
    if [ -z "${val}" ]; then
        val=$(grep "${var}" /etc/supervisor/conf.d/py-qgisserver.conf 2>/dev/null | head -1)
    fi
    if [ -n "${val}" ]; then
        OK  "${var} gesetzt ✓"
    else
        fail "${var} fehlt — lizmap_server Plugin registriert sonst keine API-Pfade!"
        INFO "  → echo '${var}=${fix_val}' >> ${file}"
        if $FIX_MODE; then
            FIX "Setze ${var} ..."
            echo "${var}=${fix_val}" >> "${file}"
            # Auch in Supervisor-Conf eintragen
            SUPCONF="/etc/supervisor/conf.d/py-qgisserver.conf"
            if [ -f "${SUPCONF}" ]; then
                sed -i "s|environment=|environment=${var}=\"${fix_val}\",|" "${SUPCONF}"
            fi
            supervisorctl reread 2>/dev/null && supervisorctl update 2>/dev/null
            supervisorctl restart py-qgisserver 2>/dev/null
        fi
    fi
}

check_env_var "QGIS_OPTIONS_PATH"               "${PYQGIS_ENV}" "/srv/qgis/"
check_env_var "QGIS_AUTH_DB_DIR_PATH"           "${PYQGIS_ENV}" "/srv/qgis/"
check_env_var "QGIS_SERVER_LIZMAP_REVEAL_SETTINGS" "${PYQGIS_ENV}" "TRUE"
check_env_var "QGSRV_API_ENABLED_LIZMAP"        "${PYQGIS_ENV}" "yes"

# Case-Check: muss TRUE sein (nicht True oder true)
REVEAL_VAL=$(grep "QGIS_SERVER_LIZMAP_REVEAL_SETTINGS" "${PYQGIS_ENV}" \
    /etc/supervisor/conf.d/py-qgisserver.conf 2>/dev/null \
    | grep -v "^#" | head -1 | grep -oP '=\K.*' | tr -d '"')
if [ "${REVEAL_VAL}" = "True" ] || [ "${REVEAL_VAL}" = "true" ]; then
    warn "QGIS_SERVER_LIZMAP_REVEAL_SETTINGS=${REVEAL_VAL} → muss TRUE (Großbuchstaben) sein!"
    if $FIX_MODE; then
        FIX "Korrigiere auf TRUE ..."
        sed -i 's/QGIS_SERVER_LIZMAP_REVEAL_SETTINGS=True/QGIS_SERVER_LIZMAP_REVEAL_SETTINGS=TRUE/g' \
            "${PYQGIS_ENV}" /etc/supervisor/conf.d/py-qgisserver.conf 2>/dev/null
        supervisorctl restart py-qgisserver 2>/dev/null
    fi
fi

# Supervisor-Befehl prüfen: muss -c (nicht --conf) und venv-Pfad verwenden
SUPCONF="/etc/supervisor/conf.d/py-qgisserver.conf"
if [ -f "${SUPCONF}" ]; then
    SUP_CMD=$(grep "^command=" "${SUPCONF}" | head -1)
    if echo "${SUP_CMD}" | grep -q "/opt/local/py-qgis-server/bin/qgisserver"; then
        OK "Supervisor: verwendet venv-Binary ✓"
    else
        fail "Supervisor: verwendet NICHT den venv-Pfad /opt/local/py-qgis-server/bin/qgisserver"
        INFO "  Aktuell: ${SUP_CMD}"
        INFO "  Soll:    command=/opt/local/py-qgis-server/bin/qgisserver -c /srv/qgis/server.conf"
        if $FIX_MODE; then
            FIX "Korrigiere Supervisor-Befehl ..."
            sed -i "s|^command=.*|command=/opt/local/py-qgis-server/bin/qgisserver -c /srv/qgis/server.conf|" "${SUPCONF}"
            supervisorctl reread && supervisorctl update && supervisorctl restart py-qgisserver 2>/dev/null
        fi
    fi
    if echo "${SUP_CMD}" | grep -q "\-\-conf"; then
        fail "Supervisor: verwendet --conf statt -c (falsches Flag!)"
        if $FIX_MODE; then
            FIX "Korrigiere Flag --conf → -c ..."
            sed -i 's/--conf /-c /g' "${SUPCONF}"
            supervisorctl reread && supervisorctl update && supervisorctl restart py-qgisserver 2>/dev/null
        fi
    fi
fi

# =============================================================================
section "9. QGIS Server Plugins"
# =============================================================================

# Plugin-Installationsfunktion (GitHub → plugins.qgis.org Fallback)
fix_install_plugin() {
    local name="$1"
    local gh_repo="$2"     # z.B. 3liz/qgis-atlasprint
    local qgis_url="$3"    # Fallback plugins.qgis.org URL
    local TMP_ZIP="/tmp/plugin_${name}.zip"
    local TMP_DIR="/tmp/plugin_${name}_extract"
    local DONE=false

    # Methode 1: GitHub Releases API
    local gh_dl
    gh_dl=$(curl -s --max-time 15 \
        "https://api.github.com/repos/${gh_repo}/releases/latest" \
        | grep '"browser_download_url"' | grep '\.zip"' | head -1 \
        | sed 's/.*"browser_download_url": "\(.*\)"/\1/')
    [ -z "${gh_dl}" ] && gh_dl="https://github.com/${gh_repo}/archive/refs/heads/master.zip"

    if curl -L --silent --max-time 60 -o "${TMP_ZIP}" "${gh_dl}" \
       && file "${TMP_ZIP}" | grep -qi "zip"; then
        unzip -q "${TMP_ZIP}" -d "${TMP_DIR}" 2>/dev/null
        local SRC
        # Suche direkt nach Verzeichnis mit Plugin-Namen + metadata.txt-Validierung
        SRC=$(find "${TMP_DIR}" -type d -name "${name}" \
              | while read -r d; do [ -f "${d}/metadata.txt" ] && echo "${d}" && break; done)
        if [ -n "${SRC}" ] && [ -d "${SRC}" ]; then
            mv "${SRC}" "${PLUGIN_DIR}/${name}"
            chown -R qgis:qgis "${PLUGIN_DIR}/${name}"
            OK "  ${name} installiert (GitHub)"
            DONE=true
        fi
        rm -rf "${TMP_ZIP}" "${TMP_DIR}"
    fi

    # Methode 2: QGIS Plugin Repository Fallback
    if ! $DONE && [ -n "${qgis_url}" ]; then
        if curl -L --silent --max-time 60 -o "${TMP_ZIP}" "${qgis_url}" \
           && file "${TMP_ZIP}" | grep -qi "zip"; then
            unzip -q "${TMP_ZIP}" -d "${TMP_DIR}" 2>/dev/null
            local SRC
            # Suche nach Verzeichnis mit Plugin-Namen (zuverlässiger als __init__.py-Suche,
            # da Unterverzeichnisse ebenfalls __init__.py enthalten können)
            SRC=$(find "${TMP_DIR}" -type d -name "${name}" \
                  | while read -r d; do [ -f "${d}/metadata.txt" ] && echo "${d}" && break; done)
            if [ -n "${SRC}" ] && [ -d "${SRC}" ]; then
                mv "${SRC}" "${PLUGIN_DIR}/${name}"
                chown -R qgis:qgis "${PLUGIN_DIR}/${name}"
                OK "  ${name} installiert (plugins.qgis.org)"
                DONE=true
            fi
            rm -rf "${TMP_ZIP}" "${TMP_DIR}"
        fi
    fi

    $DONE || FAIL "  ${name}: Download fehlgeschlagen — manuell installieren"
}

declare -A PLUGIN_GHREPO=(
    [atlasprint]="3liz/qgis-atlasprint"
    [lizmap_server]="3liz/qgis-server-lizmap-plugin"
    [wfsOutputExtension]="3liz/qgis-wfsOutputExtension"
)
declare -A PLUGIN_QGISURL=(
    [atlasprint]=""
    [lizmap_server]="https://plugins.qgis.org/plugins/lizmap_server/version/2.14.1/download/"
    [wfsOutputExtension]=""
)

for name in atlasprint lizmap_server wfsOutputExtension; do
    if [ -d "${PLUGIN_DIR}/${name}" ] \
       && [ -f "${PLUGIN_DIR}/${name}/__init__.py" ] \
       && [ -f "${PLUGIN_DIR}/${name}/metadata.txt" ]; then
        ver=$(grep "^version=" "${PLUGIN_DIR}/${name}/metadata.txt" 2>/dev/null | cut -d= -f2)
        OK "Plugin: ${name} ${ver:+(v${ver})}"
    elif [ -d "${PLUGIN_DIR}/${name}" ]; then
        fail "Plugin-Verzeichnis ${name} existiert aber ist unvollständig (metadata.txt oder __init__.py fehlt)"
        INFO "  → rm -rf ${PLUGIN_DIR}/${name}  dann erneut installieren"
        if $FIX_MODE; then
            FIX "Entferne unvollständiges Plugin ${name} und installiere neu ..."
            rm -rf "${PLUGIN_DIR:?}/${name}"
            fix_install_plugin "${name}" "${PLUGIN_GHREPO[${name}]}" "${PLUGIN_QGISURL[${name}]}"
            supervisorctl restart py-qgisserver 2>/dev/null
        fi
    else
        fail "Plugin fehlt: ${name}"
        INFO "  → GitHub: https://github.com/${PLUGIN_GHREPO[${name}]}/releases"
        [ -n "${PLUGIN_QGISURL[${name}]}" ] && INFO "  → QGIS:   ${PLUGIN_QGISURL[${name}]}"
        if $FIX_MODE; then
            FIX "Installiere Plugin ${name} ..."
            fix_install_plugin "${name}" "${PLUGIN_GHREPO[${name}]}" "${PLUGIN_QGISURL[${name}]}"
            supervisorctl restart py-qgisserver 2>/dev/null
        fi
    fi
done

# Pluginpfad-Prüfung (beide Variablen)
PPATH_QGSRV=$(grep "^QGSRV_SERVER_PLUGINPATH" "${PYQGIS_ENV}" 2>/dev/null | cut -d= -f2)
PPATH_QGIS=$(grep "^QGIS_PLUGINPATH"          "${PYQGIS_ENV}" 2>/dev/null | cut -d= -f2)
if [ -n "${PPATH_QGSRV}" ]; then
    OK  "QGSRV_SERVER_PLUGINPATH=${PPATH_QGSRV}"
else
    fail "QGSRV_SERVER_PLUGINPATH nicht in ${PYQGIS_ENV} gesetzt"
    INFO "  → echo 'QGSRV_SERVER_PLUGINPATH=/srv/qgis/plugins' >> ${PYQGIS_ENV}"
    if $FIX_MODE; then
        FIX "Setze QGSRV_SERVER_PLUGINPATH ..."
        echo "QGSRV_SERVER_PLUGINPATH=/srv/qgis/plugins" >> "${PYQGIS_ENV}"
        supervisorctl restart py-qgisserver 2>/dev/null
    fi
fi
if [ -n "${PPATH_QGIS}" ]; then
    OK  "QGIS_PLUGINPATH=${PPATH_QGIS} (Fallback-Variable)"
else
    INFO "QGIS_PLUGINPATH nicht gesetzt (optional, QGSRV_SERVER_PLUGINPATH hat Vorrang)"
fi

# =============================================================================
section "9b. qgis-plugin-manager"
# =============================================================================

PYQGIS_VENV="/opt/local/py-qgis-server"
PLUGIN_MGR_BIN="${PYQGIS_VENV}/bin/qgis-plugin-manager"
SOURCES_LIST="${PLUGIN_DIR}/sources.list"

# Binary vorhanden?
if [ -x "${PLUGIN_MGR_BIN}" ]; then
    PLUGIN_MGR_VER=$("${PLUGIN_MGR_BIN}" --version 2>/dev/null | grep -oP '[\d.]+' | head -1)
    OK "qgis-plugin-manager installiert${PLUGIN_MGR_VER:+ (v${PLUGIN_MGR_VER})}"
else
    fail "qgis-plugin-manager nicht gefunden: ${PLUGIN_MGR_BIN}"
    INFO "  → ${PYQGIS_VENV}/bin/pip install qgis-plugin-manager"
    if $FIX_MODE; then
        FIX "Installiere qgis-plugin-manager in venv ..."
        "${PYQGIS_VENV}/bin/pip" install -q qgis-plugin-manager \
            && OK "qgis-plugin-manager installiert" \
            || warn "Installation fehlgeschlagen"
    fi
fi

# sources.list vorhanden und korrekt?
if [ -f "${SOURCES_LIST}" ]; then
    SOURCES_CONTENT=$(grep -v '^\s*#' "${SOURCES_LIST}" | grep -v '^\s*$' | head -1)
    if echo "${SOURCES_CONTENT}" | grep -q "plugins.qgis.org.*qgis="; then
        QGIS_VER_IN_URL=$(echo "${SOURCES_CONTENT}" | grep -oP 'qgis=\K[\d.]+')
        OK "sources.list: ${SOURCES_CONTENT} (QGIS ${QGIS_VER_IN_URL})"
    elif [ -z "${SOURCES_CONTENT}" ]; then
        fail "sources.list ist leer oder enthält nur Kommentare"
        INFO "  → QGIS-Version ermitteln und sources.list neu schreiben:"
        INFO "    QGIS_VER=\$(dpkg -l qgis-server | awk '/^ii.*qgis-server /{print \$3}' | grep -oP '\\d+\\.\\d+' | head -1)"
        INFO "    echo \"https://plugins.qgis.org/plugins/plugins.xml?qgis=\${QGIS_VER}\" > ${SOURCES_LIST}"
        if $FIX_MODE; then
            FIX "Schreibe sources.list neu ..."
            QGIS_VER=$(dpkg -l qgis-server 2>/dev/null \
                | awk '/^ii.*qgis-server /{print $3}' \
                | grep -oP '\d+\.\d+' | head -1)
            if [ -n "${QGIS_VER}" ]; then
                echo "https://plugins.qgis.org/plugins/plugins.xml?qgis=${QGIS_VER}" \
                    > "${SOURCES_LIST}"
                OK "sources.list geschrieben (QGIS ${QGIS_VER})"
            else
                warn "QGIS-Version konnte nicht ermittelt werden — sources.list nicht aktualisiert"
            fi
        fi
    else
        warn "sources.list vorhanden aber URL enthält keine QGIS-Version (?qgis=X.Y)"
        INFO "  Aktueller Inhalt: ${SOURCES_CONTENT}"
        INFO "  → QGIS_VER=\$(dpkg -l qgis-server | awk '/^ii.*qgis-server /{print \$3}' | grep -oP '\\d+\\.\\d+' | head -1)"
        INFO "    echo \"https://plugins.qgis.org/plugins/plugins.xml?qgis=\${QGIS_VER}\" > ${SOURCES_LIST}"
        if $FIX_MODE; then
            FIX "Korrigiere sources.list ..."
            QGIS_VER=$(dpkg -l qgis-server 2>/dev/null \
                | awk '/^ii.*qgis-server /{print $3}' \
                | grep -oP '\d+\.\d+' | head -1)
            if [ -n "${QGIS_VER}" ]; then
                echo "https://plugins.qgis.org/plugins/plugins.xml?qgis=${QGIS_VER}" \
                    > "${SOURCES_LIST}"
                OK "sources.list korrigiert (QGIS ${QGIS_VER})"
            else
                warn "QGIS-Version konnte nicht ermittelt werden"
            fi
        fi
    fi
else
    fail "sources.list fehlt: ${SOURCES_LIST}"
    INFO "  → QGIS_VER=\$(dpkg -l qgis-server | awk '/^ii.*qgis-server /{print \$3}' | grep -oP '\\d+\\.\\d+' | head -1)"
    INFO "    echo \"https://plugins.qgis.org/plugins/plugins.xml?qgis=\${QGIS_VER}\" > ${SOURCES_LIST}"
    if $FIX_MODE; then
        FIX "Erstelle sources.list ..."
        QGIS_VER=$(dpkg -l qgis-server 2>/dev/null \
            | awk '/^ii.*qgis-server /{print $3}' \
            | grep -oP '\d+\.\d+' | head -1)
        if [ -n "${QGIS_VER}" ]; then
            echo "https://plugins.qgis.org/plugins/plugins.xml?qgis=${QGIS_VER}" \
                > "${SOURCES_LIST}"
            chown qgis:qgis "${SOURCES_LIST}"
            OK "sources.list erstellt (QGIS ${QGIS_VER})"
        else
            warn "QGIS-Version konnte nicht ermittelt werden"
        fi
    fi
fi

# Plugin-Versionen via qgis-plugin-manager list (nur wenn Binary vorhanden)
if [ -x "${PLUGIN_MGR_BIN}" ]; then
    PLUGIN_LIST=$(QGIS_PLUGINPATH="${PLUGIN_DIR}" \
        "${PLUGIN_MGR_BIN}" list 2>/dev/null | grep -E "atlasprint|lizmap_server|wfsOutputExtension")
    if [ -n "${PLUGIN_LIST}" ]; then
        OK "qgis-plugin-manager list:"
        echo "${PLUGIN_LIST}" | sed 's/^/         /'
    else
        INFO "qgis-plugin-manager list: keine Ausgabe (Plugins noch nicht indiziert oder sources.list fehlt)"
        INFO "  → ${PLUGIN_MGR_BIN} update"
    fi
fi

# =============================================================================
section "10. xRDP"
# =============================================================================

if systemctl is-active --quiet xrdp 2>/dev/null; then
    OK "xRDP aktiv"

    [ -f "/etc/xrdp/startwm.sh" ] && OK "startwm.sh vorhanden" \
        || fail "startwm.sh fehlt: /etc/xrdp/startwm.sh"
    grep -q "startxfce4" /etc/xrdp/startwm.sh 2>/dev/null \
        && OK  "startwm.sh: startet XFCE4" \
        || warn "startwm.sh: startxfce4 nicht gefunden"

    # gdm3 bricht xRDP-Sessions
    if dpkg -l gdm3 &>/dev/null 2>&1; then
        fail "gdm3 installiert — bricht xRDP Sessions!"
        INFO "  → apt-get purge gdm3 -y && systemctl restart xrdp xrdp-sesman"
        if $FIX_MODE; then
            FIX "Entferne gdm3 ..."
            DEBIAN_FRONTEND=noninteractive apt-get purge -y gdm3
            apt-get autoremove -y
            systemctl restart xrdp xrdp-sesman
        fi
    else
        OK "gdm3 nicht installiert ✓"
    fi

    # mate-polkit für PolicyKit in XFCE4
    if [ -f "/etc/xdg/autostart/mate-polkit-autostart.desktop" ]; then
        OK "mate-polkit Autostart vorhanden"
    else
        warn "mate-polkit Autostart fehlt (/etc/xdg/autostart/mate-polkit-autostart.desktop)"
        INFO "  → Kann zu schwarzem Bildschirm nach RDP-Login führen"
    fi
else
    INFO "xRDP nicht aktiv (optional)"
fi

# =============================================================================
section "11. Verzeichnisse und Berechtigungen"
# =============================================================================

check_dir() {
    local dir="$1" expected_owner="$2"
    if [ -d "${dir}" ]; then
        actual=$(stat -c '%U' "${dir}" 2>/dev/null)
        if [ "${actual}" = "${expected_owner}" ]; then
            OK "Verzeichnis: ${dir} (${expected_owner})"
        else
            warn "Verzeichnis ${dir}: owner=${actual} (erwartet: ${expected_owner})"
            INFO "  → chown -R ${expected_owner}:${expected_owner} ${dir}"
            if $FIX_MODE; then chown -R "${expected_owner}:${expected_owner}" "${dir}"; fi
        fi
    else
        fail "Verzeichnis fehlt: ${dir}"
        if $FIX_MODE; then
            FIX "Erstelle ${dir} ..."
            mkdir -p "${dir}"
            chown "${expected_owner}:${expected_owner}" "${dir}"
        fi
    fi
}

check_dir "/srv/qgis"                            "qgis"
check_dir "/srv/data"                            "qgis"
check_dir "/srv/qgis/cache"                      "qgis"
check_dir "/srv/qgis/plugins"                    "qgis"

# SQLite-Datenbanken — QGIS braucht diese drei Dateien zum Starten
# (Ohne sie registriert lizmap_server keine API-Pfade → "paths": {})
for db in qgis-auth.db qgis.db symbology-style.db; do
    if [ -f "/srv/qgis/${db}" ]; then
        OK  "QGIS DB: /srv/qgis/${db} ✓"
    else
        fail "QGIS DB fehlt: /srv/qgis/${db}  ← KRITISCH für Plugin-Initialisierung!"
        INFO "  → python3 -c \"import sqlite3; sqlite3.connect('/srv/qgis/${db}').close()\""
        if $FIX_MODE; then
            FIX "Erstelle /srv/qgis/${db} ..."
            python3 -c "import sqlite3; sqlite3.connect('/srv/qgis/${db}').close()"
            chown qgis:qgis "/srv/qgis/${db}"
            OK  "  /srv/qgis/${db} erstellt"
        fi
    fi
done
check_dir "${LIZMAP_DIR}/lizmap/var"             "www-data"
check_dir "${LIZMAP_DIR}/lizmap/var/cache"       "www-data"
check_dir "${LIZMAP_DIR}/lizmap/var/log"         "www-data"
check_dir "${LIZMAP_DIR}/lizmap/www"             "www-data"
check_dir "${LIZMAP_DIR}/temp"                   "www-data"
check_dir "${LIZMAP_DIR}/temp/lizmap"            "www-data"

# =============================================================================
section "Zusammenfassung"
# =============================================================================

echo ""
if   [ "${ERRORS}" -eq 0 ] && [ "${WARNINGS}" -eq 0 ]; then
    echo -e "  ${GREEN}✓ Alles OK — Stack läuft korrekt.${NC}"
elif [ "${ERRORS}" -eq 0 ]; then
    echo -e "  ${YELLOW}⚠ ${WARNINGS} Warnung(en), keine kritischen Fehler.${NC}"
else
    echo -e "  ${RED}✗ ${ERRORS} Fehler  |  ${WARNINGS} Warnung(en)${NC}"
    echo ""
    if ! $FIX_MODE; then
        echo -e "  ${CYAN}Tipp: sudo bash check_installation.sh --fix${NC}"
        echo -e "  ${CYAN}      versucht Fehler automatisch zu beheben.${NC}"
    fi
fi

echo ""
echo -e "  ${CYAN}Nützliche Befehle:${NC}"
echo "  supervisorctl status"
echo "  systemctl status nginx php${PHP_VERSION}-fpm xvfb xrdp postgresql"
echo "  tail -50 /var/log/supervisor/py-qgisserver-err.log"
echo "  tail -50 /var/log/nginx/lizmap-error.log"
echo "  journalctl -u xvfb -n 20"
echo ""
