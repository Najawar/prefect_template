#!/bin/bash

# --- Ihre Standardwerte ---
# Diese Werte werden verwendet, wenn Sie keine Flags angeben.
DEFAULT_SERVER_URL="http://13.0.0.185:4200/api"
DEFAULT_REGISTRY="registry.x4sky.net:5000"
DEFAULT_POOL_NAME="my-docker-pool"

# --- Hilfsfunktion für die Verwendung ---
usage() {
  echo "Verwendung: $0 [OPTIONEN] <projektname>"
  echo "Erstellt eine vollständige Prefect-Workflow-Umgebung."
  echo ""
  echo "Optionen:"
  echo "  -s, --server URL   Die PREFECT_API_URL (Standard: $DEFAULT_SERVER_URL)"
  echo "  -r, --registry URL Die Docker Registry URL (Standard: $DEFAULT_REGISTRY)"
  echo "  -p, --pool NAME    Der Name des Work Pools (Standard: $DEFAULT_POOL_NAME)"
  echo "  -h, --help         Diese Hilfe anzeigen"
  exit 1
}

# --- Argumente parsen ---
SERVER_URL=$DEFAULT_SERVER_URL
REGISTRY_URL=$DEFAULT_REGISTRY
POOL_NAME=$DEFAULT_POOL_NAME

while [[ "$#" -gt 0 ]]; do
  case $1 in
    -s|--server) SERVER_URL="$2"; shift ;;
    -r|--registry) REGISTRY_URL="$2"; shift ;;
    -p|--pool) POOL_NAME="$2"; shift ;;
    -h|--help) usage ;;
    *) PROJECT_NAME="$1"; break ;;
  esac
  shift
done

# Prüfen, ob ein Projektname angegeben wurde
if [ -z "$PROJECT_NAME" ]; then
  echo "Fehler: Kein Projektname angegeben."
  usage
fi

# ==============================================================================
#      BITTE ANPASSEN: Pfad zu Ihrem lokalen Vorlagen-Ordner
# ==============================================================================
TEMPLATE_DIR="/Users/iason/Desktop/prefect/template_projekt/prefect-workflow-template"

# Überprüfen, ob das Template-Verzeichnis existiert
if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "❌ Fehler: Das Template-Verzeichnis '$TEMPLATE_DIR' wurde nicht gefunden."
    echo "Bitte passen Sie die Variable 'TEMPLATE_DIR' im Skript an."
    exit 1
fi

# ==============================================================================
# HAUPTLOGIK (mit neuen Bereinigungs- und Korrektur-Schritten)
# ==============================================================================

# --- NEU: Eingabe des Projektnamens bereinigen (sanitizen) ---
ORIGINAL_PROJECT_NAME=$PROJECT_NAME
# 1. Umlaute ersetzen, 2. In Kleinbuchstaben umwandeln, 3. Ungültige Zeichen durch '-' ersetzen
# 4. Doppelte '--' entfernen, 5. '-' am Anfang/Ende entfernen
SANITIZED_PROJECT_NAME=$(echo "$PROJECT_NAME" \
    | sed -e 's/Ä/Ae/g' -e 's/Ö/Oe/g' -e 's/Ü/Ue/g' -e 's/ä/ae/g' -e 's/ö/oe/g' -e 's/ü/ue/g' -e 's/ß/ss/g' \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9]/-/g' \
    | sed -e 's/--\+/-/g' \
    | sed -e 's/^-//' -e 's/-$//')

# Wenn der Name geändert wurde, informiere den Benutzer.
if [ "$ORIGINAL_PROJECT_NAME" != "$SANITIZED_PROJECT_NAME" ]; then
    echo "ℹ️  Der Projektname wurde zu einem gültigen Format bereinigt:"
    echo "   Original: '${ORIGINAL_PROJECT_NAME}'"
    echo "   Neu:      '${SANITIZED_PROJECT_NAME}'"
fi
# Ab jetzt nur noch den bereinigten Namen verwenden
PROJECT_NAME=$SANITIZED_PROJECT_NAME

FLOW_FILE_NAME="${PROJECT_NAME}_flow.py"

# --- Prüfen, ob das Projektverzeichnis bereits existiert ---
if [ -d "$PROJECT_NAME" ]; then
    read -p "⚠️  Das Verzeichnis '${PROJECT_NAME}' existiert bereits. Möchten Sie es löschen und neu erstellen? (j/N) " response
    case "$response" in
        [jJ][aA]|[jJ])
            echo "   - Lösche existierendes Verzeichnis..."
            rm -rf "$PROJECT_NAME"
            ;;
        *)
            echo "   - Abbruch durch Benutzer."
            exit 0
            ;;
    esac
