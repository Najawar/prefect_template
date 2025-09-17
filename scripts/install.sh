#!/usr/bin/env bash
set -Eeuo pipefail

# -------- Logging & Error Handling --------
_ts() { date +"%Y-%m-%d %H:%M:%S"; }
step() { echo -e "\n[$(_ts)] ▶️  $*"; }
info() { echo    "[$(_ts)]  • $*"; }
ok()   { echo    "[$(_ts)]  ✅ $*"; }
warn() { echo    "[$(_ts)]  ⚠️  $*"; }
err()  { echo    "[$(_ts)]  ❌ $*" >&2; }

last_cmd=""
trap 'err "Fehler in Zeile $LINENO beim Kommando: ${last_cmd:-<unbekannt>}"; exit 1' ERR
# shellcheck disable=SC2128
PROMPT_COMMAND='last_cmd=$BASH_COMMAND'

usage() {
  cat <<EOF
Verwendung: $(basename "$0") <projektname>

Erzeugt ein neues Prefect-Workflow-Projekt unter WORKFLOWS_DIR/<projektname>,
basierend auf den Templates in TEMPLATES_DIR. Alle Werte kommen aus
prefect-workflow.conf im Repo-Root. Keine Defaults.

Optionen:
  -h, --help   Hilfe anzeigen
EOF
  exit 0
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage
[[ $# -ne 1 ]] && { err "Es muss genau ein Projektname angegeben werden."; usage; }
RAW_NAME="$1"

# -------- Pfade & Config --------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${REPO_ROOT}/prefect-workflow.conf"
[[ -f "$CONFIG_FILE" ]] || { err "Konfigurationsdatei fehlt: $CONFIG_FILE"; exit 1; }

step "Konfiguration laden"
unset WORKFLOWS_DIR TEMPLATES_DIR SERVER_URL REGISTRY_URL POOL_NAME
while IFS='=' read -r key val; do
  [[ -z "${key// /}" || "${key:0:1}" == "#" ]] && continue
  key="$(echo "$key" | xargs)"
  val="${val%%#*}"
  val="${val%\"}"; val="${val#\"}"
  val="${val%\'}"; val="${val#\'}"
  val="$(echo "$val" | xargs)"
  case "$key" in
    WORKFLOWS_DIR) WORKFLOWS_DIR="$val" ;;
    TEMPLATES_DIR) TEMPLATES_DIR="$val" ;;
    SERVER_URL)    SERVER_URL="$val" ;;
    REGISTRY_URL)  REGISTRY_URL="$val" ;;
    POOL_NAME)     POOL_NAME="$val" ;;
    *) warn "Ignoriere unbekannten Key: $key" ;;
  esac
done < "$CONFIG_FILE"

for var in WORKFLOWS_DIR TEMPLATES_DIR SERVER_URL REGISTRY_URL POOL_NAME; do
  [[ -n "${!var:-}" ]] || { err "Fehlender Wert in Config: $var"; exit 1; }