fi

# --- Start der Ausgabe ---
echo ""
echo "=================================================================="
echo " Prefect Workflow Initialisierung"
echo "=================================================================="
echo "  Projektname:      ${PROJECT_NAME}"
echo "  Prefect Server:   ${SERVER_URL}"
echo "  Docker Registry:  ${REGISTRY_URL}"
echo "  Work Pool:        ${POOL_NAME}"
echo "=================================================================="
echo ""

echo "➡️  Schritt 1: Erstelle Projektordner '${PROJECT_NAME}'..."
mkdir -p "$PROJECT_NAME/src"
cd "$PROJECT_NAME"

echo "➡️  Schritt 2: Erstelle Python Virtual Environment (venv)..."
python3 -m venv venv
if [ $? -ne 0 ]; then
    echo "❌ Fehler: Konnte die virtuelle Umgebung nicht erstellen. Ist python3-venv installiert?"
    exit 1
fi
echo "   - Python-Umgebung in './venv' erstellt."

echo "➡️  Schritt 3: Kopiere Template-Dateien..."
cp "${TEMPLATE_DIR}/template.Dockerfile" ./Dockerfile
cp "${TEMPLATE_DIR}/template.requirements.txt" ./requirements.txt
cp "${TEMPLATE_DIR}/src/template_flow.py" "./src/${FLOW_FILE_NAME}"
cp "${TEMPLATE_DIR}/template.dockerignore" ./.dockerignore
echo "   - Dockerfile, .dockerignore, requirements.txt und Flow-Vorlage kopiert."

echo "➡️  Schritt 4: Installiere Abhängigkeiten aus requirements.txt in venv..."
./venv/bin/pip install -r requirements.txt

echo "➡️  Schritt 5: Konfiguriere 'prefect.yaml' mit den angegebenen Werten..."
# --- KORREKTUR: Die fehlerhafte sed-Regel für den Dateinamen wurde entfernt ---
sed -e "s/__PROJECT_NAME__/${PROJECT_NAME}/g" \
    -e "s/__FLOW_FILE_NAME__/${FLOW_FILE_NAME}/g" \
    -e "s|__PREFECT_API_URL__|${SERVER_URL}|g" \
    -e "s|__DOCKER_REGISTRY__|${REGISTRY_URL}|g" \
    -e "s/__WORK_POOL_NAME__/${POOL_NAME}/g" \
    "${TEMPLATE_DIR}/template.prefect.yaml" > ./prefect.yaml
echo "   - 'prefect.yaml' erfolgreich erstellt."

echo "➡️  Schritt 6: Konfiguriere lokales Prefect-Profil..."
# --- Prüfen, ob das Profil bereits existiert, BEVOR es erstellt wird ---
if ./venv/bin/prefect profile ls | grep -q " ${PROJECT_NAME} "; then
    echo "   - ℹ️  Existierendes Prefect-Profil '${PROJECT_NAME}' gefunden. Es wird für einen sauberen Start neu erstellt."
    ./venv/bin/prefect profile delete "$PROJECT_NAME"
fi

echo "   - Erstelle Profil '${PROJECT_NAME}'..."
./venv/bin/prefect profile create "$PROJECT_NAME" > /dev/null
echo "   - Aktiviere Profil '${PROJECT_NAME}'..."
./venv/bin/prefect profile use "$PROJECT_NAME" > /dev/null

echo "   - Setze PREFECT_API_URL auf '${SERVER_URL}' für dieses Profil..."
./venv/bin/prefect config set PREFECT_API_URL="$SERVER_URL" > /dev/null

echo "   - Überprüfung: Aktive API-URL ist jetzt:"
./venv/bin/prefect config view | grep PREFECT_API_URL

echo ""
echo "✅ Projekt '${PROJECT_NAME}' erfolgreich erstellt und konfiguriert!"
echo ""
echo "------------------------------------------------------------------"
echo "                  NÄCHSTE SCHRITTE (SEHR WICHTIG!)"
echo "------------------------------------------------------------------"
echo "1. Wechsle in das neue Verzeichnis (falls noch nicht geschehen):"
echo "   cd ${PROJECT_NAME}"
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