done
[[ "$WORKFLOWS_DIR" = /* ]] || WORKFLOWS_DIR="${REPO_ROOT}/${WORKFLOWS_DIR}"
[[ "$TEMPLATES_DIR" = /* ]] || TEMPLATES_DIR="${REPO_ROOT}/${TEMPLATES_DIR}"
[[ -d "$WORKFLOWS_DIR" ]] || { err "WORKFLOWS_DIR nicht vorhanden: $WORKFLOWS_DIR"; exit 1; }
[[ -d "$TEMPLATES_DIR" ]] || { err "TEMPLATES_DIR nicht vorhanden: $TEMPLATES_DIR"; exit 1; }
ok "Konfiguration geprüft"

# -------- Projektname & Ziel --------
step "Projektnamen prüfen"
PROJECT_NAME="$(echo "$RAW_NAME" \
  | sed -e 's/Ä/Ae/g' -e 's/Ö/Oe/g' -e 's/Ü/Ue/g' -e 's/ä/ae/g' -e 's/ö/oe/g' -e 's/ü/ue/g' -e 's/ß/ss/g' \
  | tr '[:upper:]' '[:lower:]' \
  | sed -e 's/[^a-z0-9]/-/g' -e 's/--\+/-/g' -e 's/^-//' -e 's/-$//')"
[[ -n "$PROJECT_NAME" ]] || { err "Ergebnis für Projektnamen ist leer nach Sanitizing."; exit 1; }
TARGET_DIR="${WORKFLOWS_DIR}/${PROJECT_NAME}"
[[ -e "$TARGET_DIR" ]] && { err "Zielverzeichnis existiert bereits: $TARGET_DIR"; exit 1; }
ok "Projektname: ${PROJECT_NAME}"

# -------- Templates prüfen --------
step "Templates prüfen"
for f in template.Dockerfile template.requirements.txt template.dockerignore template.prefect.yaml; do
  [[ -f "${TEMPLATES_DIR}/${f}" ]] || { err "Template fehlt: ${TEMPLATES_DIR}/${f}"; exit 1; }
done
[[ -f "${TEMPLATES_DIR}/src/template_flow.py" ]] || { err "Template fehlt: ${TEMPLATES_DIR}/src/template_flow.py"; exit 1; }
ok "Templates vorhanden"

# -------- Projektstruktur anlegen --------
step "Projektordner anlegen"
mkdir -p "${TARGET_DIR}/src"
ok "Erzeuge Projekt unter: ${TARGET_DIR}"

# -------- Dateien kopieren --------
step "Basisdateien kopieren"
cp "${TEMPLATES_DIR}/template.Dockerfile"       "${TARGET_DIR}/Dockerfile"
cp "${TEMPLATES_DIR}/template.requirements.txt" "${TARGET_DIR}/requirements.txt"
cp "${TEMPLATES_DIR}/template.dockerignore"     "${TARGET_DIR}/.dockerignore"
cp "${TEMPLATES_DIR}/src/template_flow.py"      "${TARGET_DIR}/src/${PROJECT_NAME}_flow.py"
ok "Dockerfile, .dockerignore, requirements.txt und Flow-Vorlage kopiert"

# -------- venv --------
step "Python venv erstellen"
command -v python3 >/dev/null || { err "python3 nicht gefunden."; exit 1; }
python3 -m venv "${TARGET_DIR}/venv"
ok "venv erstellt"

# -------- Dependencies --------
step "Dependencies installieren"
"${TARGET_DIR}/venv/bin/pip" install --prefer-binary -r "${TARGET_DIR}/requirements.txt" || {
  warn "Mindestens eine Abhängigkeit konnte nicht installiert werden. Es kann zu Laufzeitfehlern kommen."
}
ok "Dependencies installiert (sofern verfügbar)"

# -------- prefect.yaml --------
step "prefect.yaml rendern"
sed -e "s/__PROJECT_NAME__/${PROJECT_NAME}/g" \
    -e "s/__FLOW_FILE_NAME__/${PROJECT_NAME}_flow.py/g" \
    -e "s|__PREFECT_API_URL__|${SERVER_URL}|g" \
    -e "s|__DOCKER_REGISTRY__|${REGISTRY_URL}|g" \
    -e "s/__WORK_POOL_NAME__/${POOL_NAME}/g" \
    "${TEMPLATES_DIR}/template.prefect.yaml" > "${TARGET_DIR}/prefect.yaml"
ok "prefect.yaml erzeugt"

# -------- Prefect Profile --------
step "Prefect-Profil konfigurieren"
PREFECT_BIN="${TARGET_DIR}/venv/bin/prefect"

# Projekt-lokales PREFECT_HOME (vermeidet Konflikte in ~/.prefect)
export PREFECT_HOME="${TARGET_DIR}/.prefect_home"
mkdir -p "${PREFECT_HOME}"
info "PREFECT_HOME: ${PREFECT_HOME}"

# Robustere Parser (ASCII-Only, tolerant gegenüber Box-Zeichen)
_strip_nonascii() { LC_ALL=C tr -cd '\11\12\15\40-\176'; }
active_profile() {
  "$PREFECT_BIN" profile ls 2>/dev/null \
    | _strip_nonascii \
    | awk '/\*/ { for(i=1;i<=NF;i++) if ($i=="*") { print $(i+1); exit } }'
}
profile_exists() {
  local name="$1"
  "$PREFECT_BIN" profile ls 2>/dev/null \
    | _strip_nonascii \
    | sed 's/^\s*\* /  /' \
    | awk '{$1=$1}1' \
    | awk 'NF==1 {print $1}' \
    | grep -xq "$name"
}

CUR_ACTIVE="$(active_profile || true)"
info "Aktives Profil (vorher): ${CUR_ACTIVE:-<keins>}"

# Falls das Projektprofil existiert, sicher wegschalten & löschen
if profile_exists "${PROJECT_NAME}"; then
  info "Profil '${PROJECT_NAME}' existiert → wird neu erstellt"
  if [[ "${CUR_ACTIVE}" == "${PROJECT_NAME}" ]]; then
    # Falls 'default' fehlt → anlegen
    if ! profile_exists "default"; then
      info "Default-Profil nicht vorhanden → wird angelegt"
      "$PREFECT_BIN" profile create default
      ok "Default-Profil angelegt"
    fi
    info "Wechsle zu 'default'"
    "$PREFECT_BIN" profile use default
  fi
  info "Lösche Profil '${PROJECT_NAME}'"
  "$PREFECT_BIN" profile delete "${PROJECT_NAME}"
  ok "Profil '${PROJECT_NAME}' gelöscht"
fi

# Neues Projektprofil anlegen & verwenden
if ! profile_exists "${PROJECT_NAME}"; then
  info "Erstelle Profil '${PROJECT_NAME}'"
  "$PREFECT_BIN" profile create "${PROJECT_NAME}"
  ok "Profil '${PROJECT_NAME}' erstellt"
fi

info "Aktiviere Profil '${PROJECT_NAME}'"
"$PREFECT_BIN" profile use "${PROJECT_NAME}"
ok "Profil '${PROJECT_NAME}' aktiv"

info "Setze PREFECT_API_URL=${SERVER_URL}"
"$PREFECT_BIN" config set PREFECT_API_URL="${SERVER_URL}" >/dev/null
ok "PREFECT_API_URL gesetzt"

CUR_ACTIVE="$(active_profile || true)"
info "Aktives Profil (nachher): ${CUR_ACTIVE:-<keins>}"

# -------- Abschluss --------
echo ""
ok "✅ Projekt '${PROJECT_NAME}' erfolgreich erstellt und konfiguriert!"
echo ""
echo "------------------------------------------------------------------"
echo "                  NÄCHSTE SCHRITTE (SEHR WICHTIG!)"
echo "------------------------------------------------------------------"
echo "1. Wechsle in das neue Verzeichnis (falls noch nicht geschehen):"
echo "   cd ${TARGET_DIR}"
echo ""
echo "2. Aktiviere die neue Python-Umgebung:"
echo "   source venv/bin/activate"
echo ""
echo "3. Aktiviere das für dieses Projekt erstellte Prefect-Profil:"
echo "   prefect profile use ${PROJECT_NAME}"
echo ""
echo "4. Entwickle deinen Flow in:"
echo "   src/${FLOW_FILE_NAME}"
echo ""
echo "5. Wenn du fertig bist, deploye mit einem einzigen Befehl:"
echo "   prefect deploy"
echo "------------------------------------------------------------------"
